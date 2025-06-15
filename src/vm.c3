module lox::vm;
import lox::chunk, lox::compiler, lox::memory;
import lox::table, lox::value;
import std::io @norecurse, std::time;

// Debug Flags
const bool DUMP_CODE = true;
const bool LOG_GC = false;
const bool TRACE_INSTRUCTIONS = false;
const bool STRESS_GC = false;

// Limiters
const uint FRAMES_MAX = 64;
const uint STACK_MAX = (FRAMES_MAX * (1 << 8));

faultdef COMPILE_ERROR, RUNTIME_ERROR;

struct LoxVM
{
    CallFrame[FRAMES_MAX] frames;
    int frame_count;
    Value[STACK_MAX] stack;
    Value *stack_top;
    usz bytes_allocated;
    usz next_gc;
    Obj *objects;
    Obj **gray_stack;
    int gray_capacity;
    int gray_count;
    ObjUpvalue *open_upvalues;
    Table strings;
    Table globals;
    ObjString *init_string;
    Compiler *compiler;
}

fn void LoxVM.init(&self)
{
    self.reset_stack();
    self.bytes_allocated = 0;
    self.next_gc = 1024 * 1024;
    self.objects = null;
    self.gray_stack = null;
    self.gray_capacity = 0;
    self.gray_count = 0;
    self.strings.init();
    self.globals.init();
    self.init_string = null;
    self.init_string = value::copy_string(self, "init", 4);
    self.compiler = null;

    self.define_native("clock", &clock_native);
}

fn void LoxVM.free(&self)
{
    self.globals.free(self);
    self.strings.free(self);
    self.init_string = null;
    memory::free_objects(self);
}

fn void LoxVM.reset_stack(&self) @local
{
    self.stack_top = &self.stack[0];
    self.frame_count = 0;
    self.open_upvalues = null;
}

fn void LoxVM.runtime_error(&self, String fmt, args...)
{
    io::eprintfn(fmt, ...args);

    for (int i = self.frame_count - 1; i >= 0; i--)
    {
        CallFrame *frame = &self.frames[i];
        ObjFn *function = frame.closure.function;
        int instruction = (int)(frame.ip - function.chunk.code.data - 1);
        int line = function.chunk.lines[instruction];

        io::eprintf("[line %d] in ", line);
        if (function.name == null)
        {
            io::eprintfn("script");
        }
        else
        {
            io::eprintfn("%s()", (ZString)function.name);
        }
    }
}

fn void LoxVM.concatenate(&self)
{
    ObjString *b = as_string(@peek(self));
    ObjString *a = as_string(@peek(self, 1));

    uint length = a.length + b.length;
    char *new_string = allocate_array(char, self, length + 1);
    mem::copy(new_string, a.value, a.length);
    mem::copy(new_string + a.length, b.value, b.length);
    new_string[length] = '\0';

    ObjString *result = value::take_string(self, new_string, length);
    @pop(self); // b
    @pop(self); // a
    @push(self, make_obj(result));
}

fn bool LoxVM.call(&self, ObjClosure *closure, int argc)
{
    if (argc != closure.function.arity)
    {
        self.runtime_error("Expected %d arguments but got %d instead", closure.function.arity, argc);
        return false;
    }

    if (self.frame_count == FRAMES_MAX)
    {
        self.runtime_error("Stack overflow");
        return false;
    }

    CallFrame *frame = &self.frames[self.frame_count++];
    frame.closure = closure;
    frame.ip = closure.function.chunk.code.data;
    frame.slots = self.stack_top - argc - 1;
    return true;
}

fn bool LoxVM.call_value(&self, Value callee, int argc)
{
    if (is_obj(callee))
    {
        switch (obj_type(callee))
        {
            case BOUND_METHOD:
                ObjBoundMethod *bound = as_bound_method(callee);
                self.stack_top[-argc - 1] = bound.receiver;
                return self.call(bound.method, argc);
            case CLASS:
                ObjClass *class = as_class(callee);
                Value initializer;

                self.stack_top[-argc - 1] = make_obj(value::new_instance(self, class));
                if (class.methods.get(self.init_string, &initializer))
                {
                    return self.call(as_closure(initializer), argc);
                }
                else if (argc != 0)
                {
                    self.runtime_error("Expected 0 arguments but got %d instead", argc);
                    return false;
                }

                return true;
            case CLOSURE:
                return self.call(as_closure(callee), argc);
            case NATIVE:
                NativeFn native = as_native(callee);
                Value result = native(argc, self.stack_top - argc);
                self.stack_top -= argc + 1;
                @push(self, result);
                return true;
            default:
                break; // Non-callable object type
        }
    }

    self.runtime_error("Can only call functions, methods or classes");
    return false;
}

