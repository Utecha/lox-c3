module lox::vm @private;
import lox::debug, lox::mem, lox::utils;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox \ VM
//------------------------------------------------------------------------------

const uint STACK_MAX = 256;

enum LoxInterpretResult @public
{
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR
}

struct LoxVM @public
{
    String file;    // Temporary until I introduce modules
    char *ip;
    Chunk *chunk;
    Value[STACK_MAX] stack;
    Value *stackTop;
    Obj *objects;
    Table strings;
    Table globals;
}

fn void LoxVM.init(&self) @public
{
    self.resetStack();
    self.objects = null;
    self.strings.zero();
    self.globals.zero();
}

fn void LoxVM.resetStack(&self)
{
    self.stackTop = &self.stack[0];
}

fn void LoxVM.free(&self) @public
{
    self.globals.free();
    self.strings.free();
    mem::freeObjects(self);
}

fn void LoxVM.rtError(&self, String fmt, args...)
{
    utils::log(ERROR, fmt, ...args);

    int instruction = (int)(self.ip - self.chunk.code.entries - 1);
    int line = self.chunk.getLine(instruction);
    utils::log(
        NONE,
        "{ %sfile%s %s%s%s : %sline%s %d] in main",
        utils::SBLUE, utils::SRESET,
        utils::SLIGHTGRAY, self.file, utils::SRESET,
        utils::SBLUE, utils::SRESET, line
    );

    self.resetStack();
}

fn LoxInterpretResult LoxVM.interpret(&self, String file, char *source) @public
{
    self.file = file;

    Chunk chunk;
    chunk.new();
    defer chunk.free();

    if (!compiler::compile(self, file, &chunk, source))
        { return LoxInterpretResult.COMPILE_ERROR; }

    self.chunk = &chunk;
    self.ip = self.chunk.code.entries;

    return self.run();
}

fn void LoxVM.push(&self, Value value) @public
{
    *self.stackTop = value;
    self.stackTop++;
}

fn Value LoxVM.pop(&self) @public
{
    self.stackTop--;
    return *self.stackTop;
}

fn Value LoxVM.peek(&self, int distance = 0)
{
    return self.stackTop[-1 - distance];
}

fn char LoxVM.readByte(&self) @local
{
    return *self.ip++;
}

fn Value LoxVM.readConstant(&self) @local
{
    return self.chunk.constants[self.readByte()];
}

fn ObjString *LoxVM.readString(&self) @local
{
    return asString(self.readConstant());
}

fn ushort LoxVM.readShort(&self) @local
{
    self.ip += 2;
    return (ushort)((self.ip[-2] << 8) | self.ip[-1]);
}

fn LoxInterpretResult LoxVM.binaryOp(&self, char op) @local
{
    if (!isNumber(self.peek()) && !isNumber(self.peek(1)))
    {
        self.rtError("Binary (non-addition) operands must be numbers");
        return LoxInterpretResult.RUNTIME_ERROR;
    }

    double b = asNumber(self.pop());
    double a = asNumber(self.pop());

    switch (op)
    {
        case '+':
            self.push(numberVal(a + b));
        case '-':
            self.push(numberVal(a - b));
        case '*':
            self.push(numberVal(a * b));
        case '/':
            if (b == 0)
            {
                self.rtError("Division by Zero");
                return LoxInterpretResult.RUNTIME_ERROR;
            }
            self.push(numberVal(a / b));
        case '>':
            self.push(boolVal(a > b));
        case '<':
            self.push(boolVal(a < b));
        default:
            self.rtError("Unknown binary operator: %c", op);
            return LoxInterpretResult.RUNTIME_ERROR;
    }

    return LoxInterpretResult.OK;
}

fn bool isFalsey(Value value)
{
    return isNil(value) || (isBool(value) && !asBool(value));
}

fn void LoxVM.concatenate(&self) @local
{
    ObjString *b = asString(self.pop());
    ObjString *a = asString(self.pop());

    int len = a.len + b.len;
    char *chars = mem::lalloc(char, len + 1);
    mem::copy(chars, a.chars, a.len);
    mem::copy(chars + a.len, b.chars, b.len);
    chars[len] = '\0';

    ObjString *result = value::takeString(self, chars[:len], len);
    self.push(objVal(result));
}

