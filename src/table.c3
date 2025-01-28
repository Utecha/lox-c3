module lox::vm::table;
import lox::common;
import lox::vm::mem;
import lox::vm::value;
import lox::vm @norecurse;

//------------------------------------------------------------------------------
// Lox \ VM \ Table
//------------------------------------------------------------------------------

const float MAX_LOAD_FACTOR = 0.75;

struct Entry
{
    ObjString *key;
    Value value;
}

struct Table
{
    int capacity;
    int size;
    Entry *entries;
}

fn void Table.zero(&self)
{
    self.capacity = 0;
    self.size = 0;
    self.entries = null;
}

fn Table *Table.new(&self, int capacity = 8)
{
    self.zero();
    self.entries = mem::lalloc(Entry, capacity);
    self.capacity = capacity;
    return self;
}

fn void Table.free(&self)
{
    mem::lfree(Entry, self.entries, self.capacity);
    self.zero();
}

fn Entry *Table.find(&self, ObjString *key)
{
    uint index = key.hash & (self.capacity - 1);
    Entry *tombstone = null;

    for (;;)
    {
        Entry *entry = &self.entries[index];
        if (entry.key == null)
        {
            if (isNil(entry.value))
            {
                return tombstone != null ? tombstone : entry;
            }
            else
            {
                if (tombstone == null) tombstone = entry;
            }
        }
        else if (entry.key == key)
        {
            return entry;
        }

        index = (index + 1) & (self.capacity - 1);
    }
}

fn ObjString *Table.findString(&self, char[] chars, int len, uint hash)
{
    if (self.size == 0) return null;

    uint index = hash & (self.capacity - 1);
    for (;;)
    {
        Entry *entry = &self.entries[index];
        if (entry.key == null)
        {
            if (isNil(entry.value)) return null;
        }
        else if (entry.key.len == len &&
                 entry.key.hash == hash &&
                 mem::equals(entry.key.chars.ptr, chars.ptr, len))
        {
            return entry.key;
        }

        index = (index + 1) & (self.capacity - 1);
    }
}

fn void Table.adjustCapacity(&self, int capacity)
{
    Entry *entries = mem::lalloc(Entry, capacity);
    for (int i = 0; i < capacity; i++)
    {
        entries[i].key = null;
        entries[i].value = nilVal();
    }

    self.size = 0;
    for (int i = 0; i < self.capacity; i++)
    {
        Entry *entry = &self.entries[i];
        if (entry.key == null) continue;

        Entry *dest = self.find(entry.key);
        dest.key = entry.key;
        dest.value = entry.value;
        self.size++;
    }

    mem::lfree(Entry, self.entries, self.capacity);
    self.entries = entries;
    self.capacity = capacity;
}

fn bool Table.set(&self, ObjString *key, Value value)
{
    if (self.size + 1.0f > self.capacity * MAX_LOAD_FACTOR)
    {
        int capacity = nextPowOf2(self.capacity);
        self.adjustCapacity(capacity);
    }

    Entry *entry = self.find(key);
    bool isNewKey = entry.key == null;
    if (isNewKey && isNil(entry.value)) self.size++;

    entry.key = key;
    entry.value = value;
    return isNewKey;
}

fn bool Table.get(&self, ObjString *key, Value *value)
{
    if (self.size == 0) return false;

    Entry *entry = self.find(key);
    if (entry.key == null) return false;

    *value = entry.value;
    return true;
}

fn bool Table.delete(&self, ObjString *key)
{
    if (self.size == 0) return false;

    Entry *entry = self.find(key);
    if (entry.key == null) return false;

    entry.key = null;
    entry.value = boolVal(true);
    return true;
}

fn void Table.addAll(&from, Table *to)
{
    for (int i = 0; i < from.capacity; i++)
    {
        Entry *entry = &from.entries[i];
        if (entry.key != null)
        {
            to.set(entry.key, entry.value);
        }
    }
}
