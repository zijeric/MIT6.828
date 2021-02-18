/* See COPYRIGHT for copyright information. */

#include <inc/mmu.h>
#include <inc/memlayout.h>

# Shift Right Logical 
#define SRL(val, shamt)		(((val) >> (shamt)) & ~(-1 << (32 - (shamt))))


###################################################################
# The kernel (this code) is linked at address ~(KERNBASE + 1 Meg), 
# but the bootloader loads it at address ~1 Meg.
# 内核(这段代码)被链接到地址 ~(KERNBASE + 1 Meg)，
# 但是bootloader在地址 ~1Meg 加载它。
#
# RELOC(x) 将变量x从它的链接地址映射到它在物理内存中的实际位置(它的加载地址)。
#
# RELOC(x) maps a symbol x from its link address to its actual
# location in physical memory (its load address).	 
# 那为什么要减0xF0000000呢？因为现在还没开启分页模式，entry_pgdir这个符号代表的地址又是以0xF0000000为基址的
#（为什么？没有为什么，这个是在链接时，链接器根据/kern/kernel.ld中的. = 0xF0100000;来指定的。可以参考《程序员的自我修养》p127-使用ld链接脚本）
###################################################################

#define	RELOC(x) ((x) - KERNBASE)

#define MULTIBOOT_HEADER_MAGIC (0x1BADB002)
#define MULTIBOOT_HEADER_FLAGS (0)
#define CHECKSUM (-(MULTIBOOT_HEADER_MAGIC + MULTIBOOT_HEADER_FLAGS))

###################################################################
# entry point
###################################################################

.text

# The Multiboot header
.align 4
.long MULTIBOOT_HEADER_MAGIC
.long MULTIBOOT_HEADER_FLAGS
.long CHECKSUM

# '_start' specifies the ELF entry point.  Since we haven't set up
# virtual memory when the bootloader enters this code, we need the
# bootloader to jump to the *physical* address of the entry point.
.globl		_start
_start = RELOC(entry)

.globl entry
entry:
	# 内核ELF文件中的第一条指令
	movw	$0x1234,0x472			# warm boot

	# We haven't set up virtual memory yet, so we're running from
	# the physical address the boot loader loaded the kernel at: 1MB
	# (plus a few bytes).  However, the C code is linked to run at
	# KERNBASE+1MB.  Hence, we set up a trivial page directory that
	# translates virtual addresses [KERNBASE, KERNBASE+4MB) to
	# physical addresses [0, 4MB).  This 4MB region will be
	# sufficient until we set up our real page table in mem_init
	# in lab 2.

	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.
	# 在使用 mem_init 配置分页系统之前，我们注意到已经使用以下代码在 entry.S 中配置了虚拟内存子系统：
	# 总结来说就是entry_pgdir结构所在的物理内存在RELOC(entry_pgdir)处。接下来将页目录的物理地址复制到cr3寄存器，并且将cr0 的最高位PG位设置为1后，正式打开分页功能。
	movl	$(RELOC(entry_pgdir)), %eax
	movl	%eax, %cr3			# cr3 寄存器保存页目录表的物理基地址
	# Turn on paging.
	movl	%cr0, %eax
	orl	$(CR0_PE|CR0_PG|CR0_WP), %eax
	movl	%eax, %cr0			# cr0 的最高位PG位设置为1后，正式打开分页功能

	# Turn on page size extension.
	movl  %cr4, %eax
	orl $(CR4_PSE), %eax
	movl  %eax, %cr4

	# Now paging is enabled, but we're still running at a low EIP
	# (why is this okay?).  Jump up above KERNBASE before entering
	# C code.
	mov	$relocated, %eax
	jmp	*%eax
relocated:

	# Clear the frame pointer register (EBP)
	# so that once we get into debugging C code,
	# stack backtraces will be terminated properly.
	movl	$0x0,%ebp			# nuke frame pointer

	# Set the stack pointer
	movl	$(bootstacktop),%esp

	# now to C code
	call	i386_init

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin


.data
###################################################################
# boot stack
###################################################################
	.p2align	PGSHIFT		# force page alignment
	.globl		bootstack
bootstack:
	# 长度限制 KSTKSIZE = 8×PGSIZE = 8×4KB = 32KB
	.space		KSTKSIZE
	# 通过obj/kernel/kernel.asm反汇编可得，bootstacktop: 0xf0111000
	.globl		bootstacktop   
bootstacktop:

