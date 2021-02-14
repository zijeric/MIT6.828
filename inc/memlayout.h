#ifndef JOS_INC_MEMLAYOUT_H
#define JOS_INC_MEMLAYOUT_H

#ifndef __ASSEMBLER__
#include <inc/types.h>
#include <inc/mmu.h>
#endif /* not __ASSEMBLER__ */

/*
 * This file contains definitions for memory management in our OS,
 * which are relevant to both the kernel and user-mode software.
 */

// Global descriptor numbers
#define GD_KT     0x08     // kernel text
#define GD_KD     0x10     // kernel data
#define GD_UT     0x18     // user text
#define GD_UD     0x20     // user data
#define GD_TSS0   0x28     // Task segment selector for CPU 0

/**
 * JOS处理器的32位线性地址空间分为两部分，内核控制 ULIM 分割线以上的部分，为内核保留大约256MB(0xf000000-0xffffffff)的虚拟地址空间，
 * 用户环境控制下方部分，约3.72G(0x0-0xef800000)。
 *
 * 用户环境将没有对以上 ULIM 内存的任何权限，只有内核能够读写这个内存；
 * [UTOP, ULIM]，内核和用户环境都可以读取但不能写入这个地址范围，此地址范围用于向用户环境公开某些只读内核数据结构；
 * UTOP 下的地址空间供用户环境使用;用户环境将设置访问此内存的权限。
 */
/*
 * Virtual memory map:                                Permissions
 *                                                    kernel/user
 *
 *    4 Gig -------->  +------------------------------+
 *                     |                              | RW/--
 *                     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 *                     :              .               :
 *                     :              .               :
 *                     :              .               :
 *                     |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~| RW/--
 *                     |                              | RW/--
 *                     |   Remapped Physical Memory   | RW/--
 *                     |                              | RW/--
 *    KERNBASE, ---->  +------------------------------+ 0xf0000000      --+
 *    KSTACKTOP        |     CPU0's Kernel Stack      | RW/--  KSTKSIZE   |
 *                     | - - - - - - - - - - - - - - -|                   |
 *                     |      Invalid Memory (*)      | --/--  KSTKGAP    |
 *                     +------------------------------+                   |
 *                     |     CPU1's Kernel Stack      | RW/--  KSTKSIZE   |
 *                     | - - - - - - - - - - - - - - -|                 PTSIZE
 *                     |      Invalid Memory (*)      | --/--  KSTKGAP    |
 *                     +------------------------------+                   |
 *                     :              .               :                   |
 *                     :              .               :                   |
 *    MMIOLIM ------>  +------------------------------+ 0xefc00000      --+
 *                     |       Memory-mapped I/O      | RW/--  PTSIZE
 * ULIM, MMIOBASE -->  +------------------------------+ 0xef800000
 *                     |  Cur. Page Table (User R-)   | R-/R-  PTSIZE
 *    UVPT      ---->  +------------------------------+ 0xef400000
 *                     |          RO PAGES            | R-/R-  PTSIZE
 *    UPAGES    ---->  +------------------------------+ 0xef000000
 *                     |           RO ENVS            | R-/R-  PTSIZE
 * UTOP,UENVS ------>  +------------------------------+ 0xeec00000
 * UXSTACKTOP -/       |     User Exception Stack     | RW/RW  PGSIZE
 *                     +------------------------------+ 0xeebff000
 *                     |       Empty Memory (*)       | --/--  PGSIZE
 *    USTACKTOP  --->  +------------------------------+ 0xeebfe000
 *                     |      Normal User Stack       | RW/RW  PGSIZE
 *                     +------------------------------+ 0xeebfd000
 *                     |                              |
 *                     |                              |
 *                     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 *                     .                              .
 *                     .                              .
 *                     .                              .
 *                     |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|
 *                     |     Program Data & Heap      |
 *    UTEXT -------->  +------------------------------+ 0x00800000
 *    PFTEMP ------->  |       Empty Memory (*)       |        PTSIZE
 *                     |                              |
 *    UTEMP -------->  +------------------------------+ 0x00400000      --+
 *                     |       Empty Memory (*)       |                   |
 *                     | - - - - - - - - - - - - - - -|                   |
 *                     |  User STAB Data (optional)   |                 PTSIZE
 *    USTABDATA ---->  +------------------------------+ 0x00200000        |
 *                     |       Empty Memory (*)       |                   |
 *    0 ------------>  +------------------------------+                 --+
 *
 * (*) Note: The kernel ensures that "Invalid Memory" is *never* mapped.
 *     "Empty Memory" is normally unmapped, but user programs may map pages
 *     there if desired.  JOS user programs map pages temporarily at UTEMP.
 */


// All physical memory mapped at this address
// 所有物理内存地址映射到该地址 0xF0000000 (VA)
#define	KERNBASE	0xF0000000

// At IOPHYSMEM (640K) there is a 384K hole for I/O.  From the kernel,
// IOPHYSMEM can be addressed at KERNBASE + IOPHYSMEM.  The hole ends
// at physical address EXTPHYSMEM.
#define IOPHYSMEM	0x0A0000
#define EXTPHYSMEM	0x100000

// Kernel stack.
#define KSTACKTOP	KERNBASE
#define KSTKSIZE	(8*PGSIZE)   		// size of a kernel stack
#define KSTKGAP		(8*PGSIZE)   		// size of a kernel stack guard 内核栈保护大小

