/* See COPYRIGHT for copyright information. */

#ifndef JOS_KERN_PMAP_H
#define JOS_KERN_PMAP_H
#ifndef JOS_KERNEL
# error "This is a JOS kernel header; user programs should not #include it"
#endif

#include <inc/memlayout.h>
#include <inc/assert.h>

extern char bootstacktop[], bootstack[];

extern struct PageInfo *pages;
extern size_t npages;

extern pde_t *kern_pgdir;


/* This macro takes a kernel virtual address -- an address that points above
 * KERNBASE, where the machine's maximum 256MB of physical memory is mapped --
 * and returns the corresponding physical address.  It panics if you pass it a
 * non-kernel virtual address.
 * 该宏采用虚拟地址 -- 指向 KERNBASE 之上的地址，在该地址上映射了机器最大 256MB 的物理内存并返回相应的物理地址。
 * 如果向其传递一个非虚拟地址，它会产生 panic 异常。
 * 原理：
 * KADDR/_kaddr: 将物理地址转化成虚拟地址，也就是在物理地址的数值上加上了 KERNBASE。
 * PADDR/_paddr: 相应的反向过程将虚拟地址转化为物理地址，宏函数 PADDR 在输入的虚拟地址上减去 KERNBASE。
 */
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
}

/* This macro takes a physical address and returns the corresponding kernel
 * virtual address.  It panics if you pass an invalid physical address. */
// 宏函数 KADDR 调用了函数 _kaddr，将物理地址转化成虚拟地址，也就是在物理地址的数值上加上了 KERNBAE.
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
	return (void *)(pa + KERNBASE);
}


enum {
	// For page_alloc, zero the returned physical page.
	// 用于 page_alloc函数，将返回的物理页清零。
	ALLOC_ZERO = 1<<0,
};

void	mem_init(void);

void	page_init(void);
struct PageInfo *page_alloc(int alloc_flags);
void	page_free(struct PageInfo *pp);
int	page_insert(pde_t *pgdir, struct PageInfo *pp, void *va, int perm);
void	page_remove(pde_t *pgdir, void *va);
struct PageInfo *page_lookup(pde_t *pgdir, void *va, pte_t **pte_store);
void	page_decref(struct PageInfo *pp);

void	tlb_invalidate(pde_t *pgdir, void *va);

// 虚拟页转换为物理地址，physaddr_t(uint32_t) 自定义的物理地址类型
static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	// pages: 物理页的状态描述数组
	return (pp - pages) << PGSHIFT;			// (<<12 = *1000H = *PGSIZE)
}

// 物理地址转换为虚拟页
static inline struct PageInfo*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
	return &pages[PGNUM(pa)];
}

// 虚拟页->虚拟地址：将虚拟页转换为物理地址，再调用 KADDR 转换物理地址为虚拟地址
static inline void*
page2kva(struct PageInfo *pp)
{
	return KADDR(page2pa(pp));
}

pte_t *pgdir_walk(pde_t *pgdir, const void *va, int create);

#endif /* !JOS_KERN_PMAP_H */
