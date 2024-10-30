import lox;
import std::io @norecurse;

/*
 * This is basically the pre-compiler implementation 'compile' function turned into
 * a unit test.
*/
fn void! dump_tokens() @test
{
    /* Load the 'test/lexer/tokens.lox' test file into a (char *) */
    char *source = lox::read_file("test/lexer/tokens.lox")!;
    defer free(source);

    /* Run the [source] through the lexer and dump the tokens */
    lexer::init(source);

    /* Fix funky output */
    io::printn();

    int line = -1;
    for (;;)
    {
        Token token = lexer::get_token();
        if (line != token.line)
        {
            io::eprintf("%4d ", token.line);
            line = token.line;
        }
        else
        {
            io::eprint("   | ");
        }

        io::eprintfn("%-12s '%s'", token.type, token.lexeme);
        if (token.type == EOF) break;
    }
}

fn void lex_test_program() @test
{
    /* Load the 'test/lexer/tokens.lox' test file into a (char *) */
    char *source = lox::read_file("test/lexer/program.lox")!;
    defer free(source);

    /* Fix funky output */
    io::printn();

    /* Run the [source] through the lexer and dump the tokens */
    lexer::init(source);

    int line = -1;
    for (;;)
    {
        Token token = lexer::get_token();
        if (line != token.line)
        {
            io::eprintf("%4d ", token.line);
            line = token.line;
        }
        else
        {
            io::eprint("   | ");
        }

        io::eprintfn("%-12s '%s'", token.type, token.lexeme);
        if (token.type == EOF) break;
    }
}