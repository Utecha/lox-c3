module lox::value;
import lox::array;
import lox::opcode;
import lox::memory;
import std::io @norecurse;

//------------------------------------------------------------------------------

<* The percentage capacity at which the table requires resizing. *>
const sz TABLE_LOAD_PERCENT @local = 75;

<* The scalar factor for the growth of a table. *>
const sz GROWTH_FACTOR      @local = 2;

<* The minimum capacity of an array or table object. *>
const sz MIN_CAPACITY       @local = 16;

//------------------------------------------------------------------------------

<* A type alias for a VM-managed array of bytes. *>
alias ByteArray = LoxArray { char };

<* A type alias for a VM-managed array of Line data. *>
alias LineArray = LoxArray { Line };

<* A type alias for a VM-managed array of Values. *>
alias ValueArray = LoxArray { Value };

<* Defines the supported types of Objects for the Lox language. *>
enum ObjType : int
{
    FUNCTION,
    STRING,
    TABLE
}

<*
    The "base class" of all Objects.

    Each specific Object type has an Obj as its first member, inlined.
*>
struct Obj
{
    ObjType type;
    Obj *next;
}

<*
    Binds a bytecode offset to a line of user source code for run-length
    encoding line information.
*>
struct Line
{
    int n;
    sz offset;
}

<*
    Defines a function object; the main construct behind the language itself.

    A script is just an implicit "main" function object that closes over all
    other definitions.
*>
struct ObjFun
{
    inline Obj obj;
    ByteArray code;
    LineArray lines;
    ValueArray constants;
    sz max_slots;
}

<*
    Represents a single entry in a table object.
*>
struct TableEntry
{
    Value key;
    Value value;
}

<*
    Defines a table object.
*>
struct ObjTable
{
    inline Obj obj;
    sz capacity;
    sz length;
    TableEntry *entries;
}

<*
    Defines a string object.
*>
struct ObjString
{
    inline Obj obj;
    uint hash;
    sz length;
    char[*] data;
}

//------------------------------------------------------------------------------

<*
    Promotes a primitive boolean to a full Lox Value.

    @param boolean : "The boolean value to promote."
*>
macro Value make_bool(bool boolean) => boolean ? TRUE : FALSE;

<*
    Promotes a primitive number to a full Lox Value.

    @param number : "The number value to promote."
*>
macro Value make_num(double number) => number_to_value(number);

<*
    Promotes a primitive Obj to a full Lox Value.

    @param object : "The object to promote."
*>
macro Value make_obj(Obj *object) => object_to_value(object);

<*
    Demotes the given [value] into a function object.

    @param value : "The value to demote."
*>
macro ObjFun *as_function(Value value) => (ObjFun *)as_obj(value);

<*
    Demotes the given [value] into a string object.

    @param value : "The value to demote."
*>
macro ObjString *as_string(Value value) => (ObjString *)as_obj(value);

<*
    Returns the underlying String of a given [value] that's expected to be a
    pointer to an ObjString.

    @param value : "The value to obtain the String from."
*>
macro String as_c3string(Value value)
    => (String)as_string(value).data[:as_string(value).length];

<*
    Returns whether the given [value] is a function object.

    @param value : "The value to type check."
*>
macro bool is_function(Value value) => is_obj_type(value, FUNCTION);

<*
    Returns whether the given [value] is a string object.

    @param value : "The value to type check."
*>
macro bool is_string(Value value) => is_obj_type(value, STRING);

//------------------------------------------------------------------------------

<*
    Prints the given [value] to stdout.

    @param value : "The value to print."
