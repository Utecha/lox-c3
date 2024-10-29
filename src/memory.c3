module lox::memory;
import std::thread;

//===----------------------------------------------------------------------===//
// Lox | Memory
//===----------------------------------------------------------------------===//

/*
 * This module provides the memory allocator function (and macros) for Lox.
 * This is also the home of most of the GC code when that is implemented.
*/

/*
 * Allocates, reallocates, or frees a [ptr] based on the values passed in to
 * [oldSize] and [newSize].
 *
 * This function returns 'null' if [newSize] == 0, otherwise it reallocates the
 * [ptr] and returns it as a (void *).
 *
 * If the result of the call to realloc() is 'null', Lox exits with exitcode '1'.
 *
 * NOTE: This function is only used directly once or twice within this project. It
 * is otherwise not really meant to be used directly. Instead, macro wrappers are
 * provided for allocating specific kinds of pointers, handling the appropriate sizing
 * and also type casting the result.
*/
fn void *reallocate(void *ptr, usz oldSize, usz newSize)
{
    if (newSize == 0)
    {
        free(ptr);
        return null;
    }

    void *result = realloc(ptr, newSize);
    if (result == null) thread::exit(1);

    return result;
}

/* Frees the memory of an array [ptr] allocated by reallocate() */
macro free_array($Type, ptr, old)
{
    reallocate(ptr, $Type.sizeof * old, 0);
}

/* Increases the capacity of [capacity] by a power of 2 and returns it */
macro grow_capacity(capacity)
{
    return capacity < 8 ? 8 : capacity * 2;
}

/*
 * Grows the size of an array from [old] to [new], reallocating the memory using
 * reallocate() and returning the result cast to [$Type] type.
*/
macro grow_array($Type, ptr, old, new)
{
    return ($Type *)reallocate(ptr, $Type.sizeof * old, $Type.sizeof * new);
}