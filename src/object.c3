module lox::object;
import lox::chunk;
import lox::memory @public;
import lox::value;
import lox::vm;
import std::io @norecurse;

//===----------------===//
//       Objects
//===----------------===//

/*
 * In Lox, an "object" is any value or structure of data/code that is too large to allocate
 * on the stack. The most common example of this is a string or a function.
*/

<*
    Extracts the type information from a (Value) that is an (Obj).

    @param value "The value to extract the object type from"
*>
macro obj_type(value) @builtin
    => as_obj(value).type;


<*
    Returns 'true' if the provided [value] is an (Obj), AND if the [type] of said (Obj)
    matches the provided [type].

    @param value "The value to object and type check"
    @param type "The type to check the value against"
*>
fn bool is_obj_type(Value value, ObjType type) @local
{
    return is_obj(value) && as_obj(value).type == type;
}

<*
    Returns 'true' if the provided [value] is of the type (FUNCTION). Otherwise,
    it returns 'false'.

    @param value "The value to type check as a function"
*>
macro is_function(value) @builtin
    => is_obj_type(value, ObjType.FUNCTION);

<*
    Returns 'true' if the provided [value] is of the type (NATIVE). Otherwise,
    it returns 'false'.

    @param value "The value to type check as a native function"
*>
macro is_native(value) @builtin
    => is_obj_type(value, ObjType.NATIVE);

<*
    Returns 'true' if the provided [value] is of the type (STRING). Otherwise,
    it returns 'false'.

    @param value "The value to type check as a string"
*>
macro is_string(value) @builtin
    => is_obj_type(value, ObjType.STRING);

<*
    Take's a [value] that is expected to be a valid pointer to an (ObjFunction)
    and casts it to an (ObjFunction *) for other use.

    @param value "The value to cast"
*>
macro as_function(value) @builtin
    => (ObjFunction *)as_obj(value);

<*
    Take's a [value] that is expected to be a valid pointer to an (ObjNative)
    and casts it to an (ObjNative *), returning the associated [function]
    pointer.

    @param value "The value to return a native function pointer from"
*>
macro as_native(value) @builtin
    => ((ObjNative *)as_obj(value)).function;

<*
    Take's a [value] that is expected to be a valid pointer to an (ObjString)
    and casts it to an (ObjString *) for other use.

    @param value "The value to cast"
*>
macro as_string(value) @builtin
    => (ObjString *)as_obj(value);

<*
    Take's a [value] that is expected to be a valid pointer to an (ObjString)
    and returns the underlying character array directly.

    @param value "The ObjString value to extract the character array from"
*>
macro as_cstring(value) @builtin
    => ((ObjString *)as_obj(value)).chars;

<*
    The type tag for an (Obj). A bare (Obj) is never actually used, but each object contains
    an (Obj) which itself contains one of these tags for determining the type.
*>
enum ObjType : int
{
    FUNCTION,
    NATIVE,
    STRING
}

<*
    The 'base class', if you will, of all objects in Lox. This structure contains all
    of the data that is common between each object.

    The true objects themselves all contain this structure as their first member, which
    allows you to freely cast their pointer to a raw (Obj *) and back. You can think of the
    fields of this structure as expanding inline inside of each object. This works basically
    the same as inheritance in object-oriented languages (like Lox for example).

    This structure also serves as an intrusive linked-list of objects so that they may be easily
    freed later.
*>
struct Obj
{
    ObjType type;
    Obj *next;
}

<*
    The object structure representing a (Function) in Lox.
*>
struct ObjFunction
{
    Obj obj;
    int arity;
    Chunk chunk;
    ObjString *name;
}

<*
    Function pointer to a native Lox function.
*>
def NativeFn = fn Value (int argc, Value *args);

<*
    The object structure representing a (Native) function in Lox.
*>
struct ObjNative
{
    Obj obj;
    NativeFn function;
}

<*
    The object structure representing a (String) in Lox.
*>
struct ObjString
{
    Obj obj;
    int length;
    char *chars;
    uint hash;
}

