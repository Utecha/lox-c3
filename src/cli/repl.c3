module lox::cli::repl;
import lox::cli::utils, lox::vm;
import std::collections::object, std::encoding::json, std::io;

//------------------------------------------------------------------------------
// Lox | CLI | REPL
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

fn void print_intro()
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
                utils::YELLOW, utils::RESET,
                version,
                utils::BLUE, utils::RESET,
                allocator: allocator
            );
        $else
            intro = string::format(
                "%sLoxVM%s REPL Version %s",
                utils::YELLOW, utils::RESET,
                version,
                allocator: allocator
            );
        $endif

        utils::logn(NONE, intro);
        utils::logn(INFO, "Press Ctrl-D to exit (Ctrl-C on Windows).\n");
    };
}

fn void repl(Vm *vm)
{
    print_intro();
    for (;;)
    {
        char *line = readline(">>> ");
        if (!line)
        {
            io::printn();
            return;
        }

        add_history(line);
        vm.interpret("stdin", line);
        free(line);
    }
}