/* See COPYRIGHT for copyright information. */
// 用户环境的公共定义
#ifndef JOS_INC_ENV_H
#define JOS_INC_ENV_H

#include <inc/types.h>
#include <inc/trap.h>
#include <inc/memlayout.h>

typedef int32_t envid_t;

/**
 * 一个环境ID: envid_t 有三个部分:
 * 
 * +1+---------------21-----------------+--------10--------+
 * |0|          Uniqueifier             |   Environment    |
 * | |                                  |      Index       |
 * +------------------------------------+------------------+
 *                                       \--- ENVX(eid) --/
 * 环境索引 ENVX(eid) 等于 envs[] 数组中的环境索引。Uniqueifier 用于区分在不同时间创建的环境，但是共享相同的环境索引。
 * 
 * 所有实际环境都大于0(因此符号位为零)。envid_t 小于0表示错误。
 * envid_t==0 的时候是特殊的，代表当前的环境。
 */ 
// TODO...
#define ENV_PASTE3(x, y, z) x ## y ## z

#define ENV_CREATE(x, type)						\
	do {								\
		extern uint8_t ENV_PASTE3(_binary_obj_, x, _start)[];	\
		env_create(ENV_PASTE3(_binary_obj_, x, _start),		\
			   type);					\
	} while (0)

// NENV(1024): 以2为底的指数次数
#define LOG2NENV		10
// 1<<10 = 2^10 = 1024，系统运行环境最多容纳 1024 个环境，即环境并发容量
#define NENV			(1 << LOG2NENV)
// 仅保留低 10 位(9~0)
#define ENVX(envid)		((envid) & (NENV - 1))

// Values of env_status in struct Env
enum {
	// Env 处于空闲状态，存在于 env_free_list 链表
	ENV_FREE = 0,

	// Env 是僵尸环境，将在下一次陷入内核时被释放
	ENV_DYING,

	// Env 处于等待运行于 CPU
	ENV_RUNNABLE,

	// Env 是当前正在运行的环境
	ENV_RUNNING,

	// Env 是当前正在运行的环境，但却没有准备好运行，如正在等待另一个环境的IPC（进程间通信）
	ENV_NOT_RUNNABLE
};

// Special environment types
enum EnvType {
	ENV_TYPE_USER = 0,
};

/**
 * Env 结构体记录环境状态信息
 * Env 综合了Unix的线程和地址空间，线程由 env_tf 的环境帧定义，地址空间由 env_pgdir 指向的页目录和页表定义
 * 为了运行一个环境，内核必须用存储的环境帧，以及合适的地址空间设置 CPU
 * 
 * struct Env和xv6的struct proc很像，两种结构体都持有环境的用户模式寄存器状态（通过struct TrapFrame），
 * 然而，JOS中，独立的环境并不具有不同的内核栈，因为JOS内核中同时只能有一个正在运行的JOS环境，因此JOS只需要一个内核栈
 */ 
struct Env {
	// Trapframe结构定义在inc/trap.h中，环境帧(环境所有寄存器的值)的一个快照，
	// 当环境挂起时用于暂存环境帧，当前环境恢复运行时，该结构中存储的环境帧将被重新载入
	// eg. 环境中断(系统调用)切换到内核环境运行了，或者环境调度切换到另一个环境运行的时候，需要存储当前环境帧，以便后续该环境继续执行
	struct Trapframe env_tf;

	// 索引下一个空闲的 Env 结构，指向空闲环境链表 env_free_list 中的下一个 Env 结构
	struct Env *env_link;

	/**
	 * +1+---------------21-----------------+--------10--------+
	 * |0|          Uniqueifier             |   Environment    |
	 * | |                                  |      Index       |
	 * +------------------------------------+------------------+
	 *                                       \--- ENVX(eid) --/
	 * 当前环境 Env 的 ID. 因为环境ID是正数，所以符号位是0，而中间的21位是标识符，
	 * 标识在不同时间创建但是却共享同一个环境索引号的环境，最后10位是环境的索引号，要用envs索引环境管理结构 Env 就要用 ENVX(env_id)
	 */ 
	envid_t env_id;

	// 创建 当前环境 的环境的env_id，通过该方式构建一个环境树，用于安全方面的决策
	envid_t env_parent_id;

	// 用于区分特殊环境，对于大部分环境，该值为ENV_TYPE_USER
	enum EnvType env_type;

	// 当前环境的状态
	unsigned env_status;
				// ENV_FREE - 表明struct Env环境处于空闲状态，位于env_free_list中
				// ENV_RUNNABLE - 表明struct Env代表的环境正在等待运行于 CPU 上
				// ENV_RUNNING - 表明struct Env代表的环境为正在运行的环境
				// ENV_NOT_RUNNABLE - 表明struct Env代表了一个正在运行的环境，但却没有准备好运行，如正在等待另一个环境的IPC（进程间通信）
				// ENV_DYING - 表明struct Env代表了一个僵尸环境，僵死环境将在下一次陷入内核时被释放（直到Lab4才会使用该Flag）

	// 环境运行的次数
	uint32_t env_runs;

	// 用于保存环境页目录的*虚拟地址*
	pde_t *env_pgdir;
};

#endif // !JOS_INC_ENV_H
