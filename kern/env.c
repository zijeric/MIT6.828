/* See COPYRIGHT for copyright information. */
// 实现用户态环境的内核代码
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

// Global descriptor table.
//
// Set up global descriptor table (GDT) with separate segments for
// kernel mode and user mode.  Segments serve many purposes on the x86.
// We don't use any of their memory-mapping capabilities, but we need
// them to switch privilege levels. 
//
// The kernel and user segments are identical except for the DPL.
// To load the SS register, the CPL must equal the DPL.  Thus,
// we must duplicate the segments for the user and the kernel.
//
// In particular, the last argument to the SEG macro used in the
// definition of gdt specifies the Descriptor Privilege Level (DPL)
// of that descriptor: 0 for kernel and 3 for user.
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
	// 0x0 - 未使用的(指向此处将总是导致错误 —— 用于捕获 NULL 远指针)
	SEG_NULL,

	// 0x8  - 内核代码段
	[GD_KT >> 3] = SEG(STA_X | STA_R, 0x0, 0xffffffff, 0),

	// 0x10 - 内核数据段
	[GD_KD >> 3] = SEG(STA_W, 0x0, 0xffffffff, 0),

	// 0x18 - 用户代码段
	[GD_UT >> 3] = SEG(STA_X | STA_R, 0x0, 0xffffffff, 3),

	// 0x20 - 用户数据段
	[GD_UD >> 3] = SEG(STA_W, 0x0, 0xffffffff, 3),

	// 0x28 - tss, 在 trap_init_percpu() 中进行初始化
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
 * 初始化envs数组，构建env_free_list链表，注意顺序，envs[0]应该在链表头部位置
 */ 
void
env_init(void)
{
	// 初始化envs数组
	// 将 envs 中的所有环境标记为ENV_FREE，env_ids 设置为0
	// 前插法构建 env_free_list，让每个 env 在空闲列表中保持升序
	for (int32_t i = NENV - 1; i >= 0; i--) {

		// env 处于空闲环境链表，必须设置对应的状态及id
		envs[i].env_id = 0;
		envs[i].env_status = ENV_FREE;

		// 插入链表
		envs[i].env_link = env_free_list;
		env_free_list = &envs[i];
	}
	
	// 为了区分用户态环境和内核态的访问权限：加载全局描述符表(GDT)，配置分段硬件
	// 为权限级别0(内核)和权限级别3(用户)使用单独的段
	env_init_percpu();
}

// 加载全局描述符 GDT，	并且初始化段寄存器gs, fs, es, ds, ss
void
env_init_percpu(void)
{
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" : : "a" (GD_UD|3));
	asm volatile("movw %%ax,%%fs" : : "a" (GD_UD|3));
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" : : "a" (GD_KD));
	asm volatile("movw %%ax,%%ds" : : "a" (GD_KD));
	asm volatile("movw %%ax,%%ss" : : "a" (GD_KD));
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" : : "i" (GD_KT));
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}

//
// Initialize the kernel virtual memory layout for environment e.
// Allocate a page directory, set e->env_pgdir accordingly,
// and initialize the kernel portion of the new environment's address space.
// Do NOT (yet) map anything into the user portion
// of the environment's virtual address space.
//
// Returns 0 on success, < 0 on error.  Errors include:
//	-E_NO_MEM if page directory or table could not be allocated.
//
/**
 * 参数：struct Env *e：ENV 结构指针
 * 返回值：0: 成功，-E_NO_MEM: 失败，没有足够物理地址分配页目录/页表页
 * 作用：为新环境分配一个页目录，并初始化新环境虚拟地址的内核部分
 * 
 * 相应设置e->env_pgdir，初始化新环境虚拟地址的内核部分
 * 目前不要将任何东西映射到新环境虚拟地址的用户部分
 */ 