fn bool LoxVM.bind_method(&self, ObjClass *class, ObjString *name)
{
    Value method;
    if (!class.methods.get(name, &method))
    {
        self.runtime_error("Undefined property '%s'", (ZString)name.value);
        return false;
    }

    ObjBoundMethod *bound = value::new_bound_method(self, @peek(self), as_closure(method));
    @pop(self);
    @push(self, make_obj(bound));
    return true;
}

fn bool LoxVM.invoke_from_class(&self, ObjClass *class, ObjString *name, int argc)
{
    Value method;
    if (!class.methods.get(name, &method))
    {
        self.runtime_error("Undefined property '%s'", (ZString)name.value);
        return false;
    }

    return self.call(as_closure(method), argc);
}

fn bool LoxVM.invoke(&self, ObjString *name, int argc)
{
    Value receiver = @peek(self, argc);
    if (!is_instance(receiver))
    {
        self.runtime_error("Only instances of a class have callable methods");
        return false;
    }

    ObjInstance *instance = as_instance(receiver);
    Value value;

    if (instance.fields.get(name, &value))
    {
        self.stack_top[-argc - 1] = value;
        return self.call_value(value, argc);
    }

    return self.invoke_from_class(instance.class, name, argc);
}

fn ObjUpvalue *LoxVM.capture_upvalue(&self, Value *local)
{
    ObjUpvalue *prev_upvalue = null;
    ObjUpvalue *upvalue = self.open_upvalues;

    while (upvalue != null && upvalue.location > local)
    {
        prev_upvalue = upvalue;
        upvalue = upvalue.next;
    }

    if (upvalue != null && upvalue.location == local)
    {
        return upvalue;
    }

    ObjUpvalue *created_upvalue = value::new_upvalue(self, local);
    created_upvalue.next = upvalue;

    if (prev_upvalue == null)
    {
        self.open_upvalues = created_upvalue;
    }
    else
    {
        prev_upvalue.next = created_upvalue;
    }

    return created_upvalue;
}

fn void LoxVM.close_upvalues(&self, Value *last)
{
    while (self.open_upvalues != null && self.open_upvalues.location >= last)
    {
        ObjUpvalue *upvalue = self.open_upvalues;
        upvalue.closed = *upvalue.location;
        upvalue.location = &upvalue.closed;
        self.open_upvalues = upvalue.next;
    }
}

fn void LoxVM.define_method(&self, ObjString *name)
{
    Value method = @peek(self);
    ObjClass *class = as_class(@peek(self, 1));
    class.methods.set(self, name, method);
    @pop(self);
}

fn void LoxVM.define_native(&self, String name, NativeFn function)
{
    @push(self, make_obj(value::copy_string(self, name, name.len)));
    @push(self, make_obj(value::new_native(self, function)));

    self.globals.set(self, as_string(self.stack[0]), self.stack[1]);

    @pop(self);
    @pop(self);
}

fn Value clock_native(int argc, Value *args)
{
    return make_num(time::now().to_seconds() / (double)time::SEC);
}

fn void? LoxVM.interpret(&self, char *source)
{
    ObjFn *function = compiler::compile(self, source);
    if (function == null) return COMPILE_ERROR?;

    @push(self, make_obj(function));
    ObjClosure *closure = value::new_closure(self, function);
    @pop(self);

    @push(self, make_obj(closure));
    self.call(closure, 0);

    return self.run();
}

