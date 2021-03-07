// 实现用户态环境的内核代码
/**
 * 环境映像：
 * 在JOS，每个环境都有代码段、数据段、用户栈、环境属性，由于当前系统还没有文件系统，系统将用户环境编译链接成原始的 ELF 二进制映像内嵌到内核中，
 * 所以系统加载一个用户环境对应的代码和数据时读取的对象是 ELF 格式文件。编译命令位于kern/Makefrag
 * 
 * 环境实现：
 * 在JOS，每个环境都有4GB的虚拟地址空间，其中的讷河部分是相同的。通过以上我们对JOS的了解，系统仅仅为环境分配了内存空间，
 * 并没有实际的运行用户环境，我们需要完成JOS系统中环境操作的函数
 */ 
#include <inc/x86.h>
#include <inc/mmu.h>
#include <inc/error.h>
#include <inc/string.h>
#include <inc/assert.h>
#include <inc/elf.h>

#include <kern/env.h>
#include <kern/pmap.h>
#include <kern/trap.h>
#include <kern/monitor.h>

// envs 指向所有环境链表的指针，其操作方式跟内存管理的 pages 类似
struct Env *envs = NULL;
// curenv 当前正在运行的环境 Env 结构指针
struct Env *curenv = NULL;
// env_free_list 是空闲的环境结构链表(静态的)，相当于page_free_list
// 简化环境的分配和释放，仅需要从该链表上添加或移除
static struct Env *env_free_list;

#define ENVGENSHIFT	12		// >= LOGNENV，支持最多“同时”执行NENV个活跃用户环境

/**
 * 全局描述符表
 * 为内核态和用户态设置全局描述符表(GDT)实现分段，分段在x86上有很多用途
 * 虽然不使用分段的任何内存映射功能，但是需要它们来切换权限级别
 * 
 * 除了描述符权限级别(DPL, Descriptor Privilege Level)之外，内核段和用户段都是相同的
 * 但是要加载SS栈段寄存器，当前环境权限级别(CPL, Current Privilege Level)必须等于 DPL
 * 因此，我们必须为用户和内核复制代码段和数据段（权限不同），各自单独使用对应的段
 * 从而使只有内核才能访问内核栈，尽管段的基址base和段限制Limit相同
 * 
 * 特别地，在gdt[]定义中使用的SEG宏的最后一个参数指定了 DPL: 0表示内核，3表示用户
 */ 
struct Segdesc gdt[] =
{
	// 0x0 - 未使用的(指向此处将总是导致错误 —— 用于捕获NULL指针)
	SEG_NULL,

	// 0x8  - 内核代码段，(GD_...>>3)转换成索引1,2,3...
	[GD_KT >> 3] = SEG(STA_X | STA_R, 0x0, 0xffffffff, 0),

	// 0x10 - 内核数据段
	[GD_KD >> 3] = SEG(STA_W, 0x0, 0xffffffff, 0),

	// 0x18 - 用户代码段
	[GD_UT >> 3] = SEG(STA_X | STA_R, 0x0, 0xffffffff, 3),

	// 0x20 - 用户数据段
	[GD_UD >> 3] = SEG(STA_W, 0x0, 0xffffffff, 3),

	// 0x28 - tss, 在 trap_init_percpu() 中进行初始化任务状态段TSS
	[GD_TSS0 >> 3] = SEG_NULL
};

struct Pseudodesc gdt_pd = {
	sizeof(gdt) - 1, (unsigned long) gdt
};

//
// Converts an envid to an env pointer.
// If checkperm is set, the specified environment must be either the
// current environment or an immediate child of the current environment.
//
// RETURNS
//   0 on success, -E_BAD_ENV on error.
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
		*env_store = curenv;
		return 0;
	}

	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
	if (e->env_status == ENV_FREE || e->env_id != envid) {
		*env_store = 0;
		return -E_BAD_ENV;
	}

	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
		*env_store = 0;
		return -E_BAD_ENV;
	}

	*env_store = e;
	return 0;
}

/**
 * 函数功能：初始化NENV个Env结构体(envs数组)，将它们加入到空闲环境链表(构建env_free_list)，
 * 注意，函数将结构体插入空闲环境链表时，以反序的方式插入(高->低)，envs[0]在链表头部位置
 */ 