static int
env_setup_vm(struct Env *e)
{
	int i;
	struct PageInfo *p = NULL;

	// 分配环境页目录
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;

	p->pp_ref++;

	// 让e->env_pgdir指向新分配的环境页目录pgdir
	e->env_pgdir = (pde_t *) page2kva(p);

	/**
	 * 由于每个用户进程都需要共享内核空间，所以对于用户进程而言，在UTOP以上的部分，和系统内核的空间是完全一样的。
	 * 因此在初始化pgdir的时候，只需要在页目录上，把共享部分的页目录部分复制进用户进程的地址空间就可以了，
	 * 这样，就实现了页式映射的共享。因为页目录里面存储的是页表页的物理地址，其直接映射到物理内存部分，
	 * 而共享的内核部分的页表页在前期的内核操作中，已经完成了映射，所以页表页是不需要初始化的
	 * 简单来说，不需要映射页表页的原因是，用户进程可以和内核共用这些页表页
	 * UTOP 以下部分清空: 注意 4GB 虚拟地址空间是由低到高每 4MB 按顺序映射到页目录项的，因此需要取出UTOP的PDX索引部分，将前PDX项清空
	 * 
	 * - 因为ULIM之上是内核部分，ULIM往下是用户环境，所以内核部分加上pages与envs的内容 = 虚拟地址 UTOP 以上
	 * - 初始化新环境虚拟地址的内核部分：把 UTOP 以上的内容从kern_pgdir中复制到env_pgdir中
	 * 注意，kern_pgdir 是用户可读的
	*/
	// memcpy 从低地址到高地址复制，只能先调用 memcpy 再调用 memset
	memcpy(e->env_pgdir, kern_pgdir, PGSIZE);
	// 代码实现无需设置新环境页目录的[0, UTOP]为0(未映射)，因为在内核页目录中也未映射
	// memset(e->env_pgdir, 0, UTOP >> PTSHIFT);

	// 安全设置：配置新环境页目录的 UVPT 映射 env 自己的页表为只读，无法被用户篡改
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;

	return 0;
}

//
// Allocates and initializes a new environment.
// On success, the new environment is stored in *newenv_store.
//
// Returns 0 on success, < 0 on failure.  Errors include:
//	-E_NO_FREE_ENV if all NENV environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;

	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
	if (generation <= 0)	// Don't create a negative env_id.
		generation = 1 << ENVGENSHIFT;
	e->env_id = generation | (e - envs);

	// Set the basic status variables.
	e->env_parent_id = parent_id;
	e->env_type = ENV_TYPE_USER;
	e->env_status = ENV_RUNNABLE;
	e->env_runs = 0;

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));

	// Set up appropriate initial values for the segment registers.
	// GD_UD is the user data segment selector in the GDT, and
	// GD_UT is the user text segment selector (see inc/memlayout.h).
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
	e->env_tf.tf_es = GD_UD | 3;
	e->env_tf.tf_ss = GD_UD | 3;
	e->env_tf.tf_esp = USTACKTOP;
	e->env_tf.tf_cs = GD_UT | 3;
	// You will set e->env_tf.tf_eip later.

	// commit the allocation
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}

//
// Allocate len bytes of physical memory for environment env,
// and map it at virtual address va in the environment's address space.
// Does not zero or otherwise initialize the mapped pages in any way.
// Pages should be writable by user and kernel.
// Panic if any allocation attempt fails.
//
/**
 * 为一个环境分配和映射物理内存，该函数只在load_icode()中调用，需要注意边界条件[va, va+len)
 * 参数：
 * e:Env指针, va:虚拟地址, len:分配和映射的空间大小
 * 作用：在e指向的用户虚拟地址空间中分配[va, va+len)一段区域，为后续写入数据作准备
 * 
 * 实现：
 * 把va和va+len ROUND处理好，然后把虚拟地址空间[va, va+len]，序号[va/PGSIZE, va+len/PGSIZE]分配给e->env_pgdir
 * 这个函数和env_setup_vm()是连贯的，env_setup_vm() 先给e分配一个物理页的索引空间，region_alloc()为这个索引开辟[va, va+len]的虚拟地址
 * 并且建立映射、设置权限
 * 
 * 类似pmap.c中的boot_map_region()，却不一样
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
		// 分配一个物理页帧，无需清零
		pp = page_alloc(0);
		if (!pp) {
			panic("region_alloc: out of memory when allocating pp!\n");
		}

		// 修改e->env_pgdir，在页表页建立线性地址start到物理页pp的映射关系，插入页表页项
		result = page_insert(e->env_pgdir, pp, start, PTE_W | PTE_U);
		if (result < 0) {
			panic("region_alloc: %e", result);
		}
	}
}

// 为用户环境设置初始程序二进制、栈和处理器标志。
// load_icode 函数只在内核初始化期间，运行第一个用户环境之前调用。
//
// 此函数从ELF程序头文件中指定的虚拟地址开始，将ELF二进制映像中的所有可加载段加载到环境的用户内存中。
// 同时，它将所有在程序头文件中被标记为正在映射但在ELF映像中实际不存在的片段清除为零 —— 即程序的.bss部分。
//
// 这一切和我们的boot loader做的很像，只是boot loader还需要从磁盘读取代码。看看boot/main.c就有想法了。
//
// 最后，这个函数为程序的初始堆栈映射一页。
//
// load_icode遇到问题就会死机。
// --load _ icode怎么可能失败？给定的输入可能有什么问题？
/**
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
	 * 看到第15行:lcr3 (e->env_cr3);
	 * 这个语句在我们进入每个程序头进行具体设置时，将页表切换到用户虚拟地址空间。
	 * 这样我们就可以方便的在后面使用memset和memmove等函数对一个虚拟地址进行相应的操作了。其中e→env_cr3的值是在前面的env_setup_vm() 设置好的。
	 * 但是仍要小心的是，对于ELF载入完毕以后，我们就不需要对用户空间进行操作了，所以记得在22行重新切回到内核虚拟地址空间来。
	 * 
	 * 3.注释中还提到了要对程序的入口地址作一定的设置，这里对应的操作:e->env_tf.tf_eip = ELFHDR->e_entry;
	 * 这里涉及到对struct Trapframe 结构的具体介绍
	 */ 

	// binary 指向第一个用户环境开始的虚拟地址(内核va之后首个)
	// 将参数binary指针转换成 Elf 结构指针
	struct Elf *elfHdr = (struct Elf*) binary;
	struct Proghdr *ph = (struct Proghdr *)(elfHdr + elfHdr->e_phoff);
	if (elfHdr->e_magic != ELF_MAGIC)
		panic("load_icode: The binary is not a ELF file!\n");
		
	// 确保环境从入口点开始执行
	if (elfHdr->e_entry == 0)
		panic("load_icode: The program can't be executed because the entry point is invalid!\n");
	e->env_tf.tf_eip = elfHdr->e_entry;

	lcr3(PADDR(e->env_pgdir));

	int i;
	for (i = 0; i < elfHdr->e_phnum; ++i)
	{ 
		if(ph->p_type != ELF_PROG_LOAD) {//不可载入段  
			ph++;
		 	continue;
		}
		//xv6分配用户空间是连续的, 给出起始地址va和结束地址，然后ROUNDUP(va)，根据结束地址分配了足够的页空间，
		//va的值是结束地址，而不是当前空间顶端。读取下一段的时候，新的开始地址是上次结束地址, 新的结束地址是ph.vaddr + ph.memsz。 
		//jos分配用户空间不是连续的,而是根据ph->p_va作为每次的开始地址，以p_memsz为长度进行页分配。
		region_alloc(e,(void*)ph->p_va,ph->p_memsz);
		//read into env's memory , need env's pgdir
		memcpy((char*)ph->p_va,(char*)(binary + ph->p_offset),ph->p_filesz);
		ph++;
	}
	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.

	// LAB 3: Your code here. 
	region_alloc(e,(void*)USTACKTOP - PGSIZE,PGSIZE);

	//todo...binary的数据位于内核空间的哪个节？
	// e->env_tf.tf_eip = elfHdr->e_entry;  // main 

	lcr3(PADDR(kern_pgdir));
}

