module lox::vm;
import lox::chunk;
import lox::common;
import lox::compiler;
import lox::error;
import lox::memory;
import lox::object;
import lox::table;
import lox::value;
import std::io @norecurse;
import std::time;

//===----------------===//
// Lox Virtual Machine
//===----------------===//

<* The maximum number of call frames allowed at any given point *>
const uint FRAMES_MAX = 64;

<* The maximum size of the VMs 'Value' stack *>
const uint STACK_MAX = FRAMES_MAX * UINT8_COUNT;

<* Fault values returned by the VM under different error conditions (compiler, runtime) *>
fault VMResult
{
    COMPILE_ERROR,
    RUNTIME_ERROR
}

<*
    Structure representing a call frame.

    When a function is called and it is loaded onto the VMs stack, the VM
    records the location of the first slot where the functions locals begin.

    Instructions for working with locals will access them by a slot index
    relative to that location, rather than relative to the bottom of the
    stack.

    These values are calculated at compile time. At runtime, the relative
    slot is then converted to an absolute stack index. This is what is
    known as a 'call frame'. It is a runtime view of a functions instructions
    relative to the instructions surrounding it.
*>
struct CallFrame
{
    ObjClosure *closure;
    char *ip;
    Value *slots;
}

<*
    Structure representing the Lox Virtual Machine

    The VM is essentially the global state machine for a given script. It manages the
    compilation of the users source code, and loads the resulting data into itself
    to run inside the interpreter.

    It also handles all of the memory that is allocated and needs to be freed during compile
    time, runtime, and at the end of the program.
*>
struct LoxVM
{
    /*  */
    CallFrame[FRAMES_MAX] frames;
    int frame_count;

    Value[STACK_MAX] stack;
    Value *stack_top;

    Table globals;
    Table strings;
    ObjUpvalue *open_upvalues;
    Obj *objects;
}

<* Global Lox VM *>
LoxVM vm @builtin;

<*
    Native 'clock' function. This returns the elapsed time since the program
    began (or since the function was called), in seconds.

    @param argc "The argument count"
    @param [&in] args "The arguments passed into the function"
*>
fn Value clock_native(int argc, Value *args)
{
    return number_val(time::now().to_seconds() / (double)time::SEC);
}

<*
    Reset's the pointer [vm.stack_top] to the beginning of the VM's [stack].

    @ensure vm.stack_top != null
*>
fn void reset_stack() @private
{
    vm.stack_top = &vm.stack[0];
    vm.frame_count = 0;
    vm.open_upvalues = null;
}

<*
    Initializes the global Lox VM.
*>
fn void init()
{
    reset_stack();

    vm.globals.init();
    vm.strings.init();
    vm.objects = null;

    define_native("clock", &clock_native);
}

<*
    Free's the associated data for the global Lox VM.
*>
fn void free()
{
    vm.globals.free();
    vm.strings.free();
    memory::free_objects();
}

<*
    Run's the compiler and loads the compiled bytecode into the VM and passes on
    to 'run_interpreter' for execution of the bytecode.

    Returns a void optional. This means that the actual return value is void. In the event
    of an error, it returns the optional result (also known as an excuse).

    @param [in] source "The source code to compile and execute"
*>
fn void! interpret(char *source)
{
    if (source == null) return;

    ObjFunction *function = compiler::compile(source);
    if (function == null) return VMResult.COMPILE_ERROR?;

    push(obj_val(function));
    ObjClosure *closure = object::new_closure(function);
    pop();
    push(obj_val(closure));
    call(closure, 0);

    return run_interpreter()!;
}

<*
    Pushes a [value] onto the VMs 'Value' [stack].

    @require vm.stack_top != null
*>
fn void push(Value value)
{
    *vm.stack_top = value;
    vm.stack_top++;
}

<*
    Pop's a 'Value' from the VMs 'Value' [stack].

    @require vm.stack_top != null
*>
fn Value pop()
{
    vm.stack_top--;
    return *vm.stack_top;
}

<*
    Returns the (Value) found on the VM's stack at a given distance
    without popping values off of the stack.

    @param distance "How far back into the stack to view"
*>
fn Value peek(int distance) @local
{
    return *(vm.stack_top - 1 - distance);
}

