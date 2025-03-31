module lox::vm;

const uint FRAMES_MAX   = 64;
const uint STACK_MAX    = FRAMES_MAX * 256;

struct LoxVM
{
    CallFrame[FRAMES_MAX] frames;
    int frameCount;
    Value[STACK_MAX] stack;
    Value *stackTop;
    LoxGC gc;
}

fn void LoxVM.init(&self)
{
    self.resetStack();
    self.gc.init();
}

fn void LoxVM.free(&self)
{
    self.gc.free();
}

fn void LoxVM.resetStack(&self)
{
    self.frameCount = 0;
    self.stackTop = &self.stack[0];
}

macro LoxVM.push(&self, Value value)
{
    *self.stackTop++ = value;
}

macro LoxVM.pop(&self)
{
    return *(--self.stackTop);
}

macro LoxVM.peek(&self, int dinstance = 0)
{
    return *(self.stackTop - 1 - distance);
}