fn LoxInterpretResult LoxVM.run(&self) @local
{
    for (;;)
    {
        $if $feature(DEBUG) &&& (debug::TRACE_INSTRUCTIONS ||| debug::ENABLE_ALL):
            io::eprintf("        ");
            for (Value *slot = &self.stack[0]; slot < self.stackTop; slot++)
            {
                io::eprintf("[ ");
                value::print(*slot, io::stderr());
                io::eprintf(" ]");
            }
            io::eprint("\n");
            self.chunk.disassembleInstruction((int)(self.ip - self.chunk.code.entries));
        $endif

        OpCode instruction;
        switch (instruction = OpCode.from_ordinal(self.readByte()))
        {
            /* Simple Instructions */
            case RETURN:
                return LoxInterpretResult.OK;
            case NIL:
                self.push(nilVal());
            case TRUE:
                self.push(boolVal(true));
            case FALSE:
                self.push(boolVal(false));
            case POP:
                self.pop();
            case ADD:
            {
                if (isString(self.peek()) && isString(self.peek(1)))
                {
                    self.concatenate();
                }
                else if (isNumber(self.peek()) && isNumber(self.peek(1)))
                {
                    self.binaryOp('+');
                }
                else
                {
                    self.rtError("Binary (addition) operands must be numbers or strings");
                    return LoxInterpretResult.RUNTIME_ERROR;
                }
            }
            case SUBTRACT:
            {
                LoxInterpretResult result = self.binaryOp('-');
                if (result != OK) return result;
            }
            case MULTIPLY:
            {
                LoxInterpretResult result = self.binaryOp('*');
                if (result != OK) return result;
            }
            case DIVIDE:
            {
                LoxInterpretResult result = self.binaryOp('/');
                if (result != OK) return result;
            }
            case NEGATE:
            {
                if (!isNumber(self.peek()))
                {
                    self.rtError("Negation operand must be a number");
                    return LoxInterpretResult.RUNTIME_ERROR;
                }
                self.push(numberVal(-asNumber(self.pop())));
            }
            case NOT:
                self.push(boolVal(isFalsey(self.pop())));
            case EQUAL:
            {
                Value b = self.pop();
                Value a = self.pop();
                self.push(boolVal(value::equals(a, b)));
            }
            case GREATER:
            {
                LoxInterpretResult result = self.binaryOp('>');
                if (result != OK) return result;
            }
            case LESS:
            {
                LoxInterpretResult result = self.binaryOp('<');
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
                Value constant = self.readConstant();
                self.push(constant);
            }
            case DEFINE_GLOBAL:
            {
                ObjString *name = self.readString();
                self.globals.set(name, self.peek());
                self.pop();
            }
            case GET_GLOBAL:
            {
                ObjString *name = self.readString();
                Value value;

                if (!self.globals.get(name, &value))
                {
                    self.rtError("Undefined variable '%s'", name.chars);
                    return LoxInterpretResult.RUNTIME_ERROR;
                }

                self.push(value);
            }
            case SET_GLOBAL:
            {
                ObjString *name = self.readString();
                if (self.globals.set(name, self.peek()))
                {
                    self.globals.delete(name);
                    self.rtError("Undefined variable '%s'", name.chars);
                    return LoxInterpretResult.RUNTIME_ERROR;
                }
            }

            /* Byte Instructions */
            case GET_LOCAL:
            {
                char slot = self.readByte();
                self.push(self.stack[slot]);
            }
            case SET_LOCAL:
            {
                char slot = self.readByte();
                self.stack[slot] = self.peek();
            }

            /* Jump Instructions */
            case JUMP:
            {
                ushort offset = self.readShort();
                self.ip += offset;
            }
            case JUMP_IF_TRUE:
            {
                ushort offset = self.readShort();
                if (!isFalsey(self.peek(0))) self.ip += offset;
            }
            case JUMP_IF_FALSE:
            {
                ushort offset = self.readShort();
                if (isFalsey(self.peek(0))) self.ip += offset;
            }
            case LOOP:
            {
                ushort offset = self.readShort();
                self.ip -= offset;
            }
        }
    }
}
