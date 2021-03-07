/* See COPYRIGHT for copyright information. */
// 内核中私有陷阱处理定义
#ifndef JOS_KERN_TRAP_H
#define JOS_KERN_TRAP_H
#ifndef JOS_KERNEL
# error "This is a JOS kernel header; user programs should not #include it"
#endif

#include <inc/trap.h>
#include <inc/mmu.h>

/**
 * 在kern/trapentry.S中定义每个中断对应的中断处理程序，在kern/trap.c中根据定义好的中断处理程序初始化IDT。
 * 每个中断对应的中断处理程序实际上是在内核栈中设置好Trapframe的布局结构，然后将这个结构传递给trap()函数进行处理，最后在trap_dispatch()中进行具体中断处理程序的分发。
 */
/* 内核中断描述符表IDT(Interrupt Descriptor Table) */
extern struct Gatedesc idt[];
extern struct Pseudodesc idt_pd;

void trap_init(void);
void trap_init_percpu(void);
void print_regs(struct PushRegs *regs);
void print_trapframe(struct Trapframe *tf);
void page_fault_handler(struct Trapframe *);
void backtrace(struct Trapframe *);

#endif /* JOS_KERN_TRAP_H */
