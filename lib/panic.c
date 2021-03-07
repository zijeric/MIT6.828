
#include <inc/lib.h>

/*
 * 在无法解决的致命错误时调用panic
 * 它打印"panic: <message>"，然后触发断点异常，内核将进入JOS内核监视器
 */
void
_panic(const char *file, int line, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);

	// 打印panic的错误信息
	cprintf("[%08x] user panic in %s at %s:%d: ",
		sys_getenvid(), binaryname, file, line);
	vcprintf(fmt, ap);
	cprintf("\n");

	// 触发断点异常
	while (1)
		asm volatile("int3");
}

