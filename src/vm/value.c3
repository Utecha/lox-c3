module lox::vm::value;
import lox::mem;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox \ VM \ Value -- Value
//------------------------------------------------------------------------------

enum ValueType : int
{
    BOOL,
    NIL,
    NUMBER,
    OBJ
}

struct Value
{
    ValueType type;
    union as
    {
        bool boolean;
        double number;
        Obj *obj;
    }
}

macro Value boolVal(value)      @builtin => Value { BOOL, { .boolean = value } };
macro Value nilVal()            @builtin => Value { NIL, { .number = 0 } };
macro Value numberVal(value)    @builtin => Value { NUMBER, { .number = value } };
macro Value objVal(object)      @builtin => Value { OBJ, { .obj = (Obj *)object } };

macro bool asBool(value)        @builtin => value.as.boolean;
macro double asNumber(value)    @builtin => value.as.number;
macro Obj *asObj(value)         @builtin => value.as.obj;

macro bool isBool(value)        @builtin => value.type == ValueType.BOOL;
macro bool isNil(value)         @builtin => value.type == ValueType.NIL;
macro bool isNumber(value)      @builtin => value.type == ValueType.NUMBER;
macro bool isObj(value)         @builtin => value.type == ValueType.OBJ;

fn void print(Value value, OutStream stream = io::stdout())
{
    switch (value.type)
    {
        case BOOL:      (void) io::fprintf(stream, asBool(value) ? "true" : "false");
        case NIL:       (void) io::fprintf(stream, "nil");
        case NUMBER:    (void) io::fprintf(stream, "%g", asNumber(value));
        case OBJ:       printObj(value, stream);
        default:        return;
    }
}

fn bool equals(Value a, Value b)
{
    if (a.type != b.type) return false;
    switch (a.type)
    {
        case BOOL:      return asBool(a) == asBool(b);
        case NIL:       return true;
        case NUMBER:    return asNumber(a) == asNumber(b);
        case OBJ:       return asObj(a) == asObj(b);
        default:        return false;
    }
}

//------------------------------------------------------------------------------
// Lox \ VM \ Value -- Object
//------------------------------------------------------------------------------

enum ObjType : int
{
    STRING,
}

struct Obj
{
    ObjType type;
    Obj *next;
}

struct ObjString
{
    Obj obj;
    int len;
    uint hash;
    String chars;
}

macro ObjType objType(value) @builtin => asObj(value).type;

macro asString(value)   @builtin => (ObjString *)asObj(value);
macro asCString(value)  @builtin => ((ObjString *)asObj(value)).chars;

fn bool isObjType(Value value, ObjType type) @local @inline
{
    return isObj(value) && asObj(value).type == type;
}

macro bool isString(value) @builtin => isObjType(value, STRING);

fn Obj *allocateObject(LoxVM *vm, usz size, ObjType type) @local
{
    Obj *object = mem::lalloc(Obj, size);
    object.type = type;
    object.next = vm.objects;
    vm.objects = object;
    return object;
}

macro allocateObj($Type, LoxVM *vm, ObjType objType) @local
{
    return ($Type *)allocateObject(vm, $Type.sizeof, objType);
}

fn ObjString *allocateString(LoxVM *vm, char[] chars, int len, uint hash) @local
{
    ObjString *string = allocateObj(ObjString, vm, STRING);
    string.len = len;
    string.hash = hash;
    string.chars = (String)chars;
    vm.strings.set(string, nilVal());
    return string;
}

fn uint hashString(char[] key, int len)
{
    uint hash = 2166136261u;

    for (int i = 0; i < len; i++)
    {
        hash ^= (char)key[i];
        hash *= 16777619;
    }

    return hash;
}

fn ObjString *copyString(LoxVM *vm, char[] chars, int len)
{
    uint hash = hashString(chars, len);
    ObjString *interned = vm.strings.findString(chars, len, hash);
    if (interned != null) return interned;

    char *heapChars = mem::lalloc(char, len + 1);
    mem::copy(heapChars, chars, len);
    heapChars[len] = '\0';
    return allocateString(vm, heapChars[:len], len, hash);
}

fn ObjString *takeString(LoxVM *vm, char[] chars, int len)
{
    uint hash = hashString(chars, len);
    ObjString *interned = vm.strings.findString(chars, len, hash);
    if (interned != null)
    {
        mem::lfree(char, chars, len + 1);
        return interned;
    }

    return allocateString(vm, chars, len, hash);
}

fn void printObj(Value value, OutStream stream = io::stdout())
{
    switch (objType(value))
    {
        case STRING:
            (void) io::fprintf(stream, "%s", asCString(value));
    }
}