<*
    Handles the loading of a function for a call expression.

    This initializes the next call frame on the VMs stack.

    @param [&in] closure "A reference to the closure being called"
    @param argc "The argument count of the function"
*>
fn bool call(ObjClosure *closure, int argc) @local
{
    if (argc != closure.function.arity)
    {
        error::runtime(
            "Expected %d arguments, but got %d instead",
            closure.function.arity,
            argc
        );
        return false;
    }

    if (vm.frame_count == FRAMES_MAX)
    {
        error::runtime("Stack overflow");
        return false;
    }

    CallFrame *frame = &vm.frames[vm.frame_count++];
    frame.closure = closure;
    frame.ip = closure.function.chunk.code;
    frame.slots = vm.stack_top - argc - 1;
    return true;
}

<*
    Handles the dispatching of a call expression based on the type of object
    the call is being made on (such as a class, function, or method).
*>
fn bool call_value(Value callee, int argc) @local
{
    if (is_obj(callee))
    {
        switch (obj_type(callee))
        {
            case CLOSURE:
                return call(as_closure(callee), argc);
            case NATIVE:
            {
                NativeFn native = as_native(callee);
                Value result = native(argc, vm.stack_top - argc);
                vm.stack_top -= argc + 1;
                push(result);
                return true;
            }
            default:
                break; // Non-callable object type
        }
    }

    error::runtime("You can only call classes, functions, or methods on an instance");
    return false;
}

<*
    Creates and returns a new (ObjUpvalue) when a [local] is captured. If the upvalue
    already exists, it is returned instead.

    @param [&in] local "The local variable to capture"
*>
fn ObjUpvalue *capture_upvalue(Value *local)
{
    ObjUpvalue *prev_upvalue = null;
    ObjUpvalue *upvalue = vm.open_upvalues;

    while (upvalue != null && upvalue.location > local)
    {
        prev_upvalue = upvalue;
        upvalue = upvalue.next;
    }

    if (upvalue != null && upvalue.location == local)
    {
        return upvalue;
    }

    ObjUpvalue *created_upvalue = object::new_upvalue(local);

    if (prev_upvalue == null)
        { vm.open_upvalues = created_upvalue; }
    else
        { prev_upvalue.next = created_upvalue; }

    return created_upvalue;
}

<*
    When a local variable is captured, it is made into an upvalue. Before that upvalue leaves the stack,
    it is closed over, which hoists it onto the heap so that it may still be referenced.

    @param [&in] last "A pointer to the value at the last slot to check for upvalues"
*>
fn void close_upvalues(Value *last)
{
    while (vm.open_upvalues != null && vm.open_upvalues.location >= last)
    {
        ObjUpvalue *upvalue = vm.open_upvalues;
        upvalue.closed = *upvalue.location;
        upvalue.location = &upvalue.closed;
        vm.open_upvalues = upvalue.next;
    }
}

<*
    Takes in a [name] and a pointer to a [function], pushing them onto the stack long
    enough to add them to the VMs global variables table.

    It then immediately pops them off the stack to prevent them from being freed during
    a GC cycle, as both 'object::copy_string()' and 'object::new_native()' dynamically allocate
    memory using the custom 'reallocate()' function. That function is the the main allocator
    used by the GC and when it is called, can potentially trigger the GC to run a collection
    cycle.

    Since natives are stored in the globals table, they are freed along with the rest of
    the globals.
*>
fn void define_native(String name, NativeFn function) @local
{
    push(obj_val(object::copy_string(name, name.len)));
    push(obj_val(object::new_native(function)));
    vm.globals.set(as_string(vm.stack[0]), vm.stack[1]);
    pop();
    pop();
}

<*
    Returns 'true' if the provided [value] is considered 'falsey'. Otherwise,
    it returns 'false'.

    'Falsey' in Lox is similar to that of Ruby. 'nil' and 'false' are falsey
    values, while every other value is 'truthy'.

    @param value "The value to check for falsiness"
*>
fn bool is_falsey(Value value) @local
{
    return is_nil(value) || (is_bool(value) && !as_bool(value));
}

<*
    Concatenates two (ObjString)s on the stack, taking ownership of the
    characters and returning a newly combined (ObjString).
