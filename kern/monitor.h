#ifndef JOS_KERN_MONITOR_H
#define JOS_KERN_MONITOR_H
#ifndef JOS_KERNEL
# error "This is a JOS kernel header; user programs should not #include it"
#endif

struct Trapframe;

// Activate the kernel monitor,
// optionally providing a trap frame indicating the current state
// (NULL if none).
void monitor(struct Trapframe *tf);

// Functions implementing monitor commands.
int mon_help(int argc, char **argv, struct Trapframe *tf);
int mon_kerninfo(int argc, char **argv, struct Trapframe *tf);
int mon_backtrace(int argc, char **argv, struct Trapframe *tf);

// 输出所有物理页的映射
int mon_showmappings(int argc, char **argv, struct Trapframe *tf);
// 可以在指定的物理页上设置或清除一个flags标志位 (P|W|U)
int mon_setperm(int argc, char **argv, struct Trapframe *tf);
// 输出虚拟地址对应的物理内存地址
int mon_showmem(int argc, char **argv, struct Trapframe *tf);
// step 单步调试
int mon_step(int argc, char **argv, struct Trapframe *tf);
// continue 恢复程序执行，直到下一个断点或程序结束
int mon_continue(int argc, char **argv, struct Trapframe *tf);

#endif	// !JOS_KERN_MONITOR_H
