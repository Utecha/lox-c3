module lox::buffer { Type };
import lox::memory, lox::vm;

struct Buffer
{
    int capacity;
    int count;
    Type *data;
}

<*
    @param [&inout] self : "The buffer to initialize"
*>
fn void Buffer.init(&self)
{
    self.capacity = 0;
    self.count = 0;
    self.data = null;
}

<*
    @param [&inout] self : "The buffer to free"
    @param [&inout] vm : "The VM managing the buffer"
*>
fn void Buffer.free(&self, LoxVM *vm)
{
    deallocate_array(Type, vm, self.data, self.capacity);
    self.init();
}

<*
    @param [&inout] self : "The buffer to write into"
    @param [&inout] vm : "The VM managing the buffer"
    @param data : "The data to write"

    @ensure self.data != null
*>
fn void Buffer.write(&self, LoxVM *vm, Type data)
{
    if (self.capacity < self.count + 1)
    {
        int capacity = grow_capacity(self.capacity);
        self.data = reallocate(Type, vm, self.data, self.capacity, capacity);
        self.capacity = capacity;
    }

    self.data[self.count++] = data;
}

<*
    @param [&inout] self : "The buffer to get data from"
    @param index : "The index of the data in the buffer"

    @require index < self.len()
*>
fn Type Buffer.get(&self, int index) @operator([])
{
    return self.data[index];
}

<*
    @param [&inout] self : "The buffer to set data in"
    @param index : "The index to set the data in the buffer"
    @param data : "The data to set"

    @require index < self.len()
*>
fn void Buffer.set(&self, int index, Type data) @operator([]=)
{
    self.data[index] = data;
}

<*
    @param [&inout] self : "The buffer to get the length of"
*>
fn int Buffer.len(&self) @operator(len)
{
    return self.count;
}
