module lox::mem;

//------------------------------------------------------------------------------
// Lox \ Mem
//------------------------------------------------------------------------------

fn void *reallocate(void *memory, usz old_size, usz new_size)
{
    (void) old_size;
    if (new_size == 0)
    {
        free(memory);
        return null;
    }

    return realloc(memory, new_size);
}

macro lalloc($Type, count)
{
    if (count > 0)
    {
        return ($Type *)reallocate(null, 0, $Type.sizeof * count);
    }

    return ($Type *)reallocate(null, 0, $Type.sizeof);
}

macro lrealloc(ptr, old_size, new_size)
{
    usz size = $typeof(ptr).sizeof;

    return ($typeof(ptr))reallocate(ptr,
        size * old_size, size * new_size);
}

macro lfree(ptr, old_size)
{
    usz size = $typeof(ptr).sizeof;

    if (old_size > size)
    {
        reallocate(ptr, size * old_size, 0);
        return;
    }

    reallocate(ptr, size, 0);
}
