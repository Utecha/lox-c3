module lox;
import lox::memory @public;
import std::io @norecurse;

//------------------------------------------------------------------------------

excuse
{
    COMPILE_ERROR,
    RUNTIME_ERROR
}

struct LoxConfig
{
    LoxReallocFn reallocate;
}

struct LoxVM
{
    ObjFun *fun;
    char *ip;
    Value *stack;
    Value *stack_top;
    sz stack_capacity;
    Obj *objects;
    sz bytes_allocated;
    LoxConfig config;
}

//------------------------------------------------------------------------------

<*
    Returns a pointer to a newly allocated and initialized LoxVM instance.

    @param [inout] config : "A pointer to a LoxConfig."
*>
fn LoxVM *new(LoxConfig *config = null)
{
    LoxReallocFn reallocate = &memory::__reallocate;
    if (config)
    {
        reallocate = config.reallocate ? config.reallocate : &memory::__reallocate;
    }

    LoxVM *vm = (LoxVM *)reallocate(null, LoxVM::size);

    vm.fun = null;
    vm.ip = null;
    vm.stack = null;
    vm.stack_top = null;
    vm.stack_capacity = 0;
    vm.objects = null;
    vm.bytes_allocated = 0;

    if (config)
    {
        mem::copy(&vm.config, config, LoxConfig::size);
        vm.config.reallocate = reallocate;
    }
    else
    {
        init_config(&vm.config);
    }

    return vm;
}

<*
    Releases the memory held by [vm], including itself.

    @param [&inout] vm : "A pointer to a LoxVM to free."
*>
fn void free(LoxVM *vm)
{
    if (!vm) return;

    value::free_objects(vm);
    memory::free(LoxVM, vm, vm);
}

<*
    Initializes [config] with the remaining arguments (if applicable).
    Otherwise, it is initialized with default values.

    @param [&inout] config : "A pointer to a LoxConfig to initialize."
    @param reallocate : "A pointer to a function for reallocating memory."

    @ensure config.reallocate != null
*>
fn void init_config(
    LoxConfig *config,
    LoxReallocFn reallocate = &memory::__reallocate
)
{
    config.reallocate = reallocate;
}

<*
    @param [&inout] vm : "A pointer to a LoxVM."
*>
fn void? interpret(LoxVM *vm, ObjFun *fun)
{
    ensure_stack(vm, fun.constants.len() + 1);

    vm.fun = fun;
    vm.ip = fun.code.data;
    return execute(vm)!;
}

//------------------------------------------------------------------------------

<*
    Reads a byte from the [vm]'s instruction pointer.

    @param [&inout] vm : "A pointer to a LoxVM."
*>
macro char read_byte(LoxVM *vm) @local
{
    return *vm.ip++;
}

<*
    Reads through 2 bytes from the [vm]'s instruction pointer.

    @param [&inout] vm : "A pointer to a LoxVM."
*>
macro ushort read_short(LoxVM *vm) @local
{
    vm.ip += 2;
    return (ushort)((vm.ip[-2] << 8) | vm.ip[-1]);
}

<*
    Reads a constant from the running functions constants pool.

    @param [&inout] vm : "A pointer to a LoxVM."
*>
macro Value read_constant(LoxVM *vm) @local
{
    return vm.fun.constants[read_short(vm)];
}

<*
    Pushes [value] onto the top of the stack.

    @param [&inout] vm : "A pointer to a LoxVM."
*>
macro void stack_push(LoxVM *vm, Value value) @local
{
    *vm.stack_top++ = value;
}

<*
    Pops the Value from the top of the stack.

    @param [&inout] vm : "A pointer to a LoxVM."
*>
macro Value stack_pop(LoxVM *vm) @local
{
    return *(--vm.stack_top);
}

<*
    Peeks back into the Value stack by the given [distance].

    @param [&inout] vm : "A pointer to a LoxVM."

    @require [distance] distance >= 0 && distance <= 2
        : "Cannot peek back more than two values or peek forward (negative distance.)"
*>
macro Value stack_peek(LoxVM *vm, int distance = 0) @local
{
    return vm.stack_top[-1 - distance];
}

<*
    Resets the stack pointer to the beginning of the stack.

    @param [&inout] vm : "A pointer to a LoxVM."
*>
macro void stack_reset(LoxVM *vm) @local
{
    vm.stack_top = vm.stack;
}

<*
    Performs a binary operation on the top two values on the stack.
    If one or both values are not a numeric value, a runtime error
    excuse is returned.

    @param [&inout] vm : "A pointer to a LoxVM."
