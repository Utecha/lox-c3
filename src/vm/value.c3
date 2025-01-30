module lox::vm::value;
import lox::gc::memory;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox | VM | Value @Value
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

macro Value bool_val(value)      @builtin => Value { BOOL, { .boolean = value } };
macro Value nil_val()            @builtin => Value { NIL, { .number = 0 } };
macro Value number_val(value)    @builtin => Value { NUMBER, { .number = value } };
macro Value obj_val(object)      @builtin => Value { OBJ, { .obj = (Obj *)object } };

macro bool as_bool(value)        @builtin => value.as.boolean;
macro double as_number(value)    @builtin => value.as.number;
macro Obj *as_obj(value)         @builtin => value.as.obj;

macro bool is_bool(value)        @builtin => value.type == ValueType.BOOL;
macro bool is_nil(value)         @builtin => value.type == ValueType.NIL;
macro bool is_number(value)      @builtin => value.type == ValueType.NUMBER;
macro bool is_obj(value)         @builtin => value.type == ValueType.OBJ;

fn void print(Value value, OutStream stream = io::stdout())
{
    switch (value.type)
    {
        case BOOL:      (void) io::fprintf(stream, as_bool(value) ? "true" : "false");
        case NIL:       (void) io::fprintf(stream, "nil");
        case NUMBER:    (void) io::fprintf(stream, "%g", as_number(value));
        case OBJ:       print_obj(value, stream);
        default:        return;
    }
}

fn bool equals(Value a, Value b)
{
    if (a.type != b.type) return false;
    switch (a.type)
    {
        case BOOL:      return as_bool(a) == as_bool(b);
        case NIL:       return true;
        case NUMBER:    return as_number(a) == as_number(b);
        case OBJ:       return as_obj(a) == as_obj(b);
        default:        return false;
    }
}

//------------------------------------------------------------------------------
// Lox | VM | Value @Object
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
    String value;
}

macro ObjType obj_type(value) @builtin => as_obj(value).type;

fn bool is_obj_type(Value value, ObjType type) @local @inline
{
    return is_obj(value) && as_obj(value).type == type;
}

macro ObjString *as_string(value)   @builtin => (ObjString *)as_obj(value);
macro String as_cstring(value)      @builtin => ((ObjString *)as_obj(value)).value;

macro bool is_string(value)         @builtin => is_obj_type(value, STRING);

fn Obj *allocate_object(Vm *vm, usz size, ObjType type) @local
{
    Obj *object = memory::lalloc(Obj, size);
    object.type = type;
    object.next = vm.objects;
    vm.objects = object;
    return object;
}

macro allocate_obj($Type, Vm *vm, ObjType obj_type) @local
{
    return ($Type *)allocate_object(vm, $Type.sizeof, obj_type);
}

fn ObjString *allocate_string(Vm *vm, char[] chars, int len, uint hash) @local
{
    ObjString *string = allocate_obj(ObjString, vm, STRING);
    string.len = len;
    string.hash = hash;
    string.value = (String)chars;
    vm.strings.set(string, nil_val());
    return string;
}

fn uint hash_string(char[] key, int len)
{
    uint hash = 2166136261u;

    for (int i = 0; i < len; i++)
    {
        hash ^= (char)key[i];
        hash *= 16777619;
    }

    return hash;
}

fn ObjString *copy_string(Vm *vm, char[] chars, int len)
{
    uint hash = hash_string(chars, len);
    ObjString *interned = vm.strings.find_string(chars, len, hash);
    if (interned != null) return interned;

    char *heap_chars = memory::lalloc(char, len + 1);
    mem::copy(heap_chars, chars.ptr, len);
    heap_chars[len] = '\0';
    return allocate_string(vm, heap_chars[:len], len, hash);
}

fn ObjString *take_string(Vm *vm, char[] chars, int len)
{
    uint hash = hash_string(chars, len);
    ObjString *interned = vm.strings.find_string(chars, len, hash);
    if (interned != null)
    {
        memory::lfree(char, chars, len + 1);
        return interned;
    }

    return allocate_string(vm, chars, len, hash);
}

fn void print_obj(Value value, OutStream stream = io::stdout())
{
    switch (obj_type(value))
    {
        case STRING:
            (void) io::fprintf(stream, "%s", as_cstring(value));
    }
}