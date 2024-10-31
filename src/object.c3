module lox::object;
import lox::memory;
import lox::value;
import lox::vm;
import std::io @norecurse;

//===----------------------------------------------------------------------===//
// Lox | Object
//===----------------------------------------------------------------------===//

/* Object Type Tag */
enum ObjType : int
{
    STRING
}

/*
 * The base (Obj) representation.
 *
 * This exists in order to implement what is the effective equivalent of inheritance in C.
 * Each type of (Obj), such as an (ObjString), takes a raw (Obj) as its first member,
 * which causes the fields in (Obj) to expand inline to be a part of the (ObjString). It also
 * enables the ability to freely cast an (Obj) to another (ObjString) and back, assuming it is
 * safe to do so.
 *
 * It also serves to provide a linked-list of objects so that they may all be found and freed
 * later.
*/
struct Obj
{
    ObjType type;
    Obj *next;
}

/* Lox's (String) representation */
struct ObjString
{
    Obj obj;
    int len;
    uint hash;
    char *chars;
}

/* Extract the type tag for an Obj */
macro ObjType obj_type(value)   @builtin => as_obj(value).type;

/* Similar to the macros in 'value.c3', these check if an (Obj) is of the appropriate (ObjType) */
macro bool is_string(value)     @builtin => is_obj_type(value, STRING);

/* This mostly exists to avoid having to type cast the result of 'allocate_object()' */
macro allocate_obj($Type, obj_type) @builtin
{
    return ($Type *)allocate_object($Type.sizeof, obj_type);
}

/*
 * These macros accept a [value] that is expected to contain a pointer to a valid (ObjString) on
 * the heap. The first one returns the (ObjString) pointer, the second returns the character array
 * itself.
*/
macro ObjString *as_string(value)   @builtin => (ObjString *)as_obj(value);
macro char *as_cstring(value)       @builtin => ((ObjString *)as_obj(value)).chars;

/* Check's if a value is an (Obj) of the provided (ObjType) */
fn bool is_obj_type(Value value, ObjType type) @builtin @inline
{
    return is_obj(value) && as_obj(value).type == type;
}

/* Allocates an (Obj) on the heap and returns the pointer */
fn Obj *allocate_object(usz size, ObjType type)
{
    Obj *object = (Obj *)memory::reallocate(null, 0, size);
    object.type = type;
    object.next = vm.objects;
    vm.objects = object;
    return object;
}

/* Allocates an (ObjString) on the heap and returns the pointer */
fn ObjString *allocate_string(char *chars, int len, uint hash) @private
{
    ObjString *string = allocate_obj(ObjString, ObjType.STRING);
    string.len = len;
    string.hash = hash;
    string.chars = chars;
    vm.strings.set(string, nil_val());
    return string;
}

/*
 * FNV-1a hashing algorithm for hashing an (ObjString).
 *
 * This exists here since the only keys usable in the (Table) are
 * (ObjString)s. As a result, the hash is stored within the (ObjString)
 * directly to make it easier to intern said (ObjString).
*/
fn uint hash_string(char *key, int len) @private
{
    uint hash = 2166136261u;
    for (int i = 0; i < len; i++)
    {
        hash ^= (char)key[i];
        hash *= 16777619;
    }

    return hash;
}

/*
 * Takes ownership of and returns a freshly allocated (ObjString) populated
 * with the provided [chars].
 *
 * It also creates a fresh hash for that new (ObjString).
*/
fn ObjString *take_string(char *chars, int len)
{
    uint hash = hash_string(chars, len);

    ObjString *interned = vm.strings.find_string(chars, len, hash);
    if (interned != null)
    {
        memory::free_array(char, chars, len + 1);
        return interned;
    }

    return allocate_string(chars, len, hash);
}

/* Makes a copy of the [chars] passed into it */
fn ObjString *copy_string(char *chars, int len)
{
    uint hash = hash_string(chars, len);

    ObjString *interned = vm.strings.find_string(chars, len, hash);
    if (interned != null) return interned;

    char *heap_chars = memory::allocate(char, len + 1);
    mem::copy(heap_chars, chars, len);
    heap_chars[len] = '\0';

    return allocate_string(heap_chars, len, hash);
}

/*
 * Same as the one for values, with the exception of [stream] not being a
 * default argument. The reason for this is that this function is only ever called
 * from 'value::print()', which is guaranteed to provide the [stream].
 *
 * All (Obj)s in lox are also (Value)s, which is why it takes a value and is only
 * ever called from the (Value)s print function.
*/
fn void print(Value value, OutStream stream)
{
    switch (obj_type(value))
    {
        case STRING:
            String string = (String)as_cstring(value)[:as_string(value).len];
            (void) io::fprintf(stream, "%s", string);
    }
}