# 汇编语言陷阱处理程序入口点

#include <inc/mmu.h>
#include <inc/memlayout.h>
#include <inc/trap.h>



###################################################################
# exceptions/interrupts
# 不同的 exceptions/interrupts 的处理方式和结构都不一样，可否恢复、从哪里恢复、执行的权限等级、是否有error code等
# 因此，需要为每个exceptions/interrupts设置单独的处理函数
###################################################################

/* 
 * 提供了两个宏TRAPHANDLER*，对所有interrupt进行了统一处理。
 * 接受两个宏参数，name:要生成的中断入口名字, num:中断向量. 中断向量在文件inc/trap.h中有一系列宏声明
 * 这两个宏的功能是将函数的符号声明为全局global，也就可以在文件trap.c中的C代码获得函数指针。通过这些函数指针就可以初始化IDT.
 *  1.创建一个函数symbol，名字由宏参数name得到
 *  2.将这个symbol设置为全局，即定义全局函数'name'
 *  3.这个函数将中断向量压栈，并跳转到_alltraps
 *
 * 在中断触发、进入中断处理程序前发生：
 * 从tss找到内核栈的地址，临时保存旧栈的ss, esp，修改当前ss, esp指向内核栈
 * 向内核栈压入旧ss, 旧esp, eflag, cs, eip，若中断有errcd，自动压入
 * cs, eip指向中断处理程序入口，准备执行中断处理程序
 */
#define TRAPHANDLER(name, num)						\
	.globl name;		/* 定义全局符号'name' */	\
	.type name, @function;	/* 符号类型是函数 */		\
	.align 2;		/* 对齐函数定义的字节 */		\
	name:			/* 函数的实现从这里开始 */		\
	pushl $(num);							\
	jmp _alltraps

/* 
 * 有的中断会将一个额外的error code压栈，在进入中断描述符表指定的入口函数之前，就和其他数据一起压栈了。
 * 有的中断不会进行这个操作。为了统一处理这两种中断，使得它们的栈具有相同形式，
 * 对于不进行压error code操作的中断，我们在原本error code的位置压一个0填充，正如宏TRAPHANDLER_NOEC中的那样
 * 对于CPU无需push error code的trap，可以使用TRAPHANDLER_NOEC
 * 该函数 push 一个0来顶替error code的位置，从而让trap帧在两种情况下的格式相同
 */
#define TRAPHANDLER_NOEC(name, num)					\
	.globl name;							\
	.type name, @function;						\
	.align 2;							\
	name:								\
	pushl $0;							\
	pushl $(num);							\
	jmp _alltraps

/*
 * 为不同的trap生成入口点.
 * 中断向量8:0, [10, 14]有error code
 * 我们使用这两个宏创建所有中断的入口，故所有中断都要跳转到_alltraps，同时每个中断入口的创建形式都相同，也就具有了实际上的中断统一入口
 */
.text
	TRAPHANDLER_NOEC(t_divide, T_DIVIDE)# 0.除法错误
	TRAPHANDLER_NOEC(t_debug, T_DEBUG)	# 1.调试异常
	TRAPHANDLER_NOEC(t_nmi, T_NMI)		# 2.不可屏蔽中断
	TRAPHANDLER_NOEC(t_brkpt, T_BRKPT)	# 3.断点(一个字节的INT3指令)
	TRAPHANDLER_NOEC(t_oflow, T_OFLOW)	# 4.溢出(INTO指令)
	TRAPHANDLER_NOEC(t_bound, T_BOUND)	# 5.边界检验(BOUND指令)
	TRAPHANDLER_NOEC(t_illop, T_ILLOP)	# 6.非法操作符
	TRAPHANDLER_NOEC(t_device, T_DEVICE)# 7.设备不可用
	TRAPHANDLER(t_dblflt, T_DBLFLT)		# 8.双重错误
	/* RESERVED: 保留9号中断:协处理器段溢出 */
	TRAPHANDLER(t_tss, T_TSS)				# 10.无效的TSS
	TRAPHANDLER(t_segnp, T_SEGNP)			# 11.段不存在
	TRAPHANDLER(t_stack, T_STACK)			# 12.栈异常
	TRAPHANDLER(t_gpflt, T_GPFLT)			# 13.一般性保护
	TRAPHANDLER(t_pgflt, T_PGFLT)			# 14.页错误
	/* RESERVED: 保留15号中断 */
	TRAPHANDLER_NOEC(t_fperr, T_FPERR)	# 16.x87FPU 浮点错误
	TRAPHANDLER_NOEC(t_align, T_ALIGN)	# 17.界限检查
	TRAPHANDLER_NOEC(t_mchk, T_MCHK)	# 18.机器检查
	TRAPHANDLER_NOEC(t_simderr, T_SIMDERR)# 19.SIMD 浮点错误

	TRAPHANDLER_NOEC(t_syscall, T_SYSCALL)# 48.系统调用

/*
 * _alltraps是所有trap handler共用的代码(中断统一入口)
 *   1.按结构Trapframe的顺序，push寄存器的值到栈，对应汇编指令pushl和popl
 *   2.为了访问内核数据和栈，加载GD_KD(内核数据段选择子)到 ds寄存器 和 es寄存器
 *   3.pushl %esp 压栈当前栈指针，以作为 trap() 的一个参数
 *   4.调用trap
 *
 * 根据x86手册，中断产生时，处理器已经根据gdt中的TSS自动压栈部分寄存器
 * 特权转换(ss、esp、eflags、cs、eip)，无特权转换(eflags、cs、eip) —— 无需切换到内核栈
 * trapnum和errcode已经被前面的宏TRAPHANDLER...处理好了，最后跳转到此继续压栈
 *
 * 低地址                                                           高地址
 * +--------------------------------------------------------------------+
 * | regs | es | ds | trapno | errcode | eip | cs | eflags |( esp | ss )|
 * +--------------------------------------------------------------------+
 */
_alltraps:
	# 1.按结构Trapframe的倒序(先进后出)，push寄存器的值到栈，对应汇编指令pushal和popal
	pushl %ds
	pushl %es
	pushal

	# 2.加载 GD_KD 到 ds寄存器 和 es寄存器
	movw $GD_KD, %ax
	movw %ax, %ds
	movw %ax, %es

	# 3.为函数trap()传递一个指向Trapframe的指针
	pushl %esp

	# 4.调用函数trap
	call trap

	# 调用trap后应该调用对应的handler处理后，恢复原来的用户态环境 - 不可能返回此处(除非内核代码出现bug)
	# 但这里为了错误处理，恢复为原来的用户态环境(未处理trap)
trap_ret:
	addl $4, %esp
	popal
	popl %gs
	popl %fs
	popl %es
	popl %ds
	# trapno & errcode
	addl $0x8, %esp
	iret