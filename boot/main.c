#include <inc/x86.h>
#include <inc/elf.h>

/**********************************************************************
 * This a dirt simple boot loader, whose sole job is to boot
 * an ELF kernel image from the first IDE hard disk.
 *
 * 磁盘布局
 *  * 这个程序(boot.S and main.c)是引导加载器程序，应该被保存在磁盘的第一个扇区
 *
 *  * 第二个扇区往后保存着内核映像
 *
 *  * 内核映像必须必须是ELF格式的
 *
 * BOOT UP STEPS
 *  * when the CPU boots it loads the BIOS into memory and executes it
 *
 *  * the BIOS intializes devices, sets of the interrupt routines, and
 *    reads the first sector of the boot device(e.g., hard-drive)
 *    into memory and jumps to it.
 *
 *  * Assuming this boot loader is stored in the first sector of the
 *    hard-drive, this code takes over...
 *
 *  * control starts in boot.S -- which sets up protected mode,
 *    and a stack so C code then run, then calls bootmain()
 *
 *  * bootmain() in this file takes over, reads in the kernel and jumps to it.
 **********************************************************************/

#define SECTSIZE 512
// 指向常量0x10000的结构体指针
// (类似于数组名，不可以通过指针修改指向变量的值)
#define ELFHDR ((struct Elf *)0x10000) // scratch space

void readsect(void *, uint32_t);
// Read 'count' bytes at 'offset' from kernel into physical address 'pa'.
void readseg(uint32_t, uint32_t, uint32_t);

void bootmain(void)
{
	// ph: ELF头部的程序头，eph: ELF头部所有程序之后的结尾处
	struct Proghdr *ph, *eph;

	// 从磁盘读取出第一个页(首4096Byte)的数据 - ELFHDR
	// 即，将操作系统映像文件的前 0~4096(PAGESIZE 4KB) 读入内存到ELFHDR(0x10000) 处, 这其中包括 ELF 文件头部
	// 根据 ELF 文件头部规定属性格式，可以找到文件的每一段的位置
	readseg((uint32_t)ELFHDR, SECTSIZE * 8, 0);

	// ELF 文件的头部就是用来描述这个 ELF 文件如何在存储器中存储，
	// 文件是可链接文件还是可执行文件，都会有不同的 ELF 头部格式
	// 对于一个可执行程序，通常包含存放代码的文本段(text section)，
	// 存放全局变量的 data 段，以及存放字符串常量的 rodata 段

	// 通过判断 ELF 头部的魔数是否为正确的ELF
	if (ELFHDR->e_magic != ELF_MAGIC)
		// return to spin;
		return;

	// ph: 指向程序段头部的指针，准备加载所有程序段
	// 从磁盘中 ELF 头之后 e_phoff(Program Header's offset)字节处读取扇区的内容，
	// 程序头表项的起始地址包含了 Program Header Table。
	// 这个表格存放着程序中所有段的信息。通过这个表我们才能找到要执行的代码段，数据段到底有多少等等。
	// 反汇编：ph = 0x10000 + [0x10001c]=52 (struct Elf 内e_phoff的偏移量)
	ph = (struct Proghdr *)((uint8_t *) ELFHDR + ELFHDR->e_phoff);
	// ELFHDR中程序段的数量: eph = (struct Proghdr *)0x10000 + e_phoff + e_phnum;
	eph = ph + ELFHDR->e_phnum;

	// 将内核的各个段加载进入内存，ph++(struct Proghdr)
	for (; ph < eph; ph++)
		// 将ELFHDR中所有的程序段信息读入 ph
		// p_pa: 目标加载地址(期望包含该段的目的物理地址: 0x100000)，由 kernel.ld 决定内核的起始物理地址
		// p_memsz: 在内存中的大小，p_offset: 被读取时的偏移量
		readseg(ph->p_pa, ph->p_memsz, ph->p_offset);
		// 内存0x00100000是内核的最终载入地址，内核由Boot loader负责载入。
		// 初始当BIOS切换到boot loader时，它还没有开始相应的装载工作，所以这个时候看所有的8个word全是0。
		// 而当boot loader进入内核运行时，这个时候内核已经装载完毕，所以从0x00100000开始就是内核ELF文件的文件内容了。

	// bootstrap 执行的最后一条指令：将内核ELF文件载入内存后，从ELF文件头调用内核入口地址 bootmain, 且永不返回。
	((void (*)(void))(ELFHDR->e_entry))();
}

// Read 'count' bytes at 'offset' from kernel into physical address 'pa'.
// Might copy more than asked
// 从内核的 offset 处读取 count 个字节到物理地址pa处
// 可能读取会超过count个（扇区对齐）
void readseg(uint32_t pa, uint32_t count, uint32_t offset)
{
	uint32_t end_pa;

	end_pa = pa + count; // 结束物理地址

	// round down to sector boundary  对齐到扇区
	pa &= ~(SECTSIZE - 1);

	// translate from bytes to sectors, and kernel starts at sector 1
	// 算出扇区数 注意扇区从1开始（0为引导扇区）
	offset = (offset / SECTSIZE) + 1;

	// If this is too slow, we could read lots of sectors at a time.
	// We'd write more to memory than asked, but it doesn't matter --
	// we load in increasing order.
	// 在实际中往往将多个扇区一起读出以提高效率。
	while (pa < end_pa)
	{
		// Since we haven't enabled paging yet and we're using
		// an identity segment mapping (see boot.S), we can
		// use physical addresses directly.  This won't be the
		// case once JOS enables the MMU.
		// 考虑到没有开启分页以及 boot.S 中使用了
		// 分段映射的线性地址 = 物理地址 的映射规则，
		// 加载地址和物理地址是一致的。
		readsect((uint8_t *)pa, offset);
		pa += SECTSIZE;
		offset++;
	}
}

void waitdisk(void)
{
	// wait for disk ready  等待磁盘准备完毕
	while ((inb(0x1F7) & 0xC0) != 0x40)
		/* do nothing */;
}

void readsect(void *dst, uint32_t offset)
{
	// wait for disk to be ready
	waitdisk();

	outb(0x1F2, 1); // count = 1 0x1F2 Disk 0 sector count
	// Read one sector each time
	outb(0x1F3, offset); // Disk 0 sector number (CHS Mode)
	// First sector's number
	outb(0x1F4, offset >> 8);  // Cylinder low (CHS Mode)
	outb(0x1F5, offset >> 16); // Cylinder high (CHS Mode)
	// Cylinder number
	outb(0x1F6, (offset >> 24) | 0xE0); // Disk 0 drive/head
	// MASK 11100000
	// Drive/Head Register: bit 7 and bit 5 should be set to 1
	// Bit6: 1 LBA mode, 0 CHS mode
	outb(0x1F7, 0x20); // cmd 0x20 - read sectors
	/*20H       Read sector with retry. NB: 21H = read sector
                without retry. For this command you have to load
                the complete circus of cylinder/head/sector
                first. When the command completes (DRQ goes
                active) you can read 256 words (16-bits) from the
                disk's data register. */

	// wait for disk to be ready
	waitdisk();

	// read a sector
	insl(0x1F0, dst, SECTSIZE / 4);
	// Data register: data exchange with 8/16 bits
	// insl port addr cnt: read cnt dwords from the input port
	// specified by port into the supplied output array addr.
	// dword: 4 bytes = 16 bits
}
