module lox::table;
import lox::memory, lox::value, lox::vm;

const double MAX_LOAD_FACTOR = 0.75;

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

fn void Table.free(&self, LoxVM *vm)
{
    deallocate_array(Entry, vm, self.entries, self.capacity);
    self.init();
}

fn Entry *find_entry(Entry *entries, int capacity, ObjString *key)
{
    uint index = key.hash & (capacity - 1);
    Entry *tombstone = null;

    for (;;)
    {
        Entry *entry = &entries[index];
        if (entry.key == null)
        {
            if (is_nil(entry.value))
            {
                // Empty entry
                return tombstone != null ? tombstone : entry;
            }
            else
            {
                // We found a tombstone
                if (tombstone == null) tombstone = entry;
            }
        }
        else if (entry.key == key)
        {
            // We found the key
            return entry;
        }

        index = (index + 1) & (capacity - 1);
    }
}

fn void Table.adjust_capacity(&self, LoxVM *vm, int capacity)
{
    Entry *entries = allocate_array(Entry, vm, capacity);
    for (int i = 0; i < capacity; i++)
    {
        entries[i].key = null;
        entries[i].value = make_nil();
    }

    self.count = 0;
    for (int i = 0; i < self.capacity; i++)
    {
        Entry *entry = &self.entries[i];
        if (entry.key == null) continue;

        Entry *dest = find_entry(entries, capacity, entry.key);
        dest.key = entry.key;
        dest.value = entry.value;
        self.count++;
    }

    deallocate_array(Entry, vm, self.entries, self.capacity);
    self.entries = entries;
    self.capacity = capacity;
}

fn bool Table.get(&self, ObjString *key, Value *value)
{
    if (self.count == 0) return false;

    Entry *entry = find_entry(self.entries, self.capacity, key);
    if (entry.key == null) return false;

    *value = entry.value;
    return true;
}

fn bool Table.set(&self, LoxVM *vm, ObjString *key, Value value)
{
    if ((double)(self.count + 1) > self.capacity * MAX_LOAD_FACTOR)
    {
        int capacity = grow_capacity(self.capacity);
        self.adjust_capacity(vm, capacity);
    }

    Entry *entry = find_entry(self.entries, self.capacity, key);
    bool is_new_key = entry.key == null;
    if (is_new_key && is_nil(entry.value)) self.count++;

    entry.key = key;
    entry.value = value;
    return is_new_key;
}

fn bool Table.delete(&self, ObjString *key)
{
    if (self.count == 0) return false;

    Entry *entry = find_entry(self.entries, self.capacity, key);
    if (entry.key == null) return false;

    entry.key = null;
    entry.value = make_bool(true);
    return true;
}

fn ObjString *Table.find_string(&self, char *text, uint length, uint hash)
{
    if (self.count == 0) return null;

    uint index = hash & (self.capacity - 1);
    for (;;)
    {
        Entry *entry = &self.entries[index];
        if (entry.key == null)
        {
            // Stop if we find an empty non-tombstone entry
            if (is_nil(entry.value)) return null;
        }
        else if (entry.key.length == length &&
                 entry.key.hash == hash &&
                 mem::equals(entry.key.value, text, length))
        {
            // We found it
            return entry.key;
        }

        index = (index + 1) & (self.capacity - 1);
    }
}

fn void add_all(LoxVM *vm, Table *from, Table *to)
{
    for (int i = 0; i < from.capacity; i++)
    {
        Entry *entry = &from.entries[i];
        if (entry.key != null)
        {
            to.set(vm, entry.key, entry.value);
        }
    }
}