*>
macro void? @binary_op(LoxVM *vm, #valtype, #op) @local
{
    if (!value::is_num(stack_peek(vm)) || !value::is_num(stack_peek(vm, 1)))
    {
        return rt_error(
            vm,
            "Binary (non-addition) operands must both be numbers."
        )~;
    }

    double b = value::as_num(stack_pop(vm));
    double a = value::as_num(stack_pop(vm));
    stack_push(vm, #valtype(#op(a, b)));
}

<*
    Ensures that the stack has at least [needed] slots available. If the
    pointer is moved when resizing, the stack top is updated to point to
    the same relative distance into the new stack as it was in the old
    one.

    @param [&inout] vm : "A pointer to a LoxVM."
    @param needed : "The expected number of slots needed."
*>
fn void ensure_stack(LoxVM *vm, sz needed) @local
{
    if (vm.stack_capacity >= needed) return;

    sz capacity = memory::next_power_of_two(needed);
    Value *old_stack = vm.stack;

    vm.stack = memory::realloc(Value, vm, vm.stack, vm.stack_capacity, capacity);
    vm.stack_capacity = capacity;

    // Recalculate any pointers that still point into the old stack to the same
    // relative distance in the new stack.
    if (vm.stack != old_stack)
    {
        vm.stack_top = vm.stack - (vm.stack_top - old_stack);
    }
}

<*
    Reports a runtime error and returns the excuse for exiting the
    interpreter loop.

    @param [&inout] vm : "A pointer to a LoxVM."
    @param fmt : "The format string for the error message."
    @param args : "The arguments for the format string (if applicable.)"
*>
fn fault rt_error(LoxVM *vm, String fmt, args...) @local
{
    io::eprintf("[ Runtime ] ");
    io::eprintfn(fmt, ...args);

    sz instruction = vm.ip - vm.fun.code.data - 1;
    int line = value::get_line(vm.fun, instruction);

    io::eprintfn("{ ln %d } in script");
    stack_reset(vm);

    return RUNTIME_ERROR;
}

<*
    Returns whether the given [value] is falsey.

    @param value : "The value to determine is falsey."
*>
fn bool is_falsey(Value value) @local
{
    return value::is_nil(value) || (value::is_bool(value) && !value::as_bool(value));
}

<*
    Executes the function held by [vm] through the bytecode interpreter.

    @param [&inout] vm : "A pointer to a LoxVM."
*>
fn void? execute(LoxVM *vm) @local
{
    for (;;)
    {
        $switch:
            $case $feat(DEBUG) &&& debug::TRACE_EXECUTION:
                debug::dump_stack(vm);
                debug::dump_instruction(vm.fun, vm.ip - vm.fun.code.data);

            $case $feat(DEBUG) &&& debug::DUMP_STACK:
                debug::dump_stack(vm);
        $endswitch

        OpCode instruction;
        switch (instruction = (OpCode)read_byte(vm))
        {
            case NIL:
                stack_push(vm, value::NIL);

            case FALSE:
                stack_push(vm, value::FALSE);

            case TRUE:
                stack_push(vm, value::TRUE);

            case POP:
                stack_pop(vm);

            case NEGATE:
                if (!value::is_num(stack_peek(vm)))
                {
                    return rt_error(
                        vm,
                        "Unary negation operand must be a number."
                    )~;
                }

                stack_push(vm, value::make_num(-value::as_num(stack_pop(vm))));

            case NOT:
                stack_push(vm, value::make_bool(is_falsey(stack_pop(vm))));

            case ADD:
                @binary_op(vm, value::make_num, math::add)!;

            case SUB:
                @binary_op(vm, value::make_num, math::sub)!;

            case MUL:
                @binary_op(vm, value::make_num, math::mul)!;

            case DIV:
                @binary_op(vm, value::make_num, math::div)!;

            case MOD:
                @binary_op(vm, value::make_num, math::mod)!;

            case GREATER:
                @binary_op(vm, value::make_bool, math::gt)!;

            case LESS:
                @binary_op(vm, value::make_bool, math::lt)!;

            case EQUAL:
                Value b = stack_pop(vm);
                Value a = stack_pop(vm);
                stack_push(vm, value::make_bool(value::equals(a, b)));

            case AND:
                ushort offset = read_short(vm);
                Value condition = stack_peek(vm);

                if (is_falsey(condition))
                {
                    vm.ip += offset;
                }
                else
                {
                    stack_pop(vm);
                }


            case OR:
                ushort offset = read_short(vm);
                Value condition = stack_peek(vm);

                if (is_falsey(condition))
                {
                    stack_pop(vm);
                }
                else
                {
                    vm.ip += offset;
                }

            case RETURN:
                value::print(stack_pop(vm));
                io::printn();
                return;

            case CONSTANT:
                stack_push(vm, read_constant(vm));
        }
    }
}
