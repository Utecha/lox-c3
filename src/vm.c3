module lox;
import lox::memory @public;

//------------------------------------------------------------------------------

struct LoxConfig
{
    LoxReallocFn reallocate;
}

struct LoxVM
{
    Obj *objects;
    sz bytes_allocated;
    LoxConfig config;
}

//------------------------------------------------------------------------------

<*
    Returns a pointer to a newly allocated and initialized LoxVM instance.

    @param [inout] config : "A pointer to a LoxConfig."
*>
fn LoxVM *new(LoxConfig *config = null)
{
    LoxReallocFn reallocate = &memory::__reallocate;
    if (config)
    {
        reallocate = config.reallocate ? config.reallocate : &memory::__reallocate;
    }

    LoxVM *vm = (LoxVM *)reallocate(null, LoxVM::size);

    vm.objects = null;
    vm.bytes_allocated = 0;

    if (config)
    {
        mem::copy(&vm.config, config, LoxConfig::size);
        vm.config.reallocate = reallocate;
    }
    else
    {
        init_config(&vm.config);
    }

    return vm;
}

<*
    Releases the memory held by [vm], including itself.

    @param [&inout] vm : "A pointer to a LoxVM to free."
*>
fn void free(LoxVM *vm)
{
    if (!vm) return;

    value::free_objects(vm);
    memory::free(LoxVM, vm, vm);
}

<*
    @param [&inout] config : "A pointer to a LoxConfig to initialize."
    @param reallocate : "A pointer to a function for reallocating memory."

    @ensure config.reallocate != null
*>
fn void init_config(
    LoxConfig *config,
    LoxReallocFn reallocate = &memory::__reallocate
)
{
    config.reallocate = reallocate;
}