//
// Allocates a new env with env_alloc, loads the named elf
// binary into it with load_icode, and sets its env_type.
// This function is ONLY called during kernel initialization,
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, enum EnvType type)
{
	// LAB 3: Your code here. TODO...
	struct Env *newEnv;
	// Allocates a new env 
	int i = env_alloc(&newEnv,0);
	if(i<0) panic("env_create");
	// loads the named elf binary into
	load_icode(newEnv,binary);
	// set env_type
	newEnv->env_type = type;
}

//
// Frees env e and all memory it uses.
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

//
// Frees environment e.
//
void
env_destroy(struct Env *e)
{
	env_free(e);

	cprintf("Destroyed the only environment - nothing more to do!\n");
	while (1)
		monitor(NULL);
}


//
// Restores the register values in the Trapframe with the 'iret' instruction.
// This exits the kernel and starts executing some environment's code.
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
	asm volatile(
		"\tmovl %0,%%esp\n"
		"\tpopal\n"
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret\n"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
}

//
// Context switch from curenv to env e.
// Note: if this is the first call to env_run, curenv is NULL.
//
// This function does not return.
//
void
env_run(struct Env *e)
{
	// Step 1: If this is a context switch (a new environment is running):
	//	   1. Set the current environment (if any) back to
	//	      ENV_RUNNABLE if it is ENV_RUNNING (think about
	//	      what other states it can be in),
	//	   2. Set 'curenv' to the new environment,
	//	   3. Set its status to ENV_RUNNING,
	//	   4. Update its 'env_runs' counter,
	//	   5. Use lcr3() to switch to its address space.
	// Step 2: Use env_pop_tf() to restore the environment's
	//	   registers and drop into user mode in the
	//	   environment.

	// Hint: This function loads the new environment's state from
	//	e->env_tf.  Go back through the code you wrote above
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.

	// LAB 3: Your code here. TODO...
	if(!e) panic("env_run panic"); 
	if(curenv && curenv->env_status == ENV_RUNNING){
		curenv->env_status = ENV_RUNNABLE;
	}	
	curenv = e;
	e->env_status = ENV_RUNNING;
	e->env_runs += 1;
	lcr3(PADDR(e->env_pgdir)); 

	env_pop_tf(&(e->env_tf));//never return  
	// panic("env_run not yet implemented");
}

