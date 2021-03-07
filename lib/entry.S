// 用户环境的入口点
#include <inc/mmu.h>
#include <inc/memlayout.h>

.data
// 定义全局符号'envs', 'pages', 'uvpt', 'uvpd'
// 这样它们就可以像普通全局数组一样在C中使用
	// envs = UENVS, 在kern/pmap.c的mem_init将虚拟地址空间UENVS已经映射到envs的物理地址空间
	.globl envs
	.set envs, UENVS
	// pages = UPAGES
	.globl pages
	.set pages, UPAGES
	.globl uvpt
	.set uvpt, UVPT
	.globl uvpd
	.set uvpd, (UVPT+(UVPT>>12)*4)


// Entrypoint——最初加载一个新环境时，这是内核(或父环境)启动新环境地方
.text
.globl _start
_start:
	// 看看是否从栈上的参数开始
	cmpl $USTACKTOP, %esp
	// $USTACKTOP!=%esp 说明有参数，跳转到args_exist
	jne args_exist

	// 如果不是，则 push 伪造的 argc, argv 参数
	// 这发生在我们被内核加载时，因为内核不知道传递参数
	pushl $0
	pushl $0

args_exist:
	call libmain
1:	jmp 1b

