/* See COPYRIGHT for copyright information. */

#include <inc/x86.h>
#include <inc/mmu.h>
#include <inc/error.h>
#include <inc/string.h>
#include <inc/assert.h>

#include <kern/pmap.h>
#include <kern/kclock.h>
#include <kern/env.h>

// 通过 i386_detect_memory() 对 npages 和 npages_basemem 赋值
size_t npages;					// 物理内存量（以页为单位）
static size_t npages_basemem;	// 基本内存量（以页为单位）

// 这些变量在 mem_init() 中赋值
// 内核初始化的页目录
pde_t *kern_pgdir;
// 所有 Page 在内存（物理内存）中的存放是连续的，存放于 pages 处，可以通过数组的形式访问各个 Page，
// 而 pages 紧接于 kern_pgdir 页目录之上，对应物理和虚拟内存布局也就是在kernel向上的紧接着的高地址部分连续分布着 pages 数组。
// Physical page state array 页数组，数组中第 i 个成员代表内存中第 i 个 page，因此，物理地址和数组索引很方便相换算。
struct PageInfo *pages;
// 空闲物理页链表
static struct PageInfo *page_free_list;

/**
 * check_page_alloc 这一行之上进行的操作汇总如下。
 * 1.直接调用硬件查看可以使用的内存大小，也就是函数 i386_detect_memory。
 * 2.创建一个内核初始化时的 page 目录，并设置权限。
 * 3.创建用于管理 page 的数组，初始化 page 分配器组件。
 * 4.测试 page 分配器组件。
 * 
 * boot_alloc，page 未初始化时的分配器。
 * page_init, page_alloc, page_free，page分配器组件。
 * mem_init，总的内存初始化函数。
 */ 
// --------------------------------------------------------------
// Detect machine's physical memory setup.
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
}

/**
 * 直接调用硬件查看可以使用的内存大小。
 * (更新全局变量 npages:总内存所需物理页的数目 & npages_basemem:0x000A0000，IO hole之前)
 */ 
static void
i386_detect_memory(void)
{
	size_t basemem, extmem, ext16mem, totalmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	// 调用 CMOS 来测量可用的基本内存和扩展内存。（CMOS 调用返回的结果以 KB 作为单位。）
	basemem = nvram_read(NVRAM_BASELO);
	extmem = nvram_read(NVRAM_EXTLO);
	ext16mem = nvram_read(NVRAM_EXT16LO) * 64;

	// Calculate the number of physical pages available in both base
	// and extended memory.
	// 计算基本内存和扩展内存中可用的物理页数。
	if (ext16mem)
		totalmem = 16 * 1024 + ext16mem;
	else if (extmem)
		totalmem = 1 * 1024 + extmem;
	else
		totalmem = basemem;

	// CMOS 调用返回的结果以 KB 为单位
	npages = totalmem / (PGSIZE / 1024);
	npages_basemem = basemem / (PGSIZE / 1024);

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		totalmem, basemem, totalmem - basemem);
}


// --------------------------------------------------------------
// Set up memory mappings above UTOP.
// --------------------------------------------------------------

static void boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm);
static void check_page_free_list(bool only_low_memory);
static void check_page_alloc(void);
static void check_kern_pgdir(void);
static physaddr_t check_va2pa(pde_t *pgdir, uintptr_t va);
static void check_page(void);
static void check_page_installed_pgdir(void);

/**
 * boot_alloc(n)是个简单的内存分配器，这个简单的物理内存分配器只在JOS设置其虚拟内存系统时使用。
 * page_alloc()是真正的分配器。
 * 
 * 如果 n>0，则分配足够容纳'n'个字节的连续物理内存页（不初始化该内存）。
 * 返回虚拟地址。
 * 
 * 如果 n==0，则不分配任何内容就返回下一个空闲页的地址。
 * 
 * 如果我存不足，boot_alloc 会崩溃调用panic()。
 * 仅在初始化 page_free_list 链表之前，才能调用此函数。
 */ 
