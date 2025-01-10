module lox::value;
import lox::common;
import lox::memory;
import lox::object;
import std::io @norecurse;

//===----------------===//
// Value @if(NAN_BOXING)
//===----------------===//

<*
    Defines the 'sign' bit. This, naturally, sets the sign bit as a sort of type
    tag for us to use to determine if a (Value) is an (Obj).

    This is *ONLY* set for (Obj) values!
*>
const SIGN_BIT  @if(NAN_BOXING) = (ulong)0x8000000000000000;

<*
    Defines the 'quiet' NaN bits. If these are set, we are dealing with
    a (Value) that is NaN (nil, boolean, Obj).

    Number values do *NOT* have these bits set.
*>
const QNAN      @if(NAN_BOXING) = (ulong)0x7ffc000000000000;

<*
    These constants are the bit representations used for 'nil' and boolean values.

    They are bitwise-OR'ed with 'QNAN' to provide an effectively type-tagged, nan-boxed
    representation of those value types.
*>
const TAG_NIL   @if(NAN_BOXING) = 1;
const TAG_FALSE @if(NAN_BOXING) = 2;
const TAG_TRUE  @if(NAN_BOXING) = 3;

<*
    If NaN-Boxing is enabled, all Lox values are compressed and stored
    within a single 64-bit integer type.

    If NaN-Boxing is disabled, it instead uses the below (Value) struct
    and accompanying (ValueType) enum to store Lox values.
*>
def Value = ulong @if(NAN_BOXING);

<*
    If NaN-Boxing is enabled, replaces the 'nil_val' macro with this one.
*>
macro nil_val() @builtin @if(NAN_BOXING)
    => (Value)(ulong)(QNAN | TAG_NIL);

<*
    If NaN-Boxing is enabled, replaces the 'bool_val' macro with this one.
*>
macro bool_val(b) @builtin @if(NAN_BOXING)
    => b ? true_val() : false_val();

<*
    If NaN-Boxing is enabled, this macro returns the nan-boxed representation of
    'false'.
*>
macro false_val() @builtin @if(NAN_BOXING)
    => (Value)(ulong)(QNAN | TAG_FALSE);

<*
    If NaN-Boxing is enabled, this macro returns the nan-boxed representation of
    'true'.
*>
macro true_val() @builtin @if(NAN_BOXING)
    => (Value)(ulong)(QNAN | TAG_TRUE);

<*
    If NaN-Boxing is enabled, replaces the 'number_val' macro with this one.
*>
macro number_val(num) @builtin @if(NAN_BOXING)
    => num_to_value(num);

<*
    If NaN-Boxing is enabled, replaces the 'obj_val' macro with this one. This does
    a bunch of bit-twiddling to stuff an (Obj *) into a (ulong).
*>
macro obj_val(obj) @builtin @if(NAN_BOXING)
    => (Value)(SIGN_BIT | QNAN | (ulong)(uptr)(obj));

<*
    If NaN-Boxing is enabled, 'converts' a double to a ulong by copying the memory
    of the digits to the new value representation (which is a typedef for a ulong).

    As stated in the book 'This looks horrendously slow.... Thankfully, because this
    is the supported idiom for type punning, most compilers recognize the pattern and
    optimize away the memcpy entirely'.

    @param num "The number (as a double) to turn into a Lox nan-tagged value (ulong)"
*>
fn Value num_to_value(double num) @inline @if(NAN_BOXING)
{
    Value value;
    mem::copy(&value, &num, double.sizeof);
    return value;
}

<*
    If NaN-Boxing is enabled, this macro uses a bit of a trick to return a 'true' or
    'false' value based on the value passed in. It's simple in nature, going off the idea
    that if it isn't 'true', it must be 'false'.
*>
macro as_bool(value) @builtin @if(NAN_BOXING)
    => value == true_val();

<*
    If NaN-Boxing is enabled, 'converts' a Lox nan-tagged [value] into its original
    (double) type. This is the reverse of 'number_val'.
*>
macro as_number(value) @builtin @if(NAN_BOXING)
    => value_to_num(value);

<*
    If NaN-Boxing is enabled, uses special bit-twiddling and type casting to clear the
    tag bits and leave just the bits for the (Obj *).
*>
macro as_obj(value) @builtin @if(NAN_BOXING)
    => (Obj *)(uptr)(value & ~(SIGN_BIT | QNAN));

<*
    The reverse of 'num_to_value', converting a (Value) (aka a ulong) to a (double).

    @param value "The value (as a Value) to convert back to a C3 double"
*>
fn double value_to_num(Value value) @inline @if(NAN_BOXING)
{
    double num;
    mem::copy(&num, &value, Value.sizeof);
    return num;
}

<*
    If NaN-Boxing is enabled, this macro does a similar thing to 'as_bool'.
    The difference is that this is used for type checking, where 'true' means
    it is the correct type and 'false' if it is not.

    By bitwise-ORing the [value] with 1, you end up with 1 of 3 results (2 of which
    return 'true'):

    1. The value was a 'false_val' and has now been converted to a 'true_val'. This
    return 'true'.

    2. The value was a 'true_val' and the '| 1' did nothing. This returns 'true'.

    3. It is another, non-boolean value. This returns 'false'.
*>
macro is_bool(value) @builtin @if(NAN_BOXING)
    => (value | 1) == true_val();

<*
    If NaN-Boxing is enabled, checks if the value is directly equal to the
    nan-boxed 'nil' value.
*>
macro is_nil(value) @builtin @if(NAN_BOXING)
    => value == nil_val();

<*
    If NaN-Boxing is enabled, checks if the [value] is a number by checking if the
    QNAN bits are set. If they are, then the input [value] is likely another value of
    some type.

    This replaces the 'is_number' macro defined below for traditional (Value) representations.
