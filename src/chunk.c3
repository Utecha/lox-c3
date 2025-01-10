module lox::vm::chunk;
import lox::vm::list;
import lox::vm::mem;
import lox::vm::value;

//------------------------------------------------------------------------------
// Lox \ VM \ Chunk
//------------------------------------------------------------------------------

struct Line
{
    int line;
    int offset;
}

def CodeBuffer = LoxList(<char>);
def LineBuffer = LoxList(<Line>);
def ValueBuffer = LoxList(<Value>);

struct Chunk
{
    CodeBuffer code;
    LineBuffer lines;
    ValueBuffer constants;
}

fn void Chunk.zero(&self)
{
    self.code.zero();
    self.lines.zero();
    self.constants.zero();
}

fn Chunk *Chunk.new(&self)
{
    self.code.new();
    self.lines.new();
    self.constants.new();
    return self;
}

fn void Chunk.free(&self)
{
    self.constants.free();
    self.lines.free();
    self.code.free();
    self.zero();
}

fn void Chunk.write(&self, char byte, int line)
{
    if (self.code.len() == 0 || self.lines.last().line != line)
        { self.lines.append({ .line = line, .offset = self.code.len() }); }

    self.code.append(byte);
}

fn int Chunk.addConstant(&self, Value value)
{
    self.constants.append(value);
    return self.constants.len() - 1;
}

fn int Chunk.getLine(&self, int offset)
{
    int start = 0;
    int end = self.lines.len() - 1;

    while (start <= end)
    {
        int mid = (start + end) / 2;
        Line line = self.lines[mid];

        if (offset < line.offset)
            { end = mid - 1; }
        else if (mid == self.lines.len() - 1 || offset < self.lines[mid + 1].offset)
            { return line.line; }
        else
            { start = mid + 1; }
    }

    return -1;
}
