module lox::table;
import lox::memory;
import lox::object;
import lox::value;

//===----------------===//
//      Hash Table
//===----------------===//

const MAX_LOAD_FACTOR = 0.75;

<*
    The structure representing a key-value pair in a hash table.
*>
struct Entry
{
    ObjString *key;
    Value value;
}

<*
    The structure for the hash table implementation of Lox.

    A hash table is just a dynamic array of key-value pairs (an Entry, as its known),
    with they key having a specific associated hash value.

    NOTE: In Lox, the hash table uses only an (ObjString) as its key. Lox also
    interns ALL strings. As a result, the associated hash value is stored within
    the (ObjString) struct itself, and NOT in the (Entry) struct.
*>
struct Table
{
    int capacity;
    int count;
    Entry *entries;
}

<*
    Initializes a hash table.

    @param [&inout] self "A reference to the table to initialize"
*>
fn void Table.init(&self)
{
    self.capacity = 0;
    self.count = 0;
    self.entries = null;
}

<*
    Free's the associated memory for a hash table.

    @param [&inout] self "A reference to the table containing freeable data"
*>
fn void Table.free(&self)
{
    memory::free_array(Entry, self.entries, self.capacity);
    self.init();
}

<*
    Searches through [entries] to find the provided [key], based on the hash of
    the [key] % the [capacity].

    NOTE: This uses the optimized modulo operator, which in this example is
    'hash & (capacity - 1)'. This is usually not added until the optimization chapter,
    however from past experience, C3 seems to not like using the direct modulo.

    @param [&in] entries "The array of entries to search through"
    @param capacity "The capacity of the table of entries"
    @param [&in] key "The key to search for"
*>
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
                // Found a tombstone
                if (tombstone == null) tombstone = entry;
            }
        }
        else if (entry.key == key)
        {
            // Found the key
            return entry;
        }

        index = (index + 1) & (capacity - 1);
    }
}

<*
    Reallocates [self].entries as needed by [capacity].

    @param [&inout] self "A reference to the table to adjust the capacity for"
    @param capacity "The new capacity value to reallocate the table for"
*>
fn void Table.adjust_capacity(&self, int capacity) @private
{
    Entry *entries = memory::allocate(Entry, capacity);
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

        Entry *dest = find_entry(entries, capacity, entry.key);
        dest.key = entry.key;
        dest.value = entry.value;
        self.count++;
    }

    memory::free_array(Entry, self.entries, self.capacity);
    self.entries = entries;
    self.capacity = capacity;
}

<*
    Take's in a [value] by pointer in order to load it with
    the matching pair for the [key] if that [key] is found.

    @param [&inout] self "A reference to the table to search through"
    @param [&in] key "The key of the entry to find"
    @param [&inout] value "The Value to load with the found value"
*>
fn bool Table.get(&self, ObjString *key, Value *value)
{
    if (self.count == 0) return false;

    Entry *entry = find_entry(self.entries, self.capacity, key);
    if (entry.key == null) return false;

    *value = entry.value;
    return true;
}

<*
    If the [key] is not new, this will set that [key] to whatever the provided [value]
    is and return 'false'. If it is new, it add's a new (Entry) to the [self] and loads the key-value
    pair with the provided values, returning 'true'.

    @param [&inout] self "A reference to the table to set a key-value pair for"
    @param [&in] key "The key of the entry to set"
    @param value "The value of the entry to set"
*>
fn bool Table.set(&self, ObjString *key, Value value)
{
    if ((double)(self.count + 1) > self.capacity * MAX_LOAD_FACTOR)
    {
        int capacity = memory::grow_capacity(self.capacity);
        self.adjust_capacity(capacity);
    }

    Entry *entry = find_entry(self.entries, self.capacity, key);
    bool is_new_key = entry.key == null;
    if (is_new_key && is_nil(entry.value)) self.count++;

    entry.key = key;
    entry.value = value;
    return is_new_key;
}

<*
    Remove's an entry by [key] from [self].

    @param [&inout] self "A reference to the table to remove an entry from"
    @param [&inout] key "The key of the entry to remove"
*>
fn bool Table.delete(&self, ObjString *key)
{
    if (self.count == 0) return false;

    Entry *entry = find_entry(self.entries, self.capacity, key);
    if (entry.key == null) return false;

    entry.key = null;
    entry.value = bool_val(true);
    return true;
}

<*
    Add's all entries [from] on table [to] another.

    NOTE: 'from' is taking the place of 'self' for this method just
    so it makes a little more sense when reading.

    @param [&inout] from "The table to pull entries from"
    @param [&inout] to "The table to add entries to"
*>
fn void Table.add_all(&from, Table *to)
{
    for (int i = 0; i < from.capacity; i++)
    {
        Entry *entry = &from.entries[i];

        if (entry.key != null)
            { to.set(entry.key, entry.value); }
    }
}

<*
    Searches [self] for an interned string. All strings in Lox are interned,
    so if it exists it SHOULD be found.

    @param [&inout] self "A reference to the table to search for the string in"
    @param [&inout] chars "The array of characters in the string"
    @param len "The length of the string"
    @param hash "The hash value of the string"
*>
fn ObjString *Table.find_string(&self, char *chars, int len, uint hash)
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
        else if (entry.key.length == len &&
                 entry.key.hash == hash &&
                 mem::equals(entry.key.chars, chars, len))
        {
            // The key was found
            return entry.key;
        }

        index = (index + 1) & (self.capacity - 1);
    }
}

<*
    Marks roots within a given [table].

    @param [&in] table "The table to check and mark roots for"
*>
fn void mark_table(Table *table)
{
    for (int i = 0; i < table.capacity; i++)
    {
        Entry *entry = &table.entries[i];
        memory::mark_object((Obj *)entry.key);
        memory::mark_value(entry.value);
    }
}

<*
    Frees any 'white' strings in a [table] during a GC cycle.
*>
fn void remove_white(Table *table)
{
    for (int i = 0; i < table.capacity; i++)
    {
        Entry *entry = &table.entries[i];
        if (entry.key != null && !entry.key.obj.is_marked)
            { table.delete(entry.key); }
    }
}