*>
fn void concatenate() @local
{
    ObjString *b = as_string(pop());
    ObjString *a = as_string(pop());

    int len = a.length + b.length;
    char *chars = memory::allocate(char, len + 1);
    mem::copy(chars, a.chars, a.length);
    mem::copy(chars + a.length, b.chars, b.length);
    chars[len] = '\0';

    ObjString *result = object::take_string(chars, len);
    push(obj_val(result));
}

<*
    Macro to read a byte from the VMs bytecode array.

    @param [&inout] frame "A reference to the call frame to read a byte from"
    @ensure return != null
*>
macro read_byte(CallFrame *frame) @local
{
    return *frame.ip++;
}

<*
    Macro to read a short from the VMs bytecode array.

    @param [&inout] frame "A reference to the call frame to read a short from"
    @ensure return != null
*>
macro read_short(CallFrame *frame) @local
{
    frame.ip += 2;
    return (ushort)((frame.ip[-2] << 8) | frame.ip[-1]);
}

<*
    Macro to read a constant from the VMs chunk constants pool.

    @param [&inout] frame "A reference to the call frame to read a constant from"
    @ensure return.typeid == Value.typeid
*>
macro read_constant(CallFrame *frame) @local
{
    return frame.closure.function.chunk.constants.values[read_byte(frame)];
}

<*
    Macro to read a string from the VM's chunk constants pool.

    @param [&inout] frame "A reference to the call frame to read a string from"
    @ensure return.typeid == ObjString.typeid
*>
macro read_string(CallFrame *frame) @local
{
    return as_string(read_constant(frame));
}

<*
    Macro that pops the top 2 values from the stack, evaluates the
    binary operation on those values based on the provided [op], and
    pushes the result onto the [stack].

    @param op "The operator to use for the binary operation, passed as a char"
*>
macro binary_op(char op) @local
{
    if (!is_number(peek(0)) || !is_number(peek(1)))
    {
        error::runtime("Binary (non-addition) operands must be numbers");
        return VMResult.RUNTIME_ERROR?;
    }

    double b = as_number(pop());
    double a = as_number(pop());

    switch (op)
    {
        case '-':   push(number_val(a - b));
        case '*':   push(number_val(a * b));
        case '/':   push(number_val(a / b));
        case '%':   push(number_val(a % b));
        case '>':   push(bool_val(a > b));
        case '<':   push(bool_val(a < b));
        default:
        {
            error::runtime("Unknown binary operator");
            return VMResult.RUNTIME_ERROR?;
        }
    }
}

<*
    Interprets the bytecode instructions for the Lox VM.
