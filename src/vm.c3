module lox;

//------------------------------------------------------------------------------

struct LoxVM
{
    sz bytes_allocated;
    LoxReallocFn realloc;
}
