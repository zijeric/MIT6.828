/* See COPYRIGHT for copyright information. */

#include <inc/x86.h>
#include <inc/mmu.h>
#include <inc/error.h>
#include <inc/string.h>
#include <inc/assert.h>

#include <kern/pmap.h>
#include <kern/kclock.h>

// These variables are set by i386_detect_memory()
size_t npages;					// 物理内存量（以页为单位）
static size_t npages_basemem;	// 基本内存量（以页为单位）

// These variables are set in mem_init()
pde_t *kern_pgdir;			// Kernel's initial page directory
// 所有 Page 在内存（物理内存）中的存放是连续的，存放于 pages 处，可以通过数组的形式访问各个 Page，
// 而 pages 紧接于 kern_pgdir 页目录之上，对应物理和虚拟内存布局也就是在kernel向上的紧接着的高地址部分连续分布着 pages 数组。
// Physical page state array 页数组，数组中第 i 个成员代表内存中第 i 个 page，因此，物理地址和数组索引很方便相换算。
struct PageInfo *pages;
static struct PageInfo *page_free_list;	// Free list of physical pages

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

// 直接调用硬件查看可以使用的内存大小 
// (更新全局变量 npages:总内存所需物理页的数目 & npages_basemem:0x000A0000，IO hole之前)
static void
i386_detect_memory(void)
{
	size_t basemem, extmem, ext16mem, totalmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	// 调用 CMOS 来测量可用的基本内存和扩展内存。（CMOS 调用返回的结果以千字节（KB）为单位。）
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

	// CMOS 调用返回的结果以千字节（KB）为单位
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

// boot_alloc(n)是个简单的内存分配器，这个简单的物理内存分配器只在JOS设置其虚拟内存系统时使用。page_alloc()是真正的分配器。
// This simple physical memory allocator is used only while JOS is setting
// up its virtual memory system.  page_alloc() is the real allocator.
//
// 如果 n>0，则分配足够的连续物理内存页以容纳'n'个字节。
// 不初始化内存。返回内核虚拟地址。
// If n>0, allocates enough pages of contiguous physical memory to hold 'n'
// bytes.  Doesn't initialize the memory.  Returns a kernel virtual address.
//
// 如果 n==0，则不分配任何内容就返回下一个空闲页的地址。
// If n==0, returns the address of the next free page without allocating
// anything.
//
// 如果我们内存不足，boot_alloc 应该会崩溃。
// 仅在初始化 page_free_list 列表之前，才会调用此函数。
// If we're out of memory, boot_alloc should panic.
// This function may ONLY be used during initialization,
// before the page_free_list list has been set up.
static void *
boot_alloc(uint32_t n)
{
	// 下一个空闲内存的首字节虚拟地址
	static char *nextfree;	// virtual address of next byte of free memory
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

	// 分配足够大的块以容纳 'n' 个字节，然后更新 nextfree
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
			nextfree = result;		// 还原 nextfree
			result = NULL;
		}
	}
	cprintf("boot_alloc memory at %x, next memory allocate at %x\n", result, nextfree);
	return result;
}

