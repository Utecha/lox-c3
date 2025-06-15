module lox::value;
import lox::buffer, lox::chunk, lox::memory;
import lox::table, lox::vm;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Value | Common
//------------------------------------------------------------------------------

alias ValueBuffer = Buffer { Value };
alias NativeFn = fn Value (int argc, Value *args);

//------------------------------------------------------------------------------

enum ObjType : inline int
{
    BOUND_METHOD,
    CLASS,
    CLOSURE,
    FUNCTION,
    INSTANCE,
    NATIVE,
    STRING,
    UPVALUE,
}

struct Obj
{
    ObjType type;
    bool is_marked;
    Obj *next;
}

struct ObjBoundMethod
{
    Obj obj;
    Value receiver;
    ObjClosure *method;
}

struct ObjClass
{
    Obj obj;
    ObjString *name;
    Table methods;
}

struct ObjClosure
{
    Obj obj;
    ObjFn *function;
    ObjUpvalue **upvalues;
    int upvalue_count;
}

struct CallFrame
{
    ObjClosure *closure;
    char *ip;
    Value *slots;
}

struct ObjFn
{
    Obj obj;
    int arity;
    int upvalue_count;
    Chunk chunk;
    ObjString *name;
}

struct ObjInstance
{
    Obj obj;
    ObjClass *class;
    Table fields;
}

struct ObjNative
{
    Obj obj;
    NativeFn function;
}

struct ObjString
{
    Obj obj;
    uint length;
    uint hash;
    char *value;
}

struct ObjUpvalue
{
    Obj obj;
    Value *location;
    Value closed;
    ObjUpvalue *next;
}

//------------------------------------------------------------------------------

macro obj_type(value)       @builtin => as_obj(value).type;

macro make_num(number)      @builtin => number_to_value(number);
macro make_obj(object)      @builtin => object_to_value((Obj *)object);

macro as_bound_method(value)    @builtin => (ObjBoundMethod *)as_obj(value);
macro as_class(value)           @builtin => (ObjClass *)as_obj(value);
macro as_closure(value)         @builtin => (ObjClosure *)as_obj(value);
macro as_function(value)        @builtin => (ObjFn *)as_obj(value);
macro as_instance(value)        @builtin => (ObjInstance *)as_obj(value);
macro as_num(value)             @builtin => value_to_number(value);
macro as_native(value)          @builtin => ((ObjNative *)as_obj(value)).function;
macro as_string(value)          @builtin => (ObjString *)as_obj(value);
macro as_cstring(value)         @builtin => objstring_to_string(value);

macro is_bool(value)            @builtin => value_is_bool(value);
macro is_bound_method(value)    @builtin => is_obj_type(value, BOUND_METHOD);
macro is_class(value)           @builtin => is_obj_type(value, CLASS);
macro is_closure(value)         @builtin => is_obj_type(value, CLOSURE);
macro is_function(value)        @builtin => is_obj_type(value, FUNCTION);
macro is_instance(value)        @builtin => is_obj_type(value, INSTANCE);
macro is_native(value)          @builtin => is_obj_type(value, NATIVE);
macro is_string(value)          @builtin => is_obj_type(value, STRING);

//------------------------------------------------------------------------------

fn bool is_obj_type(Value value, ObjType type) @inline
{
    return is_obj(value) && obj_type(value) == type;
}

fn bool value_is_bool(Value value) @inline
{
    $if $feature(NAN_TAGGING):
        return value == TRUE_VAL || value == FALSE_VAL;
    $else
        return value.type == BOOL;
    $endif
}

fn Value object_to_value(Obj *object)
{
    $if $feature(NAN_TAGGING):
        return (Value)(SIGN_BIT | QNAN | (ulong)(uptr)(object));
    $else
        return (Value) { OBJ, { .obj = object } };
    $endif
}

fn Value number_to_value(double number) @inline
{
    $if $feature(NAN_TAGGING):
        Value value;
        mem::copy(&value, &number, double.sizeof);
        return value;
    $else
        return (Value) { NUMBER, { .number = number } };
    $endif
}

fn double value_to_number(Value value) @inline
{
    $if $feature(NAN_TAGGING):
        double number;
        mem::copy(&number, &value, Value.sizeof);
        return number;
    $else
        return value.as.number;
    $endif
}

fn String objstring_to_string(Value value)
{
    if (!is_string(value)) return "";
    ObjString *string = as_string(value);
    return (String)(string.value[:string.length]);
}

