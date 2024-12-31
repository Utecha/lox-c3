module lox::value;
import lox::list;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox \ Value
//------------------------------------------------------------------------------

enum ValueType : int
{
    BOOL,
    NIL,
    NUMBER
}

struct Value
{
    ValueType type;
    union as
    {
        bool boolean;
        double number;
    }
}

def ValueList = LoxList(<Value>);

macro boolVal(value)    @builtin => Value { ValueType.BOOL, { .boolean = value } };
macro nilVal()          @builtin => Value { ValueType.NIL, { .number = 0 } };
macro numberVal(value)  @builtin => Value { ValueType.NUMBER, { .number = value } };

macro asBool(value)     @builtin => value.as.boolean;
macro asNumber(value)   @builtin => value.as.number;

macro isBool(value)     @builtin => value.type == ValueType.BOOL;
macro isNil(value)      @builtin => value.type == ValueType.NIL;
macro isNumber(value)   @builtin => value.type == ValueType.NUMBER;

fn void print(Value value, OutStream stream = io::stdout())
{
    switch (value.type)
    {
        case BOOL:      (void) io::fprintf(stream, asBool(value) ? "true" : "false");
        case NIL:       (void) io::fprintf(stream, "nil");
        case NUMBER:    (void) io::fprintf(stream, "%g", asNumber(value));
        default:        unreachable();
    }
}

fn bool equal(Value a, Value b)
{
    if (a.type != b.type) return false;
    switch (a.type)
    {
        case BOOL:      return asBool(a) == asBool(b);
        case NIL:       return true;
        case NUMBER:    return asNumber(a) == asNumber(b);
        default:        return false;
    }
}
