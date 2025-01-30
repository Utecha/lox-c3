module lox::gc::memory;
import lox::vm::value;

//------------------------------------------------------------------------------
// Lox | GC | Mem
//------------------------------------------------------------------------------

fn void *reallocate(void *ptr, usz old_size, usz new_size) @local
{
    if (new_size == 0)
    {
        free(ptr);
        return null;
    }

    return realloc(ptr, new_size);
}

macro lalloc($Type, count = 0)
{
    if (count > 0)
    {
        return ($Type *)reallocate(null, 0, $Type.sizeof * count);
    }

    return ($Type *)reallocate(null, 0, $Type.sizeof);
}

macro lrealloc($Type, ptr, old_size, new_size)
{
    return ($Type *)reallocate(ptr, $Type.sizeof * old_size, $Type.sizeof * new_size);
}

macro lfree($Type, ptr, old_size = 0)
{
    if (old_size > $Type.sizeof)
    {
        reallocate(ptr, $Type.sizeof * old_size, 0);
        return;
    }

    reallocate(ptr, $Type.sizeof, 0);
}

macro grow2x(n)
{
    return n < 16U ? 16U : n * 2U;
}