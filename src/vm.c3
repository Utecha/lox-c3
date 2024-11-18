module lox::vm;
import lox::chunk;
import lox::common;
import lox::compiler;
import lox::error;
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

fn Value peek(int distance) @local
{
    return *(vm.stack_top - 1 - distance);
}

fn bool is_falsey(Value value) @local
{
    return is_nil(value) || (is_bool(value) && !as_bool(value));
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
    if (!is_number(peek(0)) || !is_number(peek(1)))
    {
        error::runtime("Binary (non-addition) operands must be numbers");
        return VMResult.RUNTIME_ERROR?;
    }

    double b = as_number(pop());
    double a = as_number(pop());

    switch (op)
    {
        case '+':   push(number_val(a + b));
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
