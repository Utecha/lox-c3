module lox::buffer (<Type>);
import lox::cli::utils, lox::gc::memory;

//------------------------------------------------------------------------------
// Lox \ VM \ Buffer
//------------------------------------------------------------------------------

struct TBuffer
{
    int capacity;
    int size;
    Type *entries;
}

fn void TBuffer.init(&self)
{
    self.capacity = 0;
    self.size = 0;
    self.entries = null;
}

fn TBuffer *TBuffer.new(&self, int capacity = 8)
{
    self.init();
    self.entries = memory::lalloc(Type, capacity);
    self.capacity = capacity;
    return self;
}

fn void TBuffer.free(&self)
{
    memory::lfree(Type, self.entries, self.capacity);
    self.init();
}

fn void TBuffer.append(&self, Type value)
{
    if (self.capacity < self.size + 1)
    {
        int capacity = self.capacity;
        self.capacity = memory::grow2x(capacity);
        self.entries = memory::lrealloc(Type, self.entries, capacity, self.capacity);
    }

    self.entries[self.size++] = value;
}

fn Type TBuffer.get(&self, int index) @operator([]) @inline
{
    assert(index < self.size);
    return self.entries[index];
}

fn Type *TBuffer.getref(&self, int index) @operator(&[]) @inline
{
    assert(index < self.size);
    return &self.entries[index];
}

fn void TBuffer.set(&self, int index, Type value) @operator([]=)
{
    assert(index < self.size);
    self.entries[index] = value;
}

fn int TBuffer.len(&self) @operator(len) @inline
{
    return self.size;
}

fn Type TBuffer.first(&self) @inline
{
    assert(self.size > 0);
    return self.entries[0];
}

fn Type TBuffer.last(&self) @inline
{
    assert(self.size > 0);
    return self.entries[self.size - 1];
}

fn Type TBuffer.pop(&self) @inline
{
    assert(self.size > 0);
    return self.entries[--self.size];
}
