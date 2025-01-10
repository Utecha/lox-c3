module lox::vm::list (<Type>);
import lox::common;
import lox::vm::mem;

//------------------------------------------------------------------------------
// Lox \ VM \ Buffer
//------------------------------------------------------------------------------

struct LoxList
{
    int capacity;
    int size;
    Type *entries;
}

fn void LoxList.zero(&self)
{
    self.capacity = 0;
    self.size = 0;
    self.entries = null;
}

fn LoxList *LoxList.new(&self, int capacity = 8)
{
    self.zero();
    self.entries = mem::lalloc(Type, capacity);
    self.capacity = capacity;
    return self;
}

fn void LoxList.free(&self)
{
    mem::lfree(Type, self.entries, self.capacity);
    self.zero();
}

fn void LoxList.append(&self, Type value)
{
    if (!self.entries) self.new();

    if (self.capacity < self.size + 1)
    {
        int oldCapacity = self.capacity;
        self.capacity = nextPowOf2(oldCapacity);
        self.entries = mem::lrealloc(Type, self.entries, oldCapacity, self.capacity);
    }

    self.entries[self.size++] = value;
}

fn Type LoxList.get(&self, int index) @operator([]) @inline
{
    assert(index < self.size);
    return self.entries[index];
}

fn Type *LoxList.getref(&self, int index) @operator(&[]) @inline
{
    assert(index < self.size);
    return &self.entries[index];
}

fn void LoxList.set(&self, int index, Type value) @operator([]=)
{
    assert(index < self.size);
    self.entries[index] = value;
}

fn int LoxList.len(&self) @operator(len) @inline
{
    return self.size;
}

fn Type LoxList.first(&self) @inline
{
    assert(self.size > 0);
    return self.entries[0];
}

fn Type LoxList.last(&self) @inline
{
    assert(self.size > 0);
    return self.entries[self.size - 1];
}

fn Type LoxList.pop(&self) @inline
{
    assert(self.size > 0);
    return self.entries[--self.size];
}
