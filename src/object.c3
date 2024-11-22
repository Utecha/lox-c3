module lox::object;
import lox::chunk;
import lox::common;
import lox::memory @public;
import lox::table;
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
    Returns 'true' if the provided [value] is of the type (CLASS). Otherwise,
    it returns 'false'.

    @param value "The value to type check as a class"
*>
macro is_class(value) @builtin
    => is_obj_type(value, ObjType.CLASS);

<*
    Returns 'true' if the provided [value] is of the type (CLOSURE). Otherwise,
    it returns 'false'.

    @param value "The value to type check as a closure"
*>
macro is_closure(value) @builtin
    => is_obj_type(value, ObjType.CLOSURE);

<*
    Returns 'true' if the provided [value] is of the type (FUNCTION). Otherwise,
    it returns 'false'.

    @param value "The value to type check as a function"
*>
macro is_function(value) @builtin
    => is_obj_type(value, ObjType.FUNCTION);

<*
    Returns 'true' if the provided [value] is of the type (FUNCTION). Otherwise,
    it returns 'false'.

    @param value "The value to type check as a function"
*>
macro is_instance(value) @builtin
    => is_obj_type(value, ObjType.INSTANCE);

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
    Takes in a [value] that is expected to be a valid pointer to an (ObjClass)
    and casts it to an (ObjClass *) for other use.

    @param value "The value to cast"
*>
macro as_class(value) @builtin
    => (ObjClass *)as_obj(value);

<*
    Takes in a [value] that is expected to be a valid pointer to an (ObjClosure)
    and casts it to an (ObjClosure *) for other use.

    @param value "The value to cast"
*>
macro as_closure(value) @builtin
    => (ObjClosure *)as_obj(value);

<*
    Takes in a [value] that is expected to be a valid pointer to an (ObjFunction)
    and casts it to an (ObjFunction *) for other use.

    @param value "The value to cast"
*>
macro as_function(value) @builtin
    => (ObjFunction *)as_obj(value);

<*
    Takes in a [value] that is expected to be a valid pointer to an (ObjInstance)
    and casts it to an (ObjInstance *) for other use.

    @param value "The value to cast"
*>
macro as_instance(value) @builtin
    => (ObjInstance *)as_obj(value);

<*
    Takes in a [value] that is expected to be a valid pointer to an (ObjNative)
    and returns the underlying function directly.

    @param value "The value to return the function from"
*>
macro as_native(value) @builtin
    => ((ObjNative *)as_obj(value)).function;

<*
    Takes in a [value] that is expected to be a valid pointer to an (ObjString)
    and casts it to an (ObjString *) for other use.

    @param value "The value to cast"
*>
macro as_string(value) @builtin
    => (ObjString *)as_obj(value);

<*
    Takes in a [value] that is expected to be a valid pointer to an (ObjString)
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
    CLASS,
    CLOSURE,
    FUNCTION,
    INSTANCE,
    NATIVE,
    STRING,
    UPVALUE
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
    bool is_marked;
    Obj *next;
}

<*
    The object structure representing a (Class) in Lox.
*>
struct ObjClass
{
    Obj obj;
    ObjString *name;
}

<*
    The object structure representing a (Closure) in Lox.

    NOTE: The function contained within a closure stores its own [upvalue_count] field.
    It exists within the closure itself as well in the event the GC needs to know
    the size of the upvalue array after the closures function has been freed.
*>
struct ObjClosure
{
    Obj obj;
    ObjFunction *function;
    ObjUpvalue **upvalues;
    int upvalue_count;
}

<*
    The object structure representing a (Function) in Lox.
*>
struct ObjFunction
{
    Obj obj;
    int arity;
    int upvalue_count;
    Chunk chunk;
    ObjString *name;
}

<*
    The object structure representing an (Instance) of a class in Lox.
*>
struct ObjInstance
{
    Obj obj;
    ObjClass *class;
    Table fields;
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
    The object structure representing an (Upvalue) in Lox.
*>
struct ObjUpvalue
{
    Obj obj;
    Value *location;
    Value closed;
    ObjUpvalue *next;
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
    object.is_marked = false;
    object.next = vm.objects;
    vm.objects = object;

    $if $feature(DEBUG) &&& LOG_GC:
        io::eprintfn("Addr: %p | Allocated %d bytes for %s", (void *)object, size, type);
    $endif

    return object;
}

<*
    Allocates a new (ObjClass) on the heap and returns the pointer.

    @param [&in] name "The name of the class object"
*>
fn ObjClass *new_class(ObjString *name)
{
    ObjClass *class = allocate_obj(ObjClass, ObjType.CLASS);
    class.name = name;
    return class;
}

<*
    Allocates a new (ObjClosure) on the heap and returns the pointer.

    @param [&in] function "The function being enclosed"
*>
fn ObjClosure *new_closure(ObjFunction *function)
{
    ObjUpvalue **upvalues = memory::allocate(ObjUpvalue *, function.upvalue_count);
    for (int i = 0; i < function.upvalue_count; i++)
    {
        upvalues[i] = null;
    }

    ObjClosure *closure = allocate_obj(ObjClosure, ObjType.CLOSURE);
    closure.function = function;
    closure.upvalues = upvalues;
    closure.upvalue_count = function.upvalue_count;
    return closure;
}

<*
    Allocates a new (ObjFunction) on the heap and returns the pointer.
*>
fn ObjFunction *new_function()
{
    ObjFunction *function = allocate_obj(ObjFunction, ObjType.FUNCTION);
    function.arity = 0;
    function.upvalue_count = 0;
    function.chunk.init();
    function.name = null;
    return function;
}

fn ObjInstance *new_instance(ObjClass *class)
{
    ObjInstance *instance = allocate_obj(ObjInstance, ObjType.INSTANCE);
    instance.class = class;
    instance.fields.init();
    return instance;
}

<*
    Allocates a new (ObjNative) on the heap and returns the pointer.

    @param function "A pointer to a native C3 function"
*>
fn ObjNative *new_native(NativeFn function)
{
    ObjNative *native = allocate_obj(ObjNative, ObjType.NATIVE);
    native.function = function;
    return native;
}

<*
    Allocates a new (ObjUpvalue) on the heap and returns the pointer.

    @param [&in] slot "The address of the upvalue being allocated"
*>
fn ObjUpvalue *new_upvalue(Value *slot)
{
    ObjUpvalue *upvalue = allocate_obj(ObjUpvalue, ObjType.UPVALUE);
    upvalue.location = slot;
    upvalue.closed = nil_val();
    upvalue.next = null;
    return upvalue;
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

    vm::push(obj_val(string));
    vm.strings.set(string, nil_val());
    vm::pop();

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
        case CLASS:
            (void) io::fprintf(stream, "<class %s>", (ZString)as_class(value).name.chars);
        case CLOSURE:
            print_function(as_closure(value).function, stream);
        case FUNCTION:
            print_function(as_function(value), stream);
        case INSTANCE:
            (void) io::fprintf(stream, "<instance of class %s>", (ZString)as_instance(value).class.name.chars);
        case NATIVE:
            (void) io::fprintf(stream, "<native fn>");
        case STRING:
            (void) io::fprintf(stream, "%s", (ZString)as_cstring(value));
        case UPVALUE:
            (void) io::fprintf(stream, "upvalue");
    }
}