*>
fn void print(Value value)
{
    $if $feat(NAN_TAGGING):
        if (is_num(value))
        {
            io::printf("%.16g", as_num(value));
        }
        else if (is_obj(value))
        {
            print_obj(value);
        }
        else
        {
            switch (get_tag(value))
            {
                case TAG_NAN:       io::print("NaN");
                case TAG_NIL:       io::print("nil");
                case TAG_FALSE:     io::print("false");
                case TAG_TRUE:      io::print("true");
                case TAG_UNDEFINED: unreachable();
            }
        }
    $else
        switch (value.type)
        {
            case FALSE:     io::print("false");
            case NIL:       io::print("nil");
            case NUMBER:    io::printf("%.16g", as_num(value));
            case OBJECT:    print_obj(value);
            case TRUE:      io::print("true");
            case UNDEFINED: unreachable();
        }
    $endif
}

<*
    Returns whether [a] and [b] are equal Values.

    @param a : "The first Value to compare."
    @param b : "The second Value to compare."
*>
fn bool equals(Value a, Value b)
{
    if (same(a, b)) return true;

    // If we reach here, it's only possible for two immutable objects to
    // be equal.
    if (!is_obj(a) || !is_obj(b)) return false;

    Obj *a_obj = as_obj(a);
    Obj *b_obj = as_obj(b);

    // Must be the same type.
    if (a_obj.type != b_obj.type) return false;

    switch (a_obj.type)
    {
        case STRING:
            ObjString *a_str = (ObjString *)a_obj;
            ObjString *b_str = (ObjString *)b_obj;

            return a_str.hash == b_str.hash &&
                string_equals_cstring(a_str, &b_str.data[0], b_str.length);

        default:
            // All other types are only equal if they are the same.
            return false;
    }
}

<*
    Returns whether the given [string] is equal to the given C string [data].

    @param [&inout] string : "The string to compare."
    @param [&inout] data : "The C string to compare."
    @param length : "The length of the C string."
*>
fn bool string_equals_cstring(ObjString *string, char *data, sz length) @inline
{
    return string.length == length && mem::equals(&string.data[0], data, length);
}

<*
    Releases the memory for all of the objects held by [vm].

    @param [&inout] vm : "A pointer to a LoxVM."
*>
fn void free_objects(LoxVM *vm)
{
    Obj *obj = vm.objects;
    while (obj != null)
    {
        Obj *next = obj.next;
        free_obj(vm, obj);
        obj = next;
    }
}

<*
    Returns the pointer to a new function object managed by [vm].

    @param [&inout] vm : "A pointer to a LoxVM."
*>
fn ObjFun *new_function(LoxVM *vm)
{
    ObjFun *fun = memory::alloc(ObjFun, vm);
    init_obj(vm, fun, FUNCTION);

    fun.code = {};
    fun.lines = {};
    fun.constants = {};

    return fun;
}

<*
    Returns the corresponding line number for the given [offset] of the given
    functions bytecode.

    @param [&inout] fun : "A pointer to an ObjFun."
    @param offset : "The bytecode offset corresponding to a line number."
*>
fn int get_line(ObjFun *fun, sz offset)
{
    sz start = 0;
    sz end = fun.lines.len() - 1;

    while (start <= end)
    {
        sz mid = (start + end) / 2;
        Line line = fun.lines[mid];

        if (offset < line.offset)
        {
            end = mid - 1;
        }
        else if (mid == fun.lines.len() - 1 ||
                 offset < fun.lines[mid + 1].offset)
        {
            return line.n;
        }
        else
        {
            start = mid + 1;
        }
    }

    return -1;
}

<*
    Returns the pointer to a new table object.

    @param [&inout] vm : "A pointer to a LoxVM."
*>
fn ObjTable *new_table(LoxVM *vm)
{
    ObjTable *table = memory::alloc(ObjTable, vm);
    init_obj(vm, table, TABLE);

    table.capacity = 0;
    table.length = 0;
    table.entries = null;

    return table;
}

<*
    Releases the memory for the given [table]'s array of entries and zeroes out
    the pointer.

    @param [&inout] vm : "A pointer to a LoxVM."
    @param [&inout] table : "A pointer to the ObjTable to clear."
*>
fn void table_clear(LoxVM *vm, ObjTable *table)
{
    memory::free(TableEntry, vm, table.entries, table.capacity);
    *table = {};
}