// Memory-mapped IO.  (PTSIZE = 4096*1024 = 0x400000)
#define MMIOLIM		(KSTACKTOP - PTSIZE)    // 0xf0000000 - 4KB = 0xefc00000
#define MMIOBASE	(MMIOLIM - PTSIZE)      // 0xefc00000 - 4KB = 0xef800000

#define ULIM		(MMIOBASE)				// 0xef800000

/*
 * User read-only mappings! Anything below here til UTOP are readonly to user.
 * They are global pages mapped in at env allocation time.
 * 用户只读映射！[UVPT, UTOP]的所有内容对用户都是只读的。它们是在环境分配时映射的全局页。
 */

// User read-only virtual page table (see 'uvpt' below)
#define UVPT		(ULIM - PTSIZE)
// Read-only copies of the Page structures
#define UPAGES		(UVPT - PTSIZE)
// Read-only copies of the global env structures
#define UENVS		(UPAGES - PTSIZE)

/*
 * Top of user VM. User can manipulate VA from UTOP-1 and down!
 * 用户 VM 的顶部。用户可以从 UTOP-1 向下操作 VA
 */

// Top of user-accessible VM
#define UTOP		UENVS
// Top of one-page user exception stack
#define UXSTACKTOP	UTOP
// Next page left invalid to guard against exception stack overflow; then:
// Top of normal user stack
// 为防止异常堆栈溢出，下一页无效； 然后：普通用户堆栈的顶部
#define USTACKTOP	(UTOP - 2*PGSIZE)

// Where user programs generally begin
#define UTEXT		(2*PTSIZE)				// 0x00800000

// Used for temporary page mappings.  Typed 'void*' for convenience
// 用于临时页映射。类型为'void *'，方便转换为任何类型
#define UTEMP		((void*) PTSIZE)		// 0x00400000
// Used for temporary page mappings for the user page-fault handler
// (should not conflict with other temporary page mappings)
// 用于用户页故障处理程序的临时页映射（不应与其他临时页映射冲突）
#define PFTEMP		(UTEMP + PTSIZE - PGSIZE)	// 0x7ff000
// The location of the user-level STABS data structure
// 用户级 STABS 数据结构的位置
#define USTABDATA	(PTSIZE / 2)

#ifndef __ASSEMBLER__

typedef uint32_t pte_t;
typedef uint32_t pde_t;

#if JOS_USER
/*
 * The page directory entry corresponding to the virtual address range
 * [UVPT, UVPT + PTSIZE) points to the page directory itself.  Thus, the page
 * directory is treated as a page table as well as a page directory.
 *
 * One result of treating the page directory as a page table is that all PTEs
 * can be accessed through a "virtual page table" at virtual address UVPT (to
 * which uvpt is set in lib/entry.S).  The PTE for page number N is stored in
 * uvpt[N].  (It's worth drawing a diagram of this!)
 *
 * A second consequence is that the contents of the current page directory
 * will always be available at virtual address (UVPT + (UVPT >> PGSHIFT)), to
 * which uvpd is set in lib/entry.S.
 * 与虚拟地址范围 [UVPT，UVPT + PTSIZE) 对应的 page目录条目指向 page目录本身。
 * 因此， page目录被视为页表以及 page目录(page目录也是页表)。
 * 将 page目录视为页表的一个结果是，
 * 1.所有 (PTE *) 都可以通过虚拟地址 UVPT 上的“虚拟页表”（在lib/entry.S中设置了 uvpt）进行访问。
 * 页号为 N 的 PTE 存储在 uvpt[N] 中。（值得为此绘制一个图表！）
 * 2.第二个结果是，当前 page目录的内容始终在虚拟地址 UVPT +（UVPT >> PGSHIFT）上可用，
 * 在 lib/entry.S 中设置 uvpd。
 */
extern volatile pte_t uvpt[];     // VA of "virtual page table"
extern volatile pde_t uvpd[];     // VA of current page directory
#endif

/*
 * Page descriptor structures, mapped at UPAGES.
 * Read/write to the kernel, read-only to user programs.
 *
 * Each struct PageInfo stores metadata for one physical page.
 * Is it NOT the physical page itself, but there is a one-to-one
 * correspondence between physical pages and struct PageInfo's.
 * You can map a struct PageInfo * to the corresponding physical address
 * with page2pa() in kern/pmap.h.
 *
 * 页结构，映射到 UPAGES
 * 内核: 读/写，用户程序: 只读
 * 
 * 每个 PageInfo 结构体存储一个物理页的元数据
 * 不是物理页本身，而是物理页和 struct PageInfo 之间的一对一的对应关系。
 * 您可以将结构 (PageInfo*) 映射到相应的物理地址
 * 与 kern/pmap.h 中的 page2pa() 一起使用。
 */ 
struct PageInfo {
	// Next page on the free list.
	// 用于pageInfo链表管理，指向空闲列表中的下一个页(结构)
	struct PageInfo *pp_link;

	// pp_ref is the count of pointers (usually in page table entries)
	// to this page, for pages allocated using page_alloc.
	// Pages allocated at boot time using pmap.c's
	// boot_alloc do not have valid reference count fields.
	// 该物理页被引用的次数，即被(map)映射到虚拟地址的数量（通常在页表条目中）
	// 当引用数为 0，即可释放
	uint16_t pp_ref;
};

#endif /* !__ASSEMBLER__ */
#endif /* !JOS_INC_MEMLAYOUT_H */
