#ifndef JOS_INC_MMU_H
#define JOS_INC_MMU_H

/*
 * This file contains definitions for the x86 memory management unit (MMU),
 * including paging- and segmentation-related data structures and constants,
 * the %cr0, %cr4, and %eflags registers, and traps.
 */

/*
 *
 *	Part 1.  分页需要的数据机构和常数.
 *
 */

// 线性地址“ la”有三部分结构，如下：
// 
// +--------10------+-------10-------+---------12----------+
// | Page Directory |   Page Table   | Offset within Page  |
// |      Index     |      Index     |                     |
// +----------------+----------------+---------------------+
//  \--- PDX(la) --/ \--- PTX(la) --/ \---- PGOFF(la) ----/
//  \---------- PGNUM(la) ----------/
//
// PDX、PTX、PGOFF 和 PGNUM 宏分解线性地址，如下所示。
// 从 PDX (la)、PTX(la)和 PGOFF(la)构造线性地址 la，
// 使用 PGADDR(PDX(la)，PTX(la)，PGOFF(la))。

// (page directory index + page table index) 右移12位
#define PGNUM(la)	(((uintptr_t) (la)) >> PTXSHIFT)

// page directory index	右移22位，与操作只保留低10位(9~0)
#define PDX(la)		((((uintptr_t) (la)) >> PDXSHIFT) & 0x3FF)

// page table index		右移12位，与操作只保留低10位(9~0)
#define PTX(la)		((((uintptr_t) (la)) >> PTXSHIFT) & 0x3FF)

// offset in page: page frame index		与操作只保留低12位(11~0)
#define PGOFF(la)	(((uintptr_t) (la)) & 0xFFF)

// 由索引和偏移构造线性地址
#define PGADDR(d, t, o)	((void*) ((d) << PDXSHIFT | (t) << PTXSHIFT | (o)))

// Page directory and page table constants.
#define NPDENTRIES	1024		// 每个页目录的 pde 数目为1024
#define NPTENTRIES	1024		// 每个页表页的 pte 数目为1024

#define PGSIZE		4096		// 一个物理页映射的字节数，即页大小为4096，4KB
#define PGSHIFT		12			// log2(PGSIZE)

#define PTSIZE		(PGSIZE*NPTENTRIES) // 一个页表对应实际物理内存的大小，即1024 * 4KB = 4MB
#define PTSHIFT		22		// log2(PTSIZE)

#define PTXSHIFT	12		// 线性地址中页表页索引的偏移
#define PDXSHIFT	22		// 线性地址中页目录索引的偏移

// 页目录表/页表的权限位，在访问对应页时CPU会自动地判断，如果访问违规，会产生异常
#define PTE_P		0x001	// Present		存在位
#define PTE_W		0x002	// Writeable	可写位，同时影响 kernel 和 user
#define PTE_U		0x004	// User			用户1->(0,1,2,3), 管理员0->(0,1,2)
#define PTE_PWT		0x008	// Write-Through	页级通写位，内存 or 高速缓存
#define PTE_PCD		0x010	// Cache-Disable	页级高速缓存禁止位
#define PTE_A		0x020	// Accessed		访问位，由CPU设置，1:已访问可换出到外存
#define PTE_D		0x040	// Dirty		脏页位，针对页表项，CPU写时置为1
#define PTE_PS		0x080	// Page Size	页大小位，0:4KB, 1:4MB
#define PTE_G		0x100	// Global		全局位，是否为全局页，即存储在TLB

// The PTE_AVAIL bits aren't used by the kernel or interpreted by the
// hardware, so user processes are allowed to set them arbitrarily.
#define PTE_AVAIL	0xE00	// Available for software use

// Flags in PTE_SYSCALL may be used in system calls.  (Others may not.)
#define PTE_SYSCALL	(PTE_AVAIL | PTE_P | PTE_W | PTE_U)

