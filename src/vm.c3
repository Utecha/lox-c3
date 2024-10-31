module lox::vm;
import lox::chunk;
import lox::common;
import lox::compiler;
import lox::memory;
import lox::object;
import lox::value;
import std::io @norecurse;

//===----------------------------------------------------------------------===//
// Lox | Virtual Machine
//===----------------------------------------------------------------------===//

/* Maximum stack size */
const uint STACK_MAX = 512;

/* Faults thrown to signal compiler/runtime errors */
fault VmResult
{
    COMPILE_ERROR,
    RUNTIME_ERROR,
}

/* Data structure for the Lox Virtual Machine */
struct Vm
{
    Chunk *chunk;
    char *ip;
    Value[STACK_MAX] stack;
    Value *stack_top;
    Obj *objects;
}

/* Global VM */
Vm vm @builtin;

/* Initializes the global [vm] */
fn void init()
{
    reset_stack();
}

/* Free's the heap-allocated data of the global [vm] */
fn void free()
{

}

/* Reset the [stack_top] pointer to the beginning of the [stack] */
fn void reset_stack() @local
{
    vm.stack_top = &vm.stack[0];
}

fn void runtime_error(String message, args...) @private
{
    io::eprintf("Runtime Error: ");
    io::eprintfn(message, ...args);

    int instruction = (int)(vm.ip - vm.chunk.code - 1);
    int line = vm.chunk.get_line(instruction);
    io::eprintfn("[line %d] in script", line);

    reset_stack();
}

/* Push a [value] onto the [stack] */
fn void push(Value value)
{
    *vm.stack_top = value;
    vm.stack_top++;
}

/* Pop a [value] from the [stack] */
fn Value pop()
{
    vm.stack_top--;
    return *vm.stack_top;
}

/* Peek at a [value] by [distance] in the [stack] */
fn Value peek(int distance) @private
{
    return vm.stack_top[-1 - distance];
}

/* Determines whether or not a [value] is 'falsey' */
fn bool is_falsey(Value value) @private
{
    return is_nil(value) || (is_bool(value) && !as_bool(value));
}

/* Concatenates two (ObjString)s */
fn void concatenate() @private
{
    ObjString *b = as_string(pop());
    ObjString *a = as_string(pop());

    int len = a.len + b.len;
    char *chars = memory::allocate(char, len + 1);
    mem::copy(chars, a.chars, a.len);
    mem::copy(chars + a.len, b.chars, b.len);
    chars[len] = '\0';

    ObjString *result = object::take_string(chars, len);
    push(obj_val(result));
}

/*** INTERPRETER SECTION ***/

/* (Later) compiles the bytecode into [chunk] and calls run_interpreter() */
fn void! interpret(char *source)
{
    Chunk chunk;
    chunk.init();
    defer chunk.free();

    if (!compiler::compile(source, &chunk))
        { return VmResult.COMPILE_ERROR?; }

    vm.chunk = &chunk;
    vm.ip = vm.chunk.code;
    return run_interpreter()!;
}

/* Reads a byte from the compiled bytecode [chunk] */
fn char read_byte() @local
{
    return *vm.ip++;
}

/* Retrieves a constant (Value) from the constants pool of a compiled bytecode [chunk] */
fn Value read_constant() @local
{
    return vm.chunk.constants.values[read_byte()];
}

/* Retrieves a constant long (Value) from the constants pool of a compiled bytecode [chunk] */
fn Value read_constant_long() @local
{
    int index = (vm.chunk.code[(read_byte() + 1) << 16]) |
                (vm.chunk.code[(read_byte() + 2) << 8]) |
                (vm.chunk.code[read_byte() + 3]);
    return vm.chunk.constants.values[index];
}

/* Performs binary operations on values based on the [op] provided */
fn void! binary_op(char op) @local
{
    if (!is_number(peek(0)) && !is_number(peek(1)))
    {
        runtime_error("Binary (non-addition) operands must be numbers");
        return VmResult.RUNTIME_ERROR?;
    }

    double b = as_number(pop());
    double a = as_number(pop());

    switch (op)
    {
        case '/':
        {
            if (b == 0)
            {
                runtime_error("Cannot divide by zero");
                return VmResult.RUNTIME_ERROR?;
            }
            push(number_val(a / b));
        }
        // case '+':   push(number_val(a + b));
        case '-':   push(number_val(a - b));
        case '*':   push(number_val(a * b));
        case '>':   push(bool_val(a > b));
        case '<':   push(bool_val(a < b));
        default:    unreachable();
    }
}

/* Runs the [vm] interpreter loop on the current compiled bytecode [chunk] */
fn void! run_interpreter() @private
{
    for (;;)
    {
        $if (TRACE_INSTRUCTIONS):
            io::eprint("        ");
            for (Value *slot = &vm.stack[0]; slot < vm.stack_top; slot++)
            {
                io::eprint("[ ");
                value::print(*slot, io::stderr());
                io::eprint(" ]");
            }
            io::eprint("\n");
            vm.chunk.disassemble_instruction((int)(vm.ip - vm.chunk.code));
        $endif

        OpCode instruction;
        switch (instruction = to_code(read_byte()))
        {
            case CONSTANT_LONG:
                Value constant = read_constant_long();
                push(constant);
            case CONSTANT:
                Value constant = read_constant();
                push(constant);
            case TERNARY:
                Value falsey = pop();
                Value truthy = pop();

                !is_falsey(pop()) ? push(truthy) : push(falsey);
            case EQUAL:
                Value b = pop();
                Value a = pop();

                push(bool_val(value::equal(a, b)));
            case GREATER:
                binary_op('>')!;
            case LESS:
                binary_op('<')!;
            case NIL:
                push(nil_val());
            case TRUE:
                push(bool_val(true));
            case FALSE:
                push(bool_val(false));
            case NOT:
                push(bool_val(is_falsey(pop())));
            case NEGATE:
                if (!is_number(peek(0)))
                {
                    runtime_error("Negation operand must be a number");
                    return VmResult.RUNTIME_ERROR?;
                }

                push(number_val(-as_number(*(--vm.stack_top))));
            case ADD:
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
                    runtime_error("Binary (addition) operands must be numbers or strings.");
                    return VmResult.RUNTIME_ERROR?;
                }
            case SUBTRACT:
                binary_op('-')!;
            case MULTIPLY:
                binary_op('*')!;
            case DIVIDE:
                binary_op('/')!;
            case RETURN:
                value::print(pop());
                io::printn();
                return;
        }
    }
}