static void *
boot_alloc(uint32_t n)
{
	// 下一个空闲内存的首字节虚拟地址
	static char *nextfree;
	char *result;

	// 从 linker 中获取内核的最后一个字节的地址 end，将这个指针的数值向上对齐到 4096 的整数倍。
	// 很巧妙的利用了局部静态变量 nextfree 没有显式的赋值初始化的时候，会默认初始化为0，并且只初始化一次
	// 这里,这两个特点都利用的很好。如果 nextfree 是第一次使用（默认0），就进入if判断语句，如果之前进入过if判断语句了（只初始化一次），再次调用boot_alloc的时候就不需要再进入if语句了。
	// 如果这是第一次，将初始化 nextfree
	// end 是 linker 自动生成的(kern/kernel.ld 53行)，指向内核的最后一个字节的下一个字节。
	// 因此 end 是 linker 没有 分配任何内核代码或全局变量的第一个虚拟地址(bss 段是已加载内核代码的最后一个段)
	if (!nextfree) {
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);  // ROUNDUP: end 向上对齐（取整）成 PGSIZE(4096) 的倍数
	}
	// 既然char end[]是通过linker自动获得的，并且指向内核bss段的结尾，也就是说接下来的空间都是linker过程没有分配的虚拟地址。
	// 所以需要从end开始，分配n字节的空间，更新nextfree并且保持它对齐。

	// 分配足够大的内存块以容纳 'n' 个字节，然后更新 nextfree
	// 确保 nextfree 与 PGSIZE 的倍数保持对齐
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	// ROUNDUP to make sure nextfree is kept aligned
	// to a multiple of PGSIZE
	// 用 char *result 返回 nextfree 所指向的地址
	result = nextfree;
	// 根据函数设计要求，当 n=0 则不分配任何内容就直接返回下一个空闲页的地址。
	// 因此 n!=0 时再划分内存
	if (n != 0) {
		// 根据参数 n 更新 nextfree 的值，使其指向下一个空闲地址处。
		// 何为足够大？刚好足以容纳 n 个字节（恰好满足申请的内存空间），
		// 并且必须满足 PGSIZE 字节向上对齐，nextfree 本身已对齐
		// nextfree = ROUNDUP(nextfree + n, PGSIZE);
		nextfree += ROUNDUP(n, PGSIZE);

		// 如果我们内存不足，boot_alloc 应该会崩溃。
		// 0xf0400000: 先前在 entry.S 进行了虚拟内存映射，将0xf0000000~0xf0400000映射到物理地址0x00000000~00400000(4MB)
		// 仅在初始化 page_free_list 列表之前，才会调用此函数。
		// 因此以下判断是作谨慎处理其他内存不足的机器
		if ((uintptr_t) nextfree >= KERNBASE + PTSIZE) {
			cprintf("boot_alloc: out of memory\n");
			panic("boot_alloc: failed to allocate %d bytes, returning NULL...\n", n);
			// 还原 nextfree
			nextfree = result;
			result = NULL;
		}
	}
	cprintf("boot_alloc memory at %x, next memory allocate at %x\n", result, nextfree);
	return result;
}

/**
 * 设置二级页表：
 *   kern_pgdir 是其 root 的线性（虚拟）地址
 * 此函数仅设置地址空间的内核部分（即地址 >= UTOP），地址空间的用户部分稍后再设置。
 * 从 UTOP 到 ULIM，允许用户读取但不能写入。在 ULIM 之上，用户无法读取或写入。
 */ 
