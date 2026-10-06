import lox;

//------------------------------------------------------------------------------

fn int main(String[] args)
{
    LoxConfig config;
    lox::init_config(&config);

    LoxVM *vm = lox::new(&config);
    defer lox::free(vm);

    ObjFun *fun = value::new_function(vm);

    sz constant = value::add_constant(vm, fun, value::make_num(34));
    value::write_code(vm, fun, CONSTANT, 1);
    value::write_byte(vm, fun, (char)(constant >> 8) & 0xff, 1);
    value::write_byte(vm, fun, (char)(constant & 0xff), 1);

    constant = value::add_constant(vm, fun, value::make_num(35));
    value::write_code(vm, fun, CONSTANT, 1);
    value::write_byte(vm, fun, (char)(constant >> 8) & 0xff, 1);
    value::write_byte(vm, fun, (char)(constant & 0xff), 1);

    value::write_code(vm, fun, ADD, 1);
    value::write_code(vm, fun, RETURN, 2);

    debug::disassemble(fun, "test");
    return 0;
}
