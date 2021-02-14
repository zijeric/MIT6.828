#ifndef JOS_KERN_KDEBUG_H
#define JOS_KERN_KDEBUG_H

#include <inc/types.h>

// 关于特定指令指针的调试信息
struct Eipdebuginfo {
	const char *eip_file;		// EIP 源代码文件名
	int eip_line;				// EIP 源代码行数

	const char *eip_fn_name;	// 包含EIP的函数名
					// 注意：不能以 NULL 为终止！
	int eip_fn_namelen;			// 函数名的长度
	uintptr_t eip_fn_addr;		// 函数起始地址
	int eip_fn_narg;			// 函数参数个数
};

int debuginfo_eip(uintptr_t eip, struct Eipdebuginfo *info);

#endif