// Set up a two-level page table:
//    kern_pgdir is its linear (virtual) address of the root
//
// This function only sets up the kernel part of the address space
// (ie. addresses >= UTOP).  The user part of the address space
// will be set up later.
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
// 设置二级页表：
//   kern_pgdir 是其 root 的线性（虚拟）地址
// 此函数仅设置地址空间的内核部分（即地址 >= UTOP），地址空间的用户部分稍后再设置。
// 从 UTOP 到 ULIM，允许用户读取但不能写入。在 ULIM 之上，用户无法读取或写入。
void
mem_init(void)
{
	uint32_t cr0;
	size_t n;

	// Find out how much memory the machine has (npages & npages_basemem).
	// 1.通过汇编指令直接调用硬件查看可以使用的内存大小 (底层 kern/kclock.c)
	// 其中得到的内存信息是整数 npages，代表现有内存的 page 个数(所需 PageInfo 结构体的数量)
	i386_detect_memory();

	// Remove this line when you're ready to test this function.
	// panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	// 2.创建一个正式的页目录(一个页的大小)替换在kern/entry.S的entry_pgdir，并设置权限。
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);
	memset(kern_pgdir, 0, PGSIZE);

	//////////////////////////////////////////////////////////////////////
	// Recursively insert PD in itself as a page table, to form
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following line.)
	// 递归地将页目录 PD 本身作为页表插入，以在虚拟地址 UVPT 处形成一个虚拟页表。
	//（到目前为止，您还不了解下一行的更多用途。）

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;

	//////////////////////////////////////////////////////////////////////
	// Allocate an array of npages 'struct PageInfo's and store it in 'pages'.
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct PageInfo in this
	// array.  'npages' is the number of physical pages in memory.  Use memset
	// to initialize all fields of each struct PageInfo to 0.
	// 分配 npages 个 PageInfo 结构体的数组并将其存储在 'pages' 中。
	// 内核使用 pages 数组来跟踪物理页面：
	// pages数组的每一项是一个PageInfo结构，对应一个物理页的信息，定义在inc/memlayout.h中
	// "npages"是内存需要的物理页数。调用 memset 将每个PageInfo结构体的所有字段初始化为 0。
	// Your code goes here:
	uint32_t page_mem = npages * sizeof(struct PageInfo);
	pages = (struct PageInfo *)boot_alloc(page_mem);
	// void pointer，任何类型的指针都可以直接赋值给它，无需进行强制类型转换
	// 指针的类型用于每取多少字节将其视为对应类型的值 (char:1, int:2)
	memset(pages, 0, page_mem);
	cprintf("pages in pmap.c: %08x", pages);

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
	// Map 'pages' read-only by the user at linear address UPAGES
	// Permissions:
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:

	//////////////////////////////////////////////////////////////////////
	// Use the physical memory that 'bootstack' refers to as the kernel
	// stack.  The kernel stack grows down from virtual address KSTACKTOP.
	// We consider the entire range from [KSTACKTOP-PTSIZE, KSTACKTOP)
	// to be the kernel stack, but break this into two pieces:
	//     * [KSTACKTOP-KSTKSIZE, KSTACKTOP) -- backed by physical memory
	//     * [KSTACKTOP-PTSIZE, KSTACKTOP-KSTKSIZE) -- not backed; so if
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:

	//////////////////////////////////////////////////////////////////////
	// Map all of physical memory at KERNBASE.
	// Ie.  the VA range [KERNBASE, 2^32) should map to
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:

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
//
// 初始化页结构和空闲内存列表。完成此操作后，请勿再使用boot_alloc。
// 仅使用下面的页分配器函数 page_init 来分配和释放由 page_free_list 进行存储的物理内存。
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

//
// Allocates a physical page.  If (alloc_flags & ALLOC_ZERO), fills the entire
// returned physical page with '\0' bytes.  Does NOT increment the reference
// count of the page - the caller must do these if necessary (either explicitly
// or via page_insert).
//
// Be sure to set the pp_link field of the allocated page to NULL so
// page_free can check for double-free bugs.
//
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct PageInfo *
page_alloc(int alloc_flags)
{
	// 获取空闲页链表的第一个页结点
	struct PageInfo *ret = page_free_list;

	// 还存在空闲的内存，更新空闲页链表
	if(ret != NULL) {
		// 将`page_init()`组织的空闲页链表`page_free_list`的第一个页结点取出，将头指针指向下一个页结点
		// 空闲页链表page_free_list指向*准备取出的页结点*的下一个页结点
		page_free_list = ret->pp_link;
		// 将*准备取出的页结点*的pp_link设置为NULL来进行双重错误检查
		ret->pp_link = NULL;
		// alloc_flags 和 ALLOC_ZERO 进行与运算，1:需要将返回的页清零
		if(alloc_flags & ALLOC_ZERO) {
			// 获取*准备取出的页结点*对应的虚拟地址
			char *kvaddr = page2kva(ret);
			// 调用 memset 函数将*准备取出的页结点*初始化
			memset(kvaddr, 0, PGSIZE);
		}
		return ret;
	} 
	// 无空闲内存，返回NULL
	else {
		cprintf("page_alloc: out of free memory!\n");
		return NULL;
	}
}

