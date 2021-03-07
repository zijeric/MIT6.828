// System call stubs.

#include <inc/syscall.h>
#include <inc/lib.h>

/**
 * 用户的指令式系统调用，该函数将系统调用序号放入eax寄存器，五个参数依次放入edx, ecx, ebx, edi, esi，然后执行指令int 0x30，
 * 发生中断后，去IDT中查找中断处理函数，最终会走到kern/trap.c的trap_dispatch()中
 */ 
static inline int32_t
syscall(int num, int check, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
	int32_t ret;

	/**
	 * 通过'int 0x30'指令进行系统调用，可传递最多5个参数，处理完成后将返回值存储在eax
	 * 发生中断后，去IDT中查找中断处理函数，最终会走到kern/trap.c的trap_dispatch()中
	 * 根据中断号0x30，又会调用kern/syscall.c中的syscall()函数（注意这时候我们已经进入了内核模式CPL=0）
	 * 在该函数中根据系统调用号调用对应的系统调用处理函数
	 * 
	 * C语言内联汇编
	 * asm volatile ("asm code" : output : input : changed);
	 * 通用系统调用: 在eax中传递系统调用序号，在edx, ecx, ebx, edi, esi中最多传递五个参数
	 * 用T_SYSCALL中断内核
	 * volatile 告诉汇编程序不要因为我们不使用返回值就优化该指令
	 * 最后一个子句告诉汇编程序，指令可能会改变条件代码cx和任意内存memory位置
	 * 由汇编编译器做好数据保存和恢复工作(栈)
	 */ 
	asm volatile("int %1\n"		// code: int T_SYSCALL
		     : "=a" (ret)		// ret = eax
		     : "i" (T_SYSCALL),	// T_SYSCALL作为整数型立即数
		       "a" (num),		// eax = num 系统调用序号
		       "d" (a1),		// edx = a1
		       "c" (a2),		// ecx = a2
		       "b" (a3),		// ebx = a3
		       "D" (a4),		// edi = a4
		       "S" (a5)			// esi = a5
		     : "cc", "memory");	// 指令可能会改变条件代码cx和任意内存memory位置
			//  由汇编编译器做好数据保存和恢复工作(栈)

	if(check && ret > 0)
		panic("syscall %d returned %d (> 0)", num, ret);

	return ret;
}

void
sys_cputs(const char *s, size_t len)
{
	// 调用lib/syscall.c中的syscall()
	// SYS_cputs: 系统调用序号(eax)，s: 需要输出的字符数组，len: 数组长度
	syscall(SYS_cputs, 0, (uint32_t)s, len, 0, 0, 0);
}

int
sys_cgetc(void)
{
	return syscall(SYS_cgetc, 0, 0, 0, 0, 0, 0);
}

int
sys_env_destroy(envid_t envid)
{
	// 销毁envid对应的环境
	return syscall(SYS_env_destroy, 1, envid, 0, 0, 0, 0);
}

envid_t
sys_getenvid(void)
{
	// 获取当前用户环境id
	return syscall(SYS_getenvid, 0, 0, 0, 0, 0, 0);
}