*>
macro is_number(value) @builtin @if(NAN_BOXING)
    => (value & QNAN) != QNAN;

<*
    If NaN-Boxing is enabled, uses bit twiddling to determine whether we are dealing with an
    (Obj *) or a negative number. This is because (Obj *)s are stored with their sign bits set.

    The sign bit is what determines if a number is negative or not, as well. This makes the
    determination by checking if both the sign bit *AND* the quiet NaN bits are set.
*>
macro is_obj(value) @builtin @if(NAN_BOXING)
    => (value & (QNAN | SIGN_BIT)) == (QNAN | SIGN_BIT);

//===----------------===//
// Value @if(!NAN_BOXING)
//===----------------===//

<*
    The type tags used to differentiate types of (Value)s.
*>
enum ValueType : int @if(!NAN_BOXING)
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
struct Value @if(!NAN_BOXING)
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
macro bool_val(value) @builtin @if(!NAN_BOXING)
    => Value { ValueType.BOOL, { .boolean = value } };

<*
    This is less of a promotion and more of a representation. This uses the underyling value
    of 0 to represent a nil (or null) (Value).
*>
macro nil_val() @builtin @if(!NAN_BOXING)
    => Value { ValueType.NIL, { .number = 0 } };

<*
    Promote's a C3 double value into a Lox number (Value).

    @param value "The underlying value to promote"
*>
macro number_val(value) @builtin @if(!NAN_BOXING)
    => Value { ValueType.NUMBER, { .number = value } };

<*
    Promote's a raw (Obj *) to a Lox (Value). All objects in Lox are also values.

    @param object "The object to promote to a Value"
*>
macro obj_val(object) @builtin @if(!NAN_BOXING)
    => Value { ValueType.OBJ, { .obj = (Obj *)object } };

/*
 * Macros to unwrap a Lox (Value) and return the underyling C3 value
*/

<*
    Unwraps a Lox (Value) of type (BOOL) and returns the underyling C3 bool value.

    @param value "The Value to unwrap"
*>
macro as_bool(value) @builtin @if(!NAN_BOXING)
    => value.as.boolean;

<*
    Unwraps a Lox (Value) of type (NUMBER) and returns the underyling C3 double value.

    @param value "The Value to unwrap"
*>
macro as_number(value) @builtin @if(!NAN_BOXING)
    => value.as.number;

<*
    Unwraps a Lox (Value) of type (OBJ) and returns the bare (Obj *).

    @param value "The Value to unwrap"
*>
macro as_obj(value) @builtin @if(!NAN_BOXING)
    => value.as.obj;

/*
 * Macros for type-checking Lox (Value)s
*/

<*
    Returns 'true' if the type of the [value] is (BOOL), otherwise
    returns 'false'.

    @param value "The value whose type needs checking"
*>
macro is_bool(value) @builtin @if(!NAN_BOXING)
    => value.type == ValueType.BOOL;

<*
    Returns 'true' if the type of the [value] is (NIL), otherwise
    returns 'false'.

    @param value "The value whose type needs checking"
*>
macro is_nil(value) @builtin @if(!NAN_BOXING)
    => value.type == ValueType.NIL;

<*
    Returns 'true' if the type of the [value] is (NUMBER), otherwise
    returns 'false'.

    @param value "The value whose type needs checking"
*>
macro is_number(value) @builtin @if(!NAN_BOXING)
    => value.type == ValueType.NUMBER;

<*
    Returns 'true' if the type of the [value] is (OBJ), otherwise
    returns 'false'.

    @param value "The value whose type needs checking"
*>
macro is_obj(value) @builtin @if(!NAN_BOXING)
    => value.type == ValueType.OBJ;

//===----------------===//
//    Value Functions
//===----------------===//

<*
    Print function specific to Lox dynamic values.

    @param value "The Value to print"
    @param stream "The output stream to print to (default is stdout)"
*>
fn void print(Value value, OutStream stream = io::stdout())
{
    $if (NAN_BOXING):
        switch
        {
            case is_bool(value):
                (void) io::fprintf(stream, as_bool(value) ? "true" : "false");
            case is_nil(value):
                (void) io::fprintf(stream, "nil");
            case is_number(value):
                (void) io::fprintf(stream, "%.32g", as_number(value));
            case is_obj(value):
                object::print(value, stream);
        }
    $else
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
    $endif
}

<*
    Returns 'true' if the (Value)s [a] and [b] are equal. Otherwise, it
    returns 'false'.

    @param a "The first, or 'a' value to compare"
    @param b "The second, or 'b' value to compare"
*>
fn bool equal(Value a, Value b)
{
    $if (NAN_BOXING):
        /*
         * This check exists to satisfy the IEEE 754 standard for floating-point
         * arithmetic. It mandates that numerical NaN values are *NOT* equal to themselves.
         *
         * An example as provided in the book:
         *
         * var nan = 0/0;
         * print nan == nan;
         *
         * According to the standard, that program should return 'false'. This check makes sure
         * that continues to happen regardless of whether nan-boxing is enabled or disabled. Without it,
         * that would only apply when nan-boxing is disabled.
        */
        if (is_number(a) && is_number(b))
            { return as_number(a) == as_number(b); }

        return a == b;
    $else
        if (a.type != b.type) return false;
        switch (a.type)
        {
            case BOOL:      return as_bool(a) == as_bool(b);
            case NIL:       return true;
            case NUMBER:    return as_number(a) == as_number(b);
            case OBJ:       return as_obj(a) == as_obj(b);
            default:        return false; // Unreachable
        }
    $endif
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
