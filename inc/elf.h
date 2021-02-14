#ifndef JOS_INC_ELF_H
#define JOS_INC_ELF_H

#define ELF_MAGIC 0x464C457FU	/* "\x7FELF" in little endian */

// ELF file
// Header(识别+执行): ELF Header (ELF) + Program Header Table (Proghdr)
// Section: 可执行的内容: Code + Data + Section's Name
// Header(链接 执行可忽略): Section Header Table
// 1. 解析 Header 1
// 2. 根据 Segment 属性字段将文件映射到内存
// 3. 执行: a.调用 entry, (Elf->e_entry) 执行开始的地址
// 			b.系统调用: R7 寄存器的系统调用, 并调用 SVC 指令
struct Elf {
	uint32_t e_magic;	// must equal ELF_MAGIC
	uint8_t e_elf[12];
	uint16_t e_type;	// 可执行/可链接
	uint16_t e_machine;	// 处理器类型
	uint32_t e_version;	// 版本: 1
	uint32_t e_entry;	// 执行开始的地址
	uint32_t e_phoff;	// 程序头部的偏移
	uint32_t e_shoff;	// 段(section)头部的偏移
	uint32_t e_flags;	// 权限: 可执行 和 可链接
	uint16_t e_ehsize;	// ELF 头部的大小
	uint16_t e_phentsize; // 单个程序头部的大小
	uint16_t e_phnum;	// 程序头部的数量
	uint16_t e_shentsize; // 单个段(section)头部的大小
	uint16_t e_shnum;	// 段(section)头部的数量
	uint16_t e_shstrndx; // 表中 name 段(section)的索引
};

struct Proghdr {
	uint32_t p_type;	// 是否应该加载进内存的段(segment), 假设 yes
	uint32_t p_offset;	// 被读取时的偏移
	uint32_t p_va;		// 期望被加载的虚拟地址
	uint32_t p_pa;		// 期望被加载的物理地址
	uint32_t p_filesz;	// 文件大小
	uint32_t p_memsz;	// 在内存中的大小
	uint32_t p_flags;	// 权限: 可执行 和 可链接
	uint32_t p_align;	// 字节对齐协议
};

struct Secthdr {
	uint32_t sh_name;	// "" .shrtrtab .text .rodata ......
	uint32_t sh_type;
	uint32_t sh_flags;
	uint32_t sh_addr;
	uint32_t sh_offset;
	uint32_t sh_size;
	uint32_t sh_link;
	uint32_t sh_info;
	uint32_t sh_addralign;
	uint32_t sh_entsize;
};

// Values for Proghdr::p_type
#define ELF_PROG_LOAD		1

// Flag bits for Proghdr::p_flags
#define ELF_PROG_FLAG_EXEC	1
#define ELF_PROG_FLAG_WRITE	2
#define ELF_PROG_FLAG_READ	4

// Values for Secthdr::sh_type
#define ELF_SHT_NULL		0
#define ELF_SHT_PROGBITS	1
#define ELF_SHT_SYMTAB		2
#define ELF_SHT_STRTAB		3

// Values for Secthdr::sh_name
#define ELF_SHN_UNDEF		0

#endif /* !JOS_INC_ELF_H */
