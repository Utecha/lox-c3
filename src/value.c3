module lox::value;
import lox::array;
import lox::opcode;
import lox::memory;
import std::io @norecurse;

//------------------------------------------------------------------------------

// Defines the specific array types needed for function objects.
alias ByteArray = LoxArray { char };
alias LineArray = LoxArray { Line };
alias ValueArray = LoxArray { Value };

enum ObjType : int
{
    FUNCTION,
}

struct Obj
{
    ObjType type;
    Obj *next;
}

struct Line
{
    int n;
    sz offset;
}

struct ObjFun
{
    inline Obj obj;
    ByteArray code;
    LineArray lines;
    ValueArray constants;
}

//------------------------------------------------------------------------------

// Primitive -> Value
macro Value make_bool(bool boolean)     => boolean ? TRUE : FALSE;
macro Value make_num(double number)     => number_to_value(number);
macro Value make_obj(Obj *object)       => object_to_value(object);

// Value -> Primitive
macro ObjFun *as_function(Value value)  => (ObjFun *)as_obj(value);

// Value type checking
macro bool is_function(Value value)     => is_obj_type(value, FUNCTION);

//------------------------------------------------------------------------------

<*
    Prints [value] to the standard output.

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
    Returns the corresponding line number for the given [offset] in the
    bytecode of [fun].

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

/*** TEMPORARY ***/

fn void write_byte(LoxVM *vm, ObjFun *fun, char byte, int line)
{
    if (fun.code.len() == 0 || fun.lines[fun.lines.len() - 1].n != line)
    {
        fun.lines.append(
            vm,
            (Line) { .n = line, .offset = fun.code.len() }
        );
    }

    fun.code.append(vm, byte);
}

fn void write_code(LoxVM *vm, ObjFun *fun, OpCode instruction, int line)
{
    write_byte(vm, fun, instruction.ordinal, line);
}

fn sz add_constant(LoxVM *vm, ObjFun *fun, Value value)
{
    fun.constants.append(vm, value);
    return fun.constants.len() - 1;
}

/*** END TEMPORARY ***/

//------------------------------------------------------------------------------

<*
    Returns the full Value representation for a primitive [number] based on
    whether the `NAN_TAGGING` feature flag exists.

    @param number : "The number to promote."
*>
fn Value number_to_value(double number) @inline @local
{
    $if $feat(NAN_TAGGING):
        return bitcast(double, Value);
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
    Prints [value], which is expected to be an Obj type, to standard output.

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
    Returns whether [value] is an Obj of [type].

    @param value : "The value to check."
    @param type : "The type to check against."
*>
fn bool is_obj_type(Value value, ObjType type) @inline @local
{
    return is_obj(value) && as_obj(value).type == type;
}

<*
    Initializes [obj] and adds it to the linked list of objects held by [vm].

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

enum ValueType : int
{
    FALSE,
    NIL,
    NUMBER,
    OBJECT,
    TRUE,
    UNDEFINED
}

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

// Singleton Value constants.
const Value FALSE       = { FALSE, { 0 } };
const Value NIL         = { NIL, { 0 } };
const Value TRUE        = { TRUE, { 0 } };
const Value UNDEFINED   = { UNDEFINED, { 0 } };

//------------------------------------------------------------------------------

// Value -> Primitive
macro bool as_bool(Value value)     => value.type == TRUE;
macro double as_num(Value value)    => value.as.number;
macro Obj *as_obj(Value value)      => value.as.obj;

// Value type checking.
macro bool is_bool(Value value)     => value.type == FALSE || value.type == TRUE;
macro bool is_false(Value value)    => value.type == FALSE;
macro bool is_nil(Value value)      => value.type == NIL;
macro bool is_num(Value value)      => value.type == NUMBER;
macro bool is_obj(Value value)      => value.type == OBJECT;
macro bool is_undef(Value value)    => value.type == UNDEFINED;

//==============================================================================
module lox::value @feat(NAN_TAGGING);

//------------------------------------------------------------------------------

typedef Value = inline ulong;

//------------------------------------------------------------------------------

// Bitmask for setting the sign bit of a Value.
const ulong SIGN_BIT    = (ulong)1 << 63;

// Bitmask for setting the quiet NaN bits of a Value.
const ulong QNAN        = (ulong)(0x7ffc000000000000);

// Bitmask for checking the type tag of a singleton Value.
const int MASK_TAG      = 7;

// Bitmasks that act as type tags for the singleton Values.
const int TAG_NAN       = 0;
const int TAG_NIL       = 1;
const int TAG_FALSE     = 2;
const int TAG_TRUE      = 3;
const int TAG_UNDEFINED = 4;

// Singleton Value constants
const Value FALSE       = (Value)(ulong)(QNAN | TAG_FALSE);
const Value NIL         = (Value)(ulong)(QNAN | TAG_NIL);
const Value TRUE        = (Value)(ulong)(QNAN | TAG_TRUE);
const Value UNDEFINED   = (Value)(ulong)(QNAN | TAG_TRUE);

//------------------------------------------------------------------------------

// Returns the type tag for a singleton Value.
macro int get_tag(Value value)      => (int)(value & MASK_TAG);

// Value -> Primitive
macro bool as_bool(Value value)     => value == TRUE;
macro double as_num(Value value)    => bitcast(value, double);
macro Obj *as_obj(Value value)      => (Obj *)(uptr)(value & ~(SIGN_BIT | QNAN));

// Value type checking
macro bool is_bool(Value value)     => value == FALSE || value == TRUE;
macro bool is_false(Value value)    => value == FALSE;
macro bool is_nil(Value value)      => value == NIL;
macro bool is_num(Value value)      => (value & QNAN) != QNAN;
macro bool is_obj(Value value)      => (value & (SIGN_BIT | QNAN)) == (SIGN_BIT) | QNAN;
macro bool is_undef(Value value)    => value == UNDEFINED;