void
env_init(void)
{
	// 初始化envs数组
	// 将 envs 中的所有环境标记为ENV_FREE，env_ids 设置为0
	// 前插法构建 env_free_list，让每个 env 在空闲列表中保持升序
	for (int32_t i = NENV - 1; i >= 0; i--) {

		// env 处于空闲环境链表，必须设置对应的状态及id
		// envs[i].env_id = 0;
		envs[i].env_status = ENV_FREE;

		// 插入链表
		envs[i].env_link = env_free_list;
		env_free_list = &envs[i];
	}
	
	// 为了区分用户态环境和内核态的访问权限：加载全局描述符表(GDT)，配置分段硬件
	// 为权限级别0(内核)和权限级别3(用户)使用单独的段
	env_init_percpu();
}

// 加载全局描述符 GDT，并且初始化段寄存器gs, fs(留给用户数据段使用), es, ds, ss(在用户态和内核态切换使用)
void
env_init_percpu(void)
{
	// 1.加载新的gdt
	lgdt(&gdt_pd);
	// 2.初始化数据段寄存器GS、FS（留给用户数据段使用）、ES、DS、SS（在用户态和内核态切换使用），DPL: 段描述符权限级别
	asm volatile("movw %%ax,%%gs" : : "a" (GD_UD | DPL_USER));
	asm volatile("movw %%ax,%%fs" : : "a" (GD_UD | DPL_USER));
	asm volatile("movw %%ax,%%es" : : "a" (GD_KD));
	asm volatile("movw %%ax,%%ds" : : "a" (GD_KD));
	asm volatile("movw %%ax,%%ss" : : "a" (GD_KD));
	// 3.初始化内核的代码段寄存器CS
	asm volatile("ljmp %0,$1f\n 1:\n" : : "i" (GD_KT));
	// 4.初始化LDT表为0，并未使用
	lldt(0);
}

/**
 * 参数：struct Env *e: ENV 结构指针
 * 返回值：0: 成功，-E_NO_MEM: 失败，没有足够物理地址分配页目录/页表页
 * 函数功能：为当前用户环境e分配页目录，并初始化用户环境虚拟地址的内核部分
 * 
 * 相应设置e->env_pgdir，初始化用户环境虚拟地址的内核部分
 * 目前不要将任何东西映射到用户环境虚拟地址的用户部分
 */ 