// 返回页表(页目录项)中的PPN索引，将低12位(0~11) Flags 状态位置为0
#define PTE_ADDR(pte)	((physaddr_t) (pte) & ~0xFFF)

// Control Register flags
#define CR0_PE		0x00000001	// Protection Enable
#define CR0_MP		0x00000002	// Monitor coProcessor
#define CR0_EM		0x00000004	// Emulation
#define CR0_TS		0x00000008	// Task Switched
#define CR0_ET		0x00000010	// Extension Type
#define CR0_NE		0x00000020	// Numeric Error
#define CR0_WP		0x00010000	// Write Protect
#define CR0_AM		0x00040000	// Alignment Mask
#define CR0_NW		0x20000000	// Not Writethrough
#define CR0_CD		0x40000000	// Cache Disable
#define CR0_PG		0x80000000	// Paging

#define CR4_PCE		0x00000100	// Performance counter enable
#define CR4_MCE		0x00000040	// Machine Check Enable
#define CR4_PSE		0x00000010	// Page Size Extensions
#define CR4_DE		0x00000008	// Debugging Extensions
#define CR4_TSD		0x00000004	// Time Stamp Disable
#define CR4_PVI		0x00000002	// Protected-Mode Virtual Interrupts
#define CR4_VME		0x00000001	// V86 Mode Extensions

// Eflags register
#define FL_CF		0x00000001	// Carry Flag
#define FL_PF		0x00000004	// Parity Flag
#define FL_AF		0x00000010	// Auxiliary carry Flag
#define FL_ZF		0x00000040	// Zero Flag
#define FL_SF		0x00000080	// Sign Flag
#define FL_TF		0x00000100	// Trap Flag
#define FL_IF		0x00000200	// Interrupt Flag
#define FL_DF		0x00000400	// Direction Flag
#define FL_OF		0x00000800	// Overflow Flag
#define FL_IOPL_MASK	0x00003000	// I/O Privilege Level bitmask
#define FL_IOPL_0	0x00000000	//   IOPL == 0
#define FL_IOPL_1	0x00001000	//   IOPL == 1
#define FL_IOPL_2	0x00002000	//   IOPL == 2
#define FL_IOPL_3	0x00003000	//   IOPL == 3
#define FL_NT		0x00004000	// Nested Task
#define FL_RF		0x00010000	// Resume Flag
#define FL_VM		0x00020000	// Virtual 8086 mode
#define FL_AC		0x00040000	// Alignment Check
#define FL_VIF		0x00080000	// Virtual Interrupt Flag
#define FL_VIP		0x00100000	// Virtual Interrupt Pending
#define FL_ID		0x00200000	// ID flag

// Page fault error codes
#define FEC_PR		0x1	// Page fault caused by protection violation
#define FEC_WR		0x2	// Page fault caused by a write
#define FEC_U		0x4	// Page fault occured while in user mode


/*
 *
 *	Part 2.  分段需要的数据结构和常数.
 *
 */

#ifdef __ASSEMBLER__

/*
 * Macros to build GDT entries in assembly.
 */
#define SEG_NULL						\
	.word 0, 0;						\
	.byte 0, 0, 0, 0
#define SEG(type,base,lim)					\
	.word (((lim) >> 12) & 0xffff), ((base) & 0xffff);	\
	.byte (((base) >> 16) & 0xff), (0x90 | (type)),		\
		(0xC0 | (((lim) >> 28) & 0xf)), (((base) >> 24) & 0xff)

#else	// not __ASSEMBLER__

#include <inc/types.h>

