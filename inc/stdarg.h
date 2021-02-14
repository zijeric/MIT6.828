/*	$NetBSD: stdarg.h,v 1.12 1995/12/25 23:15:31 mycroft Exp $	*/

#ifndef JOS_INC_STDARG_H
#define	JOS_INC_STDARG_H

typedef __builtin_va_list va_list;

#define va_start(ap, last) __builtin_va_start(ap, last)

// va_arg每次是以地址往后增长取出下一个参数变量的地址。默认编译器是以从右往左的顺序将参数入栈的。
// 因为栈是从高往低的方向增长的。后压栈的参数放在了内存的低地址，所以如果要从左往右的顺序依次取出每个变量，
// 那么编译器必须以相反的顺序即从右往左将参数压栈。(或给定参数的个数)
#define va_arg(ap, type) __builtin_va_arg(ap, type)

#define va_end(ap) __builtin_va_end(ap)

#endif	/* !JOS_INC_STDARG_H */
