module lox::array <Type>;
import lox::memory;

//------------------------------------------------------------------------------

<*
    A generic dynamic array structure whose memory is managed by the LoxVM.
*>
struct LoxArray
{
    sz capacity;
    sz length;
    Type *data;
}

//------------------------------------------------------------------------------

<*
    Releases the memory for the underlying array and zeroes out the receiver.

    The memory is managed by the LoxVM reallocator.

    @param [&inout] self : "A reference to the receiving LoxArray."
    @param [&inout] vm : "A pointer to a LoxVM."

    @ensure self.capacity == 0 && self.length == 0 && self.data == null
*>
fn void LoxArray.clear(&self, LoxVM *vm)
{
    memory::free(Type, vm, self.data, self.capacity);
    *self = {};
}

<*
    Fills the receiver with the given [value] by [count] times.

    The memory is managed by the LoxVM reallocator.

    @param [&inout] self : "A reference to the receiving LoxArray."
    @param [&inout] vm : "A pointer to a LoxVM."
    @param value : "The value to append."
    @param count : "The number of times to append the value."
*>
fn void LoxArray.fill(&self, LoxVM *vm, Type value, sz count)
{
    resize(vm, self, count);
    for (sz i = 0; i < count; i++)
    {
        self.data[self.length++] = value;
    }
}

<*
    Appends the given [value] to the receiver.

    The memory is managed by the LoxVM reallocator.

    @param [&inout] self : "A reference to the receiving LoxArray."
    @param [&inout] vm : "A pointer to a LoxVM."
    @param value : "The value to append."
*>
fn void LoxArray.append(&self, LoxVM *vm, Type value)
{
    resize(vm, self, 1);
    self.data[self.length++] = value;
}

<*
    Returns the value found at the given [index] within the receiver.

    NOTE: This is an operator overload method and is not meant to be called
    directly. Instead, index into the LoxArray directly.

    @param [&inout] self : "A reference to the receiving LoxArray."
    @param index : "The index of the value to get."

    @require [index] index < self.length : "Out of bounds memory access."
*>
fn Type LoxArray.get(&self, sz index) @operator([])
{
    return self.data[index];
}

<*
    Returns a reference to the value found at [index] within the receiver.

    NOTE: This is an operator overload method and is not meant to be called
    directly. Instead, index into the LoxArray directly.

    @param [&inout] self : "A reference to the receiving LoxArray."
    @param index : "The index of the value to get a reference to."

    @require [index] index < self.length : "Out of bounds memory access."
*>
fn Type *LoxArray.get_ref(&self, sz index) @operator(&[])
{
    return &self.data[index];
}

<*
    Sets the data found at the given [index] to the given [value].

    NOTE: This is an operator overload method and is not meant to be called
    directly. Instead, index into the LoxArray directly.

    @param [&inout] self : "A reference to the receiving LoxArray."
    @param index : "The index of the data to set."
    @param value : "The value to set the data to."

    @require [index] index < self.length : "Out of bounds memory access."
*>
fn void LoxArray.set(&self, sz index, Type value) @operator([]=)
{
    self.data[index] = value;
}

<*
    Returns the length of the receiver.

    NOTE: This is an operator overload method, however it can and essentially
    is meant to be called directly. You can otherwise just access it through
    the `length` property. It is up to personal preference.

    @param [&inout] self : "A reference to the receiving LoxArray."
*>
fn sz LoxArray.len(&self) @operator(len)
{
    return self.length;
}

//------------------------------------------------------------------------------

<*
    Resizes the given array by the current length plus the [expected] number of
    elements to add.

    The memory is managed by the LoxVM reallocator.

    @param [&inout] vm : "A pointer to a LoxVM."
    @param [&inout] arr : "A pointer to a LoxArray."
    @param expected : "The expected number of elements to add."

    @ensure arr.data != null
*>
fn void resize(LoxVM *vm, LoxArray *arr, sz expected) @inline @local
{
    if (arr.capacity < arr.length + expected)
    {
        sz capacity = memory::next_power_of_two(arr.length + expected);
        arr.data = memory::realloc(Type, vm, arr.data, arr.capacity, capacity);
        arr.capacity = capacity;
    }
}
