module lox::value;
import lox::memory;
import std::io @norecurse;

//===----------------===//
//        Value
//===----------------===//

/* Temporary typedef for the Value type */
def Value = double;

<*
    Print function specific to Lox dynamic values.

    @param value "The Value to print"
    @param stream "The output stream to print to (default is stdout)"
*>
fn void print(Value value, OutStream stream = io::stdout())
{
    (void) io::fprintf(stream, "%g", value);
}

//===----------------===//
//      ValueList
//===----------------===//

/* Structure representing a dynamic array of Lox values */
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
