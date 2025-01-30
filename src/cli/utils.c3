module lox::cli::utils;
import std::io @norecurse;

//------------------------------------------------------------------------------
// Lox | Utils
//------------------------------------------------------------------------------

const String RED = "\x1b[38;2;230;16;16m";
const String GREEN = "\x1b[38;2;50;207;10m";
const String BLUE = "\x1b[38;2;14;78;227m";
const String ORANGE = "\x1b[38;2;235;137;19m";
const String YELLOW = "\x1b[38;2;235;205;35m";
const String LIGHTGRAY = "\x1b[38;2;215;215;210m";
const String RESET = "\x1b[0m";

enum LogLevel : ichar
{
    NONE,
    DEBUG,
    INFO,
    WARNING,
    ERROR
}

fn void log(LogLevel level, String fmt, args...)
{
    switch (level)
    {
        case NONE:      break;
        case DEBUG:     io::eprintf("[ %sDEBUG%s ] ", BLUE, RESET);
        case INFO:      io::eprintf("[ %sINFO%s ] ", GREEN, RESET);
        case WARNING:   io::eprintf("[ %sWARNING%s ] ", ORANGE, RESET);
        case ERROR:     io::eprintf("[ %sERROR%s ] ", RED, RESET);
    }

    io::eprintf(fmt, ...args);
}

fn void logn(LogLevel level, String fmt, args...) @inline
{
    log(level, fmt, ...args);
    io::eprintfn("");
}