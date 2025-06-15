module lox::memory;
import lox::compiler, lox::table, lox::value, lox::vm;
import std::io @norecurse, std::thread;

const uint HEAP_GROWTH_FACTOR = 2;

fn void *reallocator(LoxVM *vm, void *ptr, usz old_size, usz new_size)
{
    vm.bytes_allocated += new_size - old_size;

    if (new_size > old_size)
    {
        $if $feature(DEBUG) &&& vm::STRESS_GC:
            collect_garbage(vm);
        $endif

        if (vm.bytes_allocated > vm.next_gc)
        {
            collect_garbage(vm);
        }
    }

    if (new_size == 0)
    {
        free(ptr);
        return null;
    }

    return realloc(ptr, new_size);
}

macro grow_capacity(capacity) @builtin
{
    return capacity < 8U ? 8U : capacity * 2U;
}

macro allocate($Type, vm) @builtin
{
    return ($Type *)reallocator(vm, null, 0, $Type.sizeof);
}

macro allocate_array($Type, vm, count) @builtin
{
    return ($Type *)reallocator(vm, null, 0, $Type.sizeof * count);
}

macro reallocate($Type, vm, ptr, old_size, new_size) @builtin
{
    return ($Type *)reallocator(vm, ptr, $Type.sizeof * old_size, $Type.sizeof * new_size);
}

macro deallocate($Type, vm, ptr) @builtin
{
    reallocator(vm, ptr, $Type.sizeof, 0);
}

macro deallocate_array($Type, vm, ptr, old_size) @builtin
{
    reallocator(vm, ptr, $Type.sizeof * old_size, 0);
}

fn void collect_garbage(LoxVM *vm) @local
{
    $if $feature(DEBUG) &&& vm::LOG_GC:
        io::printfn("--> Begin GC");
        io::printfn("----------------");
        usz before = vm.bytes_allocated;
    $endif

    mark_roots(vm);
    trace_references(vm);
    table_remove_white(vm, &vm.strings);
    sweep(vm);

    vm.next_gc = vm.bytes_allocated * HEAP_GROWTH_FACTOR;

    $if $feature(DEBUG) &&& vm::LOG_GC:
        io::printfn("----------------");
        io::printfn("--> End GC");
        io::printfn(
            "Collected: %db (from %d to %d). Next collection at: %d",
            before - vm.bytes_allocated,
            before,
            vm.bytes_allocated,
            vm.next_gc
        );
    $endif
}

fn void mark_roots(LoxVM *vm) @local
{
    for (Value *slot = &vm.stack[0]; slot < vm.stack_top; slot++)
    {
        mark_value(vm, *slot);
    }

    for (int i = 0; i < vm.frame_count; i++)
    {
        mark_object(vm, (Obj *)vm.frames[i].closure);
    }

    for (ObjUpvalue *upvalue = vm.open_upvalues; upvalue != null; upvalue = upvalue.next)
    {
        mark_object(vm, (Obj *)upvalue);
    }

    mark_table(vm, &vm.globals);
    mark_compiler_roots(vm);
    mark_object(vm, (Obj *)vm.init_string);
}

fn void mark_compiler_roots(LoxVM *vm) @local
{
    Compiler *compiler = vm.compiler;
    while (compiler != null)
    {
        mark_object(vm, (Obj *)compiler.function);
        compiler = compiler.parent;
    }
}

fn void mark_object(LoxVM *vm, Obj *object) @local
{
    if (object == null) return;
    if (object.is_marked) return;

    $if $feature(DEBUG) &&& vm::LOG_GC:
        io::printf("%p | Marked: '", (void *)object);
        value::print(make_obj(object));
        io::printn("'");
    $endif

    object.is_marked = true;

    if (vm.gray_capacity < vm.gray_count + 1)
    {
        vm.gray_capacity = grow_capacity(vm.gray_capacity);
        vm.gray_stack = (Obj **)realloc(vm.gray_stack, (Obj *).sizeof * vm.gray_capacity);
        if (vm.gray_stack == null) thread::exit(1);
    }

    vm.gray_stack[vm.gray_count++] = object;
}

fn void mark_table(LoxVM *vm, Table *table) @local
{
    for (int i = 0; i < table.capacity; i++)
    {
        Entry *entry = &table.entries[i];
        mark_object(vm, (Obj *)entry.key);
        mark_value(vm, entry.value);
    }
}

