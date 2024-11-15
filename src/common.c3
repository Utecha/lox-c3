module lox::common;

/*
 * This module contains all common definitions that may be used throughout the project.
 *
 * NOTE: Most if not all definitions here will be marked as '@builtin' for convenience.
*/

//===----------------===//
//     Debug Flags
//===----------------===//

/*
 * NOTE: These flags depend on this project being compiled with the 'DEBUG' feature
 * flag (e.g. 'c3c build -D DEBUG') in order to have any functionality.
*/

/* Enable to dump the entirety of each Chunk */
const DUMP_CHUNK            @builtin = false;

/* Enable to trace the individual instructions as they execute in the VM */
const TRACE_INSTRUCTIONS    @builtin = true;

//===----------------===//
//     Misc Flags
//===----------------===//

/*
 * These flags were added for the fun of it and for testing/learning purposes.
*/

/* Enables the optimization for the negate (-) operator */
const OPTIMIZE_NEGATION     @builtin = false;
