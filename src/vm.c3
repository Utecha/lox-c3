module lox::vm;
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
    DIVISION_BY_ZERO
}

struct LoxVM
{
    Chunk *chunk;
    char *ip;
    Value[STACK_MAX] stack;
    Value *stackTop;
}

fn void LoxVM.init(&self)
{
    self.resetStack();
}

fn void LoxVM.free(&self)
{

}

fn void LoxVM.resetStack(&self)
{
    self.stackTop = &self.stack[0];
}

fn void LoxVM.push(&self, Value value)
{
    *self.stackTop = value;
    self.stackTop++;
}

fn Value LoxVM.pop(&self)
{
    self.stackTop--;
    return *self.stackTop;
}

fn LoxResult LoxVM.interpret(&self, ZString source)
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
    Value b = self.pop();
    Value a = self.pop();

    switch (op)
    {
        default:
            unreachable();
        case '+':
            self.push(a + b);
        case '-':
            self.push(a - b);
        case '*':
            self.push(a * b);
        case '/':
            if (b == 0)
            {
                return InterpretError.DIVISION_BY_ZERO?;
            }
            self.push(a / b);
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

        OpCode instruction;
        switch (instruction = OpCode.from_ordinal(self.readByte()))
        {
            case RETURN:
                value::print(self.pop());
                io::printn();
                return;
            case ADD:
                self.binaryOp('+')!;
            case SUBTRACT:
                self.binaryOp('-')!;
            case MULTIPLY:
                self.binaryOp('*')!;
            case DIVIDE:
                self.binaryOp('/')!;
            case NEGATE:
                self.push(-*(--self.stackTop));
            case CONSTANT:
                Value constant = self.readConstant();
                self.push(constant);
        }
    }
}