<*
    Deletes the entry found at the given [key] from the given [table].

    NOTE: This has the potential to shrink the allocation of the entries
    array.

    @param [&inout] vm : "A pointer to a LoxVM."
    @param [&inout] table : "A pointer to an ObjTable."
    @param key : "The key of the entry to delete."
*>
fn Value table_delete(LoxVM *vm, ObjTable *table, Value key)
{
    TableEntry *entry;
    if (!table_find(table.entries, table.capacity, key, &entry))
        { return NIL; }

    // Remove the value for the entry from the table and replace the entry with
    // a tombstone. A tombstone is similar to an empty entry, except the value
    // is set to 'TRUE'. When searching for a key, we stop on empty slots, but
    // continue past any deleted ones.
    Value value = entry.value;
    entry.key = UNDEFINED;
    entry.value = TRUE;

    table.length--;
    if (table.length == 0)
    {
        // We removed the last item, so free the array.
        table_clear(vm, table);
    }
    else if (table.capacity > MIN_CAPACITY &&
             table.length < table.capacity / GROWTH_FACTOR * TABLE_LOAD_PERCENT / 100)
    {
        sz capacity = table.capacity / GROWTH_FACTOR;
        if (capacity < MIN_CAPACITY) capacity = MIN_CAPACITY;

        table_resize(vm, table, capacity);
    }

    return value;
}

<*
    @param [&inout] table : "A pointer to an ObjTable."
    @param key : "The key for the entry to set."
*>
fn Value table_get(ObjTable *table, Value key)
{
    TableEntry *entry;
    if (table_find(table.entries, table.capacity, key, &entry))
        { return entry.value; }

    return UNDEFINED;
}

<*
    If an entry already exists with the given [key], the value is then
    set to [value]. Otherwise, if it is a new key, the entries key
    and value fields are set to the given [key] and [value].

    @param [&inout] vm : "A pointer to a LoxVM."
    @param [&inout] table : "A pointer to an ObjTable."
    @param key : "The key for the entry to set."
    @param value : "The value for the entry to set."
*>
fn void table_set(LoxVM *vm, ObjTable *table, Value key, Value value)
{
    if (table.length + 1 > table.capacity * TABLE_LOAD_PERCENT / 100)
    {
        sz capacity = table.capacity * GROWTH_FACTOR;
        if (capacity < MIN_CAPACITY) capacity = MIN_CAPACITY;

        table_resize(vm, table, capacity);
    }

    if (table_insert(table.entries, table.capacity, key, value))
    {
        // A new key was added.
        table.length++;
    }
}

<*
    Returns the promoted Value for a new ObjString of [length] characters.

    @param [&inout] vm : "A pointer to a LoxVM."
    @param [inout] data : "A pointer to the beginning of the string data."
    @param length : "The length of the string."

    @require length == 0 || data != null : "Unexpected null string."
*>
fn Value new_string_length(LoxVM *vm, char *data, sz length)
{
    ObjString *string = allocate_string(vm, length);

    // Copy the string, if given one.
    if (length > 0 && data != null)
        { mem::copy(&string.data[0], data, length); }

    hash_string(string);
    return make_obj(string);
}

<*
    Returns the promoted Value for a new ObjString.

    @param [&inout] vm : "A pointer to a LoxVM."
    @param [inout] data : "A pointer to the beginning of the string data."
*>
fn Value new_string(LoxVM *vm, char *data)
{
    if (!data) return new_string_length(vm, data, 0);
    return new_string_length(vm, data, ((ZString)data).len());
}

<*
    Pops two string objects off the top of the stack, creates a new one
    to concatenate the strings, then pushes the result onto the stack.

    @param [&inout] vm : "A pointer to a LoxVM."
    @param a : "The starting string Value."
    @param b : "The ending string Value."
