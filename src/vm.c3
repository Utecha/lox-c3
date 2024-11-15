module lox::vm;
import lox::chunk;
import lox::common;
import lox::compiler;
import lox::value;
import std::io @norecurse;

//===----------------===//
// Lox Virtual Machine
//===----------------===//

/* Maximum size of the VM's 'Value' stack before an overflow would occur */
const uint STACK_MAX = 256;

/* Fault values returned by the VM under different error conditions (compiler, runtime) */
fault VMResult
{
    COMPILE_ERROR,
    RUNTIME_ERROR
}

/* Structure representing the Lox Virtual Machine */
struct LoxVM
{
    Chunk *chunk;
    char *ip;
    Value[STACK_MAX] stack;
    Value *stack_top;
}

/* Global Lox VM */
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
}

<*
    Free's the associated data for the global Lox VM.
*>
fn void free()
{

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
    compiler::compile(source);
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
    Macro that pops the top 2 values from the stack, evaluates the
    binary operation on those values based on the provided [op], and
    pushes the result onto the [stack].
*>
macro binary_op(op) @local
{
    Value b = pop();
    Value a = pop();

    switch (op)
    {
        case '+':   push(a + b);
        case '-':   push(a - b);
        case '*':   push(a * b);
        case '/':   push(a / b);
        case '%':   push(a % b);
        default:
        {
            io::eprintfn("[ RUNTIME ] Error: Unknown binary operator");
            reset_stack();
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
        $if $feature(DEBUG) && TRACE_INSTRUCTIONS:
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

            case NEGATE:
            {
                $if OPTIMIZE_NEGATION:
                    push(-*(--vm.stack_top));
                $else
                    push(-pop());
                $endif
            }

            case ADD:       binary_op('+')!;
            case SUBTRACT:  binary_op('-')!;
            case MULTIPLY:  binary_op('*')!;
            case DIVIDE:    binary_op('/')!;
            case MODULUS:   binary_op('%')!;

            case RETURN:
            {
                value::print(pop());
                io::printn();
                return;
            }
        }
    }
}
