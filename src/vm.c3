module lox::vm @private;
import lox::common;
import lox::compiler;
import lox::chunk;
import lox::value;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox \ VM
//------------------------------------------------------------------------------

const uint STACK_MAX = 256;

fault InterpretError
{
    DIVISION_BY_ZERO,
    INVALID_OPERAND,
    INVALID_OPERANDS
}

struct LoxVM @public
{
    Chunk *chunk;
    char *ip;
    Value[STACK_MAX] stack;
    Value *stackTop;
}

fn void LoxVM.init(&self) @public
{
    self.resetStack();
}

fn void LoxVM.free(&self) @public
{

}

fn void LoxVM.resetStack(&self)
{
    self.stackTop = &self.stack[0];
}

fn void LoxVM.runtimeError(&self, String fmt, args...)
{
    io::eprintfn(fmt, ...args);

    usz instruction = self.ip - self.chunk.code - 1;
    int line = self.chunk.lines[instruction];

    io::eprintfn("[line %d] in script", line);
    self.resetStack();
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

fn bool isFalsey(Value value) @local
{
    return isNil(value) || (isBool(value) && !asBool(value));
}

fn LoxResult LoxVM.interpret(&self, ZString source) @public
{
    Compiler compiler;
    Chunk chunk;

    defer chunk.free();

    if (!compiler.compile(&chunk, source))
        { return LoxResult.COMPILE_ERROR; }

    self.chunk = &chunk;
    self.ip = self.chunk.code;

    if (catch self.run())
        { return LoxResult.RUNTIME_ERROR; }

    return LoxResult.OK;
}

fn char LoxVM.readByte(&self)
{
    return *self.ip++;
}

fn Value LoxVM.readConstant(&self)
{
    return self.chunk.constants[self.readByte()];
}

fn void! LoxVM.binaryOp(&self, char op)
{
    if (!isNumber(self.peek()) && !isNumber(self.peek(1)))
    {
        self.runtimeError("Binary (non-addition) operands must be numbers");
        return InterpretError.INVALID_OPERANDS?;
    }

    double b = asNumber(self.pop());
    double a = asNumber(self.pop());

    switch (op)
    {
        default:
            unreachable();
        case '+':
            self.push(numberVal(a + b));
        case '-':
            self.push(numberVal(a - b));
        case '*':
            self.push(numberVal(a * b));
        case '/':
            if (b == 0)
            {
                self.runtimeError("Division by Zero");
                return InterpretError.DIVISION_BY_ZERO?;
            }
            self.push(numberVal(a / b));
        case '>':
            self.push(boolVal(a > b));
        case '<':
            self.push(boolVal(a < b));
    }
}

fn void! LoxVM.run(&self)
{
    for (;;)
    {
        $if $feature(DEBUG) &&& DEBUG_TRACE_EXEC:
            io::eprintf("        ");
            for (Value *slot = &self.stack[0]; slot < self.stackTop; slot++)
            {
                io::eprintf("[ ");
                value::print(*slot, io::stderr());
                io::eprintf(" ]");
            }
            io::eprintf("\n");
            self.chunk.disassembleInstruction((int)(self.ip - self.chunk.code));
        $endif

        char instruction;
        switch (instruction = self.readByte())
        {
            case OpCode.RETURN.ordinal:
                value::print(self.pop());
                io::printn();
                return;
            case OpCode.NIL.ordinal:
                self.push(nilVal());
            case OpCode.FALSE.ordinal:
                self.push(boolVal(false));
            case OpCode.TRUE.ordinal:
                self.push(boolVal(true));
            case OpCode.ADD.ordinal:
                self.binaryOp('+')!;
            case OpCode.SUBTRACT.ordinal:
                self.binaryOp('-')!;
            case OpCode.MULTIPLY.ordinal:
                self.binaryOp('*')!;
            case OpCode.DIVIDE.ordinal:
                self.binaryOp('/')!;
            case OpCode.NEGATE.ordinal:
                if (!isNumber(self.peek()))
                {
                    self.runtimeError("Negation operand must be a number");
                    return InterpretError.INVALID_OPERAND?;
                }
                self.push(numberVal(-asNumber(*(--self.stackTop))));
            case OpCode.NOT.ordinal:
                self.push(boolVal(isFalsey(self.pop())));
            case OpCode.EQUAL.ordinal:
                Value b = self.pop();
                Value a = self.pop();
                self.push(boolVal(value::equal(a, b)));
            case OpCode.GREATER.ordinal:
                self.binaryOp('>')!;
            case OpCode.LESS.ordinal:
                self.binaryOp('<')!;
            case OpCode.CONSTANT.ordinal:
                Value constant = self.readConstant();
                self.push(constant);
        }
    }
}
