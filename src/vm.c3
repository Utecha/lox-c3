module lox;
import lox::memory @public;

//------------------------------------------------------------------------------

struct LoxConfig
{
    LoxReallocFn realloc;
}

struct LoxVM
{
    Obj *objects;
    sz bytes_allocated;
    LoxConfig config;
}

//------------------------------------------------------------------------------

fn LoxVM *new(LoxConfig *config = null)
{
    LoxReallocFn reallocate = &memory::__reallocate;
    if (config)
    {
        reallocate = config.realloc ? config.realloc : &memory::__reallocate;
    }

    LoxVM *vm = (LoxVM *)reallocate(null, LoxVM::size);

    vm.objects = null;
    vm.bytes_allocated = 0;

    if (config)
    {
        mem::copy(&vm.config, config, LoxConfig::size);
        vm.config.realloc = reallocate;
    }
    else
    {
        init_config(&vm.config);
    }

    return vm;
}

fn void free(LoxVM *vm)
{
    value::free_objects(vm);
    memory::free(LoxVM, vm, vm);
}

fn void init_config(LoxConfig *config)
{
    config.realloc = &memory::__reallocate;
}