<*
    Allocates a generic (Obj) on the heap.

    This is wrapped by a macro that provides the necessary arguments and correctly
    typecasts the (Obj) to match the [type] of object being allocated.

    @param size "The size of the object"
    @param type "The type tag of the object"
*>
fn Obj *allocate_object(usz size, ObjType type)
{
    Obj *object = (Obj *)memory::reallocate(null, 0, size);
    object.type = type;
    object.next = vm.objects;
    vm.objects = object;
    return object;
}

<*
    Allocates a new (ObjFunction) on the heap and returns the pointer.
*>
fn ObjFunction *new_function()
{
    ObjFunction *function = allocate_obj(ObjFunction, ObjType.FUNCTION);
    function.arity = 0;
    function.chunk.init();
    function.name = null;
    return function;
}

<*
    Allocates a new (ObjNative) on the heap and returns the pointer.
*>
fn ObjNative *new_native(NativeFn function)
{
    ObjNative *native = allocate_obj(ObjNative, ObjType.NATIVE);
    native.function = function;
    return native;
}

<*
    Returns a newly allocated (Obj) of type [obj_type]. This is a wrapper around
    'allocate_object()' to avoid the need to redundantly cast the (void *) back
    into the correct ($Type *).

    @param $Type "The type of object to allocate"
    @param obj_type "The type tag for the object to allocate"
*>
macro allocate_obj($Type, obj_type) @local
{
    return ($Type *)allocate_object($Type.sizeof, obj_type);
}

<*
    Allocates a new (ObjString *) on the heap and returns it.

    @param [in] chars "The characters to initialize the ObjString with"
    @param len "The length of the character array of the ObjString"
*>
fn ObjString *allocate_string(char *chars, int len, uint hash) @private
{
    ObjString *string = allocate_obj(ObjString, ObjType.STRING);
    string.length = len;
    string.chars = chars;
    string.hash = hash;
    vm.strings.set(string, nil_val());
    return string;
}

fn uint hash_string(char *key, int len) @local
{
    uint hash = 2166136261u;
    for (int i = 0; i < len; i++)
    {
        hash ^= (char)key[i];
        hash *= 16777619;
    }

    return hash;
}

<*
    Allocates the memory for a new (char *) and copies the data from [chars] by [len]
    to the new character array. Returns an (ObjString *) that is allocated with that
    array.

    This exists because it is unsafe to have the (ObjString)'s character array point
    directly back into the users source code. This copies the characters over so that
    the (ObjString *) reliably owns its own array and can free it.

    @param [in] chars "The characters to copy over"
    @param len "The length of the string to copy"
*>
fn ObjString *copy_string(char* chars, int len)
{
    uint hash = hash_string(chars, len);

    ObjString *interned = vm.strings.find_string(chars, len, hash);
    if (interned != null) return interned;

    char *heap_chars = memory::allocate(char, len + 1);
    mem::copy(heap_chars, chars, len);
    heap_chars[len] = '\0';
    return allocate_string(heap_chars, len, hash);
}

<*
    Used generally during runtime for operations such as concatenation,
    this function assumes it CAN take ownership of the characters passed in.

    This is the opposite of 'copy_string()', which creates a copy of the characters
    that are passed in as it assumes it CANNOT take ownership of said characters.
*>
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

<*
    Handles the printing of function objects.

    @param [&in] function "A reference to the function to print"
    @param stream "The output stream to print to"
*>
fn void print_function(ObjFunction *function, OutStream stream) @local
{
    if (function.name == null)
    {
        (void) io::fprintf(stream, "<fn main>");
        return;
    }

    (void) io::fprintf(stream, "<fn %s>", (ZString)function.name.chars);
}

<*
    Print function specific to Lox objects.

    @param value "The Value to print"
    @param stream "The output stream to print to (default is stdout)"
*>
fn void print(Value value, OutStream stream = io::stdout())
{
    switch (obj_type(value))
    {
        case FUNCTION:
            print_function(as_function(value), stream);
        case NATIVE:
            (void) io::fprintf(stream, "<native fn>");
        case STRING:
            (void) io::fprintf(stream, "%s", (ZString)as_cstring(value));
    }
}
