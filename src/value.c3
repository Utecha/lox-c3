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

//------------------------------------------------------------------------------

<*
    Promotes a primitive boolean to a full Lox Value.

    @param boolean : "The boolean value to promote."
*>
macro Value make_bool(bool boolean)     => boolean ? TRUE : FALSE;

<*
    Promotes a primitive number to a full Lox Value.

    @param number : "The number value to promote."
*>
macro Value make_num(double number)     => number_to_value(number);

<*
    Promotes a primitive Obj to a full Lox Value.

    @param object : "The object to promote."
*>
macro Value make_obj(Obj *object)       => object_to_value(object);

<*
    Demotes the given [value] into a function object.

    @param value : "The value to demote."
*>
macro ObjFun *as_function(Value value)  => (ObjFun *)as_obj(value);

<*
    Returns whether the given [value] is a function object.

    @param value : "The value to type check."
*>
macro bool is_function(Value value)     => is_obj_type(value, FUNCTION);

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
                return false; // Not yet implemented

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