void
mem_init(void)
{
	uint32_t cr0;
	size_t n;

	// Find out how much memory the machine has (npages & npages_basemem).
	// 1.通过汇编指令直接调用硬件查看可以使用的内存大小 (底层 kern/kclock.c)
	// 其中得到的内存信息是整数 npages，代表现有内存的 page 个数(所需 PageInfo 结构体的数量)
	i386_detect_memory();

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	// 2.创建一个正式的页目录(一个页的大小)替换在 kern/entry.S 的 entry_pgdir，并设置权限。
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);
	memset(kern_pgdir, 0, PGSIZE);

	//////////////////////////////////////////////////////////////////////
	// Recursively insert PD in itself as a page table, to form
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following line.)
	// 递归地将页目录 PD 自身作为页表插入，以在虚拟地址 UVPT 处形成一个虚拟页表。
	//（到目前为止，您还不了解下一行的更多用途。）

	// Permissions: kernel R, user R
	// 将UVPT对应到的虚拟地址映射在系统页目录中的表项设置成它自己的物理地址
	// 如果想查找一个任意虚拟地址所在的页的物理地址和其对应的二级页表物理地址的话，
	// 只要有页目录地址就可以做到
	// 具体来讲，如果要查询的虚拟地址是addr = PDX|PTX|OFFSET的话，显然只有PDX|PTX决定了addr物理页的地址
	// 查找addr对应的物理页地址的方法如下：
	// 构造虚拟地址vaddr = UVPT[31:22]|PDX|PTX|00在虚拟内存空间里查询。
	// 根据二级页表翻译机制：
	// 1. 系统首先取出 vaddr 的前10位，即UVPT[31:22]，去页目录里查询，根据
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
	//    注意UVPT[31:22]等价于PDX(UVPT)，所以得到的二级页表地址A0，还是页目录pgdir本身。
	// 2. 再取出vaddr的中间10位，即PDX，去二级页表中A0（即页目录），
	//    查找到的是addr所在二级页表的物理地址A1，注意！不是addr的物理页地址，是二级页表的地址！
	// 3. 最后取出vaddr的最后12位，即PTX|00，去A1物理页中（即addr所在二级页表）查找，
	//    得到的就是addr最后所在物理页的物理地址
	// 
	// 查询addr对应的二级页表物理地址的方法：
	// 构造虚拟地址vaddr = UVPT[31:22]|UVPT[31:22]|PDX|00在虚拟内存空间里查询。
	// 注意，这个地址等价于PDX(UVPT)|PDX(UVPT)|PDX|00。
	// 1. 根据上面的分析，我们可以知道页式转换的前两步，地址转换系统都会跳回到页目录本身
	// 2. 最后一步取出vaddr的最后12位，即PDX|00，去pgdir的物理页查询，查到的就是addr对应的二级页表物理地址

	//////////////////////////////////////////////////////////////////////
	// Allocate an array of npages 'struct PageInfo's and store it in 'pages'.
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct PageInfo in this
	// array.  'npages' is the number of physical pages in memory.  Use memset
	// to initialize all fields of each struct PageInfo to 0.
	// 分配 npages 个 PageInfo 结构体的数组并将其存储在 'pages' 中。
	// 内核使用 pages 数组来跟踪物理页：
	// pages数组的每一项是一个PageInfo结构，对应一个物理页的信息，定义在inc/memlayout.h中
	// "npages"是内存需要的物理页数。调用 memset 将每个PageInfo结构体的所有字段初始化为 0。
	size_t page_mem = npages * sizeof(struct PageInfo);
	pages = (struct PageInfo *)boot_alloc(page_mem);
	// void pointer，任何类型的指针都可以直接赋值给它，无需进行强制类型转换
	// 指针的类型用于每取多少字节将其视为对应类型的值 (char:1, int:2)
	memset(pages, 0, page_mem);
	// cprintf("pages in pmap.c: %08x", pages);

	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.

	//////////////////////////////////////////////////////////////////////
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	// 3. 创建用于管理page的数组，初始化page分配器组件
	page_init();

	// 4. 测试page分配器组件
	check_page_free_list(1);
	check_page_alloc();
	check_page();
	
	// 现在pages数组保存这所有物理页的信息，page_free_list链表记录这所有空闲的物理页。
	// 可以用page_alloc()和page_free()进行分配和回收。

	//////////////////////////////////////////////////////////////////////
	// Now we set up virtual memory

	//////////////////////////////////////////////////////////////////////
	// 将虚拟地址的 UPAGES 映射到物理地址pages数组开始的位置(权限：用户只读)
	// 默认在映射时分配 PTE_P 权限
	boot_map_region(kern_pgdir, UPAGES, PTSIZE, PADDR(pages), PTE_U);

	//////////////////////////////////////////////////////////////////////
	// Map the 'envs' array read-only by the user at linear address UENVS
	// (ie. perm = PTE_U | PTE_P).
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.

	//////////////////////////////////////////////////////////////////////
	// 使用 bootstack 所指的物理内存作为内核堆栈。内核堆栈从虚拟地址 KSTACKTOP 向下扩展
	// 我们认为从[KSTACKTOP-PTSIZE, KSTACKTOP]整个范围都是内核堆栈，但是把它分成两部分:
	// [KSTACKTOP-KSTKSIZE, KSTACKTOP) ---- 由物理内存支持，可以被映射
	// [KSTACKTOP-PTSIZE, KSTACKTOP-KSTKSIZE) ---- 没有物理内存支持，不可映射
	// 因此，如果内核栈溢出将会触发 panic 错误，而不是覆盖内存。类似规定被称为“守护页”
	// 权限: 内核 RW，用户 NONE
	uintptr_t backed_stack = KSTACKTOP - KSTKSIZE;
	// 仅映射[KSTACKTOP-KSTKSIZE, KSTACKTOP)，即基址:KSTACKTOP-KSTKSIZE, 拓展偏移:KSTKSIZE
	boot_map_region(kern_pgdir, backed_stack, KSTKSIZE, PADDR(bootstack), PTE_W);

	//////////////////////////////////////////////////////////////////////
	// 在 KERNBASE 映射所有物理内存。
	// 即 va 范围[KERNBASE, 2^32)应该映射到 PA 范围[0, 2^32-KERNBASE]
	// 我们可能没有 2^32-KERNBASE 字节的物理内存，但我们还是设置了映射。
	// 权限: 内核 RW，用户 NONE
	boot_map_region(kern_pgdir, KERNBASE, 0xffffffff-KERNBASE, 0, PTE_W);

	// Check that the initial page directory has been set up correctly.
	check_kern_pgdir();

	// Switch from the minimal entry page directory to the full kern_pgdir
	// page table we just created.	Our instruction pointer should be
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));

	check_page_free_list(0);

	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}

// --------------------------------------------------------------
// 跟踪物理页。 
// 初始化之前分配的pages数组，'pages'数组在每个物理页上都有一个'struct PageInfo'条目。
// 物理页被引用计数，并且构建一个PageInfo链表，保存空闲的物理页，表头是全局变量page_free_list。
// --------------------------------------------------------------

/**
 * 初始化页结构和空闲内存列表。完成此操作后，请勿再使用boot_alloc。
 * 仅使用下面的页分配器函数 page_init 来分配和释放由 page_free_list 进行存储的物理内存。
 */ 
