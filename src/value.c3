//------------------------------------------------------------------------------
module lox::vm::value;
import lox::utils, lox::vm::array, lox::vm::gc;

//------------------------------------------------------------------------------
// Object Definitions
//------------------------------------------------------------------------------

enum ObjType : int
{
    FUNCTION,
    STRING,
}

// Used for the RLE of line numbers
struct Line
{
    int number;
    int offset;
}

struct Obj
{
    ObjType type;
    bool isMarked;
    Obj *next;
}

struct CallFrame
{
    char *ip;
    ObjFn *function;
    Value *stackStart;
}

struct ObjFn
{
    Obj obj;
    int arity;
    ObjString *name;
    Array { char } code;
    Array { Line } lines;
    Array { Value } constants;
}

struct ObjString
{
    Obj obj;
    uint length;
    uint hash;
    char[*] value;
}

//------------------------------------------------------------------------------
// Value-Centric Macros
//------------------------------------------------------------------------------

/*
 * Promotes a literal C3 value to a Lox Value of the appropriate type.
*/
macro Value fromBool(boolean)   @builtin => boolean ? TRUE_VAL : FALSE_VAL;
macro Value fromNil()           @builtin => NIL_VAL;
macro Value fromNum(number)     @builtin => numToValue(number);
macro Value fromObj(object)     @builtin => objToValue((Obj *)object);

/*
 * Extracts a literal C3 value out of a Lox Value of the appropriate type.
*/
macro bool asBool(value)    @builtin => value == TRUE_VAL;
macro double asNum(value)   @builtin => valueToNum(value);
macro Obj *asObj(value)     @builtin => valueToObj(value);

/*
 * Type check a respective Value type.
*/
macro bool isBool(value)    @builtin => valueIsBool(value);
macro bool isNil(value)     @builtin => valueIsNil(value);
macro bool isNum(value)     @builtin => valueIsNum(value);
macro bool isObj(value)     @builtin => valueIsObj(value);

//------------------------------------------------------------------------------
// Value-Centric Functions
//------------------------------------------------------------------------------

fn Value numToValue(double number) @local @inline
{
    $if $feature(NAN_TAGGING):
        Value value;
        mem::copy(&value, &number, double.sizeof);
        return value;
    $else
        return (Value) { ValueType.NUMBER, { .number = number } };
    $endif
}

fn double valueToNum(Value value) @local @inline
{
    $if $feature(NAN_TAGGING):
        double number;
        mem::copy(&number, &value, Value.sizeof);
        return value;
    $else
        return value.as.number;
    $endif
}

fn Value objToValue(Obj *object) @local @inline
{
    $if $feature(NAN_TAGGING):
        return (Value)(SIGN_BIT | QNAN | (ulong)(uptr)(object));
    $else
        return (Value) { ValueType.OBJECT, { .obj = (Obj *)object } };
    $endif
}

fn Obj *valueToObj(Value value) @local @inline
{
    $if $feature(NAN_TAGGING):
        return (Obj *)(ulong)(value & ~(SIGN_BIT | QNAN));
    $else
        return value.as.obj;
    $endif
}

fn bool valueIsBool(Value value) @local @inline
{
    $if $feature(NAN_TAGGING):
        return value == TRUE_VAL || value == FALSE_VAL;
    $else
        return value.type == ValueType.FALSE || value.type == ValueType.TRUE;
    $endif
}

fn bool valueIsNil(Value value) @local @inline
{
    $if $feature(NAN_TAGGING):
        return value == NIL_VAL;
    $else
        return value.type == ValueType.NIL;
    $endif
}

fn bool valueIsObj(Value value) @local @inline
{
    $if $feature(NAN_TAGGING):
        return (value & (QNAN | SIGN_BIT)) == (QNAN | SIGN_BIT);
    $else
        return value.type == ValueType.OBJECT;
    $endif
}

fn bool valueIsNum(Value value) @local @inline
{
    $if $feature(NAN_TAGGING):
        return ((value) & QNAN) != QNAN;
    $else
        return value.type == ValueType.NUMBER;
    $endif
}

//------------------------------------------------------------------------------
// Object-Centric Macros
//------------------------------------------------------------------------------

/*
 * Extracts a C3 struct pointer out of a Lox Object of the appropriate type.
*/
macro ObjFn *asFunction(Value value) @builtin
    => (ObjFn *)asObj(value);

macro ObjString *asString(Value value) @builtin
    => (ObjString *)asObj(value);

macro String asCString(Value value) @builtin
    => (String)asString(value).value[:asString(value).length];

