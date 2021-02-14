// Simple command-line kernel monitor useful for
// controlling the kernel and exploring the system interactively.

#include <inc/stdio.h>
#include <inc/string.h>
#include <inc/memlayout.h>
#include <inc/assert.h>
#include <inc/x86.h>

#include <kern/console.h>
#include <kern/monitor.h>
#include <kern/kdebug.h>

#define CMDBUF_SIZE 80 // enough for one VGA text line

struct Command
{
	const char *name;
	const char *desc;
	// return -1 to force monitor to exit
	int (*func)(int argc, char **argv, struct Trapframe *tf);
};

static struct Command commands[] = {
	{"help", "Display this list of commands", mon_help},
	{"kerninfo", "Display information about the kernel", mon_kerninfo},
	{"backtrace", "Display backtrace information", mon_backtrace},
};

/***** Implementations of basic kernel monitor commands *****/

int mon_help(int argc, char **argv, struct Trapframe *tf)
{
	int i;

	for (i = 0; i < ARRAY_SIZE(commands); i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
	return 0;
}

int mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
	extern char _start[], entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
	cprintf("  _start                  %08x (phys)\n", _start);
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
			ROUNDUP(end - entry, 1024) / 1024);
	return 0;
}

/**
 * 实现过程:
 * 1.通过objdump命令,观察内核中不同的段
 * 2.objdump -h obj/kern/kernel
 *    需要注意.stab 和 .stabstr两段
 * 3.objdump -G obj/kern/kernel > stabs.txt
 *    由于显示内容较多,可以将结果输出到文件中
 *    文件(N_SO)和函数(N_FUN)项在.stab中按照指令地址递增的顺序组织
 * 4.根据eip 和 n_type(N_SO, N_SOL或N_FUN), 在.stab段中查找相应的Stab结构项(调用stab_binsearch)
 * 5.根据相应 Stab 结构的 n_strx 属性，找到其在.stabstr段中的索引，从该索引开始的字符串就是其对应的名字（文件名或函数名）
 * 6(*).根据 eip 和 n_type(N_SLINE)，在.stab段中找到相应的行号(n_desc字段)
 */ 
int mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
	// uint32_t *ebp, *eip;

	// esp: stack pointer 栈指针(push/pop 操作), ebp: base pointer 当前函数栈的开头
	// eip: instruction pointer 存储原调用函数的下一个指令的地址
	// 1. 利用 read_ebp() 函数获取当前ebp的值 
	// 2. 利用 ebp 的初始值与0比较，判断是否停止(0:停止)
	// 3. 利用数组指针运算来获取 eip 以及 args 参数
	// 4. 利用 Eipdebuginfo 结构体的属性参数获取文件名信息
	uint32_t ebp = read_ebp();
	uint32_t *ptr_ebp = (uint32_t*)ebp;  // ebp 指针
	struct Eipdebuginfo info;
	cprintf("Stack backtrace:\n");
	while (ebp != 0 && debuginfo_eip(ptr_ebp[1], &info) == 0) {

		// 打印 ebp, eip, 最近(前)的五个参数
		//                  -> mon_backtrace的三个参数+其他栈参数
		// 返回指令指针(eip)通常指向调用指令(ebp)之后的指令
		// 通过 ret eip 跳转到调用本函数的call指令的下一个指令
		// 调用链：
		// 1. 当前函数的参数被压入栈
		// 2. 保存调用函数状态，以便再当前被调用函数返回时，恢复调用函数的帧
		cprintf(" ebp %x  eip %x  args %08x %08x %08x %08x %08x\n",
		// 调用函数的栈指针 ebp
		 ebp,
		// 参数
		 ptr_ebp[1], ptr_ebp[2], ptr_ebp[3], ptr_ebp[4], ptr_ebp[5], ptr_ebp[6]);
		// 打印文件名信息
		cprintf("     %s:%d: %.*s+%d\n", info.eip_file, info.eip_line, info.eip_fn_namelen, info.eip_fn_name, ptr_ebp[1] - info.eip_fn_addr);
		// ebp 指向 old ebp，所以用类似链表的方法， 就可以得到整个调用链了
		ebp = *ptr_ebp;
		ptr_ebp = (uint32_t *)ebp;
	}

	cprintf("\n");

	return 0;
}

/***** Kernel monitor command interpreter *****/

#define WHITESPACE "\t\r\n "
#define MAXARGS 16

static int
runcmd(char *buf, struct Trapframe *tf)
{
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1)
	{
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
		if (*buf == 0)
			break;

		// save and scan past next arg
		if (argc == MAXARGS - 1)
		{
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
			buf++;
	}
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < ARRAY_SIZE(commands); i++)
	{
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
	return 0;
}

void monitor(struct Trapframe *tf)
{
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
	cprintf("Type 'help' for a list of commands.\n");

	while (1)
	{
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
