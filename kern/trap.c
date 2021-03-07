// 陷阱处理代码
#include <inc/mmu.h>
#include <inc/x86.h>
#include <inc/assert.h>

#include <kern/pmap.h>
#include <kern/trap.h>
#include <kern/console.h>
#include <kern/monitor.h>
#include <kern/env.h>
#include <kern/syscall.h>

static struct Taskstate ts;

/**
 * 为了调试，print_trapframe可以区分打印已保存的trapframe和打印当前trapframe
 * 并在当前trapframe中打印一些附加信息
 */
static struct Trapframe *last_tf;

/**
 * Interrupt descriptor table.
 * 中断描述符表必须在运行时构建(不能在boot阶段)，因为移位的函数地址不能在重定位记录中表示
 */
struct Gatedesc idt[256] = { { 0 } };
struct Pseudodesc idt_pd = {
	sizeof(idt) - 1, (uint32_t) idt
};


static const char *trapname(int trapno)
{
	static const char * const excnames[] = {
		"Divide error",			// 0.除法错误
		"Debug",				// 1.调试异常
		"Non-Maskable Interrupt",// 0.不可屏蔽中断
		"Breakpoint",			// 3.断点(一个字节的INT3指令)
		"Overflow",				// 4.溢出(INTO指令)
		"BOUND Range Exceeded",	// 5.边界检验(BOUND指令)
		"Invalid Opcode",		// 6.非法操作符
		"Device Not Available",	// 7.设备不可用
		"Double Fault",			// 8.双重错误
		"Coprocessor Segment Overrun",	// 9.协处理器段溢出
		"Invalid TSS",			// 10.无效的TSS
		"Segment Not Present",	// 11.段不存在
		"Stack Fault",			// 10.栈异常
		"General Protection",	// 13.通用保护
		"Page Fault",			// 14.页错误
		"(unknown trap)",		// 15.保留
		"x87 FPU Floating-Point Error",	// 16.x87FPU 浮点错误
		"Alignment Check",		// 17.界限检查
		"Machine-Check",		// 18.机器检查
		"SIMD Floating-Point Exception"	// 19.SIMD 浮点错误
		// [20,31]: 保留，[32,255]: 用户可定义的中断
	};

	if (trapno < ARRAY_SIZE(excnames))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";	// 48.系统调用
	return "(unknown trap)";
}

/**
 * 设置x86的所有中断向量(中断向量、终端类型、中断处理函数、DPL)，并加载 TSS和IDT
 */ 
