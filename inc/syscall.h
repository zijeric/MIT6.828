// 从用户环境到内核的系统调用的公共定义
#ifndef JOS_INC_SYSCALL_H
#define JOS_INC_SYSCALL_H

/* 系统调用序号 */
enum {
	// 输出
	SYS_cputs = 0,
	// 输入
	SYS_cgetc,
	// 获取用户环境id
	SYS_getenvid,
	// 销毁用户环境
	SYS_env_destroy,
	// 未定义
	NSYSCALLS
};

#endif /* !JOS_INC_SYSCALL_H */
