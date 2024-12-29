module lox::list (<Type>);
import lox::common;
import lox::mem;

//------------------------------------------------------------------------------
// Lox \ List
//------------------------------------------------------------------------------

struct LoxList
{
    usz capacity;
    usz size;
    Type *values;
}

fn void LoxList.init(&self)
{
    self.capacity = 0;
    self.size = 0;
    self.values = null;
}

fn void LoxList.new(&self)
{
    self.init();
    self.values = mem::lalloc(Type, DEFAULT_LIST_CAPACITY);
    self.capacity = DEFAULT_LIST_CAPACITY;
}

fn void LoxList.free(&self)
{
    mem::lfree(self.values, self.capacity);
    self.init();
}

fn void LoxList.append(&self, Type value)
{
    if (self.capacity < self.size + 1)
    {
        usz old = self.capacity;
        self.capacity = nextPowOf2(old);
        self.values = mem::lrealloc(self.values, old, self.capacity);
    }

    self.values[self.size++] = value;
}

<*
    @require index <= self.size "Index out of bounds"
*>
fn Type LoxList.get(&self, int index) @operator([])
{
    return self.values[index];
}

<*
    @require index <= self.size "Index out of bounds"
*>
fn Type *LoxList.getref(&self, int index) @operator(&[])
{
    return &self.values[index];
}

<*
    @require index <= self.size "Index out of bounds"
*>
fn void LoxList.set(&self, int index, Type value) @operator([]=)
{
    self.values[index] = value;
}

fn usz LoxList.len(&self) @operator(len)
{
    return self.size;
}
