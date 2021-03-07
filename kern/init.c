/* See COPYRIGHT for copyright information. */

#include "inc/stdio.h"
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
	// 可以随意更改
	// 这个宏相当于调用env_create(_binary_obj_user_hello_start, ENV_TYPE_USER)
	// 从而指定了在之后的env_run中要执行的环境，user/hello的umain环境
	ENV_CREATE(user_hello, ENV_TYPE_USER);
#endif // TEST*

	// 目前我们只有一个用户环境，envs[0]已经在env_create的时候初始化过了
	env_run(&envs[0]);
	// 在函数env_run调用env_pop_tf之后，处理器开始执行trapentry.S下的代码
	// 应该首先跳转到TRAPENTRY_NOEC(divide_handler, T_DIVIDE)处，再经过_alltraps，进入trap函数

	// 进入trap函数后，先判断是否由用户态进入内核态，若是，则必须保存环境状态
	// 也就是将刚刚得到的TrapFrame存到对应环境结构体的属性中，之后要恢复环境运行，就是从这个TrapFrame进行恢复
	// 若中断令处理器从内核态切换到内核态，则不做特殊处理(嵌套interrupt，无需切换栈)

	// 接着调用分配函数trap_dispatch，这个函数根据中断向量，调用相应的处理函数，并返回
	// 故函数trap_dispatch返回之后，对中断的处理应当是已经完成了，该切换回触发中断的环境
	// 修改函数trap_dispatch的代码时应注意，函数后部分(内核/环境存在bug)不应该执行，否则会销毁当前环境curenv
	// 中断处理函数返回后，trap_dispatch应及时返回

	// 切换回到旧进程，调用的是env_run，根据当前进程结构体curenv中包含和运行有关的信息，恢复进程执行
}

/*
 * 变量panicstr包含第一次调用panic()的参数; 用作标志，表示内核已经调用了死机. 
 */
const char *panicstr;

/*
 * 无法解决的fatal error会导致panic. 它打印 panic:mesg，然后进入内核监视器. 
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
