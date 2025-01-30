module lox::vm::table;
import lox::vm::value;
import lox::cli::utils, lox::gc::memory;

//------------------------------------------------------------------------------
// Lox | VM | Table
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
    int count;
    Entry *entries;
}

fn void Table.init(&self)
{
    self.capacity = 0;
    self.count = 0;
    self.entries = null;
}

fn Table *Table.new(&self, int capacity = 8)
{
    self.init();
    self.entries = memory::lalloc(Entry, capacity);
    self.capacity = capacity;
    return self;
}

fn void Table.free(&self)
{
    memory::lfree(Entry, self.entries, self.capacity);
    self.init();
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
            if (is_nil(entry.value))
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

fn ObjString *Table.find_string(&self, char[] chars, int len, uint hash)
{
    if (self.count == 0) return null;

    uint index = hash & (self.capacity - 1);
    for (;;)
    {
        Entry *entry = &self.entries[index];
        if (entry.key == null)
        {
            if (is_nil(entry.value)) return null;
        }
        else if (entry.key.len == len &&
                 entry.key.hash == hash &&
                 mem::equals(entry.key.value.ptr, chars.ptr, len))
        {
            return entry.key;
        }

        index = (index + 1) & (self.capacity - 1);
    }
}

fn void Table.resize(&self, int capacity)
{
    Entry *entries = memory::lalloc(Entry, capacity);
    for (int i = 0; i < capacity; i++)
    {
        entries[i].key = null;
        entries[i].value = nil_val();
    }

    self.count = 0;
    for (int i = 0; i < self.capacity; i++)
    {
        Entry *entry = &self.entries[i];
        if (entry.key == null) continue;

        Entry *dest = self.find(entry.key);
        dest.key = entry.key;
        dest.value = entry.value;
        self.count++;
    }

    memory::lfree(Entry, self.entries, self.capacity);
    self.entries = entries;
    self.capacity = capacity;
}

fn bool Table.set(&self, ObjString *key, Value value)
{
    if (self.count + 1.0f > self.capacity * MAX_LOAD_FACTOR)
    {
        int capacity = memory::grow2x(self.capacity);
        self.resize(capacity);
    }

    Entry *entry = self.find(key);
    bool is_new_key = entry.key == null;
    if (is_new_key && is_nil(entry.value)) self.count++;

    entry.key = key;
    entry.value = value;
    return is_new_key;
}

fn bool Table.get(&self, ObjString *key, Value *value)
{
    if (self.count == 0) return false;

    Entry *entry = self.find(key);
    if (entry.key == null) return false;

    *value = entry.value;
    return true;
}

fn bool Table.delete(&self, ObjString *key)
{
    if (self.count == 0) return false;

    Entry *entry = self.find(key);
    if (entry.key == null) return false;

    entry.key = null;
    entry.value = bool_val(true);
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
