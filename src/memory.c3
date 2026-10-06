module lox::memory;

//------------------------------------------------------------------------------

<*
    Defines a pointer to a function for reallocating memory.

    @param [inout] ptr : "A pointer to memory to reallocate."
    @param size : "The size of the memory block (in number of bytes.)"
*>
alias LoxReallocFn = fn void *(void *ptr, sz size);

//------------------------------------------------------------------------------

<*
    Allocates memory for a single instance of the given [$Type].

    @param $Type : "The type to allocate."
    @param [&inout] vm : "A pointer to a LoxVM."

    @ensure ptr != null : "Pointer should not be null after call to `memory::alloc`."
*>
macro alloc($Type, LoxVM *vm)
{
    return ($Type *)reallocate(vm, null, 0, $Type::size);
}

<*
    Allocates memory for an array of the given [$Type].

    @param $Type : "The type to allocate."
    @param [&inout] vm : "A pointer to a LoxVM."
    @param size : "The size of the array (in number of elements.)"

    @ensure ptr != null : "Pointer should not be null after call to `memory::alloca`."
*>
macro alloca($Type, LoxVM *vm, sz size)
{
    return ($Type *)reallocate(vm, null, 0, $Type::size * size);
}

<*
    Allocates memory for an single instance of [$MainType] with a flexible
    array of [$ArrayType].

    @param $MainType : "The type of the structure to allocate."
    @param $ArrayType : "The type of the flexible array to allocate."
    @param [&inout] vm : "A pointer to a LoxVM."
    @param size : "The size of the array (in number of elements.)"

    @ensure ptr != null : "Pointer should not be null after call to `memory::allocf`."
*>
macro allocf($MainType, $ArrayType, LoxVM *vm, sz size)
{
    return ($MainType *)reallocate(
        vm,
        null,
        0,
        $MainType::size + $ArrayType::size * size
    );
}

<*
    Reallocates the memory of [$Type] found at [ptr] from [old_size] elements to
    [new_size] elements.

    @param $Type : "The type to allocate."
    @param [&inout] vm : "A pointer to a LoxVM."
    @param [inout] ptr : "A pointer to memory to reallocate."
    @param old_size : "The current size of the array (in number of elements.)"
    @param new_size : "The new size for the array (in number of elements.)"

    @ensure ptr != null : "Pointer should not be null after call to `memory::realloc`."
*>
macro realloc($Type, LoxVM *vm, void *ptr, sz old_size, sz new_size)
{
    return ($Type *)reallocate(
        vm,
        ptr,
        $Type::size * old_size,
        $Type::size * new_size
    );
}

<*
    Releases the memory of [$Type] and [size] pointed to by [ptr].

    NOTE: This macro is also used to release single instances and not
    just arrays. You can do so by omitting the [size] argument.

    @param $Type : "The type to release."
    @param [&inout] vm : "A pointer to a LoxVM."
    @param [inout] ptr : "A pointer to memory to release."
    @param size : "The current size of the array (in number of elements.)"

    @ensure ptr == null
*>
macro free($Type, LoxVM *vm, void *ptr, sz size = 1)
{
    reallocate(vm, ptr, $Type::size * size, 0);
}

<*
    Releases the memory of [$Type] and [size] pointed to by [ptr].

    NOTE: This macro is also used to release single instances and not
    just arrays. You can do so by omitting the [size] argument.

    @param $MainType : "The type of the structure to release."
    @param $ArrayType : "The type of the flexible array to release."
    @param [&inout] vm : "A pointer to a LoxVM."
    @param [inout] ptr : "A pointer to memory to release."
    @param size : "The current size of the array (in number of elements.)"

    @ensure ptr == null
*>
macro freef($MainType, $ArrayType, LoxVM *vm, void *ptr, sz size)
{
    reallocate(
        vm,
        ptr,
        $MainType::size + $ArrayType::size * size,
        0
    );
}

<*
    Returns the next power of two that is greater than or equal to [n].

    @param n : "The value to get the next power of two for."

    @require types::is_int($Typeof(n)) : "Input value must be an integer type."
    @require n >= 0 : "Input value must be non-negative."
*>
macro next_power_of_two(n)
{
    var $Type = $Typeof(n);

    if (n <= 1) return ($Type)1;
    if (n == 2) return ($Type)2;

    $Type r = --n;

    r |= r >> 1;
    r |= r >> 2;
    r |= r >> 4;

    $if (@sizeof(n) >= 2): r |= r >> 8; $endif
    $if (@sizeof(n) >= 4): r |= r >> 16; $endif
    $if (@sizeof(n) >= 8): r |= r >> 32; $endif

    return ++r;
}

//------------------------------------------------------------------------------

<*
    The standard allocator function for the VM. This wraps the main allocator
    to track the memory usage and trigger garbage collections, when necessary.

    @param [&inout] vm : "A pointer to a LoxVM."
    @param [inout] ptr : "A pointer to memory to reallocate."
    @param old_size : "The current size of the memory block (in number of bytes.)"
    @param new_size : "The new size for the memory block (in number of bytes.)"

    @require old_size >= 0 : "A memory block cannot have a negative size."
    @require new_size >= 0 : "Cannot allocate a negative number of bytes."
*>
fn void *reallocate(LoxVM *vm, void *ptr, sz old_size, sz new_size)
{
    vm.bytes_allocated += new_size - old_size;
    return vm.realloc(ptr, new_size);
}

//------------------------------------------------------------------------------

<*
    The default implementation of the `LoxReallocFn`. This simply uses `realloc`
    or `free`, depending on the value passed to the [size] parameter.

    @param [inout] ptr : "A pointer to memory to reallocate."
    @param size : "The size of the memory block (in number of bytes.)"

    @require size >= 0 : "Cannot allocate a negative number of bytes."
*>
fn void *__reallocate(void *ptr, sz size) @private
{
    if (size == 0)
    {
        alloc::free(mem, ptr);
        return null;
    }

    return alloc::realloc(mem, ptr, size);
}
