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

//===----------------===//
// Lox Virtual Machine
//===----------------===//

<* Maximum size of the VM's 'Value' stack before an overflow would occur *>
const uint STACK_MAX = 256;

<* Fault values returned by the VM under different error conditions (compiler, runtime) *>
fault VMResult
{
    COMPILE_ERROR,
    RUNTIME_ERROR
}

<* Structure representing the Lox Virtual Machine *>
struct LoxVM
{
    Chunk *chunk;
    char *ip;
    Value[STACK_MAX] stack;
    Value *stack_top;
    Table globals;
    Table strings;
    Obj *objects;
}

<* Global Lox VM *>
LoxVM vm @builtin;

<*
    Reset's the pointer [vm.stack_top] to the beginning of the VM's [stack].

    @ensure vm.stack_top != null
*>
fn void reset_stack() @private
{
    vm.stack_top = &vm.stack[0];
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

    Chunk chunk;
    chunk.init();
    defer chunk.free();

    if (!compiler::compile(source, &chunk))
        { return VMResult.COMPILE_ERROR?; }

    vm.chunk = &chunk;
    vm.ip = vm.chunk.code;

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

    @require vm.ip != null
    @ensure return != null
*>
macro read_byte() @local
{
    return *vm.ip++;
}

<*
    Macro to read a constant from the VM's chunk constants pool.

    @require vm.chunk.constants.values != null
    @ensure return.typeid == Value.typeid
*>
macro read_constant() @local
{
    return vm.chunk.constants.values[read_byte()];
}

<*
    Macro to read a string from the VM's chunk constants pool.

    @require vm.chunk.constants.values != null
    @ensure return.typeid == ObjString.typeid
*>
macro read_string() @local
{
    return as_string(read_constant());
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

            vm.chunk.disassemble_instruction((int)(vm.ip - vm.chunk.code));
        $endif

        OpCode instruction;
        switch (instruction = (OpCode)read_byte())
        {
            case CONSTANT:
            {
                Value constant = read_constant();
                push(constant);
            }
            case DEFINE_GLOBAL:
            {
                ObjString *name = read_string();
                vm.globals.set(name, peek(0));
                pop();
            }
            case GET_GLOBAL:
            {
                ObjString *name = read_string();
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
                ObjString *name = read_string();
                if (vm.globals.set(name, peek(0)))
                {
                    vm.globals.delete(name);
                    error::runtime("Undefined variable '%s'", (ZString)name.chars);
                    return VMResult.RUNTIME_ERROR?;
                }
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
            case RETURN:    return;
        }
    }
}