/*
 * Type check a respective Object type.
*/
macro bool isFunction(Value value) @builtin
    => isObjType(value, ObjType.FUNCTION);

macro bool isString(Value value) @builtin
    => isObjType(value, ObjType.STRING);

//------------------------------------------------------------------------------
// Object-Centric Functions
//------------------------------------------------------------------------------

/*
 * Used by the macros above to safely type check an Object.
*/
fn bool isObjType(Value value, ObjType type)
    => isObj(value) && asObj(value).type == type;

/*
 * Extracts the type tag from an object.
*/
fn ObjType objType(Value value) @builtin
    => asObj(value).type;

fn void initObj(LoxVM *vm, Obj *obj, ObjType type) @local
{
    obj.type = type;
    obj.isMarked = false;
    obj.next = vm.gc.first;
    vm.gc.first = obj;
}

fn ObjFn *newFunction(LoxVM *vm)
{
    ObjFn *function = allocate(ObjFn, &vm.gc);
    initObj(vm, &function.obj, ObjType.FUNCTION);

    function.arity = 0;
    function.name = null;
    function.code.init();
    function.lines.init();
    function.constants.init();

    return function;
}

fn uint hashCString(char[] key, int length)
{
    uint hash = 2166136261u;
    for (int i = 0; i < length; i++)
    {
        hash ^= (char)key[i];
        hash *= 16777619;
    }

    return hash;
}

macro hashString(ObjString *key)
{
    key.hash = hashCString(key.value[:key.length], key.length);
}

fn ObjString *allocateString(LoxVM *vm, usz length)
{
    ObjString *string = allocateFlex(ObjString, char, &vm.gc, length);
    initObj(vm, &string.obj, ObjType.STRING);
    string.length = (uint)length;
    string.value[length] = '\0';
    return string;
}

// Effectively equivalent to the old 'copyString' function
fn Value newStringLength(LoxVM *vm, char[] text, usz length)
{
    assert(length == 0 || text.len > 0, "Unexpected null string");
    ObjString *string = allocateString(vm, length);

    if (length > 0 && text.len > 0)
    {
        mem::copy(&string.value[0], text, length);
    }

    hashString(string);
    return fromObj(string);
}

// Effectively equivalent to the old 'takeString' function
fn Value newString(LoxVM *vm, char[] text)
{
    return newStringLength(vm, text, text.len);
}

//------------------------------------------------------------------------------
module lox::vm::value @if(!$feature(NAN_TAGGING));

//------------------------------------------------------------------------------
// Value Definitions @if NOT (NAN_TAGGING)
//------------------------------------------------------------------------------

enum ValueType : int
{
    NIL,
    FALSE,
    TRUE,
    NUMBER,
    OBJECT
}

// The base Value representation for Lox, if NAN_TAGGING is disabled.
struct Value
{
    ValueType type;
    union as
    {
        double number;
        Obj *obj;
    }
}

/*
 * The actual singleton Values for the simple literals 'nil', 'false', and 'true'.
 * As they are singleton values and do not require arguments to produce, they are
 * defined as constants rather than macros.
*/
const Value NIL_VAL     = (Value) { ValueType.NIL, { 0 } };
const Value FALSE_VAL   = (Value) { ValueType.FALSE, { 0 } };
const Value TRUE_VAL    = (Value) { ValueType.TRUE, { 0 } };

//------------------------------------------------------------------------------
module lox::vm::value @if($feature(NAN_TAGGING));

//------------------------------------------------------------------------------
// Value Definitions @if (NAN_TAGGING)
//------------------------------------------------------------------------------

// A NaN-boxed Value is just a 64-bit unsigned integer
typedef Value = ulong;

/*
 * Bit masks for defining NaN Values. *SIGN_BIT* being set along
 * with the *QNAN* bits signals an Obj type.
*/
const ulong SIGN_BIT    = (ulong)0x8000000000000000;
const ulong QNAN        = (ulong)0x7ffc000000000000;

/*
 * Bit tags that denote the simple literals 'nil', 'false', and 'true'.
 * These are bitwise OR'd with *QNAN* to produce the NaN-boxed Value.
*/
const ulong TAG_NIL     = 1;
const ulong TAG_FALSE   = 2;
const ulong TAG_TRUE    = 3;

/*
 * These are constants for the same reason as they are in (!NAN_TAGGING).
*/
const Value NIL_VAL     = (Value)(ulong)(QNAN | TAG_NIL);
const Value FALSE_VAL   = (Value)(ulong)(QNAN | TAG_FALSE);
const Value TRUE_VAL    = (Value)(ulong)(QNAN | TAG_TRUE);
