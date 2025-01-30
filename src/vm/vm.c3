module lox::vm @private;
import lox::cli::utils, lox::debug, lox::gc;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox | VM @public
//------------------------------------------------------------------------------

enum VmResult @public
{
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR
}

struct Vm @public
{
    String file;
    Chunk *chunk;
    char *ip;
    Value[MAX_STACK] stack;
    Value *stack_top;
    Obj *objects;
    Table strings;
    Table globals;
}

fn void Vm.init(&self) @public
{
    self.reset_stack();
    self.objects = null;
    self.strings.init();
    self.globals.init();
}

fn void Vm.free(&self) @public
{
    self.globals.free();
    self.strings.free();
    gc::free_objects(self);
}

fn VmResult Vm.interpret(&self, String file, char *source) @public
{
    Chunk chunk;
    chunk.new();
    defer chunk.free();

    if (!compiler::compile(self, file, &chunk, source))
        { return VmResult.COMPILE_ERROR; }

    self.file = file;
    self.chunk = &chunk;
    self.ip = self.chunk.code.entries;

    return self.run();
}

fn void Vm.push(&self, Value value) @public
{
    *self.stack_top = value;
    self.stack_top++;
}

fn Value Vm.pop(&self) @public
{
    self.stack_top--;
    return *self.stack_top;
}

//------------------------------------------------------------------------------
// Lox | VM @private
//------------------------------------------------------------------------------

const uint MAX_STACK = 256;

fn void Vm.reset_stack(&self)
{
    self.stack_top = &self.stack[0];
}

fn void Vm.rt_error(&self, String fmt, args...)
{
    utils::logn(ERROR, fmt, ...args);

    int instruction = (int)(self.ip - self.chunk.code.entries - 1);
    int line = self.chunk.get_line(instruction);
    utils::logn(
        NONE,
        "{ %sfile%s %s%s%s : %sline%s %d } in main",
        utils::BLUE, utils::RESET,
        utils::GREEN, self.file, utils::RESET,
        utils::BLUE, utils::RESET, line
    );

    self.reset_stack();
}

fn Value Vm.peek(&self, int distance = 0)
{
    return self.stack_top[-1 - distance];
}

fn char Vm.read_byte(&self)
{
    return *self.ip++;
}

fn ushort Vm.read_short(&self)
{
    self.ip += 2;
    return (ushort)((self.ip[-2] << 8) | self.ip[-1]);
}

fn Value Vm.read_constant(&self)
{
    return self.chunk.constants[self.read_byte()];
}

fn ObjString *Vm.read_string(&self)
{
    return as_string(self.read_constant());
}

fn VmResult Vm.binary_op(&self, char op)
{
    if (!is_number(self.peek()) && !is_number(self.peek(1)))
    {
        self.rt_error("Binary (non_addition) operands must be numbers");
        return VmResult.RUNTIME_ERROR;
    }

    double b = as_number(self.pop());
    double a = as_number(self.pop());

    switch (op)
    {
        case '-':   self.push(number_val(a - b));
        case '*':   self.push(number_val(a * b));
        case '/':
        {
            if (b == 0.0)
            {
                self.rt_error("Division by Zero");
                return VmResult.RUNTIME_ERROR;
            }

            self.push(number_val(a / b));
        }
        case '%':
        {
            if (b == 0.0)
            {
                self.rt_error("Division by Zero");
                return VmResult.RUNTIME_ERROR;
            }

            self.push(number_val(a % b));
        }
        case '>':   self.push(bool_val(a > b));
        case '<':   self.push(bool_val(a < b));
        default:    return VmResult.RUNTIME_ERROR;
    }

    return VmResult.OK;
}

fn bool is_falsey(Value value)
{
    return is_nil(value) || (is_bool(value) && !as_bool(value));
}

fn void Vm.concatenate(&self)
{
    ObjString *b = as_string(self.pop());
    ObjString *a = as_string(self.pop());

    int len = a.len + b.len;
    char *chars = memory::lalloc(char, len + 1);
    mem::copy(chars, a.value.ptr, a.len);
    mem::copy(chars + a.len, b.value.ptr, b.len);
    chars[len] = '\0';

    ObjString *result = value::take_string(self, chars[:len], len);
    self.push(obj_val(result));
}

