/* See COPYRIGHT for copyright information. */
// 系统调用实现代码
#include <inc/x86.h>
#include <inc/error.h>
#include <inc/string.h>
#include <inc/assert.h>

#include <kern/env.h>
#include <kern/pmap.h>
#include <kern/trap.h>
#include <kern/syscall.h>
#include <kern/console.h>

/**
 * 将字符串s打印到系统控制台，字符串长度正好是len个字符
 * 无权限访问内存就销毁环境
 */ 
static void
sys_cputs(const char *s, size_t len)
{
	// 调用user_mem_assert检查用户是否有权限读取内存[s, s+len]，如果没有就销毁环境
	user_mem_assert(curenv, s, len, 0);

	// 打印用户提供的字符串.
	cprintf("%.*s", len, s);
}

/**
 * 在不阻塞的情况下从系统控制台读取字符
 * 返回字符，如果没有输入等待，则返回0
 */
static int
sys_cgetc(void)
{
	return cons_getc();
}

// 返回当前环境的envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
}

/**
 * 销毁envid对应的环境(可能是当前运行的环境)
 * 
 * 成功返回0，错误返回< 0；错误:-E_BAD_ENV(环境envid当前不存在，或者调用者没有修改envid的权限)
 */ 
static int
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
		return r;
	if (e == curenv)
		cprintf("[%08x] exiting gracefully\n", curenv->env_id);
	else
		cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id);
	env_destroy(e);
	return 0;
}

/**
 * syscall函数: 根据 syscallno 分派到对应的内核调用处理函数，并传递参数.
 * 参数:
 * syscallno: 系统调用序号(inc/syscall.h)，告诉内核要使用那个处理函数，进入寄存器eax
 * a1~a5: 传递给内核处理函数的参数，进入剩下的寄存器edx, ecx, ebx, edi, esi
 * 这些寄存器都在中断产生时被压栈了，可以通过Trapframe访问到
 */ 
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
	// 调用对应于'syscallno'参数的函数.
	int32_t result = 0;

	switch (syscallno) {

		case SYS_cputs:
			sys_cputs((const char*)a1, a2);
			break;

		case SYS_cgetc:
			result = sys_cgetc();
			break;

		case SYS_getenvid:
			result = sys_getenvid();
			break;

		case SYS_env_destroy:
			result = sys_env_destroy((envid_t)a1);
			break;

		default:
			result = -E_INVAL;
	}
	return result;
}

