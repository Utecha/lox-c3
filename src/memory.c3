module lox::memory;
import lox::object;
import lox::vm;
import std::thread;

/*
 * This module contains all memory related functions and macros for use with Lox.
 * This is also where the majority of the GC ends up within the original Lox implementation.
 *
 * NOTE: I will be changing this for the post 0.1.0 releases to split up all non-GC handled memory
 * as well as GC-handled memory code into their own modules (the former will be found in this module).
*/

//===----------------===//
//    Memory Macros
//===----------------===//

<*
    Allocates an array of ($Type) on the heap.

    @param $Type "The type of the array to allocate"
    @param count "The size of the array to allocate"
*>
macro allocate($Type, count)
{
    return ($Type *)reallocate(null, 0, $Type.sizeof * count);
}

<*
    Grows the capacity value of a dynamic array by a factor of 2.

    @param capacity "The capacity value to increase"
*>
macro grow_capacity(capacity)
{
    return capacity < 8 ? 8 : capacity * 2;
}

<*
    Reallocates the memory for a dynamic array, returning result
    pre-cast to the desired type.

    @param $Type "The type of the dynamic array"
    @param [inout] ptr "The pointer to the dynamic array"
    @param old_size "The old capacity of the dynamic array"
    @param new_size "The new capacity of the dynamic array"
*>
macro grow_array($Type, ptr, old_size, new_size)
{
    return ($Type *)reallocate(ptr, $Type.sizeof * old_size, $Type.sizeof * new_size);
}

<*
    Free's the memory for a dynamic array allocated by the Lox allocator.

    @param $Type "The type of the dynamic array"
    @param [inout] ptr "The pointer to the dynamic array"
    @param old_size "The capacity of the dynamic array"
*>
macro free_array($Type, ptr, old_size)
{
    reallocate(ptr, $Type.sizeof * old_size, 0);
}

<*
    Free's an individual heap-allocated pointer (usually an Obj *).

    @param $Type "The type of the pointer"
    @param ptr "The pointer to free"
*>
macro free_ptr($Type, ptr)
{
    reallocate(ptr, $Type.sizeof, 0);
}

<*
    The main allocator function used by Lox. Later, this will trigger the GC.

    If [new_size] == 0, it frees the pointer and returns null. Otherwise, it calls realloc
    with the [new_size] value, returning the resulting pointer (assuming it succeeds). If that fails,
    it will exit the VM due to lack of memory.

    @param [inout] ptr "The pointer to the dynamic array to reallocate"
    @param old_size "The original capacity of the dynamic array"
    @param new_size "The new capacity to reallocate for the dynamic array"
*>
fn void *reallocate(void *ptr, usz old_size, usz new_size)
{
    if (new_size == 0)
    {
        free(ptr);
        return null;
    }

    void *result = realloc(ptr, new_size);
    if (result == null) thread::exit(1);

    return result;
}

<*
    Free's the memory for an (Obj *).

    @param [inout] object "The object to be freed"
*>
fn void free_object(Obj *object) @local
{
    switch (object.type)
    {
        case CLOSURE:
        {
            ObjClosure *closure = (ObjClosure *)object;
            free_array(ObjUpvalue *, closure.upvalues, closure.upvalue_count);
            free_ptr(ObjClosure, object);
        }
        case FUNCTION:
        {
            ObjFunction *function = (ObjFunction *)object;
            function.chunk.free();
            free_ptr(ObjFunction, object);
        }
        case NATIVE:
            free_ptr(ObjNative, object);
        case STRING:
        {
            ObjString *string = (ObjString *)object;
            free_array(char, string.chars, string.length + 1);
            free_ptr(ObjString, object);
        }
        case UPVALUE:
            free_ptr(ObjUpvalue, object);
    }
}

<*
    Walks the linked-list of objects held by the VM and frees each node.
*>
fn void free_objects()
{
    Obj *object = vm.objects;
    while (object != null)
    {
        Obj *next = object.next;
        free_object(object);
        object = next;
    }
}