// Segment Descriptors
struct Segdesc {
	unsigned sd_lim_15_0 : 16;  // Low bits of segment limit
	unsigned sd_base_15_0 : 16; // Low bits of segment base address
	unsigned sd_base_23_16 : 8; // Middle bits of segment base address
	unsigned sd_type : 4;       // Segment type (see STS_ constants)
	unsigned sd_s : 1;          // 0 = system, 1 = application
	unsigned sd_dpl : 2;        // Descriptor Privilege Level
	unsigned sd_p : 1;          // Present
	unsigned sd_lim_19_16 : 4;  // High bits of segment limit
	unsigned sd_avl : 1;        // Unused (available for software use)
	unsigned sd_rsv1 : 1;       // Reserved
	unsigned sd_db : 1;         // 0 = 16-bit segment, 1 = 32-bit segment
	unsigned sd_g : 1;          // Granularity: limit scaled by 4K when set
	unsigned sd_base_31_24 : 8; // High bits of segment base address
};
// Null segment
#define SEG_NULL	{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
// Segment that is loadable but faults when used
#define SEG_FAULT	{ 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0 }
// Normal segment
#define SEG(type, base, lim, dpl) 					\
{ ((lim) >> 12) & 0xffff, (base) & 0xffff, ((base) >> 16) & 0xff,	\
    type, 1, dpl, 1, (unsigned) (lim) >> 28, 0, 0, 1, 1,		\
    (unsigned) (base) >> 24 }
#define SEG16(type, base, lim, dpl) (struct Segdesc)			\
{ (lim) & 0xffff, (base) & 0xffff, ((base) >> 16) & 0xff,		\
    type, 1, dpl, 1, (unsigned) (lim) >> 16, 0, 0, 1, 0,		\
    (unsigned) (base) >> 24 }

#endif /* !__ASSEMBLER__ */

// Application segment type bits
#define STA_X		0x8	    // Executable segment
#define STA_E		0x4	    // Expand down (non-executable segments)
#define STA_C		0x4	    // Conforming code segment (executable only)
#define STA_W		0x2	    // Writeable (non-executable segments)
#define STA_R		0x2	    // Readable (executable segments)
#define STA_A		0x1	    // Accessed

// System segment type bits
#define STS_T16A	0x1	    // Available 16-bit TSS
#define STS_LDT		0x2	    // Local Descriptor Table
#define STS_T16B	0x3	    // Busy 16-bit TSS
#define STS_CG16	0x4	    // 16-bit Call Gate
#define STS_TG		0x5	    // Task Gate / Coum Transmitions
#define STS_IG16	0x6	    // 16-bit Interrupt Gate
#define STS_TG16	0x7	    // 16-bit Trap Gate
#define STS_T32A	0x9	    // Available 32-bit TSS
#define STS_T32B	0xB	    // Busy 32-bit TSS
#define STS_CG32	0xC	    // 32-bit Call Gate
#define STS_IG32	0xE	    // 32-bit Interrupt Gate
#define STS_TG32	0xF	    // 32-bit Trap Gate


/*
 *
 *	Part 3.  Traps.
 *
 */

#ifndef __ASSEMBLER__

// 任务状态段TSS(Task state segment)格式  (参照奔腾架构书)
struct Taskstate {
	uint32_t ts_link;	// 前-任务状态选择子
	uintptr_t ts_esp0;	// 栈指针
	uint16_t ts_ss0;	// 提高特权级别为0之后，使用ss0:esp0定义内核栈的位置
	uint16_t ts_padding1;
	uintptr_t ts_esp1;
	uint16_t ts_ss1;
	uint16_t ts_padding2;
	uintptr_t ts_esp2;
	uint16_t ts_ss2;
	uint16_t ts_padding3;
	physaddr_t ts_cr3;	// 页目录基址
	uintptr_t ts_eip;	// 保存上次任务切换的状态
	uint32_t ts_eflags;
	uint32_t ts_eax;	// 保存x86所有寄存器
	uint32_t ts_ecx;
	uint32_t ts_edx;
	uint32_t ts_ebx;
	uintptr_t ts_esp;
	uintptr_t ts_ebp;
	uint32_t ts_esi;
	uint32_t ts_edi;
	uint16_t ts_es;		// 保存x86所有段选择子
	uint16_t ts_padding4;
	uint16_t ts_cs;
	uint16_t ts_padding5;
	uint16_t ts_ss;
	uint16_t ts_padding6;
	uint16_t ts_ds;
	uint16_t ts_padding7;
	uint16_t ts_fs;
	uint16_t ts_padding8;
	uint16_t ts_gs;
	uint16_t ts_padding9;
	uint16_t ts_ldt;
	uint16_t ts_padding10;
	uint16_t ts_t;		// Trap on task switch
	uint16_t ts_iomb;	// I/O 映射基址
};

