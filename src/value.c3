module lox::value;
import lox::memory;
import lox::object;
import std::io @norecurse;

//===----------------===//
//        Value
//===----------------===//

<*
    The type tags used to differentiate types of (Value)s.
*>
enum ValueType : int
{
    BOOL,
    NIL,
    NUMBER,
    OBJ,
}

<*
    The dynamic Lox (Value). This stores the (ValueType) tag, as well
    as a union of data with underlying types.
*>
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

// NOTE: The below macros are marked with the '@builtin' attribute for convenience.
/*
 * Macros for promoting a C3 value (such as a double) to a Lox (Value)
*/

<*
    Promote's a C3 bool value to a Lox bool (Value).

    @param value "The underlying value to promote"
*>
macro bool_val(value) @builtin
    => Value { ValueType.BOOL, { .boolean = value } };

<*
    This is less of a promotion and more of a representation. This uses the underyling value
    of 0 to represent a nil (or null) (Value).
*>
macro nil_val() @builtin
    => Value { ValueType.NIL, { .number = 0 } };

<*
    Promote's a C3 double value into a Lox number (Value).

    @param value "The underlying value to promote"
*>
macro number_val(value) @builtin
    => Value { ValueType.NUMBER, { .number = value } };

<*
    Promote's a raw (Obj *) to a Lox (Value). All objects in Lox are also values.

    @param object "The object to promote to a Value"
*>
macro obj_val(object) @builtin
    => Value { ValueType.OBJ, { .obj = (Obj *)object } };

/*
 * Macros to unwrap a Lox (Value) and return the underyling C3 value
*/

<*
    Unwraps a Lox (Value) of type (BOOL) and returns the underyling C3 bool value.

    @param value "The Value to unwrap"
*>
macro as_bool(value) @builtin
    => value.as.boolean;

<*
    Unwraps a Lox (Value) of type (NUMBER) and returns the underyling C3 double value.

    @param value "The Value to unwrap"
*>
macro as_number(value) @builtin
    => value.as.number;

<*
    Unwraps a Lox (Value) of type (OBJ) and returns the bare (Obj *).

    @param value "The Value to unwrap"
*>
macro as_obj(value) @builtin
    => value.as.obj;

/*
 * Macros for type-checking Lox (Value)s
*/

<*
    Returns 'true' if the type of the [value] is (BOOL), otherwise
    returns 'false'.

    @param value "The value whose type needs checking"
*>
macro is_bool(value) @builtin
    => value.type == ValueType.BOOL;

<*
    Returns 'true' if the type of the [value] is (NIL), otherwise
    returns 'false'.

    @param value "The value whose type needs checking"
*>
macro is_nil(value) @builtin
    => value.type == ValueType.NIL;

<*
    Returns 'true' if the type of the [value] is (NUMBER), otherwise
    returns 'false'.

    @param value "The value whose type needs checking"
*>
macro is_number(value) @builtin
    => value.type == ValueType.NUMBER;

<*
    Returns 'true' if the type of the [value] is (OBJ), otherwise
    returns 'false'.

    @param value "The value whose type needs checking"
*>
macro is_obj(value) @builtin
    => value.type == ValueType.OBJ;

<*
    Print function specific to Lox dynamic values.

    @param value "The Value to print"
    @param stream "The output stream to print to (default is stdout)"
*>
fn void print(Value value, OutStream stream = io::stdout())
{
    switch (value.type)
    {
        case BOOL:
            (void) io::fprintf(stream, as_bool(value) ? "true" : "false");
        case NIL:
            (void) io::fprintf(stream, "nil");
        case NUMBER:
            (void) io::fprintf(stream, "%.32g", as_number(value));
        case OBJ:
            object::print(value, stream);
    }
}

<*
    Returns 'true' if the (Value)s [a] and [b] are equal. Otherwise, it
    returns 'false'.

    @param a "The first, or 'a' value to compare"
    @param b "The second, or 'b' value to compare"
*>
fn bool equal(Value a, Value b)
{
    if (a.type != b.type) return false;
    switch (a.type)
    {
        case BOOL:      return as_bool(a) == as_bool(b);
        case NIL:       return true;
        case NUMBER:    return as_number(a) == as_number(b);
        case OBJ:
        {
            ObjString *a_string = as_string(a);
            ObjString *b_string = as_string(b);

            return mem::equals(a_string.chars, b_string.chars);
        }
        default:        return false; // Unreachable
    }
}

//===----------------===//
//      ValueList
//===----------------===//

<*
    Structure representing a dynamic array of Lox values
*>
struct ValueList
{
    int capacity;
    int count;
    Value *values;
}

<*
    Initializes a new 'ValueList'.

    @param [inout] self "A reference to the ValueList this method is being called on"
    @require self != null
*>
fn void ValueList.init(&self)
{
    self.capacity = 0;
    self.count = 0;
    self.values = null;
}

<*
    Free the memory allocated for a 'ValueList'.

    @param [inout] self "A reference to the ValueList this method is being called on"
    @require self != null
*>
fn void ValueList.free(&self)
{
    memory::free_array(Value, self.values, self.capacity);
    self.init();
}

<*
    Appends a 'Value' to the provided 'ValueList'.

    @param [inout] self "A reference to the ValueList this method is being called on"
    @require self != null
*>
fn void ValueList.append(&self, Value value)
{
    if (self.capacity < self.count + 1)
    {
        int old_cap = self.capacity;
        self.capacity = memory::grow_capacity(old_cap);
        self.values = memory::grow_array(Value, self.values, old_cap, self.capacity);
    }

    self.values[self.count] = value;
    self.count++;
}
