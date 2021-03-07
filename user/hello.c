// hello, world
#include <inc/lib.h>

void
umain(int argc, char **argv)
{
	// 调用了cprintf()，注意这是lib/print.c中的cprintf
	cprintf("hello, world\n");
	cprintf("i am environment %08x\n", thisenv->env_id);
}