void
page_init(void)
{
	// 总结:
	//  [0, PGSIZE): 存放中断向量表IDT以及BIOS的相关载入程序
	//  [IOPHYSMEM, EXTPHYSMEM): 存放输入输出所需要的空间，比如VGA的一部分显存直接映射这个地址
	//  [EXTPHYSMEM, end): 存放操作系统内核kernel
	//  [PADDR(boot pgdir), PADDR(boot pgdir) + PGSIZE): 存放页目录
	//  [PADDR(pages), boot freemem): 存放pages数组
	// 	但是除了第一项之外，后面的4段区域实际上是一段连续内存[IOPHYSMEM, boot freemem)，
	//  所以上面的代码在实现时，把这段区域对应的物理页下标算出来，那么如果是
	//  第一个物理页或者是上面区间内的物理页，就不加入空闲页链表里。
    //
    //  注意：请勿实际触及与空闲页相对应的物理内存！

	// pages数组索引，与物理页逐一映射
	size_t i;
	// [IOPHYSMEM, boot freemem): 计算这段连续内存的起始和结束下标
	// IO hole: BIOS data, Video RAM 包括显存，又称 VGA display
	// IO hole 开始的地址，需要标记为不能分配：设置该页为*已引用*且无法通过 pp_link 链接
	size_t io_hole_start_page = (size_t)IOPHYSMEM / PGSIZE;
	// 内核(0x00100000)在内存的地址之后的第一个空闲物理页
	// kern_pgdir页目录表 和 pages物理页状态数组都由 boot_alloc 分配，因此再次调用 boot_alloc(0)可返回在其之后的物理地址
	size_t kernel_end_page = PADDR(boot_alloc(0)) / PGSIZE;

	// 页状态数组索引0[0, PGSIZE) 对应于第一个页，占用内存4KB
	// 这部分内存是被占用不能分配的，用来保存实模式的中断向量表 IDT
	// 设置该页为*已引用*且无法通过 pp_link 链接
	pages[0].pp_ref = 1;
	pages[0].pp_link = NULL;
	
	for (i = 1; i < npages; i++) {
		// [IOPHYSMEM, boot freemem) 包含以下：
		//   1.[IO hole, EXTPHYSMEM]: [0x000A0000, 0x00100000]
		//   2.kernel code: [0x00100000, end], 大约25个PGSIZE
		//   3.kern_pgdir页目录表
		//   4.pages物理页状态数组
		//  3和4取决于计算机的内存大小，计算机内存越大，需要管理的物理页越多
		if(i >= io_hole_start_page && i < kernel_end_page) {
			pages[i].pp_ref = 1;
			pages[i].pp_link = NULL;
		}
		// 除以上内存都可以开始使用或重新使用，包括bootloader 和 ELFheader等
		else {
			// 空闲物理页无引用，通过 pp_link 链接 page_free_list 索引到数组地址
			// 可以将对应数组地址通过调用函数 page2pa 转换成物理地址
			pages[i].pp_ref = 0;
			pages[i].pp_link = page_free_list;
			page_free_list = &pages[i];
		}
	}
}

/**
 * 分配一个物理页。
 * If(alloc_flags & ALLOC_ZERO)==true，则通过 page2kva 和 memset用 \0 填充整个返回的物理页。
 * 不增加物理页的引用计数，如果确实需要增加引用计数，调用者必须显式地调用page_insert
 * 确保将分配物理页的 pp_link 字段设置为 NULL，这样 page_free 检查就可以双重保证。
 * (pp->pp_ref == 0 和 pp->pp_link == NULL)
 * 
 * 如果空闲内存不足，返回 NULL。
 * 
 * 提示：
 */ 
struct PageInfo *
page_alloc(int alloc_flags)
{
	// 获取空闲页链表的第一个页结点，ret就是准备取出的页结点，即将分配的物理页
	struct PageInfo *ret = page_free_list;

	// 空闲内存不足，返回 NULL
	if(ret == NULL) {
		// cprintf("page_alloc: out of free memory!\n");
		return NULL;
	}
	// 还存在空闲的内存，更新空闲页链表
	else {
		// 将`page_init()`组织的空闲页链表`page_free_list`的第一个页结点取出，将头指针指向下一个页结点
		// 空闲页链表page_free_list指向*准备取出的页结点*的下一个页结点
		page_free_list = ret->pp_link;
		// 将*准备取出的页结点*的pp_link设置为NULL来进行双重错误检查
		ret->pp_link = NULL;
		// alloc_flags 和 ALLOC_ZERO 进行与运算，1:需要将返回的页清零
		if(alloc_flags & ALLOC_ZERO) {
			// 一定记得memset参数使用的是虚拟地址
			// 获取*准备取出的页结点*对应的虚拟地址，
			// 调用 memset 函数将*准备取出的页结点*对应物理页页表的虚拟地址 PGSIZE 字节清零，确保所有的 PTE_P 都是0
			memset(page2kva(ret), '\0', PGSIZE);
		}
		return ret;
	}
}

/**
 * 从空闲链表头添加函数参数PageInfo结点，相当于栈，后进先出
 * 将一个物理页返回到空闲链表。(只有当 pp->pp_ref 等于0时才应该调用page_free)
 */ 
