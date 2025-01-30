module lox::cli;
import lox::debug, lox::utils, lox::vm;
import std::io, std::collections::object, std::encoding::json;

//------------------------------------------------------------------------------
// Lox | CLI -- File IO
//------------------------------------------------------------------------------

fn char *readFile(String path)
{
    File! file = file::open(path, "rb");
    if (catch file)
    {
        utils::log(ERROR, "Could not open file '%s'. Did you spell it right?", path);
        return null;
    }
    defer (void) file.close();

    usz size = file.seek(0, Seek.END)!!;
    file.seek(0, Seek.SET)!!;

    char *buffer = (char *)malloc(size + 1);
    if (!buffer)
    {
        utils::log(ERROR, "Not enough memory to read '%s'", path);
        return null;
    }

    usz! numBytes = file.read(buffer[:size]);
    if (catch numBytes)
    {
        utils::log(ERROR, "Could not read file '%s'", path);
        return null;
    }
    buffer[numBytes] = '\0';
    return buffer;
}

fn int runFile(LoxVM *vm, String path)
{
    char *source = readFile(path);
    if (!source) return 65;
    defer free(source);

    $if $feature(DEBUG) &&& debug::DUMP_TOKENS:
        lexer::dumpTokens(source);
        return 0;
    $endif

    $if $feature(DEBUG) &&& debug::ENABLE_ALL:
        lexer::dumpTokens(source);
        return vm.interpret(source).ordinal;
    $endif

    return vm.interpret(path, source).ordinal;
}

//------------------------------------------------------------------------------
// Lox | CLI -- REPL
//------------------------------------------------------------------------------

extern fn char *readline(char *prompt) @if(env::POSIX);
extern fn void add_history(char *input) @if(env::POSIX);

/* Fake-ish readline function */
fn char *readline(ZString prompt) @if(env::WIN32)
{
    io::print(prompt);

    String! str = io::readline();
    if (catch str) return null;
    defer str.free();

    return str.zstr_copy();
}

/* Fake add history function */
fn void add_history(char *input) @if(env::WIN32) { return; }

fn void printIntro()
{
    Allocator allocator = allocator::temp();
    @pool(allocator)
    {
        String intro;

        String! project = (String)file::load_new("project.json", allocator);
        if (catch project) return;
        
        Object *!object = json::parse_string(project, allocator);
        if (catch object) return;
        
        String! version = object.get("version").s;
        if (catch version) return;
        
        $if $feature(DEBUG):
            intro = string::format(
                "%sLoxVM%s REPL Version %s [ %sDEBUG%s ]",
                utils::SYELLOW, utils::SRESET,
                version,
                utils::SBLUE, utils::SRESET,
                allocator: allocator
            );
        $else
            intro = string::format(
                "%sLoxVM%s REPL Version %s",
                utils::SYELLOW, utils::SRESET,
                version,
                allocator: allocator
            );
        $endif        

        utils::log(NONE, intro);
        utils::log(INFO, "Press Ctrl-D to exit (Ctrl-C on Windows).\n");
    };
}

fn void repl(LoxVM *vm)
{
    printIntro();

    for (;;)
    {
        char *line = readline(">>> ");
        if (!line)
        {
            io::printn();
            return;
        }

        add_history(line);

        $if $feature(DEBUG) &&& debug::DUMP_TOKENS:
            lexer::dumpTokens(line);
        $else
            vm.interpret("stdin", line);
        $endif

        $if $feature(DEBUG) &&& debug::ENABLE_ALL:
            lexer::dumpTokens("stdin", source);
            vm.interpret("stdin", source);
        $endif

        free(line);
    }
}
