module lox::utils;
import lox::vm::array;

fn int powof2ceil(int n)
{
    n++;
    n |= n >> 1;
    n |= n >> 2;
    n |= n >> 4;
    n |= n >> 8;
    n |= n >> 16;
    n--;

    return n;
}