// interrupts and traps gate 的描述符结构体
// 优先级低的代码无法访问优先级高的代码，优先级高低由 gd_dpl 判断。数字越小越高
struct Gatedesc {
	unsigned gd_off_15_0 : 16;   // 段中低16位的偏移量
	unsigned gd_sel : 16;        // 段选择子
	unsigned gd_args : 5;        // # args, 0: interrupt/trap gates
	unsigned gd_rsv1 : 3;        // 保留位(should be zero I guess)
	unsigned gd_type : 4;        // 类型(STS_{TG,IG32,TG32})
	unsigned gd_s : 1;           // 必须为0 (system)
	unsigned gd_dpl : 2;         // 描述符(新的)特权级别
	unsigned gd_p : 1;           // 存在位
	unsigned gd_off_31_16 : 16;  // 段中高16位的偏移量
};

// 设置正常的 interrupt/trap gate 描述符。
// - istrap: 1->trap(=exception)gate，0->interrupt gate
	//	根据i386参考文献的9.6.1.3部分:“interrupt gate和trap gate的区别在于对 IF(interrupt-enable中断使能标志) 的影响
	//	通过 interrupt gate 引导的中断会将IF标志位复位，从而防止其他中断干扰当前的 中断处理程序(interrupt handler)
	//	随后的 IRET指令 将IF标志位恢复到栈上的 EFLAGS 映像中的值
	//	但是，通过 trap(=exception)gate 的中断不会改变IF标志位. ”
// - sel: interrupt/trap handler 的代码段选择子
// - off: interrupt/trap handler 的代码段中的偏移量
// - dpl: 描述符特权级别(DPL) -
//    软件使用 int 指令显式调用该 interrupt/trap gate 所需的特权级别
#define SETGATE(gate, istrap, sel, off, dpl)			\
{								\
	(gate).gd_off_15_0 = (uint32_t) (off) & 0xffff;		\
	(gate).gd_sel = (sel);					\
	(gate).gd_args = 0;					\
	(gate).gd_rsv1 = 0;					\
	(gate).gd_type = (istrap) ? STS_TG32 : STS_IG32;	\
	(gate).gd_s = 0;					\
	(gate).gd_dpl = (dpl);					\
	(gate).gd_p = 1;					\
	(gate).gd_off_31_16 = (uint32_t) (off) >> 16;		\
}

// Set up a call gate descriptor.
#define SETCALLGATE(gate, sel, off, dpl)           	        \
{								\
	(gate).gd_off_15_0 = (uint32_t) (off) & 0xffff;		\
	(gate).gd_sel = (sel);					\
	(gate).gd_args = 0;					\
	(gate).gd_rsv1 = 0;					\
	(gate).gd_type = STS_CG32;				\
	(gate).gd_s = 0;					\
	(gate).gd_dpl = (dpl);					\
	(gate).gd_p = 1;					\
	(gate).gd_off_31_16 = (uint32_t) (off) >> 16;		\
}

// Pseudo-descriptors used for LGDT, LLDT and LIDT instructions.
struct Pseudodesc {
	uint16_t pd_lim;		// 界限Limit
	uint32_t pd_base;		// 基址Base
} __attribute__ ((packed));

#endif /* !__ASSEMBLER__ */

#endif /* !JOS_INC_MMU_H */