*>
fn Value concatenate(LoxVM *vm, Value a, Value b)
{
    ObjString *str_a = value::as_string(a);
    ObjString *str_b = value::as_string(b);

    sz length = str_a.length + str_b.length;
    ObjString *result = allocate_string(vm, length);

    mem::copy(&result.data[0], &str_a.data[0], str_a.length);
    mem::copy(&result.data[str_a.length], &str_b.data[0], str_b.length);

    hash_string(result);
    return make_obj(result);
}

//------------------------------------------------------------------------------

<*
    Returns the full Value representation for a primitive [number] based on
    whether the `NAN_TAGGING` feature flag exists.

    @param number : "The number to promote."
*>
fn Value number_to_value(double number) @inline @local
{
    $if $feat(NAN_TAGGING):
        return bitcast(number, Value);
    $else
        return (Value) { NUMBER, { .number = number } };
    $endif
}

<*
    Returns the full Value representation of a primitive [object] based on
    whether the `NAN_TAGGING` feature flag exists.

    @param [&inout] object : "A pointer to an Obj."
*>
fn Value object_to_value(Obj *object) @inline @local
{
    $if $feat(NAN_TAGGING):
        return (Value)(SIGN_BIT | QNAN | (ulong)(uptr)object);
    $else
        return (Value) { OBJECT, { .obj = object } };
    $endif
}

<*
    Returns whether [a] and [b] are strictly the same Value.

    For objects, this is their identity (pointer) and a direct value equality
    for unboxed Values.

    The implementation is compiled conditionally depending on whether the NaN
    tagging optimization is enabled.

    If it is, the values are just compared for equality directly as they have
    unique bit representations.

    @param a : "The first value to compare."
    @param b : "The second value to compare."
*>
fn bool same(Value a, Value b) @local
{
    $if $feat(NAN_TAGGING):
        return a == b;
    $else
        if (a.type != b.type) return false;
        if (a.type == NUMBER) return as_num(a) == as_num(b);
        return as_obj(a) == as_obj(b);
    $endif
}

<*
    Releases the memory for the given [obj].

    @param [&inout] vm : "A pointer to a LoxVM."
    @param [&inout] obj : "A pointer to the Obj to free."
*>
fn void free_obj(LoxVM *vm, Obj *obj) @local
{
    switch (obj.type)
    {
        case FUNCTION:
            ObjFun *fun = (ObjFun *)obj;
            fun.constants.clear(vm);
            fun.lines.clear(vm);
            fun.code.clear(vm);
            memory::free(ObjFun, vm, obj);

        case STRING:
            ObjString *string = (ObjString *)obj;
            memory::freef(ObjString, char, vm, obj, string.length + 1);

        case TABLE:
            ObjTable *table = (ObjTable *)obj;
            memory::free(TableEntry, vm, table.entries, table.capacity);
            memory::free(ObjTable, vm, obj);
    }
}

<*
    Prints the given [value], which is expected to be an Obj type, to stdout.

    @param value : "The object value to print."

    @require is_obj(value) : "Value must be a type of Obj."
*>
fn void print_obj(Value value) @local
{
    switch (as_obj(value).type)
    {
        case FUNCTION:
        case TABLE:
            return; // Not yet implemented

        case STRING:
            io::print(as_c3string(value));
    }
}

<*
    Returns whether the given [value] is an Obj of the given [type].

    @param value : "The value to check."
    @param type : "The type to check against."
*>
fn bool is_obj_type(Value value, ObjType type) @inline @local
{
    return is_obj(value) && as_obj(value).type == type;
}

<*
    Initializes the given [obj] and adds it to the linked list of objects.

    @param [&inout] vm : "A pointer to a LoxVM."
    @param [&inout] obj : "A pointer to an Obj."
    @param type : "The type of the object to initialize."
*>
fn void init_obj(LoxVM *vm, Obj *obj, ObjType type) @inline @local
{
    obj.type = type;
    obj.next = vm.objects;
    vm.objects = obj;
}

<*
    Returns a newly allocated ObjString of [length].

    The [length] value is the length of the actual string itself, not
    including the null byte.

    @param [&inout] vm : "A pointer to a LoxVM."
    @param length : "The length of the string."
