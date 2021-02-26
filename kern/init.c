/* See COPYRIGHT for copyright information. */

#include <inc/stdio.h>
#include <inc/string.h>
#include <inc/assert.h>

#include <kern/monitor.h>
#include <kern/console.h>
#include <kern/pmap.h>
#include <kern/kclock.h>
#include <kern/env.h>
#include <kern/trap.h>

void i386_init(void)
{
	// 外部字符数组变量 edata 和 end，因为我们加载内核后已经启用虚拟地址映射（分页映射功能，并加载entry_pgdir到cr3寄存器）
	// 其中 edata 表示的是 bss 节起始位置（虚拟地址），而 end 则是表示内核可执行程序结束位置（虚拟地址）
	extern char edata[], end[];

	// 在执行其他操作之前，请完成 ELF 加载过程
	// 清除程序的未初始化的全局数据（BSS）部分
	// 这样可确保所有静态/全局变量均从零开始.
	memset(edata, 0, end - edata);

	// 初始化控制台
	// 在调用 cons_init 之前，无法调用 cprintf ！
	cons_init();

	// 内存管理初始化函数
	mem_init();

	// 用户环境初始化函数
	env_init();
	trap_init();

#if defined(TEST)
	// Don't touch -- used by grading script!
	ENV_CREATE(TEST, ENV_TYPE_USER);
#else
	// Touch all you want. 这个宏相当于调用env_create(_binary_obj_user_hello_start, ENV_TYPE_USER)
	ENV_CREATE(user_hello, ENV_TYPE_USER);
#endif // TEST*

	// 目前我们只有一个用户环境，envs[0]已经在env_create的时候初始化过了
	env_run(&envs[0]);
}

/*
 * Variable panicstr contains argument to first call to panic; used as flag
 * to indicate that the kernel has already called panic.
 */
const char *panicstr;

/*
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void _panic(const char *file, int line, const char *fmt, ...)
{
	va_list ap;

	if (panicstr)
		goto dead;
	panicstr = fmt;

	// Be extra sure that the machine is in as reasonable state
	asm volatile("cli; cld");

	va_start(ap, fmt);
	cprintf("kernel panic at %s:%d: ", file, line);
	vcprintf(fmt, ap);
	cprintf("\n");
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
}

/* like panic, but don't */
void _warn(const char *file, int line, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	cprintf("kernel warning at %s:%d: ", file, line);
	vcprintf(fmt, ap);
	cprintf("\n");
	va_end(ap);
}