static int
env_setup_vm(struct Env *e)
{
	int i;
	struct PageInfo *pp = NULL;

	// 分配环境页目录
	if (!(pp = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;

	pp->pp_ref++;

	// 让e->env_pgdir指向新分配的环境页目录pgdir
	e->env_pgdir = (pde_t *) page2kva(pp);

	/**
	 * 由于每个用户环境都需要共享内核空间，所以对于用户环境而言，在UTOP以上的虚拟地址空间对于所有环境来说都是相同的，用户环境无法访问和使用这一部分虚拟地址空间
	 * 因此在初始化pgdir的时候，只需要在页目录上，把共享部分的页目录部分复制进用户环境的地址空间就可以了，
	 * 这样，就实现了页式映射的共享。
	 * 因为页目录里面存储的是页表页的物理地址，其直接映射到物理内存部分，
	 * 而共享的内核部分的页表页在前期的内核操作中，已经完成了映射，所以页表页是不需要初始化的
	 * 简单来说，不需要映射页表页的原因是，用户环境可以和内核共用这些页表页
	 * UTOP 以下部分清空: 注意 4GB 虚拟地址空间是由低到高每 4MB 按顺序映射到页目录项的，因此需要取出UTOP的PDX索引部分，将前PDX项清空
	 * 
	 * - 因为ULIM之上是内核部分，ULIM往下是用户环境，所以内核部分加上pages与envs的内容 = 虚拟地址 UTOP 以上
	 * - 初始化新环境虚拟地址的内核部分：把 UTOP 以上的内容从kern_pgdir中复制到env_pgdir中
	 * 注意，kern_pgdir 是用户可读的
	 */
	// memmove 从低地址到高地址复制，只能先调用 memmove 再调用 memset
	memmove(e->env_pgdir, kern_pgdir, PGSIZE);
	// 代码实现无需设置新环境页目录的[0, UTOP]为0(未映射)，因为在内核页目录中也未映射
	memset(e->env_pgdir, 0, UTOP >> PTSHIFT);

	// 安全设置：配置新环境页目录的 UVPT 映射 env 自己的页表为只读，无法被用户篡改
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;

	return 0;
}

/**
 * 分配并初始化一个新的用户环境
 * 成功后，新环境存储在 *newenv_store
 * 
 * 成功时返回0，失败时返回<0。错误包括:
 * -如果分配了所有NENV环境，则为E_NO_FREE_ENV
 * -E_NO_MEM: 内存不足
 */
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;

	// 为新的环境分配并设置页目录(映射BIOS与内核代码数据段)
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// 为新环境生成env_id
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
	if (generation <= 0)	// 生成的env_id必须为正数
		generation = 1 << ENVGENSHIFT;
	e->env_id = generation | (e - envs);

	// 设置基础的状态变量：父id、环境类型、环境状态(就绪态，等待CPU)、运行次数
	e->env_parent_id = parent_id;
	e->env_type = ENV_TYPE_USER;
	e->env_status = ENV_RUNNABLE;
	e->env_runs = 0;

	// 清除所有已保存的寄存器状态，防止当前环境的寄存器值泄漏到新环境中(所有环境所使用寄存器相同)
	memset(&e->env_tf, 0, sizeof(e->env_tf));

	// 为段寄存器设置适当的初始值
	// GD_UD是GDT中的用户数据段选择子，GD_UT是用户文本段选择子(参见inc/memlayout.h)
	// 每个段寄存器的低2位包含当前访问者权限级别(RPL); 0:内核，3:用户
	// 当我们切换特权级别时，硬件会进行各种检查，包括RPL和存储在段描述符本身中的描述符特权级别(DPL)
	// tf_esp: 初始化为USTACKTOP，表示当前用户栈为NULL
	// tf_cs: 初始化为用户段选择子，用户可访问
	// tf_eip: 这里eip的值就是我们在 load_icode()里设置的用户程序入口地址
	e->env_tf.tf_ds = GD_UD | DPL_USER;
	e->env_tf.tf_es = GD_UD | DPL_USER;
	e->env_tf.tf_ss = GD_UD | DPL_USER;
	e->env_tf.tf_esp = USTACKTOP;
	e->env_tf.tf_cs = GD_UT | DPL_USER;
	// You will set e->env_tf.tf_eip later.

	// commit the allocation
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}

/**
 * 为用户环境分配和映射物理内存，存储环境运行所需资源(调用page_insert)
 * 参数：
 * e:Env指针, va:虚拟地址, len:分配和映射的空间大小
 * 作用：在e指向的用户虚拟地址空间中分配[va, va+len)一段区域，为后续写入数据作准备
 * - 不需要对分配的空间初始化
 * - 分配的页用户和内核具有写权限
 * - 需要对起始地址va和长度len进行4K页面对齐
 * - 只在load_icode调用
 * 
 * 实现：
 * 把va和va+len ROUND处理好，然后把虚拟地址空间[va, va+len)，序号[va/PGSIZE, va+len/PGSIZE)分配给e->env_pgdir
 * 与env_setup_vm()配合使用，env_setup_vm() 先给e分配一个物理页的索引空间，
 * region_alloc()为这个索引开辟[va, va+len]的虚拟地址，并且建立映射、设置权限
 * 
 * 注意，类似pmap.c中的boot_map_region()，却不一样
 * boot_map_region()操作的是虚拟地址空间kern_pgdir，kern_pgdir提供的是静态映射(内核共享)，且不涉及物理页的分配
 * 而region_alloc() 则是要为实际的物理页帧分配映射到当前用户的虚拟地址空间中(页表页项)
 */ 
static void
region_alloc(struct Env *e, void *va, size_t len)
{
	// pp - 为新环境分配的PageInfo结构指针，调用 page_alloc 分配物理页
	struct PageInfo *pp;
	// 开始区间和结束区间页对齐
	void *start = ROUNDDOWN(va, PGSIZE), *end = ROUNDUP(va + len, PGSIZE);
	// 接收 page_insert 返回的结果，可能会内存不足，无法映射到页表页
	int16_t result;

	for (; start < end; start += PGSIZE) {
		// 分配一个物理页帧，如果这里没有ALLOC_ZERO清零，则最好在分配物理页并且将内容拷贝进来后，将剩余的空间置0
		pp = page_alloc(ALLOC_ZERO);
		if (!pp) {
			panic("region_alloc: out of memory when allocating a page!\n");
		}

		// 注意，根据env_pgdir页目录来控制在用户环境的虚拟地址空间分配
		// 修改e->env_pgdir，在页表页建立线性地址start到物理页pp的映射关系，插入页表页项
		result = page_insert(e->env_pgdir, pp, start, PTE_W | PTE_U);
		if (result < 0) {
			panic("region_alloc: %e", result);
		}
	}
}

/**
 * 函数功能：解析ELF二进制文件，加载其内容到新环境的用户地址空间中
 * - 每个用户环境都是一个ELF文件。像boot loader所做的那样，从ELF文件加载用户环境的初始代码区、栈和处理器标识位
 * - 这个函数仅在内核初始化期间、第一个用户态环境运行前被调用
 * - 函数将ELF文件中所有可加载的段载入到用户地址空间中，设置e->env_tf.tf_eip为ELF文件头指示的入口（虚拟地址），以便它之后能从这里开始执行程序
 * - 清零bss段
 * - 映射程序的初始栈到物理页帧
 * 
 * 因为JOS到现在为止还没有文件系统，所以为了测试我们能运行用户环境，现在的做法是将用户环境编译以后和内核链接到一起(即用户程序紧接着内核之后放置)
 * 所以这个函数的作用就是将嵌入在内核钟大哥用户环境取出释放到相应链接器指定的用户虚拟地址空间里。
 * 参数binary指针，就是用户环境在内核中的开始位置的虚拟地址
 * 可以参照boot/main.c来完成
 */ 
static void
load_icode(struct Env *e, uint8_t *binary)
{
	/**
	 * 注意:
	 * 1.对于用户程序ELF文件的每个程序头ph，ph→p_memsz和ph→p_filesz是两个概念，前者是该程序头应在内存中占用的空间大小，
	 * 而后者是实际该程序头占用的文件大小. 他们俩的区别就是ELF文件中BSS节中那些没有被初始化的静态变量，这些变量不会被分配文件储存空间，
	 * 但是在实际载入后，需要在内存中给与相应的空间，并且全部初始化为0。所以具体来讲，就是每个程序段ph，总共占用p_memsz的内存，
	 * 前面p_filesz的空间从binary的对应内存复制过来，后面剩下的空间全部清0
	 * 
	 * 2.ph→p_va是该程序段应该被放入的虚拟空间地址，但是注意，在这个时候，虚拟地址空间是用户环境Env的虚拟地址空间. 
	 * 可是，在进入load_icode() 时，是内核态进入的，所以虚拟地址空间还是内核的空间。我们要如何对用户的虚拟空间进行操作呢？
	 * 看到:lcr3 (e->env_cr3);
	 * 这个语句在我们进入每个程序头进行具体设置时，将页表切换到用户虚拟地址空间。
	 * 这样我们就可以方便的在后面使用memset和memmove等函数对一个虚拟地址进行相应的操作了。其中e->env_cr3的值是在前面的env_setup_vm() 设置好的。
	 * 但是仍要小心的是，对于ELF载入完毕以后，我们就不需要对用户空间进行操作了，所以记得在最后重新切回到内核虚拟地址空间来。
	 * 
	 * 3.注释中还提到了要对程序的入口地址作一定的设置，这里对应的操作:e->env_tf.tf_eip = ELFHDR->e_entry;
	 * 这里涉及到对struct Trapframe 结构的具体介绍
	 */ 

	// binary 指向第一个用户环境起始的虚拟地址(内核va之后首个)，因此用(Elf*)指向该虚拟地址为解析ELF头部作准备
	struct Elf *env_elf = (struct Elf*) binary;
	// ph: ELF头部的程序头，eph: ELF头部所有程序之后的结尾处
	struct Proghdr *ph, *eph;

	// 判断是否为有效的 ELF文件
	if (env_elf->e_magic != ELF_MAGIC)
		panic("load_icode: The binary is not a valid ELF!\n");

	// 加载程序段：
	// ph 指向ELF头部的程序头的起始地址(env_elf+env_elf->e_phoff)
	ph = (struct Proghdr *)((uint8_t *) env_elf + env_elf->e_phoff);
	// eph(end of ph): ELF头部所有程序之后的结尾处
	eph = ph + env_elf->e_phnum;

	// 如果可以将内核数据直接复制到ELF二进制文件中存储的虚拟地址中，加载程序段就会简单得多。
	// Q:那么在这个函数中哪个页目录应该有效呢? A:用户虚拟地址空间的页目录e->env_pgdir
	// 暂用一下用户页表目录以找到正确的虚拟地址，注意，cr3寄存器存储的是物理地址，直接索引到页目录的起始地址
	lcr3(PADDR(e->env_pgdir));

	// 遍历ELF头部的所有程序段
	for (; ph < eph; ++ph) {
		// 只加载LOAD类型的程序段到内存
		if (ph->p_type == ELF_PROG_LOAD) {
			// 程序段头部中的p_filesz ≤ p_memsz，表示中间相差的空间应该用0填充(对于C的全局变量)
			// 因此，分配p_memsz空间，只从文件读取p_filesz
			// 程序段出错，编译出来的p_memsz > p_filesz
			if(ph->p_filesz > ph->p_memsz)
				panic("load_icode(): Memory size larger than file size!\n");

			// xv6分配用户空间是连续的, 给出起始地址va和结束地址，然后ROUNDUP(va)，根据结束地址分配足够的页空间，
			// va的值是结束地址，而不是当前空间顶端。读取下一段的时候，新的开始地址是上次结束地址，新的结束地址是ph.vaddr + ph.memsz。 
			// 该内核分配用户空间不是连续的，而是根据ph->p_va作为每次的开始地址，以p_memsz为长度进行页分配
			// 首先对当前用户环境在虚拟地址处分配空闲的物理页
			region_alloc(e, (void *)ph->p_va, ph->p_memsz);
			// 加载了环境的页目录，即可通过指针(虚拟地址)读取到环境的内存

			// 将当前ELF程序段 ph 的数据复制到p_va虚拟地址空间，大小p_filesz
			memmove((void *)ph->p_va, (binary+ph->p_offset), ph->p_filesz);
			// ELF文件中BSS段中那些没有被初始化的静态变量，全部初始化为0，即p_memsz-p_filesz的部分(.bss)
			// 又因为函数 region_alloc 分配的物理页已经标志ALLOC_ZERO，无需再memset清零
			// memset((void *)(ph->p_va+ph->p_filesz), 0, (ph->p_memsz-ph->p_filesz));
		}
	}
	// 确保环境从复制的代码段的入口地址开始执行，设置环境帧的eip指令指针指向e_entry
	if (env_elf->e_entry == 0)
		panic("load_icode: The program can't be executed because the entry point is invalid!\n");
	e->env_tf.tf_eip = env_elf->e_entry;
	// 这样才能根据设置好的CS于新的偏移量eip找到用户程序需要执行的代码

	// 再在虚拟地址(USTACKTOP-PGSIZE)为程序的初始栈映射一个物理页
	region_alloc(e, (void *)(USTACKTOP-PGSIZE), PGSIZE);

	// 恢复cr3寄存器为内核的页目录
	lcr3(PADDR(kern_pgdir));
}

/**
 * 参数：
 * binary: 用户环境所在地址(va), type: 用户环境类型，一般为ENV_TYPE_USER
 * 函数功能：使用env_alloc分配一个新的env，并调用load_icode将分配的新env设置好env_type加载到binary
 * 这个函数只在内核初始化期间，即运行第一个用户态环境之前被调用。新env的父ID设置为0。
 */ 
void
env_create(uint8_t *binary, enum EnvType type)
{
	struct Env *newEnv;
	// 1.分配一个新的 env 环境，即创建用户环境的地址空间页目录
	uint16_t result = env_alloc(&newEnv, 0);
	// 处理分配环境的错误，分别是内存不足、环境分配已满(>1024)
	if (result < 0) panic("env_create: %e", result);
	
	// 设置 env_type
	newEnv->env_type = type;

	// 2.将用户环境运行所需要的代码加载到用户环境的地址空间(参数binary)
	load_icode(newEnv, binary);
}

//
// 释放环境e及其所有内存.
//
void
env_free(struct Env *e)
{
	pte_t *pt;
	uint32_t pdeno, pteno;
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
		lcr3(PADDR(kern_pgdir));

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
	e->env_pgdir = 0;
	page_decref(pa2page(pa));

	// return the environment to the free list
	e->env_status = ENV_FREE;
	e->env_link = env_free_list;
	env_free_list = e;
}

/**
 * 释放环境e.
 */
void
env_destroy(struct Env *e)
{
	env_free(e);

	cprintf("Destroyed the only environment - nothing more to do!\n");
	while (1)
		monitor(NULL);
}


/**
 * 使用 iret 指令恢复在Trapframe中寄存器值，将退出内核并开始执行环境代码
 * 此函数不会返回.
 * 
 * 设计:
 * PushRegs结构保存的正是通用寄存器的值，env_pop_tf()第一条指令，将%esp指向tf地址处，也就是将栈顶指向Trapframe结构开始处，
 * Trapframe结构开始处正是一个PushRegs结构，popal将PushRegs结构中保存的通用寄存器值弹出到寄存器中，
 * 接着按顺序弹出寄存器%es, %ds
 * 最后执行iret指令，该指令是中断返回指令，具体动作如下：
 * 从 Trapframe 结构中依次弹出 tf_eip, tf_cs, tf_eflags, tf_esp, tf_ss 到相应寄存器
 * 和Trapframe结构从上往下是完全一致的
 */ 
void
env_pop_tf(struct Trapframe *tf)
{
	asm volatile(

		// 占位符 %0 由"g"(tf)定义，代表参数tf，即Trapframe的指针地址
		// 指令代表esp指向参数(Trapframe*)tf开始位置
		"\tmovl %0,%%esp\n"

		// 这里的想法是把Trapframe看作一个保护原环境的栈，然后利用pop命令逐一恢复到寄存器里
		// 因为我们知道弹出栈的时候栈指针是不断加的过程（栈的生长是栈指针不断减），所以将ESP设置为Trapframe所在内存的首地址，就可以按内存中的排布顺序释放出所有的内容了。非常的巧妙
		// popal恢复所有r32寄存器，即tf.PushRegs里的东西
		"\tpopal\n"
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n"  /* 跳过tf_trapno和tf_err(无需弹出存储到寄存器)，使esp指向tf_eip */

		"\tiret\n"  /* iret之后发生权限级的改变(即由内核态切换到用户态)，所以iret会依次弹出5个寄存器(eip、cs、eflags、esp、ss) */
		// 这些寄存器在env_alloc()以及load_icode()中都已赋值，完成iret之后，eip就指向了程序的入口地址，cs也由内核代码段转向了用户代码段，esp也由内核栈转到了用户栈

		: : "g" (tf) : "memory");  /* g是通用传递约束(寄存器、内存、立即数)，此处表示使用内存 */

	panic("iret failed");  /* 主要是为了减少编译器的警告提示 */
}

/**
 * 上下文切换：curenv -> Env e.
 * 函数功能：上下文切换/运行初始化完毕的用户环境
 * 所以在加载新的用户环境的cr3寄存器之前(重定位CS与eip)，必须将原先设置好的es、ds和esp入栈，防止在此过程中被破坏(调用函数env_pop_tf, 完成上下文切换)
 * 加载完毕之后重置这些寄存器，然后用户环境就在新的代码段开始执行用户的环境了
 * 注意：如果这是第一次调用env_run，curenv为NULL
 */
void
env_run(struct Env *e)
{
	/**
	 * 步骤1: 如果这是一个上下文切换(一个新的环境正在运行):
	 * 	1.如果当前环境是ENV_RUNNING，则将当前环境(如果有)设置回ENV_RUNNABLE(想想它还可以处于什么状态 ENV_NOT_RUNNABLE)，
	 * 	2.将 curenv 设置为新环境，
	 * 	3.将其状态设置为ENV_RUNNING，
	 * 	4.更新其 env_runs 计数器，
	 * 	5.使用lcr3()切换到其地址空间。
	 * 
	 * 步骤2:使用env_pop_tf()恢复环境的寄存器，并在环境中返回用户态。
	 * 
	 * 注意，这个函数从e->env_tf加载新环境的状态。回顾一下您上面写的代码，确保您已经将e->env_tf的相关部分设置为合理的值
	 */

	// 1.如果当前运行的环境(curenv)是正在运行(ENV_RUNNING)，上下文切换，更新状态为等待运行(ENV_RUNNABLE)
	if(curenv && curenv->env_status == ENV_RUNNING){
		curenv->env_status = ENV_RUNNABLE;
	}
	// 2~4.设置curenv为新环境 env，并更新状态和运行次数
	curenv = e;
	e->env_status = ENV_RUNNING;
	e->env_runs++;
	// 5.使用lcr3()切换到e对应的页目录(地址空间)
	lcr3(PADDR(e->env_pgdir)); 

	// 调用env_pop_tf切换(恢复)回用户态
	env_pop_tf(&(e->env_tf));
	// panic("env_run not yet implemented");
}