void
trap_init(void)
{
	// 为了调用trap_init_percpu时设置gdt对TSS的索引
	extern struct Segdesc gdt[];

	/**
	 * 将刚刚写好的一系列入口，以函数指针的形式，写进中断描述符表
	 * 
	 * SETGATE(gate, istrap, sel, off, dpl)
	 * gate: 设置idt[T_...]，sel: 段选择子为内核代码段，off: 段内偏移为th1
	 * istrap: 0->interrupt,1->trap/exc. 区别：interrupt 返回之前阻止新的中断产生
	 * 
	 * 中断(istrap=0, dpl=3)的意义在于，允许这些中断通过int/into/...指令触发
	 * 		根据x86手册7.4，对于部分通过int指令触发的中断，只有在大于指定的权限状态下触发中断，才能进入中断入口函数
	 * 		如在用户态下触发权限为0的T_DEBUG中断，就不能进入入口，反而会触发GPFLT中断。
	*/
	SETGATE(idt[T_DIVIDE],	0, GD_KT, t_divide,	0);
	SETGATE(idt[T_DEBUG],	0, GD_KT, t_debug,	0);
	SETGATE(idt[T_NMI],		0, GD_KT, t_nmi,	0);

	// 为了让用户也可以使用断点(breakpoint)int 3，所以 dpl 设置为 3
	SETGATE(idt[T_BRKPT],	1, GD_KT, t_brkpt,	3);
	SETGATE(idt[T_OFLOW],	0, GD_KT, t_oflow,	0);
	SETGATE(idt[T_BOUND],	0, GD_KT, t_bound,	0);

	SETGATE(idt[T_ILLOP],	0, GD_KT, t_illop,	0);
	SETGATE(idt[T_DEVICE],	0, GD_KT, t_device,	0);
	SETGATE(idt[T_DBLFLT],	0, GD_KT, t_dblflt,	0);
	SETGATE(idt[T_TSS],		0, GD_KT, t_tss,	0);
	SETGATE(idt[T_SEGNP],	0, GD_KT, t_segnp,	0);
	SETGATE(idt[T_STACK],	0, GD_KT, t_stack,	0);

	// GPFLT 一般性保护为兜底中断，要是产生的错误没有对应其它中断，就会触发这个中断
	// 中断尝试从用户态进入一个只能由内核态进入的入口，就会触发这个中断，作为一种保护机制
	SETGATE(idt[T_GPFLT],	0, GD_KT, t_gpflt,	0);

	// 如果内核允许用户主动触发缺页异常，将会导致严重的不一致性(内核难以辨识用户态触发的缺页异常到底因何发生)
	SETGATE(idt[T_PGFLT],	0, GD_KT, t_pgflt,	0);

	SETGATE(idt[T_FPERR],	0, GD_KT, t_fperr,	0);
	SETGATE(idt[T_ALIGN],	0, GD_KT, t_align,	0);
	SETGATE(idt[T_MCHK],	0, GD_KT, t_mchk,	0);
	SETGATE(idt[T_SIMDERR],	0, GD_KT, t_simderr,0);

	// 为了让用户也可以进行系统调用，将DPL设置为3，参考《x86汇编语言-从实模式到保护模式》p345
	SETGATE(idt[T_SYSCALL],	1, GD_KT, t_syscall,3);

	// 为中断初始化，加载 TSS 和 IDT
	trap_init_percpu();
}

// 初始化并加载每个CPU的 TSS 和 IDT
void
trap_init_percpu(void)
{
	// 为了能在陷入内核态加载正确的栈，必须初始化并加载TSS.
	ts.ts_esp0 = KSTACKTOP;
	ts.ts_ss0 = GD_KD;
	// 设置IO操作的权限，不关心这里的细节
	ts.ts_iomb = sizeof(struct Taskstate);

	// 设置gdt对TSS的索引.
	// 宏GD_TSS0定义了TSS，要获得对gdt的索引，需要右移3位，如下
	gdt[GD_TSS0 >> 3] = SEG16(STS_T32A, (uint32_t) (&ts),
					sizeof(struct Taskstate) - 1, 0);
	gdt[GD_TSS0 >> 3].sd_s = 0;

	// 最后加载 TSS 选择子 (像其他段选择子一样，低三位是特殊的，将其设置为0)
	ltr(GD_TSS0);

	// 加载 IDT
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
	cprintf("TRAP frame at %p\n", tf);
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
		cprintf("  cr2  0x%08x\n", rcr2());
	cprintf("  err  0x%08x", tf->tf_err);
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
	cprintf("  eip  0x%08x\n", tf->tf_eip);
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
	if ((tf->tf_cs & 3) != 0) {
		cprintf("  esp  0x%08x\n", tf->tf_esp);
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
	}
}

void
print_regs(struct PushRegs *regs)
{
	cprintf("  edi  0x%08x\n", regs->reg_edi);
	cprintf("  esi  0x%08x\n", regs->reg_esi);
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
	cprintf("  edx  0x%08x\n", regs->reg_edx);
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
	cprintf("  eax  0x%08x\n", regs->reg_eax);
}