*>
fn ObjString *allocate_string(LoxVM *vm, sz length) @local
{
    ObjString *string = memory::allocf(ObjString, char, vm, length + 1);
    init_obj(vm, string, STRING);

    string.hash = 0;
    string.length = length;
    string.data[length] = '\0';

    return string;
}

<*
    Hashes the raw bits of a numeric (traditional) or unboxed
    (nan-tagging) Value.

    The code is from the Wren language, which in turn cites:
    - v8's ComputeLongHash(), which in turn cites:
    - Thomas Wang, Integer Hash Functions:
    - https://gist.github.com/badboy/6267743

    @param hash : "The bits to hash."
*>
fn uint hash_bits(ulong hash)
{
    hash = ~hash + (hash << 18);
    hash = hash ^ (hash >> 31);
    hash = hash * 21;
    hash = hash ^ (hash >> 11);
    hash = hash + (hash << 6);
    hash = hash ^ (hash >> 22);
    return (uint)(hash & 0x3fffffff);
}

<*
    Returns the hash of the raw bits of the given [number].

    @param number : "The number to hash."
*>
fn uint hash_number(double number) @inline @local
{
    return hash_bits(bitcast(number, ulong));
}

<*
    Returns the hash of the given [obj].

    @param [&inout] obj : "A pointer to an Obj."
*>
fn uint hash_object(Obj *obj) @local
{
    switch (obj.type)
    {
        case FUNCTION:
            return 0; // Not yet implemented

        case STRING:
            return ((ObjString *)obj).hash;

        default:
            unreachable("Only immutable objects can be hashed.");
    }
}

<*
    Hashes the given string [data] using the FNV-1a hashing algorithm.

    @param [&inout] data : "The string data to hash."
    @param length : "The length of the string."
*>
fn uint hash_cstring(char *data, sz length) @local
{
    uint hash = 2166136261u;

    for (uint i = 0; i < length; i++)
    {
        hash ^= data[i];
        hash *= 16777619;
    }

    return hash;
}

<*
    Calculates and sets the hash for the given [string].

    @param [&inout] string : "The string to hash."
*>
fn void hash_string(ObjString *string) @local
{
    string.hash = hash_cstring(&string.data[0], string.length);
}

<*
    Returns the hash for the given [value], which must be one of the built-in
    immutable types: nil, bool, class, number, or string.

    @param value : "The value to hash."
*>
fn uint hash(Value value)
{
    $if $feat(NAN_TAGGING):
        if (is_obj(value)) return hash_object(as_obj(value));

        // Hash the raw bits of the unboxed Value.
        return hash_bits(value);
    $else
        switch (value.type)
        {
            case FALSE:     return 1;
            case NIL:       return 0;
            case NUMBER:    return hash_number(as_num(value));
            case OBJECT:    return hash_object(as_obj(value));
            case TRUE:      return 2;
            default:        unreachable();
        }
    $endif
}

<*
    Searches for an entry with the given [key] using open addressing
    and linear probing.

    If found, the [result] is set to point to it and 'true' is returned.
    Otherwise, the [result] is set to point to the entry where the key
    should be inserted and 'false' is returned.

    @param [&inout] entries : "The entries array of the table."
    @param capacity : "The expected capacity to resize to."
    @param key : "The key to find."
    @param result : "The resulting entry."
*>
fn bool table_find(TableEntry *entries, sz capacity, Value key, TableEntry **result) @local
{
    if (capacity == 0) return false;

    sz start_index = hash(key) & (capacity - 1);
    sz index = start_index;
    TableEntry *tombstone = null;

    do
    {
        TableEntry *entry = &entries[index];
        if (is_undef(entry.key))
        {
            if (is_false(entry.value))
            {
                *result = tombstone != null ? tombstone : entry;
                return false;
            }
            else
            {
                if (tombstone == null) tombstone = entry;
            }
        }
        else if (equals(entry.key, key))
        {
            *result = entry;
            return true;
        }
    } while (index != start_index);

    assert(tombstone != null, "Table should have tombstones or empty entries.");
    *result = tombstone;
    return false;
}