void
page_free(struct PageInfo *pp)
{
	// 只有当 pp->pp_ref 等于0 且 pp->pp_link 等于NULL时，才应该调用page_free
	if (pp->pp_ref != 0 || pp->pp_link != NULL) {
		panic("page_free: pp->pp_ref is nonzero or pp->pp_link is not NULL\n");
	}
	// 向空闲页链表添加参数 PageInfo结点
	pp->pp_link = page_free_list;
	// 更新空闲页链表头
	page_free_list = pp;
}

/**
 * 减少物理页PageInfo结构上的引用计数，如果引用次数为0，就释放结构对应的物理页。
 */ 
void
page_decref(struct PageInfo* pp)
{
	// 减少物理页上的引用计数
	if (--pp->pp_ref == 0)
		// 如果引用次数为0，就释放它
		page_free(pp);
}

/**
 * 分段分页保护机制的实现。当一个程序试图访问一个虚拟地址的数据时，x86系统的保护机制运行为：
 * 1. 先检查段权限位DPL，这个是所访问数据段或者Call gate的权限级别，和当前权限级别CPL进行比较，
 * 如果不够则产生权限异常（具体机制请参考手册，在这个问题上我们不用管它），否则进入下一步
 * 2. 再检查页目录相应表项的访问权限，如果不够也产生异常
 * 3. 最后检查二级页表相应表项的访问权限，不够就产生异常
 * - 明确保护机制检查顺序，段权限位->页目录->二级页表。
 * 
 * 可以看到，在任意一次检查上违例了，那么访问失效。实际上我们知道页目
 * 录中一个表项代表的就是内存中的1024个物理页，这些页中很可能对访问的控
 * 制各不相同，比如有的可以给用户写权限，有的只能读，有的连读都不行。那
 * 么在无法提前知道这些需求的话，最明智的办法就是不在页目录这一环节限制
 * 太多，让最终的访问控制在二级页表这一环节上再去具体设置。
 */

/** 
 * 根据虚拟地址取出Page Table Entry
 * pgdir_walk 参数：
 *  - pgdir: 页目录虚拟地址
 *  - va: 虚拟地址
 *  - create: 是否需要分配新物理页，如果等于1，则虚拟地址还没有对应的物理页
 * 返回值：页表项的地址
 * 作用：给定参数 pgdir(一个指向页目录的指针)，pgdir_walk 返回线性地址 va 的页表项(PTE)的地址。
 * 
 * 这个过程需要遍历二级页表结构。
 * 根据参数create的值，如果等于1，则虚拟地址还没有对应的物理页，为它新分配物理页。
 */
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
	// 页目录表全局共享且唯一，通过 pgdir 可以索引到整个页目录表
	// 获取虚拟地址 va 的页目录项的索引 PDX(va)，通过 pgdir[PDX(va)] 索引页目录项
	// 并用(pde_t*)指针 pde 指向页目录项的虚拟地址
	pde_t *pde = &pgdir[PDX(va)];

	// 判断页目录中 va 对应二级页表是否存在，应该判断页目录的对应PDX(va)项最后一位状态位present是否为0，
	// 我一开始写成了if(*pde != 0)了，这样显然不对

	// 与物理页存在位 PTE_P(0x001) 进行与操作，0:该物理页对应的页表还没有分配，1:已分配
	// 如果该页目录项对应的物理页页表还没有分配
	if (!(*pde & PTE_P)) {
		// 参数create允许分配新物理页
		if (create) {
			// 调用 page_alloc(ALLOC_ZERO) 从空闲页链表中取出一个页结点，并将其对应的物理页清空(memset)，不增加页引用
			struct PageInfo *pp = page_alloc(ALLOC_ZERO);
			// 分配物理页失败（无空闲内存），返回NULL
			if (pp == NULL) {
				return NULL;
			}
			// 新分配物理页的 PageInfo 状态结构的引用次数++
			pp->pp_ref++;

			// 依据80386 Programmer's Reference Manual的规定，在 entry 中放置的必须是物理地址
			// 因此，将PageInfo结构体的指针转换为物理地址，
			// 授予新建物理页对应页目录项的限制权限，包括用户位、可写位和存在位
			// 权限位比较宽容，如果需要，可以在之后的页表项 PTE 中授予更严格的权限
			*pde = (page2pa(pp)) | PTE_P | PTE_U | PTE_W;

		} else {
			// create=0 不允许创建新物理页，返回 NULL
			return NULL;
		}
	}
	// 1.如果该页目录的存在位为1，说明该地址已分配，则返回已分配过的对应页表的地址
	// 2.返回新分配物理页对应页表的虚拟地址

	// 获取页目录项中 PPN 索引对应的页表 pgtable 的虚拟地址
	// 调用 PTE_ADDR(pa) 获取页表(页目录项)中的PPN索引，调用宏函数 KADDR(pa) 转换为页表的虚拟地址
	pte_t *pgtable = (pte_t*)KADDR(PTE_ADDR(*pde));

	// 返回给定虚拟地址 va 对应的页表项的虚拟地址，PPN(20)+Flags(12)
	return &pgtable[PTX(va)];
	// 非物理页帧(物理地址)，pa = PPN(20) + offset: va低12位(11~0)
}

