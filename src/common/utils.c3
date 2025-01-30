module lox::utils;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox | Utils
//------------------------------------------------------------------------------

const String SRED = "\x1b[38;2;230;16;16m";
const String SGREEN = "\x1b[38;2;50;207;10m";
const String SBLUE = "\x1b[38;2;14;78;227m";
const String SORANGE = "\x1b[38;2;235;137;19m";
const String SYELLOW = "\x1b[38;2;235;205;35m";
const String SLIGHTGRAY = "\x1b[38;2;215;215;210m";
const String SRESET = "\x1b[0m";

enum LogLevel : ichar
{
    NONE,
    DEBUG,
    INFO,
    WARNING,
    ERROR
}

fn void log(LogLevel level, String fmt, args..., bool noNewline = false)
{
    switch (level)
    {
        case NONE:      break;
        case DEBUG:     io::eprintf("[ %sDEBUG%s ] ", SBLUE, SRESET);
        case INFO:      io::eprintf("[ %sINFO%s ] ", SGREEN, SRESET);
        case WARNING:   io::eprintf("[ %sWARNING%s ] ", SORANGE, SRESET);
        case ERROR:     io::eprintf("[ %sERROR%s ] ", SRED, SRESET);
    }
    
    io::eprintf(fmt, ...args);
    if (noNewline) return;
    io::eprintf("\n");
}

macro nextPowOf2(n) @builtin
{
    return n < 16U ? 16U : n * 2U;
}