*>
fn void! run_interpreter() @private
{
    CallFrame *frame = &vm.frames[vm.frame_count - 1];

    for (;;)
    {
        $if $feature(DEBUG) &&& TRACE_INSTRUCTIONS:
            io::eprintf("        ");
            for (Value *slot = &vm.stack[0]; slot < vm.stack_top; slot++)
            {
                io::eprintf("[ ");
                value::print(*slot, io::stderr());
                io::eprintf(" ]");
            }
            io::eprintfn("");

            frame.closure.function.chunk.disassemble_instruction(
                (int)(frame.ip - frame.closure.function.chunk.code)
            );
        $endif

        OpCode instruction;
        switch (instruction = (OpCode)read_byte(frame))
        {
            /* Jump Instructions */
            case JUMP:
            {
                ushort offset = read_short(frame);
                frame.ip += offset;
            }
            case JUMP_IF_FALSE:
            {
                ushort offset = read_short(frame);
                if (is_falsey(peek(0))) frame.ip += offset;
            }
            case LOOP:
            {
                ushort offset = read_short(frame);
                frame.ip -= offset;
            }

            /* Constant Instructions */
            case CLOSURE:
            {
                ObjFunction *function = as_function(read_constant(frame));
                ObjClosure *closure = object::new_closure(function);
                push(obj_val(closure));

                for (int i = 0; i < closure.upvalue_count; i++)
                {
                    char is_local = read_byte(frame);
                    char index = read_byte(frame);

                    if (is_local)
                    {
                        closure.upvalues[i] = capture_upvalue(frame.slots + index);
                    }
                    else
                    {
                        closure.upvalues[i] = frame.closure.upvalues[index];
                    }
                }
            }
            case CONSTANT:
            {
                Value constant = read_constant(frame);
                push(constant);
            }
            case DEFINE_GLOBAL:
            {
                ObjString *name = read_string(frame);
                vm.globals.set(name, peek(0));
                pop();
            }
            case GET_GLOBAL:
            {
                ObjString *name = read_string(frame);
                Value value;

                if (!vm.globals.get(name, &value))
                {
                    error::runtime("Undefined variable '%s'", (ZString)name.chars);
                    return VMResult.RUNTIME_ERROR?;
                }

                push(value);
            }
            case SET_GLOBAL:
            {
                ObjString *name = read_string(frame);
                if (vm.globals.set(name, peek(0)))
                {
                    vm.globals.delete(name);
                    error::runtime("Undefined variable '%s'", (ZString)name.chars);
                    return VMResult.RUNTIME_ERROR?;
                }
            }
            case GET_UPVALUE:
            {
                char slot = read_byte(frame);
                push(*frame.closure.upvalues[slot].location);
            }
            case SET_UPVALUE:
            {
                char slot = read_byte(frame);
                *frame.closure.upvalues[slot].location = peek(0);
            }

            /* Byte Instructions */
            case CALL:
            {
                int argc = read_byte(frame);
                if (!call_value(peek(argc), argc))
                    { return VMResult.RUNTIME_ERROR?; }

                frame = &vm.frames[vm.frame_count - 1];
            }
            case GET_LOCAL:
            {
                char slot = read_byte(frame);
                push(frame.slots[slot]);
            }
            case SET_LOCAL:
            {
                char slot = read_byte(frame);
                frame.slots[slot] = peek(0);
            }

            /* Simple Instructions */
            case CLOSE_UPVALUE:
            {
                close_upvalues(vm.stack_top - 1);
                pop();
            }
            case NIL:       push(nil_val());
            case TRUE:      push(bool_val(true));
            case FALSE:     push(bool_val(false));
            case NOT:
            {
                /* (NOT) is able to receive the same optimization as (NEGATE) */
                $if OPTIMIZE_NOT:
                    push(bool_val(is_falsey(*(--vm.stack_top))));
                $else
                    push(bool_val(is_falsey(pop())));
                $endif
            }
            case EQUAL:
            {
                Value b = pop();
                Value a = pop();

                push(bool_val(value::equal(a, b)));
            }
            case GREATER:   binary_op('>')!;
            case LESS:      binary_op('<')!;
            case TERNARY:
            {
                Value falsey = pop();
                Value truthy = pop();

                !is_falsey(pop()) ? push(truthy) : push(falsey);
            }
            case NEGATE:
            {
                if (!is_number(peek(0)))
                {
                    error::runtime("Unary operand must be a number");
                    return VMResult.RUNTIME_ERROR?;
                }

                $if OPTIMIZE_NEGATION:
                    push(number_val(-as_number(*(--vm.stack_top))));
                $else
                    push(number_val(-as_number(pop())));
                $endif
            }
            case ADD:
            {
                if (is_string(peek(0)) && is_string(peek(1)))
                {
                    concatenate();
                }
                else if (is_number(peek(0)) && is_number(peek(1)))
                {
                    double b = as_number(pop());
                    double a = as_number(pop());

                    push(number_val(a + b));
                }
                else
                {
                    error::runtime("Binary (addition) operands must be numbers or strings, but not both.");
                    return VMResult.RUNTIME_ERROR?;
                }
            }
            case SUBTRACT:  binary_op('-')!;
            case MULTIPLY:  binary_op('*')!;
            case DIVIDE:    binary_op('/')!;
            case MODULUS:   binary_op('%')!;
            case POP:       pop();
            case PRINT:
            {
                value::print(pop());
                io::printn();
            }
            case RETURN:
            {
                Value result = pop();
                close_upvalues(frame.slots);
                vm.frame_count--;

                if (vm.frame_count == 0)
                {
                    pop();
                    return;
                }

                vm.stack_top = frame.slots;
                push(result);

                frame = &vm.frames[vm.frame_count - 1];
            }
        }
    }
}
