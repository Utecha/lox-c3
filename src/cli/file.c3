module lox::cli::file;
import lox::cli::utils, lox::vm;
import std::io;

//------------------------------------------------------------------------------
// Lox | CLI | File
//------------------------------------------------------------------------------

fn char *read_source(String path)
{
    File! file = file::open(path, "rb");
    if (catch file)
    {
        utils::logn(ERROR, "Could not open file '%s'. Did you spell it right?", path);
        return null;
    }
    defer (void) file.close();

    usz size = file.seek(0, Seek.END)!!;
    file.seek(0, Seek.SET)!!;

    char *buffer = (char *)malloc(size + 1);
    if (!buffer)
    {
        utils::logn(ERROR, "Not enough memory to read '%s'", path);
        return null;
    }

    usz! num_bytes = file.read(buffer[:size]);
    if (catch num_bytes)
    {
        utils::logn(ERROR, "Could not read file '%s'", path);
        return null;
    }

    buffer[num_bytes] = '\0';
    return buffer;
}

fn int run(Vm *vm, String path)
{
    char *source = read_source(path);
    if (!source) return 65;
    defer free(source);

    return vm.interpret(path, source).ordinal;
}

