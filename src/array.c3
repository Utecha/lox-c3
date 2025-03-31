module lox::vm::array { Type };
import lox::utils, lox::vm::gc;
import std::io @norecurse;

struct Array
{
    int capacity;
    int count;
    Type *data;
}

fn void Array.init(&self)
{
    self.capacity = 0;
    self.count = 0;
    self.data = null;
}

fn void Array.free(&self, LoxGC *gc)
{
    deallocate(Type, gc, self.data, self.capacity);
    self.init();
}

fn void Array.fill(&self, LoxGC *gc, Type data, int count)
{
    if (self.capacity < self.count + count)
    {
         int capacity = utils::powof2ceil(self.count + count);
         self.data = reallocate(Type, gc, self.data, self.capacity, capacity);
         assert(self.data, "Out of memory");
         self.capacity = capacity;
    }

    for (int i = 0; i < count; i++)
    {
        self.data[self.count++] = data;
    }
}

fn void Array.append(&self, LoxGC *gc, Type data)
{
    self.fill(gc, data, 1);
}

fn Type Array.get(&self, int index) @operator([])
{
    return self.data[index];
}

fn Type *Array.getref(&self, int index) @operator(&[])
{
    return &self.data[index];
}

fn void Array.set(&self, int index, Type data) @operator([]=)
{
    self.data[index] = data;
}

fn int Array.len(&self) @operator(len)
{
    return self.count;
}

fn void Array.infoDump(&self)
{
    io::printfn("Data Address: %p", (void *)self.data);
    io::printfn("Capacity: %d", self.capacity);
    io::printfn("Element Count: %d", self.count);
}
