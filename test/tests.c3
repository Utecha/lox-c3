module lox::test;
import lox::cli;
import lox::lexer;
import lox::token;
import std::io;

//------------------------------------------------------------------------------
// Lox \ Test
//------------------------------------------------------------------------------

fn PathList! generatePathList(String dirName)
{
    Path testDir = path::new(dirName)!;
    defer testDir.free();

    PathList basenames = path::new_ls(testDir)!;
    defer basenames.free();

    PathList tests;
    tests.new_init();

    foreach (Path test : basenames)
    {
        Path dir = path::new(dirName)!;
        Path path = dir.new_append(test.str_view())!;
        tests.push(path);
    }

    return tests;
}

fn void! testLexicalAnalysis() @test
{
    PathList tests;
    $if (env::WIN32):
        tests = generatePathList(".\\test\\scanning")!;
    $else
        tests = generatePathList("./test/scanning")!;
    $endif

    io::eprint("\n");
    foreach (Path test : tests)
    {
        char *source = cli::readFile(test.str_view());
        if (!source) return;

        io::eprintfn("=== %s ===", test.str_view());
        {
            Lexer lexer;
            lexer.init(source);

            int line = -1;
            for (;;)
            {
                Token token = lexer.getNextToken();
                if (token.line != line)
                {
                    io::eprintf("%4d ", token.line);
                    line = token.line;
                }
                else
                {
                    io::eprintf("   | ");
                }

                io::eprintfn("%-10s : '%s'", token.type, token.lexeme);
                if (token.type == TokenType.EOF) break;
            }

            free(source);
        }
        io::eprintn("");
    }
}