static void
trap_dispatch(struct Trapframe *tf)
{
	// 处理环境产生的异常(分发异常到对应的处理函数).
	switch (tf->tf_trapno)
	{
		case T_PGFLT:
			// 处理页错误，内核 -> panic，用户环境 -> env_destroy
			page_fault_handler(tf);
			break;

		case T_BRKPT:
			// 切换到内核的监控器
			monitor(tf);
			break;

		case T_SYSCALL:
			// 传递参数时，eax存储了系统调用序号，另外5个寄存器存储参数
			// 用eax寄存器接收系统调用的返回值
			tf->tf_regs.reg_eax = syscall(tf->tf_regs.reg_eax,
											tf->tf_regs.reg_edx, 
											tf->tf_regs.reg_ecx,
											tf->tf_regs.reg_ebx,
											tf->tf_regs.reg_edi,
											tf->tf_regs.reg_esi);
			break;

		default:
			// 未处理的trap: 用户环境或内核存在bug, 输出. 
			print_trapframe(tf);
			// Trapframe存储的cs寄存器若指向内核代码段，内核bug -> panic
			if (tf->tf_cs == GD_KT) {
				panic("unhandled trap in kernel!\n");
			}
			// 用户环境bug -> env_destroy
			else {
				env_destroy(curenv);
				return;
			}
	}
}

/**
 * 由kern/trapentry.S调用，并且最后pushl %esp(Trapframe基址)相当于传递了指向Trapframe的指针tf
 * esp指向栈最后一个push进入的参数，最后的指令为pushal，因此esp: tf->tf_regs.reg_edi
 * 
 * 可以看到，若中断是在用户态下触发，就要对tf指针指向的结构体，也就是刚刚压栈的那个结构体，进行拷贝，从而控制用户态下的不安全因素。
 * 拷贝完结构体之后，调用函数trap_dispatch，将中断分发到指定的handler处理。
 */
void
trap(struct Trapframe *tf)
{
	// 环境可能已经设置了逆序的DF(direction flag, 方向标志位)，并且GCC的一些版本依赖于明确的DF
	// 需要设置为正序
	asm volatile("cld" ::: "cc");

	// 确保中断被禁用. 
	// 如果这个断言失败，不要试图通过在中断路径中插入一个cli(禁用中断)指令来修复它. 
	assert(!(read_eflags() & FL_IF));
	cprintf("Incoming TRAP frame at %p\n", tf);

	if ((tf->tf_cs & 3) == 3) {
		// 确保从用户态陷入.
		assert(curenv);

		// 复制Trapframe(目前位于栈上)到 curenv->env_tf，
		// 这样运行环境将在trap point重新启动(即返回中断点下一个指令继续)
		curenv->env_tf = *tf;
		// Trapframe已经被暂存到结构curenv，从这里开始，可以忽略栈上的Trapframe
		tf = &curenv->env_tf;
	}

	// 记录tf是最后一个真正的Trapframe
	// 这样trap_dispatch()函数中的print_trapframe就可以打印一些额外的信息.
	last_tf = tf;

	// 根据发生的trap类型，调用对应的系统调用处理函数
	trap_dispatch(tf);

	// 返回到当前环境，状态应该调度为正在运行
	assert(curenv && curenv->env_status == ENV_RUNNING);
	// 恢复原环境
	env_run(curenv);
}

/**
 * 处理页错误
 * 1.读取处理器的CR2寄存器找到触发错误的虚拟地址
 * - 内核态的页错误 -> panic
 * - 用户态环境的页错误 -> env_destroy
 */ 
void
page_fault_handler(struct Trapframe *tf)
{
	uint32_t fault_va;

	// 1.通过读取处理器的CR2寄存器找到触发错误的虚拟地址
	fault_va = rcr2();

	// 处理内核态的页错误.
	if ((tf->tf_cs & 3) == 0) {
		panic("page_fault_handler: occurs in kernel mode!\n");
	}

	// 我们已经处理了内核态异常，所以如果我们到达这里，说明页错误发生在用户态. 

	// 直接销毁导致错误的用户环境. 
	cprintf("[%08x] user fault va %08x ip %08x\n",
		curenv->env_id, fault_va, tf->tf_eip);
	print_trapframe(tf);
	env_destroy(curenv);
}

