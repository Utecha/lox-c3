module lox;

//===----------------------------------------------------------------------===//
// Lox | Main
//===----------------------------------------------------------------------===//

/*
 * PLANS
 *
 * Version [0.1.0]
 * This version of the project will be the complete version of Lox, largely
 * as it was written in the book (with some of the challenges completed as well).
 * There will be some differences as I take advantage of the features of C3, without
 * trying to stray *too* far from the original implementation. The main difference
 * will be my liberal use of the 'String' type from C3, as well as turning many of the
 * functions (such as the ones for the 'Lexer') into methods on that data structure, when
 * it makes sense to do so.
 *
 * Version [0.2.0]
 * This version of the project will be a complete rewrite, taking full advantage of the
 * knowledge I have gained from working on this project multiple times (in different
 * languages), as well as the features of C3.
*/

fn int main(String[] args)
{
    Chunk chunk;
    chunk.init();
    defer chunk.free();

    int constant = chunk.add_constant(1.2);
    chunk.write_opcode(CONSTANT, 123);
    chunk.write_byte(constant, 123);

    constant = chunk.add_constant(3.4);
    chunk.write_opcode(CONSTANT, 123);
    chunk.write_byte(constant, 123);

    chunk.write_opcode(ADD, 123);

    constant = chunk.add_constant(5.6);
    chunk.write_opcode(CONSTANT, 123);
    chunk.write_byte(constant, 123);

    chunk.write_opcode(DIVIDE, 123);
    chunk.write_opcode(NEGATE, 123);
    chunk.write_opcode(RETURN, 123);

    chunk.disassemble("Test Chunk");
	return 0;
}