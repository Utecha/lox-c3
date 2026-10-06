module lox::math;

//------------------------------------------------------------------------------

/**
 * This module is defined to include math macros for use with the VM. This
 * allows us to mimic the `BINARY_OP` macro from the original C implementation.
**/

macro double add(double a, double b) => a + b;
macro double sub(double a, double b) => a - b;
macro double mul(double a, double b) => a * b;
macro double div(double a, double b) => a / b;
macro double mod(double a, double b) => a % b;
macro bool gt(double a, double b) => a > b;
macro bool lt(double a, double b) => a < b;