fn void mark_value(LoxVM *vm, Value value) @local
{
    if (is_obj(value)) mark_object(vm, as_obj(value));
}

fn void mark_array(LoxVM *vm, ValueBuffer *constants) @local
{
    for (int i = 0; i < constants.count; i++)
    {
        mark_value(vm, constants.data[i]);
    }
}

fn void trace_references(LoxVM *vm) @local
{
    while (vm.gray_count > 0)
    {
        Obj *object = vm.gray_stack[--vm.gray_count];
        blacken_object(vm, object);
    }
}

fn void blacken_object(LoxVM *vm, Obj *object) @local
{
    $if $feature(DEBUG) &&& vm::LOG_GC:
        io::printf("%p | Blackened: '", (void *)object);
        value::print(make_obj(object));
        io::printn("'");
    $endif

    switch (object.type)
    {
        case BOUND_METHOD:
            ObjBoundMethod *bound = (ObjBoundMethod *)object;
            mark_value(vm, bound.receiver);
            mark_object(vm, (Obj *)bound.method);
        case CLASS:
            ObjClass *class = (ObjClass *)object;
            mark_object(vm, (Obj *)class.name);
            mark_table(vm, &class.methods);
        case CLOSURE:
            ObjClosure *closure = (ObjClosure *)object;
            mark_object(vm, (Obj *)closure.function);
            for (int i = 0; i < closure.upvalue_count; i++)
            {
                mark_object(vm, (Obj *)closure.upvalues[i]);
            }
        case FUNCTION:
            ObjFn *function = (ObjFn *)object;
            mark_object(vm, (Obj *)function.name);
            mark_array(vm, &function.chunk.constants);
        case INSTANCE:
            ObjInstance *instance = (ObjInstance *)object;
            mark_object(vm, (Obj *)instance.class);
            mark_table(vm, &instance.fields);
        case NATIVE:
        case STRING:
            break;
        case UPVALUE:
            mark_value(vm, ((ObjUpvalue *)object).closed);
    }
}

fn void table_remove_white(LoxVM *vm, Table *table)
{
    for (int i = 0; i < table.capacity; i++)
    {
        Entry *entry = &table.entries[i];
        if (entry.key != null && !entry.key.obj.is_marked)
        {
            table.delete(entry.key);
        }
    }
}

fn void sweep(LoxVM *vm) @local
{
    Obj *previous = null;
    Obj *object = vm.objects;

    while (object != null)
    {
        if (object.is_marked)
        {
            object.is_marked = false;
            previous = object;
            object = object.next;
        }
        else
        {
            Obj *unreached = object;
            object = object.next;

            if (previous != null)
            {
                previous.next = object;
            }
            else
            {
                vm.objects = object;
            }

            free_object(vm, unreached);
        }
    }
}

fn void free_object(LoxVM *vm, Obj *object) @local
{
    $if $feature(DEBUG) &&& vm::LOG_GC:
        io::printfn("%p | Freed type: %s", (void *)object, object.type);
    $endif

    switch (object.type)
    {
        case BOUND_METHOD:
            deallocate(ObjBoundMethod, vm, object);
        case CLASS:
            ObjClass *class = (ObjClass *)object;
            deallocate(ObjClass, vm, object);
            class.methods.free(vm);
        case CLOSURE:
            ObjClosure *closure = (ObjClosure *)object;
            deallocate_array(ObjUpvalue *, vm, closure.upvalues, closure.upvalue_count);
            deallocate(ObjClosure, vm, object);
        case FUNCTION:
            ObjFn *function = (ObjFn *)object;
            function.chunk.free(vm);
            deallocate(ObjFn, vm, object);
        case INSTANCE:
            ObjInstance *instance = (ObjInstance *)object;
            instance.fields.free(vm);
            deallocate(ObjInstance, vm, object);
        case NATIVE:
            deallocate(ObjNative, vm, object);
        case STRING:
            ObjString *string = (ObjString *)object;
            deallocate_array(char, vm, string.value, string.length + 1);
            deallocate(ObjString, vm, object);
        case UPVALUE:
            deallocate(ObjUpvalue, vm, object);
    }
}

fn void free_objects(LoxVM *vm)
{
    Obj *object = vm.objects;
    while (object != null)
    {
        Obj *next = object.next;
        free_object(vm, object);
        object = next;
    }

    free(vm.gray_stack);
}