<*
    Probes the entries to find a suitable place to insert the [key]/[value]
    pair.

    Returns 'true' if the key is new. Otherwise, it returns 'false'.

    @param [&inout] entries : "The entries array of the table."
    @param capacity : "The expected capacity to resize to."
    @param key : "The key to insert."
    @param value : "The value to insert at the key."
*>
fn bool table_insert(TableEntry *entries, sz capacity, Value key, Value value) @local
{
    TableEntry *entry;
    if (table_find(entries, capacity, key, &entry))
    {
        // The key is already present, so just replace the value.
        entry.value = value;
        return false;
    }
    else
    {
        entry.key = key;
        entry.value = value;
        return true;
    }
}

<*
    Resizes the given [table] to the given [capacity].

    On resize, a new entries array is allocated with the original entries
    copied to it. The original entries array is then freed and the pointer
    is set to the new array.

    @param [&inout] vm : "A pointer to a LoxVM."
    @param [&inout] table : "A pointer to an ObjTable to resize."
    @param capacity : "The expected capacity to resize to."
*>
fn void table_resize(LoxVM *vm, ObjTable *table, sz capacity) @local
{
    // Create a new, empty hash table.
    TableEntry *entries = memory::alloca(TableEntry, vm, capacity);
    for (sz i = 0; i < capacity; i++)
    {
        entries[i].key = UNDEFINED;
        entries[i].value = FALSE;
    }

    // Re-add the existing entries.
    if (table.capacity > 0)
    {
        for (sz i = 0; i < table.capacity; i++)
        {
            TableEntry *entry = &table.entries[i];
            if (is_undef(entry.key)) continue;

            table_insert(entries, capacity, entry.key, entry.value);
        }
    }

    memory::free(TableEntry, vm, table.entries, table.capacity);
    table.entries = entries;
    table.capacity = capacity;
}

//==============================================================================
module lox::value @feat(!NAN_TAGGING);

//------------------------------------------------------------------------------

<* Defines the supported types of Values. *>
enum ValueType : int
{
    FALSE,
    NIL,
    NUMBER,
    OBJECT,
    TRUE,
    UNDEFINED
}

<* The traditional tagged union which represents a dynamic Value. *>
struct Value
{
    ValueType type;
    union as
    {
        double number;
        Obj *obj;
    }
}

//------------------------------------------------------------------------------

<* The traditional boolean singleton Value for 'false'. *>
const Value FALSE       = { FALSE, { 0 } };

<* The traditional singleton Value for 'nil'. *>
const Value NIL         = { NIL, { 0 } };

<* The traditional boolean singleton Value for 'true'. *>
const Value TRUE        = { TRUE, { 0 } };

<* The traditional singleton Value for an undefined Value. *>
const Value UNDEFINED   = { UNDEFINED, { 0 } };

//------------------------------------------------------------------------------

<*
    Demotes the given [value] back into a primitive bool.

    @param value : "The value to demote."
*>
macro bool as_bool(Value value)     => value.type == TRUE;

<*
    Demotes the given [value] back into a primitive number.

    @param value : "The value to demote."
*>
macro double as_num(Value value)    => value.as.number;

<*
    Demotes the given [value] back into a primitive Obj.

    @param value : "The value to demote."
*>
macro Obj *as_obj(Value value)      => value.as.obj;

<*
    Returns whether the given [value] is a boolean type.

    @param value : "The value to type check."
*>
macro bool is_bool(Value value)     => value.type == FALSE || value.type == TRUE;

<*
    Returns whether the given [value] is a false boolean type.

    @param value : "The value to type check."
*>
macro bool is_false(Value value)    => value.type == FALSE;

<*
    Returns whether the given [value] is a nil type.

    @param value : "The value to type check."
*>
macro bool is_nil(Value value)      => value.type == NIL;

<*
    Returns whether the given [value] is a number type.

    @param value : "The value to type check."