fn void Vm.trace(&self)
@if($feature(DEBUG) &&& (debug::TRACE_EXEC ||| debug::ENABLE_ALL))
{
    io::eprintf("        ");
    for (Value *slot = &self.stack[0]; slot < self.stack_top; slot++)
    {
        io::eprintf("[ ");
        value::print(*slot, io::stderr());
        io::eprintf(" ]");
    }
    io::eprint("\n");
    self.chunk.disassemble_instruction((int)(self.ip - self.chunk.code.entries));
}

fn VmResult Vm.run(&self)
{
    for (;;)
    {
        $if $feature(DEBUG) &&& (debug::TRACE_EXEC ||| debug::ENABLE_ALL):
            self.trace();
        $endif

        OpCode instruction;
        switch (instruction = OpCode.from_ordinal(self.read_byte()))
        {
            /* Simple Instructions */
            case RETURN:
                return VmResult.OK;
            case NIL:
                self.push(nil_val());
            case TRUE:
                self.push(bool_val(true));
            case FALSE:
                self.push(bool_val(false));
            case POP:
                self.pop();
            case ADD:
            {
                if (is_string(self.peek()) && is_string(self.peek(1)))
                {
                    self.concatenate();
                }
                else if (is_number(self.peek()) && is_number(self.peek(1)))
                {
                    double b = as_number(self.pop());
                    double a = as_number(self.pop());
                    self.push(number_val(a + b));
                }
                else
                {
                    self.rt_error("Binary (addition) operands must be numbers or strings (but not both)");
                    return VmResult.RUNTIME_ERROR;
                }
            }
            case SUBTRACT:
            {
                VmResult result = self.binary_op('-');
                if (result != OK) return result;
            }
            case MULTIPLY:
            {
                VmResult result = self.binary_op('*');
                if (result != OK) return result;
            }
            case DIVIDE:
            {
                VmResult result = self.binary_op('/');
                if (result != OK) return result;
            }
            case MODULO:
            {
                VmResult result = self.binary_op('%');
                if (result != OK) return result;
            }
            case NEGATE:
            {
                if (!is_number(self.peek()))
                {
                    self.rt_error("Negation operand must be a number");
                    return VmResult.RUNTIME_ERROR;
                }

                self.push(number_val(-as_number(*(--self.stack_top))));
            }
            case NOT:
                self.push(bool_val(is_falsey(self.pop())));
            case EQUAL:
            {
                Value b = self.pop();
                Value a = self.pop();
                self.push(bool_val(value::equals(a, b)));
            }
            case GREATER:
            {
                VmResult result = self.binary_op('>');
                if (result != OK) return result;
            }
            case LESS:
            {
                VmResult result = self.binary_op('<');
                if (result != OK) return result;
            }
            case PRINT:
            {
                value::print(self.pop());
                io::printn();
            }

            /* Constant Instructions */
            case CONSTANT:
            {
                Value constant = self.read_constant();
                self.push(constant);
            }
            case DEFINE_GLOBAL:
            {
                ObjString *name = self.read_string();
                self.globals.set(name, self.peek());
                self.pop();
            }
            case GET_GLOBAL:
            {
                ObjString *name = self.read_string();
                Value value;

                if (!self.globals.get(name, &value))
                {
                    self.rt_error("Undefined variable '%s", name.value);
                    return VmResult.RUNTIME_ERROR;
                }

                self.push(value);
            }
            case SET_GLOBAL:
            {
                ObjString *name = self.read_string();
                if (self.globals.set(name, self.peek()))
                {
                    self.globals.delete(name);
                    self.rt_error("Undefined variable '%s'", name.value);
                    return VmResult.RUNTIME_ERROR;
                }
            }

            /* Byte Instructions */
            case GET_LOCAL:
            {
                char slot = self.read_byte();
                self.push(self.stack[slot]);
            }
            case SET_LOCAL:
            {
                char slot = self.read_byte();
                self.stack[slot] = self.peek();
            }

            /* Jump Instructions */
            case JUMP:
            {
                ushort offset = self.read_short();
                self.ip += offset;
            }
            case JUMP_IF_TRUE:
            {
                ushort offset = self.read_short();
                if (!is_falsey(self.peek(0))) self.ip += offset;
            }
            case JUMP_IF_FALSE:
            {
                ushort offset = self.read_short();
                if (is_falsey(self.peek(0))) self.ip += offset;
            }
            case LOOP:
            {
                ushort offset = self.read_short();
                self.ip -= offset;
            }
        }
    }
}