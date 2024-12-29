module lox::value;
import lox::list;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox \ Value
//------------------------------------------------------------------------------

def Value = double;

fn void print(Value value, OutStream stream = io::stdout())
{
    (void) io::fprintf(stream, "%g", value);
}

def ValueList = LoxList(<Value>);
