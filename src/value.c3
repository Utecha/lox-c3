module lox::value;
import lox::memory;
import std::io @norecurse;

//===----------------------------------------------------------------------===//
// Lox | Value
//===----------------------------------------------------------------------===//

/* Temporary -- later values will be a NaN-Tagged double/Tagged Union */
distinct Value = inline double;

/*
 * Prints a [value] to the desired output [stream]. Excluding the stream argument
 * will default it to 'stdout'.
*/
fn void print(Value value, OutStream stream = io::stdout())
{
    (void) io::fprintf(stream, "%g", value);
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