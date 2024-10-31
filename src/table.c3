module lox::table;
import lox::memory;
import lox::object;
import lox::value;
import lox::vm;

//===----------------------------------------------------------------------===//
// Lox | Table
//===----------------------------------------------------------------------===//

/*
 * In this module lies the Table (hash map) implementation for Lox. This could
 * be exposed to the user (and I will likely try to do so after getting it working).
 * In the book, however, it is only ever used internally.
*/

/* The maximum load factor for the Lox (Table) */
const float MAX_LOAD @private = 0.75;

/*
 * An (Entry) in a (Table).
 *
 * Currently only takes an (ObjString *) for the key. This is subject to change in
 * the future.
*/
struct Entry
{
    ObjString *key;
    Value value;
}

/*
 * A (Table) of (Entry)'s.
*/
struct Table
{
    int capacity;
    int count;
    Entry *entries;
}

/* Zero-initializes a new (Table) */
fn void Table.init(&self)
{
    self.count = 0;
    self.capacity = 0;
    self.entries = null;
}

/* Free's the pointer to [self.entries] and clears the (Table) */
fn void Table.free(&self)
{
    memory::free_array(Entry, self.entries, self.capacity);
    self.init();
}

/* Find an (Entry *) in the (Table)s array of [entries] */
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
                /* Empty entry */
                return tombstone != null ? tombstone : entry;
            }
            else
            {
                /* We found a tombstone */
                if (tombstone == null) tombstone = entry;
            }
        }
        else if (entry.key == key)
        {
            /* We found the entry */
            return entry;
        }

        index = (index + 1) & (self.capacity - 1);
    }
}

/*
 * On initialization, this in effect just allocates an array
 * of [entries] for us. Beyond that point, creates a new array
 * and copies the old entries into the new one. It then frees the
 * original array and initializes [self] with the new array.
*/
fn void Table.adjust_capacity(&self, int capacity)
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

        Entry *dest = self.find(entry.key);
        dest.key = entry.key;
        dest.value = entry.value;
        self.count++;
    }

    memory::free_array(Entry, self.entries, self.capacity);
    self.entries = entries;
    self.capacity = capacity;
}

/*
 * This method finds the [key] in the array of entries, and loads the
 * correspoding value into the [value] passed into this method.
 * Returns true on success, false on failure.
*/
fn bool Table.get(&self, ObjString *key, Value *value)
{
    if (self.count == 0) return false;

    Entry *entry = self.find(key);
    if (entry.key == null) return false;

    *value = entry.value;
    return true;
}

/*
 * This first check's if the (Table) needs to grow, then it checks
 * if the [key] is new or not in order to determine if the count
 * needs to increase. It then sets the [value] and returns the result
 * of [is_new_key].
*/
fn bool Table.set(&self, ObjString *key, Value value)
{
    if ((float)(self.count + 1) > self.capacity * MAX_LOAD)
    {
        int capacity = memory::grow_capacity(self.capacity);
        self.adjust_capacity(capacity);
    }

    Entry *entry = self.find(key);
    bool is_new_key = entry.key == null;
    if (is_new_key && is_nil(entry.value)) self.count++;

    entry.key = key;
    entry.value = value;
    return is_new_key;
}

/*
 * Deletes an (Entry *) from [self.entries].
*/
fn bool Table.delete(&self, ObjString *key)
{
    if (self.count == 0) return false;

    Entry *entry = self.find(key);
    if (entry.key == null) return false;

    entry.key = null;
    entry.value = bool_val(true);
    return true;
}

/*
 * For the purposes of making better mental sense of this method,
 * I renamed the first argument from [self] to [from] to signify that you
 * are copying the array of entries [from] the (Table) this method is invoked
 * on [to] another (Table).
*/
fn void Table.add_all(&from, Table *to)
{
    for (int i = 0; i < from.capacity; i++)
    {
        Entry *entry = &from.entries[i];
        if (entry.key != null)
            { to.set(entry.key, entry.value); }
    }
}

/*
 * Look for a particular (ObjString) in [self.entries]. This is used to return
 * interned (ObjString)s.
*/
fn ObjString *Table.find_string(&self, char *chars, int len, uint hash)
{
    if (self.count == 0) return null;

    uint index = hash & (self.capacity - 1);
    for (;;)
    {
        Entry *entry = &self.entries[index];
        if (entry.key == null)
        {
            /* Stop if we find an empty non-tombstone entry */
            if (is_nil(entry.value)) return null;
        }
        else if (entry.key.len == len &&
                entry.key.hash == hash &&
                mem::equals(entry.key.chars, chars, len))
        {
            /* We found it */
            return entry.key;
        }

        index = (index + 1) & (self.capacity - 1);
    }
}