/**
 * 映射一段空间，将虚拟地址(线性地址)va开始的size大小的区域映射到物理页pa开始的同样大小区域
 * boot_map_region 参数：
 * pgdir:页目录指针, va:需要映射的虚拟地址(线性地址), size:内存大小
 * pa:需要被映射到的物理地址, perm:需要的权限
 * 
 * 将虚拟地址空间的[va，va+size]映射到位于 pgdir 的页表中的物理[pa，pa+size]。
 * size是 PGSIZE 的倍数，va 和 pa 都是页对齐的。
 * 对页表项的物理地址授予权限，给定的 perm 和物理页存在位 PTE_P。
 * 此函数仅用于设置地址 UTOP 之上的 静态 映射(全局)。因此，它*不应该*更改映射物理页上的 pp_ref 字段。
 * 做法：
 * 这个函数主要依赖于函数pgdir_walk()，并且建立页表保存的映射。
 * 遍历区间[va, va+size)，将每一个虚拟地址通过页表映射到物理地址空间[pa, pa+size)上，
 * 这样物理页的地址可以通过二级页表的PPN找到。
 * 这样就建立了线性地址到二级页表的映射。
 */ 
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	// 计算 size 对应了多少物理页，先将 size 页对齐，再除以 PGSIZE
	size = ROUNDUP(size, PGSIZE);
	size_t pgs = size / PGSIZE;

	// 遍历区间[va, va+size)，将每一个虚拟地址通过页表映射到物理地址空间[pa, pa+size)上
	for (size_t i = 0; i < pgs; ++i) {

		// 获取虚拟地址(线性地址)va对应的页表项PTE的地址，
		// 无则分配空的物理页，va 在[0,pgs]循环范围内 pte 必然不为空
		pte_t *pte = pgdir_walk(pgdir, (void*)va, ALLOC_ZERO);
		// pte为空，说明内存越界了，循环区间有问题
		if (!pte) {
			panic("boot_map_region(): out of memory\n");
		}

		// 设置给定虚拟地址 va 对应的页表项PTE，并授予的权限，
		// pa 是页对齐的(4096=2^12)，所以低12位为空，与PTE_P和perm或运算设置权限
		*pte = pa | PTE_P | perm;

		// 更新 pa 和 va，进入下一轮循环
		pa += PGSIZE;
		va += PGSIZE;
	}
}

/**
 * 将一个虚拟地址 va 映射到它实际对应的物理页 pp 上去。
 * 页表项的权限(低12位)应设置为 perm|PTE_P
 * 
 * 分类讨论:
 * 1. 这个虚拟地址所对应的二级页表上没有挂载页表项PPN(物理页)，那么这时直接修改相应的二级页表表项即可
 * 2. 如果已经挂载了物理页，且物理页和当前分配的物理页不一样，那么就调用 page_remove(dir,va) 卸下原来的物理页，再挂载新分配的物理页
 * 3. 如果已经挂载了物理页，而且已挂载物理页和当前分配的物理页是同样的，这种情况非常普遍，
 * 就是当内核要修改一个物理页的访问权限时，它会将同一个物理页重新插入一次，传入不同的perm参数，即完成了权限修改。
 */ 
int
page_insert(pde_t *pgdir, struct PageInfo *pp, void *va, int perm)
{
	// 获取虚拟地址va对应的页表项 PTE 地址，如果 va 对应的页表还没有分配，则分配一个空的物理页作为页表
	pte_t *pte = pgdir_walk(pgdir, va, ALLOC_ZERO);
	// 分配页表项失败
	if (!pte) {
		return -E_NO_MEM;
	}

	// 提前增加pp_ref引用次数，避免 pp 在插入之前被释放的极端情况。
	pp->pp_ref++;	
	// 当前虚拟地址va已经被映射过，需要先释放（无论是否和当前分配的物理页相同，最终都要修改perm权限设置）
	if (*pte & PTE_P) {
		// 调用 page_remove 中删除页表中对应的页表项(取消映射)
		page_remove(pgdir, va);
	}

	// 将PageInfo结构转换为对应物理页的PPN，设置权限后赋值到页表项，完成映射
	physaddr_t pa = page2pa(pp);
	// 插入物理页(页表项)到页表，为对应页表项赋值
	*pte = pa | perm | PTE_P;

	return 0;
}

