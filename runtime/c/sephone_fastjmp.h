/*
 * sephone_fastjmp.h: forced into every C file of a phone build (-include).
 *
 * gec's C calls setjmp for every assertion block and every rescue clause. On
 * Android, plain setjmp is sigsetjmp(env, 1): it saves the signal mask, which
 * is a system call. Measured on the emulator: a contract-checked pixel write
 * cost about 5 microseconds, so a 16 px stroke segment took 17 ms.
 *
 * _setjmp and _longjmp are the same jump without the signal mask. The cost:
 * a signal handler that jumps into a rescue leaves that signal blocked, so a
 * second crash of the same kind ends the process, which Android reports as an
 * ordinary crash. Nothing in sephone jumps out of a signal handler.
 */
#ifndef SEPHONE_FASTJMP_H
#define SEPHONE_FASTJMP_H

#include <setjmp.h>

#undef setjmp
#undef longjmp
#define setjmp(env) _setjmp(env)
#define longjmp(env, value) _longjmp(env, value)

#endif
