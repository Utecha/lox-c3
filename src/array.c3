module lox::array <Type>;
import lox::memory;

//------------------------------------------------------------------------------

struct LoxArray
{
    sz capacity;
    sz length;
    Type *data;
}

//------------------------------------------------------------------------------

fn void LoxArray.clear(&self, LoxVM *vm)
{
    memory::free(Type, vm, self.data, self.capacity);
    *self = {};
}

fn void LoxArray.fill(&self, LoxVM *vm, Type value, sz count)
{
    resize(vm, self, count);
    for (sz i = 0; i < count; i++)
    {
        self.data[self.length++] = value;
    }
}

fn void LoxArray.append(&self, LoxVM *vm, Type value)
{
    resize(vm, self, 1);
    self.data[self.length++] = value;
}

fn Type LoxArray.get(&self, sz index) @operator([])
{
    return self.data[index];
}

fn Type *LoxArray.get_ref(&self, sz index) @operator(&[])
{
    return &self.data[index];
}

fn void LoxArray.set(&self, sz index, Type value) @operator([]=)
{
    self.data[index] = value;
}

fn sz LoxArray.len(&self) @operator(len)
{
    return self.length;
}

//------------------------------------------------------------------------------

fn void resize(LoxVM *vm, LoxArray *arr, sz expected) @inline @local
{
    if (arr.capacity < arr.length + expected)
    {
        sz capacity = memory::next_power_of_two(arr.length + expected);
        arr.data = memory::realloc(Type, vm, arr.data, arr.capacity, capacity);
        arr.capacity = capacity;
    }
}