/** 
 * page_lookup 参数
 * pgdir: 页目录地址, va: 虚拟地址,
 * pte_store: (pte_t*)指针的地址，方便修改指针与swap同理
 * 
 * 通过虚拟地址 va 取出对应的所在物理页的地址
 * 这个函数用来检测虚拟地址 va 对应的物理页是否存在。
 * 1.不存在返回NULL，
 * 2.存在返回虚拟地址va对应物理页的描述结构体PageInfo的指针 (PageInfo 结构体仅用来描述物理页)
 * 
 * 大体思路和pgdir_walk()差不多，所以可以用函数调用：利用pgdir_walk()获取页表项虚拟地址之后，
 * 用 pte_store 指向页表项的虚拟地址，然后返回所找到的物理页帧（page frame）。
 */ 
struct PageInfo *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
	// 获取给定虚拟地址 va 对应页表项的虚拟地址，将create置为0，如果对应的页表不存在，不再新分配
	pte_t *pte =  pgdir_walk(pgdir, va, 0);
	// 对应的页表项不存在/无效，返回 NULL
	if (!pte || !(*pte & PTE_P)) return NULL;

	// 	将 pte_store 指向页表的虚拟地址 pte
	if (pte_store) {
		*pte_store = pte;
	}
	// 由 pa 接收给定虚拟地址 va 对应页表项的PPN索引(20)，根据此索引可以找到对应的物理页帧(物理地址)
	physaddr_t pa = PTE_ADDR(*pte);
	// 获取PPN索引 pa 对应的物理页结构 PageInfo
	struct PageInfo *pp = pa2page(pa);
	// 返回所找到的物理页结构
	return pp;
}

/**
 * page_remove 参数
 * pgdir: 页目录地址, va:虚拟地址
 * 从 Page Table 中删除一个 page frame 映射(页表项)
 * 实际是取消物理地址映射的虚拟地址，将映射页表中对应的项清零即可。
 * 如果没有对应的虚拟地址就什么也不做。
 * 
 * 具体做法如下：
 * 1.减少物理地址所映射的物理页数量（用page_lookup找到va虚拟地址对应的物理地址之后再进行操作）
 * 2.物理页应该被释放（用page_decref实现）
 * 3.虚拟地址 va 对应的页表项 PTE 应该被设置为0（如果存在 PTE）
 * 4.TLB 翻译缓存 必须变为不可用状态如果移除了页表入口（用tlb_invalidate实现）
 */ 
void
page_remove(pde_t *pgdir, void *va)
{
	pte_t *pte;
	// pp 获取线性地址va 对应的物理页帧结构PageInfo的地址，pte指向页表项的虚拟地址
	struct PageInfo *pp = page_lookup(pgdir, va, &pte);
	
	// 只有当 va 映射到物理页且有效，才需要取消映射，否则什么也不做
	if (pp && (*pte & PTE_P)) {
		// 将pp->pp_ref减1，如果pp->pp_ref为0，需要释放该PageInfo结构（将其放入page_free_list链表中）
		page_decref(pp);
		// 将页表项 PTE 对应的 PPN 设为0，令二级页表该项无法索引到物理页帧(物理地址)
		*pte = 0;
		// 失效化TLB缓存
		tlb_invalidate(pgdir, va);
	}
}

/**
 * 使 TLB 条目无效，但仅当正在编辑的页表是处理器当前处理的页表时才使用。
 */
void
tlb_invalidate(pde_t *pgdir, void *va)
{
	// 只有在修改当前地址空间时才刷新条目。
	// 目前，只有一个地址空间，因此总是无效。
	invlpg(va);
}

static uintptr_t user_mem_check_addr;

//
// Check that an environment is allowed to access the range of memory
// [va, va+len) with permissions 'perm | PTE_P'.
// Normally 'perm' will contain PTE_U at least, but this is not required.
// 'va' and 'len' need not be page-aligned; you must test every page that
// contains any of that range.  You will test either 'len/PGSIZE',
// 'len/PGSIZE + 1', or 'len/PGSIZE + 2' pages.
//
// A user program can access a virtual address if (1) the address is below
// ULIM, and (2) the page table gives it permission.  These are exactly
// the tests you should implement here.
//
// If there is an error, set the 'user_mem_check_addr' variable to the first
// erroneous virtual address.
//
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
	// LAB 3: Your code here.

	return 0;
}

//
// Checks that environment 'env' is allowed to access the range
// of memory [va, va+len) with permissions 'perm | PTE_U | PTE_P'.
// If it can, then the function simply returns.
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
		cprintf("[%08x] user_mem_check assertion failure for "
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
	}
}


// --------------------------------------------------------------
// Checking functions.
// --------------------------------------------------------------

//
// Check that the pages on the page_free_list are reasonable.
//
static void
check_page_free_list(bool only_low_memory)
{
	struct PageInfo *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct PageInfo *pp1, *pp2;
		struct PageInfo **tp[2] = { &pp1, &pp2 };
		// 执行该for循环后，pp1指向（0~4M）中地址最大的那个页的PageInfo结构。
		// pp2指向所有页中地址最大的那个PageInfo结构
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
		*tp[0] = pp2;
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
		assert(pp < pages + npages);
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
		assert(page2pa(pp) != EXTPHYSMEM);
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
		else
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
	assert(nfree_extmem > 0);

	cprintf("check_page_free_list() succeeded!\n");
}