fn void print_function(ObjFn *function)
{
    if (function.name == null)
    {
        io::printf("<script>");
        return;
    }

    io::printf("<fn %s>", (ZString)function.name.value);
}

fn void print_object(Value value)
{
    switch (obj_type(value))
    {
        case BOUND_METHOD:
            print_function(as_bound_method(value).method.function);
        case CLASS:
            io::printf("%s", (ZString)as_class(value).name.value);
        case CLOSURE:
            print_function(as_closure(value).function);
        case FUNCTION:
            print_function(as_function(value));
        case NATIVE:
            io::printf("<native fn>");
        case INSTANCE:
            io::printf("Instance of '%s'", (ZString)as_instance(value).class.name.value);
        case STRING:
            io::printf("%s", as_cstring(value));
        case UPVALUE:
            io::printf("upvalue");
    }
}

fn void print(Value value)
{
    $if $feature(NAN_TAGGING):
        switch
        {
            case is_bool(value):
                io::print(as_bool(value) ? "true" : "false");
            case is_nil(value):
                io::print("nil");
            case is_num(value):
                io::printf("%.16g", as_num(value));
            case is_obj(value):
                print_object(value);
        }
    $else
        switch (value.type)
        {
            case BOOL:
                io::print(as_bool(value) ? "true" : "false");
            case NIL:
                io::print("nil");
            case NUMBER:
                io::printf("%.16g", as_num(value));
            case OBJ:
                print_object(value);
        }
    $endif
}

fn bool equals(Value a, Value b)
{
    $if $feature(NAN_TAGGING):
        // For IEEE 754 compliance
        if (is_num(a) && is_num(b))
        {
            return as_num(a) == as_num(b);
        }

        return a == b;
    $else
        if (a.type != b.type) return false;
        switch (a.type)
        {
            case BOOL:
                return as_bool(a) == as_bool(b);
            case NIL:
                return true;
            case NUMBER:
                return as_num(a) == as_num(b);
            case OBJ:
                return as_obj(a) == as_obj(b);
            default:
                return false; // Unreachable
        }
    $endif
}

fn bool is_falsey(Value value) @inline
{
    return is_nil(value) || (is_bool(value) && !as_bool(value));
}

//------------------------------------------------------------------------------

fn void init_obj(LoxVM *vm, Obj *obj, ObjType type)
{
    obj.type = type;
    obj.is_marked = false;
    obj.next = vm.objects;
    vm.objects = obj;
}

macro allocate_obj($Type, vm, obj_type)
{
    var object = allocate($Type, vm);

    $if $feature(DEBUG) &&& vm::LOG_GC:
        io::printfn("%p | Allocated %d for %s", (void *)object, $Type.sizeof, obj_type);
    $endif

    return ($Type *)object;
}

fn ObjBoundMethod *new_bound_method(LoxVM *vm, Value receiver, ObjClosure *method)
{
    ObjBoundMethod *bound = allocate_obj(ObjBoundMethod, vm, ObjType.BOUND_METHOD);
    bound.receiver = receiver;
    bound.method = method;
    return bound;
}

fn ObjClass *new_class(LoxVM *vm, ObjString *name)
{
    ObjClass *class = allocate_obj(ObjClass, vm, ObjType.CLASS);
    init_obj(vm, &class.obj, CLASS);
    class.name = name;
    class.methods.init();
    return class;
}

fn ObjClosure *new_closure(LoxVM *vm, ObjFn *function)
{
    ObjUpvalue **upvalues = allocate_array(ObjUpvalue *, vm, function.upvalue_count);
    for (int i = 0; i < function.upvalue_count; i++)
    {
        upvalues[i] = null;
    }

    ObjClosure *closure = allocate_obj(ObjClosure, vm, ObjType.CLOSURE);
    init_obj(vm, &closure.obj, CLOSURE);
    closure.function = function;
    closure.upvalues = upvalues;
    closure.upvalue_count = function.upvalue_count;
    return closure;
}

fn ObjFn *new_function(LoxVM *vm)
{
    ObjFn *function = allocate_obj(ObjFn, vm, ObjType.FUNCTION);
    init_obj(vm, &function.obj, FUNCTION);
    function.arity = 0;
    function.upvalue_count = 0;
    function.chunk.init();
    function.name = null;
    return function;
}

