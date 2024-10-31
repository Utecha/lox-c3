module lox::value;
import lox::memory;
import lox::object;
import std::io @norecurse;

//===----------------------------------------------------------------------===//
// Lox | Value
//===----------------------------------------------------------------------===//

/* (Value) Type Tag */
enum ValueType : int
{
    BOOL,
    NIL,
    NUMBER,
    OBJ,
}

/* Tagged Union (Value) */
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

/* Macros to check the type tag of a (Value) */
macro bool is_bool(value)       @builtin => value.type == ValueType.BOOL;
macro bool is_nil(value)        @builtin => value.type == ValueType.NIL;
macro bool is_number(value)     @builtin => value.type == ValueType.NUMBER;
macro bool is_obj(value)        @builtin => value.type == ValueType.OBJ;

/* Macros to extract the underlying C3 value from a Lox (Value) */
macro bool as_bool(value)       @builtin => value.as.boolean;
macro double as_number(value)   @builtin => value.as.number;
macro Obj *as_obj(value)        @builtin => value.as.obj;

/* Macros to lift a C3 value to the appropriate Lox (Value) */
macro Value bool_val(value)     @builtin => { ValueType.BOOL, { .boolean = value } };
macro Value nil_val()           @builtin => { ValueType.NIL, { .number = 0 } };
macro Value number_val(value)   @builtin => { ValueType.NUMBER, { .number = value } };
macro Value obj_val(object)     @builtin => { ValueType.OBJ, { .obj = (Obj *)object } };

/*
 * Prints a [value] to the desired output [stream]. Excluding the stream argument
 * will default it to 'stdout'.
*/
fn void print(Value value, OutStream stream = io::stdout())
{
    switch (value.type)
    {
        case BOOL:
            (void) io::fprintf(stream, as_bool(value) ? "true" : "false");
        case NIL:
            (void) io::fprintf(stream, "nil");
        case NUMBER:
            (void) io::fprintf(stream, "%g", as_number(value));
        case OBJ:
            object::print(value, stream);
    }
}

fn bool equal(Value a, Value b)
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

//===----------------------------------------------------------------------===//
// Lox | Value List
//===----------------------------------------------------------------------===//

/*
 * A simple dynamic array of (Value)s. Used by a (Chunk) to store an array of
 * constant values.
*/
struct ValueList
{
    int capacity;
    int count;
    Value *values;
}

/* Initializes a new (ValueList) */
fn void ValueList.init(&self)
{
    self.capacity = 0;
    self.count = 0;
    self.values = null;
}

/* Free the underlying array of a (ValueList) and zero-out the list */
fn void ValueList.free(&self)
{
    memory::free_array(Value, self.values, self.capacity);
    self.init();
}

/* Append a [value] to a (ValueList) */
fn void ValueList.append(&self, Value value)
{
    if (self.capacity < self.count + 1)
    {
        int old = self.capacity;
        self.capacity = memory::grow_capacity(old);
        self.values = memory::grow_array(Value, self.values, old, self.capacity);
    }

    self.values[self.count] = value;
    self.count++;
}
