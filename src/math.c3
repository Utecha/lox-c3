module lox::math;

//------------------------------------------------------------------------------

/**
 * This module is defined to include math macros for use with the VM. This
 * allows us to mimic the `BINARY_OP` macro from the original C implementation.
**/

<* Returns the result of adding two doubles. *>
macro double add(double a, double b) => a + b;

<* Returns the result of subtracting two doubles. *>
macro double sub(double a, double b) => a - b;

<* Returns the result of multiplying two doubles. *>
macro double mul(double a, double b) => a * b;

<* Returns the result of dividing two doubles. *>
macro double div(double a, double b) => a / b;

<* Returns the remainder of dividing two doubles. *>
macro double mod(double a, double b) => a % b;

<* Returns whether double [a] is greater than double [b]. *>
macro bool gt(double a, double b) => a > b;

<* Returns whether double [a] is less than double [b]. *>
macro bool lt(double a, double b) => a < b;
