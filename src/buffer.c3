module lox::buffer { Type };
import lox::memory, lox::vm;

struct Buffer
{
    int capacity;
    int count;
    Type *data;
}

fn void Buffer.init(&self)
{
    self.capacity = 0;
    self.count = 0;
    self.data = null;
}

fn void Buffer.free(&self, LoxVM *vm)
{
    deallocate_array(Type, vm, self.data, self.capacity);
    self.init();
}

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

<* @require index <= self.len() - 1 *>
fn Type Buffer.get(&self, int index) @operator([])
{
    return self.data[index];
}

<* @require index <= self.len() - 1 *>
fn void Buffer.set(&self, int index, Type value) @operator([]=)
{
    self.data[index] = value;
}

fn int Buffer.len(&self) @operator(len)
{
    return self.count;
}