fn ObjInstance *new_instance(LoxVM *vm, ObjClass *class)
{
    ObjInstance *instance = allocate_obj(ObjInstance, vm, ObjType.INSTANCE);
    init_obj(vm, &instance.obj, INSTANCE);
    instance.class = class;
    instance.fields.init();
    return instance;
}

fn ObjNative *new_native(LoxVM *vm, NativeFn function)
{
    ObjNative *native = allocate_obj(ObjNative, vm, ObjType.NATIVE);
    init_obj(vm, &native.obj, NATIVE);
    native.function = function;
    return native;
}

fn ObjString *allocate_string(LoxVM *vm, char *text, uint length, uint hash)
{
    ObjString *string = allocate_obj(ObjString, vm, ObjType.STRING);
    init_obj(vm, &string.obj, STRING);
    string.length = length;
    string.hash = hash;
    string.value = text;

    vm::@push(vm, make_obj(string));
    vm.strings.set(vm, string, make_nil());
    vm::@pop(vm);

    return string;
}

fn uint hash_string(char *text, uint length)
{
    uint hash = 2166136261U;

    for (uint i = 0; i < length; i++)
    {
        hash ^= text[i];
        hash *= 16777619;
    }

    return hash;
}

fn ObjString *copy_string(LoxVM *vm, char *text, uint length)
{
    uint hash = hash_string(text, length);
    ObjString *interned = vm.strings.find_string(text, length, hash);

    if (interned != null) return interned;

    char *copy = allocate_array(char, vm, length + 1);
    mem::copy(copy, text, length);
    copy[length] = '\0';
    return allocate_string(vm, copy, length, hash);
}

fn ObjString *take_string(LoxVM *vm, char *text, uint length)
{
    uint hash = hash_string(text, length);
    ObjString *interned = vm.strings.find_string(text, length, hash);

    if (interned != null)
    {
        deallocate_array(char, vm, text, length + 1);
        return interned;
    }

    return allocate_string(vm, text, length, hash);
}

fn ObjUpvalue *new_upvalue(LoxVM *vm, Value *slot)
{
    ObjUpvalue *upvalue = allocate_obj(ObjUpvalue, vm, ObjType.UPVALUE);
    init_obj(vm, &upvalue.obj, UPVALUE);
    upvalue.location = slot;
    upvalue.closed = make_nil();
    upvalue.next = null;
    return upvalue;
}

//------------------------------------------------------------------------------
module lox::value @if(!$feature(NAN_TAGGING));

//------------------------------------------------------------------------------
// Value | *NOT* NAN_TAGGING
//------------------------------------------------------------------------------

enum ValueType : inline int
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

//------------------------------------------------------------------------------

macro make_bool(boolean)    @builtin => (Value) { BOOL, { .boolean = boolean } };
macro make_nil()            @builtin => (Value) { NIL, { .number = 0 } };

macro as_bool(value)    @builtin => value.as.boolean;
macro as_obj(value)     @builtin => value.as.obj;

macro is_nil(value)     @builtin => value.type == NIL;
macro is_num(value)     @builtin => value.type == NUMBER;
macro is_obj(value)     @builtin => value.type == OBJ;

//------------------------------------------------------------------------------
module lox::value @if($feature(NAN_TAGGING));

//------------------------------------------------------------------------------
// Value | NAN_TAGGING
//------------------------------------------------------------------------------

typedef Value = inline ulong;

const ulong SIGN_BIT    = (ulong)0x8000000000000000;
const ulong QNAN        = (ulong)0x7ffc000000000000;

const int TAG_NIL   = 1;
const int TAG_FALSE = 2;
const int TAG_TRUE  = 3;

const Value NIL_VAL     @builtin = (Value)(ulong)(QNAN | TAG_NIL);
const Value FALSE_VAL   @builtin = (Value)(ulong)(QNAN | TAG_FALSE);
const Value TRUE_VAL    @builtin = (Value)(ulong)(QNAN | TAG_TRUE);

macro make_bool(boolean)    @builtin => boolean ? TRUE_VAL : FALSE_VAL;
macro make_nil()            @builtin => NIL_VAL;

macro as_bool(value)    @builtin => (value == TRUE_VAL);
macro as_obj(value)     @builtin => (Obj *)(uptr)(value & ~(SIGN_BIT | QNAN));

macro is_nil(value)     @builtin => value == NIL_VAL;
macro is_num(value)     @builtin => (value & QNAN) != QNAN;
macro is_obj(value)     @builtin => (value & (QNAN | SIGN_BIT)) == (QNAN | SIGN_BIT);