*>
macro bool is_num(Value value)      => value.type == NUMBER;

<*
    Returns whether the given [value] is an Obj type.

    @param value : "The value to type check."
*>
macro bool is_obj(Value value)      => value.type == OBJECT;

<*
    Returns whether the given [value] is an undefined type.

    @param value : "The value to type check."
*>
macro bool is_undef(Value value)    => value.type == UNDEFINED;

//==============================================================================
module lox::value @feat(NAN_TAGGING);

//------------------------------------------------------------------------------

<* The NaN boxed representation of a dynamic Value. *>
typedef Value = inline ulong;

//------------------------------------------------------------------------------

<* Bit mask for setting the 'sign bit' of a Value. *>
const ulong SIGN_BIT    = (ulong)1 << 63;

<* Bit mask for setting the quiet NaN bits of a Value. *>
const ulong QNAN        = (ulong)(0x7ffc000000000000);

<* Bit mask for extracting the type tag of a singleton Value. *>
const int MASK_TAG      = 7;

<* Bit mask that acts as a type tag for a NaN Value. *>
const int TAG_NAN       = 0;

<* Bit mask that acts as a type tag for a nil Value. *>
const int TAG_NIL       = 1;

<* Bit mask that acts as a type tag for a false boolean Value. *>
const int TAG_FALSE     = 2;

<* Bit mask that acts as a type tag for a true boolean Value. *>
const int TAG_TRUE      = 3;

<* Bit mask that acts as a type tag for an undefined Value. *>
const int TAG_UNDEFINED = 4;

<* The NaN boxed singleton Value for the boolean 'false'. *>
const Value FALSE       = (Value)(ulong)(QNAN | TAG_FALSE);

<* The NaN boxed singleton Value for nil. *>
const Value NIL         = (Value)(ulong)(QNAN | TAG_NIL);

<* The NaN boxed singleton Value for the boolean 'true'. *>
const Value TRUE        = (Value)(ulong)(QNAN | TAG_TRUE);

<* The NaN boxed singleton Value for an undefined Value. *>
const Value UNDEFINED   = (Value)(ulong)(QNAN | TAG_UNDEFINED);

//------------------------------------------------------------------------------

<*
    Returns the type tag for a NaN boxed singleton Value (which must be a singleton!)

    @param value : "The value to extract the tag from."
*>
macro int get_tag(Value value)      => (int)(value & MASK_TAG);

<*
    Demotes the given [value] back into a primitive bool.

    @param value : "The value to extract the tag from."
*>
macro bool as_bool(Value value)     => value == TRUE;

<*
    Demotes the given [value] back into a primitive number.

    @param value : "The value to extract the tag from."
*>
macro double as_num(Value value)    => bitcast(value, double);

<*
    Demotes the given [value] back into a primitive Obj.

    @param value : "The value to extract the tag from."
*>
macro Obj *as_obj(Value value)      => (Obj *)(uptr)(value & ~(SIGN_BIT | QNAN));

<*
    Returns whether the given [value] is a boolean type.

    @param value : "The value to extract the tag from."
*>
macro bool is_bool(Value value)     => value == FALSE || value == TRUE;

<*
    Returns whether the given [value] is a false boolean type.

    @param value : "The value to type check."
*>
macro bool is_false(Value value)    => value == FALSE;

<*
    Returns whether the given [value] is a nil type.

    @param value : "The value to type check."
*>
macro bool is_nil(Value value)      => value == NIL;

<*
    Returns whether the given [value] is a number type.

    @param value : "The value to type check."
*>
macro bool is_num(Value value)      => (value & QNAN) != QNAN;

<*
    Returns whether the given [value] is an Obj type.

    @param value : "The value to type check."
*>
macro bool is_obj(Value value)      => (value & (SIGN_BIT | QNAN)) == (SIGN_BIT) | QNAN;

<*
    Returns whether the given [value] is an undefined type.

    @param value : "The value to type check."
*>
macro bool is_undef(Value value)    => value == UNDEFINED;
