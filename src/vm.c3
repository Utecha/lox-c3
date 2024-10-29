module lox::vm;
import lox::chunk;
import lox::common;
import lox::compiler;
import lox::value;
import std::io @norecurse;

//===----------------------------------------------------------------------===//
// Lox | Virtual Machine
//===----------------------------------------------------------------------===//

/* Maximum stack size */
const uint STACK_MAX = 256;

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

/*** INTERPRETER SECTION ***/

/* (Later) compiles the bytecode into [chunk] and calls run_interpreter() */
fn void! interpret(char *source)
{
    compiler::compile(source);
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
    Value b = pop();
    Value a = pop();

    switch (op)
    {
        case '+':   push(a + b);
        case '-':   push(a - b);
        case '*':   push(a * b);
        case '/':
            if (b == 0) return VmResult.RUNTIME_ERROR?;
            push(a / b);
        default:    unreachable();
    }
}

/* Runs the [vm] interpreter loop on the current compiled bytecode [chunk] */
fn void! run_interpreter()
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
            case NEGATE:
                push(-*(--vm.stack_top));
            case ADD:
                binary_op('+')!;
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