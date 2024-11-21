module lox::memory;
import lox::common;
import lox::compiler;
import lox::object;
import lox::table;
import lox::value;
import lox::vm;
import std::thread;
import std::io @norecurse;

/*
 * This module contains all memory related functions and macros for use with Lox.
 * This is also where the majority of the GC ends up within the original Lox implementation.
 *
 * NOTE: I will be changing this for the post 0.1.0 releases to split up all non-GC handled memory
 * as well as GC-handled memory code into their own modules (the former will be found in this module).
*/

const uint GC_HEAP_GROW_FACTOR = 2;

//===----------------===//
//      GC Macros
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

//===----------------===//
//   Garbage Collector
//===----------------===//

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
    vm.bytes_allocated += new_size - old_size;

    if (new_size > old_size)
    {
        $if $feature(DEBUG) &&& STRESS_GC:
            collect_garbage();
        $endif

        if (vm.bytes_allocated > vm.next_gc)
        {
            collect_garbage();
        }
    }

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
    Runs a garbage collection cycle, using the mark-sweep method.
*>
fn void collect_garbage()
{
    $if $feature(DEBUG) &&& LOG_GC:
        io::eprintn("-- Begin Garbage Collection");
        usz before = vm.bytes_allocated;
    $endif

    mark_roots();
    trace_references();
    table::remove_white(&vm.strings);
    sweep();

    vm.next_gc = vm.bytes_allocated * GC_HEAP_GROW_FACTOR;

    $if $feature(DEBUG) &&& LOG_GC:
        io::eprintn("-- End Garbage Collection");
        io::eprintfn(
            "GC collected %d bytes (from %d to %d)\nNext GC at %d bytes",
            before - vm.bytes_allocated,
            before,
            vm.bytes_allocated,
            vm.next_gc
        );
    $endif
}

<*
    Checks and calls the appropriate function for every source
    of roots within the VM.

    At the end, it calls the function that does the same for
    every source of roots held within the compiler chain.
*>
fn void mark_roots() @private
{
    for (Value *slot = &vm.stack[0]; slot < vm.stack_top; slot++)
        { mark_value(*slot); }

    for (int i = 0; i < vm.frame_count; i++)
        { mark_object((Obj *)vm.frames[i].closure); }

    for (ObjUpvalue *upvalue = vm.open_upvalues; upvalue != null; upvalue = upvalue.next)
        { mark_object((Obj *)upvalue); }

    table::mark_table(&vm.globals);
    compiler::mark_compiler_roots();
}

<*
    Checks if a [value] is a valid object and if it is, it
    marks the object.

    @param value "The value to check and mark"
*>
fn void mark_value(Value value)
{
    if (is_obj(value)) mark_object(as_obj(value));
}

<*
    Marks the values found within a value [list].

    @param [&in] list "The list of values to mark"
*>
fn void mark_array(ValueList *list) @private
{
    for (int i = 0; i < list.count; i++)
        { mark_value(list.values[i]); }
}

<*
    Marks an [object] by setting the [is_marked] flag of that
    [object] to true.

    @param [inout] object "The object to be marked"
*>
fn void mark_object(Obj *object)
{
    if (object == null) return;
    if (object.is_marked) return;

    $if $feature(DEBUG) &&& LOG_GC:
        io::eprintf("Addr: %p | Marked '", object);
        value::print(obj_val(object), io::stderr());
        io::eprintf("'\n");
    $endif

    object.is_marked = true;

    if (vm.gray_capacity < vm.gray_count + 1)
    {
        vm.gray_capacity = memory::grow_capacity(vm.gray_capacity);
        vm.gray_stack = (Obj **)realloc(vm.gray_stack, (Obj *).sizeof * vm.gray_capacity);
        if (vm.gray_stack == null) thread::exit(1);
    }

    vm.gray_stack[vm.gray_count++] = object;
}

<*
    Traces through marked (gray) objects, and makes the next step to
    mark them black. Any roots marked black will remain available, at least
    until the next collection cycle.
*>
fn void trace_references() @private
{
    while (vm.gray_count > 0)
    {
        Obj *object = vm.gray_stack[--vm.gray_count];
        blacken_object(object);
    }
}

<*
    Officially 'blackens', or further marks an (gray) object as black.
    This signifies that the object is to remain available, at least until
    the next collection cycle.
*>
fn void blacken_object(Obj *object)
{
    $if $feature(DEBUG) &&& LOG_GC:
        io::eprintf("Addr: %p | Blackened '", object);
        value::print(obj_val(object), io::stderr());
        io::eprintf("'\n");
    $endif

    switch (object.type)
    {
        case CLOSURE:
        {
            ObjClosure *closure = (ObjClosure *)object;
            mark_object((Obj *)closure.function);

            for (int i = 0; i < closure.upvalue_count; i++)
                { mark_object((Obj *)closure.upvalues[i]); }
        }
        case FUNCTION:
        {
            ObjFunction *function = (ObjFunction *)object;
            mark_object((Obj *)function.name);
            mark_array(&function.chunk.constants);
        }
        case NATIVE:
        case STRING:
            break;
        case UPVALUE:
            mark_value(((ObjUpvalue *)object).closed);
    }
}

<*
    Sweeps up any objects that were not marked.
*>
fn void sweep() @private
{
    Obj *previous = null;
    Obj *object = vm.objects;

    while (object != null)
    {
        if (object.is_marked)
        {
            object.is_marked = false;
            previous = object;
            object = object.next;
        }
        else
        {
            Obj *unreached = object;
            object = object.next;

            if (previous != null)
            {
                previous.next = object;
            }
            else
            {
                vm.objects = object;
            }

            free_object(unreached);
        }
    }
}

<*
    Free's the memory for an (Obj *).

    @param [inout] object "The object to be freed"
*>
fn void free_object(Obj *object) @private
{
    $if $feature(DEBUG) &&& LOG_GC:
        io::eprintfn("Addr: %p | Freed type %s", (void *)object, object.type);
    $endif

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

    free(vm.gray_stack);
}
