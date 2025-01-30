module lox::test;
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

fn void runAssignmentTests() @test
{
    // TODO
}