fn void? LoxVM.run(&self) @local
{
    CallFrame *frame = &self.frames[self.frame_count - 1];

    for (;;)
    {
        $if $feature(DEBUG) &&& TRACE_INSTRUCTIONS:
            io::print("        ");
            for (Value *slot = &self.stack[0]; slot < self.stack_top; slot++)
            {
                io::print("[ ");
                value::print(*slot);
                io::print(" ]");
            }
            io::print("\n");

            frame.closure.function.chunk.disassemble_instruction(
                (int)(frame.ip - frame.closure.function.chunk.code.data)
            );
        $endif

        OpCode instruction;
        switch (instruction = opcode(@read_byte(frame)))
        {
            case FALSE:
                @push(self, make_bool(false));
            case NIL:
                @push(self, make_nil());
            case TRUE:
                @push(self, make_bool(true));
            case NOT:
                @push(self, make_bool(value::is_falsey(@pop(self))));
            case NEGATE:
                if (!is_num(@peek(self)))
                {
                    self.runtime_error("Unary operand must be a number");
                    return RUNTIME_ERROR?;
                }

                @push(self, make_num(-as_num(@pop(self))));
            case ADD:
                @binary_addition(self)!;
            case SUBTRACT:
                @binary_non_addition(self, make_num, sub)!;
            case MULTIPLY:
                @binary_non_addition(self, make_num, mul)!;
            case DIVIDE:
                @binary_non_addition(self, make_num, div)!;
            case EQUAL:
                Value b = @pop(self);
                Value a = @pop(self);
                @push(self, make_bool(value::equals(a, b)));
            case GREATER:
                @binary_non_addition(self, make_bool, gt)!;
            case LESS:
                @binary_non_addition(self, make_bool, lt)!;
            case POP:
                @pop(self);
            case CLOSE_UPVALUE:
                self.close_upvalues(self.stack_top - 1);
                @pop(self);
            case PRINT:
                value::print(@pop(self));
                io::printn();
            case INHERIT:
                Value superclass = @peek(self, 1);
                if (!is_class(superclass))
                {
                    self.runtime_error("Superclass must be a class");
                    return RUNTIME_ERROR?;
                }

                ObjClass *subclass = as_class(@peek(self));
                table::add_all(self, &as_class(superclass).methods, &subclass.methods);
            case RETURN:
                Value result = @pop(self);
                self.close_upvalues(frame.slots);
                self.frame_count--;

                if (self.frame_count == 0)
                {
                    @pop(self);
                    return;
                }

                self.stack_top = frame.slots;
                @push(self, result);
                @load_frame(self, frame);
            case CLASS:
                @push(self, make_obj(value::new_class(self, @read_string(frame))));
            case CONSTANT:
                Value constant = @read_constant(frame);
                @push(self, constant);
            case METHOD:
                self.define_method(@read_string(frame));
            case DEFINE_GLOBAL:
                ObjString *name = @read_string(frame);
                self.globals.set(self, name, @peek(self));
                @pop(self);
            case GET_GLOBAL:
                ObjString *name = @read_string(frame);
                Value value;

                if (!self.globals.get(name, &value))
                {
                    self.runtime_error("Undefined variable '%s'", (ZString)name.value);
                    return RUNTIME_ERROR?;
                }

                @push(self, value);
            case SET_GLOBAL:
                ObjString *name = @read_string(frame);
                if (self.globals.set(self, name, @peek(self)))
                {
                    self.globals.delete(name);
                    self.runtime_error("Undefined variable '%s'", (ZString)name.value);
                    return RUNTIME_ERROR?;
                }
            case GET_PROPERTY:
                if (!is_instance(@peek(self)))
                {
                    self.runtime_error("Only instances of a class have properties");
                    return RUNTIME_ERROR?;
                }

                ObjInstance *instance = as_instance(@peek(self));
                ObjString *name = @read_string(frame);
                Value value;

                if (instance.fields.get(name, &value))
                {
                    @pop(self); // Instance
                    @push(self, value);
                    break;
                }

                if (!self.bind_method(instance.class, name))
                {
                    return RUNTIME_ERROR?;
                }
            case SET_PROPERTY:
                if (!is_instance(@peek(self, 1)))
                {
                    self.runtime_error("Only instances of a class have fields");
                    return RUNTIME_ERROR?;
                }

                ObjInstance *instance = as_instance(@peek(self, 1));
                instance.fields.set(self, @read_string(frame), @peek(self));
                Value value = @pop(self);
                @pop(self);
                @push(self, value);
            case GET_SUPER:
                ObjString *name = @read_string(frame);
                ObjClass *superclass = as_class(@pop(self));

                if (!self.bind_method(superclass, name))
                {
                    return RUNTIME_ERROR?;
                }
            case GET_LOCAL:
                char slot = @read_byte(frame);
                @push(self, frame.slots[slot]);
            case SET_LOCAL:
                char slot = @read_byte(frame);
                frame.slots[slot] = @peek(self);
            case GET_UPVALUE:
                char slot = @read_byte(frame);
                @push(self, *frame.closure.upvalues[slot].location);
            case SET_UPVALUE:
                char slot = @read_byte(frame);
                *frame.closure.upvalues[slot].location = @peek(self);
            case CALL:
                int argc = @read_byte(frame);
                if (!self.call_value(@peek(self, argc), argc))
                {
                    return RUNTIME_ERROR?;
                }

                @load_frame(self, frame);
                // frame = &self.frames[self.frame_count - 1];
            case JUMP:
                ushort offset = @read_short(frame);
                frame.ip += offset;
            case JUMP_IF:
                ushort offset = @read_short(frame);
                if (value::is_falsey(@peek(self))) frame.ip += offset;
            case LOOP:
                ushort offset = @read_short(frame);
                frame.ip -= offset;
            case INVOKE:
                ObjString *method = @read_string(frame);
                int argc = @read_byte(frame);

                if (!self.invoke(method, argc))
                {
                    return RUNTIME_ERROR?;
                }

                @load_frame(self, frame);
            case SUPER_INVOKE:
                ObjString *method = @read_string(frame);
                int argc = @read_byte(frame);
                ObjClass *superclass = as_class(@pop(self));

                if (!self.invoke_from_class(superclass, method, argc))
                {
                    return RUNTIME_ERROR?;
                }

                @load_frame(self, frame);
            case CLOSURE:
                ObjFn *function = as_function(@read_constant(frame));
                ObjClosure *closure = value::new_closure(self, function);
                @push(self, make_obj(closure));

                for (int i = 0; i < closure.upvalue_count; i++)
                {
                    char is_local = @read_byte(frame);
                    char index = @read_byte(frame);

                    if (is_local)
                    {
                        closure.upvalues[i] = self.capture_upvalue(frame.slots + index);
                    }
                    else
                    {
                        closure.upvalues[i] = frame.closure.upvalues[index];
                    }
                }
        }
    }
}

