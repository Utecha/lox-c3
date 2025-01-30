module lox::gc;
import lox::vm;

//------------------------------------------------------------------------------
// Lox | GC
//------------------------------------------------------------------------------

fn void free_object(Obj *object)
{
    switch (object.type)
    {
        case STRING:
            ObjString *string = (ObjString *)object;
            memory::lfree(char, string.value[:string.len], string.len);
            // memory::lfree(char, string.value[:string.len], string.len + 1);
            memory::lfree(ObjString, object);
    }
}

fn void free_objects(Vm *vm)
{
    Obj *object = vm.objects;
    while (object != null)
    {
        Obj *next = object.next;
        free_object(object);
        object = next;
    }
}