//
// 将一个页面返回到空闲列表。(只有当 pp->pp_ref 等于0时才应该调用page_free)
//
void
page_free(struct PageInfo *pp)
{
	// Hint: You may want to panic if pp->pp_ref is nonzero or
	// pp->pp_link is not NULL.
	if (pp->pp_ref != 0 || pp->pp_link != NULL)
	{
		panic("page_free: pp->pp_ref is nonzero or pp->pp_link is not NULL\n");
	}
	// 向空闲页链表添加元素
	pp->pp_link = page_free_list;
	// 更新空闲页链表头
	page_free_list = pp;
}

//
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct PageInfo* pp)
{
	if (--pp->pp_ref == 0)
		page_free(pp);
}

// Given 'pgdir', a pointer to a page directory, pgdir_walk returns
// a pointer to the page table entry (PTE) for linear address 'va'.
// This requires walking the two-level page table structure.
//
// The relevant page table page might not exist yet.
// If this is true, and create == false, then pgdir_walk returns NULL.
// Otherwise, pgdir_walk allocates a new page table page with page_alloc.
//    - If the allocation fails, pgdir_walk returns NULL.
//    - Otherwise, the new page's reference count is incremented,
//	the page is cleared,
//	and pgdir_walk returns a pointer into the new page table page.
//
// Hint 1: you can turn a PageInfo * into the physical address of the
// page it refers to with page2pa() from kern/pmap.h.
//
// Hint 2: the x86 MMU checks permission bits in both the page directory
// and the page table, so it's safe to leave permissions in the page
// directory more permissive than strictly necessary.
//
// Hint 3: look at inc/mmu.h for useful macros that manipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
	// Fill this function in
	return NULL;
}

//
// Map [va, va+size) of virtual address space to physical [pa, pa+size)
// in the page table rooted at pgdir.  Size is a multiple of PGSIZE, and
// va and pa are both page-aligned.
// Use permission bits perm|PTE_P for the entries.
//
// This function is only intended to set up the ``static'' mappings
// above UTOP. As such, it should *not* change the pp_ref field on the
// mapped pages.
//
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	// Fill this function in
}

//
// Map the physical page 'pp' at virtual address 'va'.
// The permissions (the low 12 bits) of the page table entry
// should be set to 'perm|PTE_P'.
//
// Requirements
//   - If there is already a page mapped at 'va', it should be page_remove()d.
//   - If necessary, on demand, a page table should be allocated and inserted
//     into 'pgdir'.
//   - pp->pp_ref should be incremented if the insertion succeeds.
//   - The TLB must be invalidated if a page was formerly present at 'va'.
//
// Corner-case hint: Make sure to consider what happens when the same
// pp is re-inserted at the same virtual address in the same pgdir.
// However, try not to distinguish this case in your code, as this
// frequently leads to subtle bugs; there's an elegant way to handle
// everything in one code path.
//
// RETURNS:
//   0 on success
//   -E_NO_MEM, if page table couldn't be allocated
//
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct PageInfo *pp, void *va, int perm)
{
	// Fill this function in
	return 0;
}

//
// Return the page mapped at virtual address 'va'.
// If pte_store is not zero, then we store in it the address
// of the pte for this page.  This is used by page_remove and
// can be used to verify page permissions for syscall arguments,
// but should not be used by most callers.
//
// Return NULL if there is no page mapped at va.
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct PageInfo *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
	// Fill this function in
	return NULL;
}

//
// Unmaps the physical page at virtual address 'va'.
// If there is no physical page at that address, silently does nothing.
//
// Details:
//   - The ref count on the physical page should decrement.
//   - The physical page should be freed if the refcount reaches 0.
//   - The pg table entry corresponding to 'va' should be set to 0.
//     (if such a PTE exists)
//   - The TLB must be invalidated if you remove an entry from
//     the page table.
//
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
	// Fill this function in
}

//
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
	// Flush the entry only if we're modifying the current address space.
	// For now, there is only one address space, so always invalidate.
	invlpg(va);
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
