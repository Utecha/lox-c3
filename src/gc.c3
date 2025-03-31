module lox::vm::gc;
import lox::vm::value;

alias ReallocFn = fn void *(Allocator allocator, void *ptr, usz newSize);

fn void *defaultReallocFn(Allocator allocator, void *ptr, usz newSize)
{
    if (newSize == 0)
    {
        allocator::free(allocator, ptr);
        return null;
    }

    return allocator::realloc(allocator, ptr, newSize);
}

struct LoxGC
{
    Allocator parent;
    ReallocFn realloc;
    Obj *first;
    int grayCapacity;
    int grayCount;
    Obj **gray;
    usz bytesAllocated;
    usz nextGC;
}

fn void LoxGC.init(&self)
{
    self.parent = allocator::heap();
    self.realloc = &defaultReallocFn;
    self.first = null;
    self.grayCapacity = 0;
    self.grayCount = 0;
    self.gray = null;
    self.bytesAllocated = 0;
    self.nextGC = 1024 * 1024 * 4;
}

fn void LoxGC.free(&self)
{
    self.freeObjects();
}

fn void LoxGC.updateAllocated(&self, usz total)
{
    self.bytesAllocated += total;
}

fn void *LoxGC.reallocate(&self, void *ptr, usz oldSize, usz newSize)
{
    return self.realloc(self.parent, ptr, newSize);
}

macro allocate($Type, gc) @builtin @nodiscard
{
    return ($Type *)gc.reallocate(null, 0, $Type.sizeof);
}

macro allocateArray($Type, gc, count) @builtin @nodiscard
{
    return ($Type *)gc.reallocate(null, 0, $Type.sizeof * count);
}

macro allocateFlex($MainType, $ArrayType, gc, count) @builtin @nodiscard
{
    return ($MainType *)gc.reallocate(null, 0, $MainType.sizeof + $ArrayType.sizeof * count);
}

macro reallocate($Type, gc, ptr, oldSize, newSize) @builtin @nodiscard
{
    return ($Type *)gc.reallocate(ptr, $Type.sizeof * oldSize, $Type.sizeof * newSize);
}

macro reallocateFlex($MainType, $ArrayType, gc, ptr, oldSize, newSize) @builtin @nodiscard
{
    return ($MainType *)gc.reallocate(
        ptr,
        $MainType.sizeof + $ArrayType.sizeof * oldSize,
        $MainType.sizeof + $ArrayType.sizeof * newSize
    );
}

macro deallocate($Type, gc, ptr, oldSize = 1) @builtin
{
    gc.reallocate(ptr, $Type.sizeof * oldSize, 0);
}

macro deallocateFlex($MainType, $ArrayType, gc, ptr, oldSize) @builtin
{
    gc.reallocate(ptr, $MainType.sizeof + $ArrayType.sizeof * oldSize, 0);
}

fn void LoxGC.freeGrayStack(&self) @local
{
    free(self.gray);
    self.grayCount = 0;
    self.grayCapacity = 0;
    self.gray = null;
}

fn void LoxGC.freeObject(&self, Obj *object) @local
{
    switch (object.type)
    {
        case FUNCTION:
            ObjFn *function = (ObjFn *)object;
            function.constants.free(self);
            function.lines.free(self);
            function.code.free(self);
            deallocate(ObjFn, self, object);
        case STRING:
            ObjString *string = (ObjString *)object;
            deallocateFlex(ObjString, char, self, object, string.length);
            // deallocate(char, self, &string.value[0], string.length);
            // deallocate(ObjString, self, object);
    }
}

fn void LoxGC.freeObjects(&self)
{
    Obj *object = self.first;
    while (object != null)
    {
        Obj *next = object.next;
        self.freeObject(object);
        object = next;
    }

    // self.freeGrayStack();
}
