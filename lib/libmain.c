// 从 lib/entry.S 调用并继续，entry.S 已经定义了 envs, pages, uvpd, uvpt
// 调用用户态的库设置代码entry.S
#include <inc/lib.h>

extern void umain(int argc, char **argv);

const volatile struct Env *thisenv;
const char *binaryname = "<unknown>";

void
libmain(int argc, char **argv)
{
	// 用户进程从lib/libmain.c中的函数libmain开始执行，这个函数进而调用umain，用户写的程序入口只能是umain
	// 设置常量thisenv指向envs[]中当前环境的Env结构
	envid_t envid = sys_getenvid();
	// 确保envid在NENV限制内后，thisenv指向当前环境的Env结构
	thisenv = envs + ENVX(envid);

	// 为了能让panic()提示用户错误，存储程序的名称
	if (argc > 0)
		binaryname = argv[0];

	// 调用用户的主程序
	umain(argc, argv);

	// 退出当前环境，env_destroy
	exit();
}