//
// Check the physical page allocator (page_alloc(), page_free(),
// and page_init()).
//
static void
check_page_alloc(void)
{
	struct PageInfo *pp, *pp0, *pp1, *pp2;
	int nfree;
	struct PageInfo *fl;
	char *c;
	int i;

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
	assert((pp1 = page_alloc(0)));
	assert((pp2 = page_alloc(0)));

	assert(pp0);
	assert(pp1 && pp1 != pp0);
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
	assert(page2pa(pp0) < npages*PGSIZE);
	assert(page2pa(pp1) < npages*PGSIZE);
	assert(page2pa(pp2) < npages*PGSIZE);

	// temporarily steal the rest of the free pages
	fl = page_free_list;
	page_free_list = 0;

	// should be no free memory
	assert(!page_alloc(0));

	// free and re-allocate?
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
	assert((pp1 = page_alloc(0)));
	assert((pp2 = page_alloc(0)));
	assert(pp0);
	assert(pp1 && pp1 != pp0);
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
	assert(!page_alloc(0));

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;

	// free the pages we took
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
		--nfree;
	assert(nfree == 0);

	cprintf("check_page_alloc() succeeded!\n");
}

//
// Checks that the kernel part of virtual address space
// has been set up roughly correctly (by mem_init()).
//
// This function doesn't test every corner case,
// but it is a pretty good sanity check.
//

static void
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct PageInfo), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
	assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
		case PDX(UENVS):
			assert(pgdir[i] & PTE_P);
			break;
		default:
			if (i >= PDX(KERNBASE)) {
				assert(pgdir[i] & PTE_P);
				assert(pgdir[i] & PTE_W);
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
}

// This function returns the physical address of the page containing 'va',
// defined by the page directory 'pgdir'.  The hardware normally performs
// this functionality for us!  We define our own version to help check
// the check_kern_pgdir() function; it shouldn't be used elsewhere.

static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
}


// check page_insert, page_remove, &c
static void
check_page(void)
{
	struct PageInfo *pp, *pp0, *pp1, *pp2;
	struct PageInfo *fl;
	pte_t *ptep, *ptep1;
	void *va;
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
	assert((pp1 = page_alloc(0)));
	assert((pp2 = page_alloc(0)));

	assert(pp0);
	assert(pp1 && pp1 != pp0);
	assert(pp2 && pp2 != pp1 && pp2 != pp0);

	// temporarily steal the rest of the free pages
	fl = page_free_list;
	page_free_list = 0;

	// should be no free memory
	assert(!page_alloc(0));

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
	assert(pp1->pp_ref == 1);
	assert(pp0->pp_ref == 1);

	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
	assert(pp2->pp_ref == 1);

	// should be no free memory
	assert(!page_alloc(0));

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
	assert(pp2->pp_ref == 1);

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
	assert(pp2->pp_ref == 1);
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
	assert(kern_pgdir[0] & PTE_U);

	// should be able to remap with fewer permissions
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_W);
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);

	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
	assert(pp2->pp_ref == 0);

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
	assert(pp1->pp_ref == 1);
	assert(pp2->pp_ref == 0);

	// test re-inserting pp1 at PGSIZE
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, 0) == 0);
	assert(pp1->pp_ref);
	assert(pp1->pp_link == NULL);

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
	assert(pp1->pp_ref == 0);
	assert(pp2->pp_ref == 0);

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);

	// should be no free memory
	assert(!page_alloc(0));

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
	kern_pgdir[0] = 0;
	assert(pp0->pp_ref == 1);
	pp0->pp_ref = 0;

	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
	assert(ptep == ptep1 + PTX(va));
	kern_pgdir[PDX(va)] = 0;
	pp0->pp_ref = 0;

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
	pp0->pp_ref = 0;

	// give free list back
	page_free_list = fl;

	// free the pages we took
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	cprintf("check_page() succeeded!\n");
}

// check page_insert, page_remove, &c, with an installed kern_pgdir
static void
check_page_installed_pgdir(void)
{
	struct PageInfo *pp, *pp0, *pp1, *pp2;
	struct PageInfo *fl;
	pte_t *ptep, *ptep1;
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
	assert((pp1 = page_alloc(0)));
	assert((pp2 = page_alloc(0)));
	page_free(pp0);
	memset(page2kva(pp1), 1, PGSIZE);
	memset(page2kva(pp2), 2, PGSIZE);
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
	assert(pp1->pp_ref == 1);
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
	assert(pp2->pp_ref == 1);
	assert(pp1->pp_ref == 0);
	*(uint32_t *)PGSIZE = 0x03030303U;
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
	page_remove(kern_pgdir, (void*) PGSIZE);
	assert(pp2->pp_ref == 0);

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
	kern_pgdir[0] = 0;
	assert(pp0->pp_ref == 1);
	pp0->pp_ref = 0;

	// free the pages we took
	page_free(pp0);

	cprintf("check_page_installed_pgdir() succeeded!\n");
}
