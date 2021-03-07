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
#include <kern/trap.h>
#include <kern/pmap.h>

#define CMDBUF_SIZE 80 // enough for one VGA text line

// 所有输入的命令通过 Command 数组进行管理，通过函数指针 func 进行调用。
// 因此如果增加命令，只需要在数组增加元组即可，注意，要在 kern/monitor.h 增加函数声明
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
	{"showmappings", "Display all of the physical page mappings", mon_showmappings},
	{"setperm", "Set or clear a flag in a specific page", mon_setperm},
	{"showmem", "Display memory", mon_showmem},
	{"step", "Single-step debugging", mon_step},
	{"continue", "Resume program execution", mon_continue},
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

/**
 * 返回到JOS的内核监控器(命令行)
 */ 
void monitor(struct Trapframe *tf)
{
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
	cprintf("Type 'help' for a list of commands.\n");

	if (tf != NULL)
		print_trapframe(tf);

	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
/**
 * 将字符串转换为地址
 */ 
uint32_t str2add(char* buf) {
	uint32_t res = 0;
	buf += 2; //0x...
	while (*buf) { 
		if (*buf >= 'a') *buf = *buf-'a'+'0'+10;//aha
		res = res*16 + *buf - '0';
		++buf;
	}
	return res;
}

/**
 * 输出页表页项 pte_t 的 flags 信息
 */ 
void pprint(pte_t *pte) {
	cprintf("PTE_P: %x, PTE_W: %x, PTE_U: %x\n", 
		*pte&PTE_P, *pte&PTE_W, *pte&PTE_U);
}

/**
 * 输出所有物理页的映射
 * 
 * strtol 函数
 * long int strtol(const char *nptr,char **endptr,int base);
 * 作用是将字符串转为整数，可以通过 base 指定进制，会将第一个非法字符的指针写入 endptr 中。所以相比 atoi 函数，可以检查是否转换成功。
 * 
 * pgdir_walk 函数的返回情况有几种？
 * if ( !cur_pte || !(*cur_pte & PTE_P)) 非常容易遗漏第二个条件。注意到，pgdir_walk 这个函数返回值可能为NULL，也可能是一个pte_t *，而 pte_t * 分为两种情况，一种是该二级页表项内容还未插入，所以 PTE_P 这个位为0。另一种是已经插入。
 * 
 * 如何输出 permission
 * 这个就自由发挥了，一共有9个flag，我只选了 lab2 需要用到的3个。
 */ 
int
mon_showmappings(int argc, char **argv, struct Trapframe *tf)
{
	// 参数检查
	if (argc != 3) {
		cprintf("Require 2 virtual address as arguments.\n");
		return -1;
	}
	char *errChar;
	uintptr_t start_addr = strtol(argv[1], &errChar, 16);
	if (*errChar) {
		cprintf("Invalid virtual address: %s.\n", argv[1]);
		return -1;
	}
	uintptr_t end_addr = strtol(argv[2], &errChar, 16);
	if (*errChar) {
		cprintf("Invalid virtual address: %s.\n", argv[2]);
		return -1;
	}
	if (start_addr > end_addr) {
		cprintf("Address 1 must be lower than address 2\n");
		return -1;
	}

	// 按页对齐
	start_addr = ROUNDDOWN(start_addr, PGSIZE);
	end_addr = ROUNDUP(end_addr, PGSIZE);

	// 开始循环
	uintptr_t cur_addr = start_addr;
	while (cur_addr <= end_addr) {
		pte_t *cur_pte = pgdir_walk(kern_pgdir, (void *) cur_addr, 0);
		if ( !cur_pte || !(*cur_pte & PTE_P)) {
			cprintf( "Virtual address [%08x] - not mapped\n", cur_addr);
		} 
		else {
			cprintf( "Virtual address [%08x] - physical address [%08x], permission: ", cur_addr, PTE_ADDR(*cur_pte));
			char perm_PS = (*cur_pte & PTE_PS) ? 'S':'-';
			char perm_W = (*cur_pte & PTE_W) ? 'W':'-';
			char perm_U = (*cur_pte & PTE_U) ? 'U':'-';
			// 进入 else 分支说明 PTE_P 肯定为真了
			cprintf( "-%c----%c%cP\n", perm_PS, perm_U, perm_W);
		}
		cur_addr += PGSIZE;
	}
	return 0;
}

/**
 * 可以在指定的物理页上设置或清除一个flags标志位 (P|W|U)
 */ 
int mon_setperm(int argc, char **argv, struct Trapframe *tf) {
	if (argc == 1) {
		cprintf("Usage: setperm 0xaddr [0|1: clear or set] [P|W|U]\n");
		return 0;
	}
	uint32_t addr = str2add(argv[1]);
	pte_t *pte = pgdir_walk(kern_pgdir, (void *)addr, 1);
	cprintf("%x before setperm: ", addr);
	pprint(pte);
	uint32_t perm = 0;
	if (argv[3][0] == 'P') perm = PTE_P;
	if (argv[3][0] == 'W') perm = PTE_W;
	if (argv[3][0] == 'U') perm = PTE_U;
	if (argv[2][0] == '0') 	//clear
		*pte = *pte & ~perm;
	else 	//set
		*pte = *pte | perm;
	cprintf("%x after  setperm: ", addr);
	pprint(pte);
	return 0;
}

/**
 * 输出虚拟地址对应的物理内存地址
 */ 
int mon_showmem(int argc, char **argv, struct Trapframe *tf) {
	if (argc == 1) {
		cprintf("Usage: showmem 0xaddr 0xn\n");
		return 0;
	}
	void** addr = (void**) str2add(argv[1]);
	uint32_t n = str2add(argv[2]);
	int i;
	for (i = 0; i < n; ++i)
		cprintf("VM at %x is %x\n", addr+i, addr[i]);
	return 0;
}

/**
 * JOS为了能够单步调试，需要EFLAGS的TF(Trap Flag)跟踪标志，置1则开启单步执行调试模式，置0则关闭
 * 在单步执行模式下，处理器在每条指令后产生一个调试异常，这样在每条指令执行后都可以查看执行程序的状态
 * 当然，为了达到观察每次调试结果，我们也同样需要将调试异常嵌入内核监控
 * 
 * mon_continue对应的指令是continue
 * 由于用户程序由lib/entry.S开始执行，然后调用lib/libmain.c中的libmain函数，
 * 可以看到最后libmain函数会调用exit，因此如果输入continue将会返回用户程序，最终触发一次系统调用并结束用户程序
 */ 
int mon_continue(int argc, char **argv, struct Trapframe *tf) {
	uint32_t eflags;
	if (!tf) {
		cprintf("No trapped environment\n");
		return 0;
	}
	eflags = tf->tf_eflags;
	eflags &= ~FL_TF;
	tf->tf_eflags = eflags;
	return -1;
}

/**
 * mon_step对应的指令是step
 * 那么每次执行step的话，就相当于执行一次单步调试，这是因为：
 * 当我们执行'int 3'时，eip记录了'int 3'指令的下一条用户指令的位置，然后断点异常嵌入内核监控，此时如果输入step，
 * 内核会执行对应的mon_step函数，设置TF标志，然后返回-1；由于返回-1，内核会跳出监控程序返回用户程序，执行eip所指向的用户指令，
 * 记录下一条指令位置，然后发生调试异常陷入内核监控，重复上述步骤即相当于每次执行一次单步调试
 * 我们可以借助eip值和用户程序的asm文件查看每次执行的用户指令
 */ 
int mon_step(int argc, char **argv, struct Trapframe *tf) {
	uint32_t eflags;
	if (!tf) {
		cprintf("No trapped environment\n");
		return 0;
	}
	eflags = tf->tf_eflags;
	eflags |= FL_TF;
	tf->tf_eflags = eflags;
	return -1;
}
