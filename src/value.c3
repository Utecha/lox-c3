module lox::value;
import lox::array;
import lox::opcode;
import lox::memory;
import std::io @norecurse;

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
    STRING
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
    $if $feat(NAN_TAGGING):
        if (is_num(a) && is_num(b)) return as_num(a) == as_num(b);
        return a == b;
    $else
        if (a.type != b.type) return false;
        switch (a.type)
        {
            case FALSE:
            case TRUE:
                return as_bool(a) == as_bool(b);

            case NIL:
                return true;

            case NUMBER:
                return as_num(a) == as_num(b);

            case OBJECT:
                ObjString *str_a = as_string(a);
                ObjString *str_b = as_string(b);

                return str_a.length == str_b.length &&
                    str_a.hash == str_b.hash &&
                    mem::equals(&str_a.data[0], &str_b.data[0], str_a.length);

            case UNDEFINED:
                unreachable();
        }
    $endif
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
