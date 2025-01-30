module lox::mem;
import lox::vm::value;

//------------------------------------------------------------------------------
// Lox \ VM \ Mem
//------------------------------------------------------------------------------

fn void *reallocate(void *ptr, usz oldSize, usz newSize) @local
{
    if (newSize == 0)
    {
        free(ptr);
        return null;
    }

    return realloc(ptr, newSize);
}

macro lalloc($Type, count = 0)
{
    if (count > 0)
    {
        return ($Type *)reallocate(null, 0, $Type.sizeof * count);
    }

    return ($Type *)reallocate(null, 0, $Type.sizeof);
}

macro lrealloc($Type, ptr, oldSize, newSize)
{
    return ($Type *)reallocate(ptr, $Type.sizeof * oldSize, $Type.sizeof * newSize);
}

macro lfree($Type, ptr, oldSize = 0)
{
    if (oldSize > $Type.sizeof)
    {
        reallocate(ptr, $Type.sizeof * oldSize, 0);
        return;
    }

    reallocate(ptr, $Type.sizeof, 0);
}

//------------------------------------------------------------------------------
// Lox \ VM \ Mem -- Internal
//------------------------------------------------------------------------------

fn void freeObject(Obj *object)
{
    switch (object.type)
    {
        case STRING:
            ObjString *string = (ObjString *)object;
            lfree(char, string.chars[:string.len], string.len + 1);
            lfree(ObjString, object);
    }
}

fn void freeObjects(LoxVM *vm)
{
    Obj *object = vm.objects;
    while (object != null)
    {
        Obj *next = object.next;
        freeObject(object);
        object = next;
    }
}