macro @push(#vm, value) @builtin
{
    *#vm.stack_top++ = value;
}

macro @pop(#vm) @builtin
{
    return *(--#vm.stack_top);
}

macro @peek(#vm, int distance = 0) @builtin
{
    return #vm.stack_top[-1 - distance];
}

macro @load_frame(#vm, #frame) @local
{
    #frame = &#vm.frames[#vm.frame_count - 1];
}

macro @read_byte(#frame) @local
{
    return *#frame.ip++;
}

macro @read_short(#frame) @local
{
    #frame.ip += 2;
    return (ushort)((#frame.ip[-2] << 8) | #frame.ip[-1]);
}

macro @read_constant(#frame) @local
{
    return #frame.closure.function.chunk.constants[@read_byte(#frame)];
}

macro @read_string(#frame) @local
{
    return as_string(@read_constant(#frame));
}

macro void? @binary_non_addition(#vm, #value_type, #op) @local
{
    if (!is_num(@peek(#vm)) || !is_num(@peek(#vm, 1)))
    {
        #vm.runtime_error("Binary (non-addition) operands must be numbers");
        return RUNTIME_ERROR?;
    }

    double b = as_num(@pop(#vm));
    double a = as_num(@pop(#vm));
    @push(#vm, #value_type(#op(a, b)));
}

macro void? @binary_addition(#vm) @local
{
    if (is_string(@peek(#vm)) && is_string(@peek(#vm, 1)))
    {
        #vm.concatenate();
    }
    else if (is_num(@peek(#vm)) && is_num(@peek(#vm, 1)))
    {
        double b = as_num(@pop(#vm));
        double a = as_num(@pop(#vm));
        @push(#vm, make_num(a + b));
    }
    else
    {
        #vm.runtime_error("Binary (addition) operands must be numbers or strings");
        return RUNTIME_ERROR?;
    }
}

macro sub(a, b) @local => a - b;
macro mul(a, b) @local => a * b;
macro div(a, b) @local => a / b;
macro gt(a, b)  @local => a > b;
macro lt(a, b)  @local => a < b;
