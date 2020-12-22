
obj/kern/kernel:     file format elf32-i386


Disassembly of section .text:

f0100000 <_start+0xeffffff4>:
.globl		_start
_start = RELOC(entry)

.globl entry
entry:
	movw	$0x1234,0x472			# warm boot
f0100000:	02 b0 ad 1b 00 00    	add    0x1bad(%eax),%dh
f0100006:	00 00                	add    %al,(%eax)
f0100008:	fe 4f 52             	decb   0x52(%edi)
f010000b:	e4                   	.byte 0xe4

f010000c <entry>:
f010000c:	66 c7 05 72 04 00 00 	movw   $0x1234,0x472
f0100013:	34 12 
	# sufficient until we set up our real page table in mem_init
	# in lab 2.

	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.
	movl	$(RELOC(entry_pgdir)), %eax
f0100015:	b8 00 30 11 00       	mov    $0x113000,%eax
	movl	%eax, %cr3
f010001a:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl	%cr0, %eax
f010001d:	0f 20 c0             	mov    %cr0,%eax
	orl	$(CR0_PE|CR0_PG|CR0_WP), %eax
f0100020:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl	%eax, %cr0
f0100025:	0f 22 c0             	mov    %eax,%cr0

	# Now paging is enabled, but we're still running at a low EIP
	# (why is this okay?).  Jump up above KERNBASE before entering
	# C code.
	mov	$relocated, %eax
f0100028:	b8 2f 00 10 f0       	mov    $0xf010002f,%eax
	jmp	*%eax
f010002d:	ff e0                	jmp    *%eax

f010002f <relocated>:
relocated:

	# Clear the frame pointer register (EBP)
	# so that once we get into debugging C code,
	# stack backtraces will be terminated properly.
	movl	$0x0,%ebp			# nuke frame pointer
f010002f:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Set the stack pointer
	movl	$(bootstacktop),%esp
f0100034:	bc 00 10 11 f0       	mov    $0xf0111000,%esp

	# now to C code
	call	i386_init
f0100039:	e8 6c 00 00 00       	call   f01000aa <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <test_backtrace>:
#include <kern/console.h>

// Test the stack backtrace function (lab 1 only)
void
test_backtrace(int x)
{
f0100040:	f3 0f 1e fb          	endbr32 
f0100044:	55                   	push   %ebp
f0100045:	89 e5                	mov    %esp,%ebp
f0100047:	56                   	push   %esi
f0100048:	53                   	push   %ebx
f0100049:	e8 8f 01 00 00       	call   f01001dd <__x86.get_pc_thunk.bx>
f010004e:	81 c3 ba 22 01 00    	add    $0x122ba,%ebx
f0100054:	8b 75 08             	mov    0x8(%ebp),%esi
	cprintf("entering test_backtrace %d\n", x);
f0100057:	83 ec 08             	sub    $0x8,%esp
f010005a:	56                   	push   %esi
f010005b:	8d 83 18 f9 fe ff    	lea    -0x106e8(%ebx),%eax
f0100061:	50                   	push   %eax
f0100062:	e8 e2 0a 00 00       	call   f0100b49 <cprintf>
	if (x > 0)
f0100067:	83 c4 10             	add    $0x10,%esp
f010006a:	85 f6                	test   %esi,%esi
f010006c:	7e 29                	jle    f0100097 <test_backtrace+0x57>
		test_backtrace(x-1);
f010006e:	83 ec 0c             	sub    $0xc,%esp
f0100071:	8d 46 ff             	lea    -0x1(%esi),%eax
f0100074:	50                   	push   %eax
f0100075:	e8 c6 ff ff ff       	call   f0100040 <test_backtrace>
f010007a:	83 c4 10             	add    $0x10,%esp
	else
		mon_backtrace(0, 0, 0);
	cprintf("leaving test_backtrace %d\n", x);
f010007d:	83 ec 08             	sub    $0x8,%esp
f0100080:	56                   	push   %esi
f0100081:	8d 83 34 f9 fe ff    	lea    -0x106cc(%ebx),%eax
f0100087:	50                   	push   %eax
f0100088:	e8 bc 0a 00 00       	call   f0100b49 <cprintf>
}
f010008d:	83 c4 10             	add    $0x10,%esp
f0100090:	8d 65 f8             	lea    -0x8(%ebp),%esp
f0100093:	5b                   	pop    %ebx
f0100094:	5e                   	pop    %esi
f0100095:	5d                   	pop    %ebp
f0100096:	c3                   	ret    
		mon_backtrace(0, 0, 0);
f0100097:	83 ec 04             	sub    $0x4,%esp
f010009a:	6a 00                	push   $0x0
f010009c:	6a 00                	push   $0x0
f010009e:	6a 00                	push   $0x0
f01000a0:	e8 1d 08 00 00       	call   f01008c2 <mon_backtrace>
f01000a5:	83 c4 10             	add    $0x10,%esp
f01000a8:	eb d3                	jmp    f010007d <test_backtrace+0x3d>

f01000aa <i386_init>:

void
i386_init(void)
{
f01000aa:	f3 0f 1e fb          	endbr32 
f01000ae:	55                   	push   %ebp
f01000af:	89 e5                	mov    %esp,%ebp
f01000b1:	53                   	push   %ebx
f01000b2:	83 ec 08             	sub    $0x8,%esp
f01000b5:	e8 23 01 00 00       	call   f01001dd <__x86.get_pc_thunk.bx>
f01000ba:	81 c3 4e 22 01 00    	add    $0x1224e,%ebx
	extern char edata[], end[];

	// Before doing anything else, complete the ELF loading process.
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);
f01000c0:	c7 c2 60 40 11 f0    	mov    $0xf0114060,%edx
f01000c6:	c7 c0 a0 46 11 f0    	mov    $0xf01146a0,%eax
f01000cc:	29 d0                	sub    %edx,%eax
f01000ce:	50                   	push   %eax
f01000cf:	6a 00                	push   $0x0
f01000d1:	52                   	push   %edx
f01000d2:	e8 d4 16 00 00       	call   f01017ab <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d7:	e8 5c 05 00 00       	call   f0100638 <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000dc:	83 c4 08             	add    $0x8,%esp
f01000df:	68 ac 1a 00 00       	push   $0x1aac
f01000e4:	8d 83 4f f9 fe ff    	lea    -0x106b1(%ebx),%eax
f01000ea:	50                   	push   %eax
f01000eb:	e8 59 0a 00 00       	call   f0100b49 <cprintf>
	cprintf("x=%d y=%d", 3);
f01000f0:	83 c4 08             	add    $0x8,%esp
f01000f3:	6a 03                	push   $0x3
f01000f5:	8d 83 6a f9 fe ff    	lea    -0x10696(%ebx),%eax
f01000fb:	50                   	push   %eax
f01000fc:	e8 48 0a 00 00       	call   f0100b49 <cprintf>

	// Test the stack backtrace function (lab 1 only)
	test_backtrace(5);
f0100101:	c7 04 24 05 00 00 00 	movl   $0x5,(%esp)
f0100108:	e8 33 ff ff ff       	call   f0100040 <test_backtrace>
f010010d:	83 c4 10             	add    $0x10,%esp

	// Drop into the kernel monitor.
	while (1)
		monitor(NULL);
f0100110:	83 ec 0c             	sub    $0xc,%esp
f0100113:	6a 00                	push   $0x0
f0100115:	e8 5d 08 00 00       	call   f0100977 <monitor>
f010011a:	83 c4 10             	add    $0x10,%esp
f010011d:	eb f1                	jmp    f0100110 <i386_init+0x66>

f010011f <_panic>:
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
f010011f:	f3 0f 1e fb          	endbr32 
f0100123:	55                   	push   %ebp
f0100124:	89 e5                	mov    %esp,%ebp
f0100126:	57                   	push   %edi
f0100127:	56                   	push   %esi
f0100128:	53                   	push   %ebx
f0100129:	83 ec 0c             	sub    $0xc,%esp
f010012c:	e8 ac 00 00 00       	call   f01001dd <__x86.get_pc_thunk.bx>
f0100131:	81 c3 d7 21 01 00    	add    $0x121d7,%ebx
f0100137:	8b 7d 10             	mov    0x10(%ebp),%edi
	va_list ap;

	if (panicstr)
f010013a:	c7 c0 a4 46 11 f0    	mov    $0xf01146a4,%eax
f0100140:	83 38 00             	cmpl   $0x0,(%eax)
f0100143:	74 0f                	je     f0100154 <_panic+0x35>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f0100145:	83 ec 0c             	sub    $0xc,%esp
f0100148:	6a 00                	push   $0x0
f010014a:	e8 28 08 00 00       	call   f0100977 <monitor>
f010014f:	83 c4 10             	add    $0x10,%esp
f0100152:	eb f1                	jmp    f0100145 <_panic+0x26>
	panicstr = fmt;
f0100154:	89 38                	mov    %edi,(%eax)
	asm volatile("cli; cld");
f0100156:	fa                   	cli    
f0100157:	fc                   	cld    
	va_start(ap, fmt);
f0100158:	8d 75 14             	lea    0x14(%ebp),%esi
	cprintf("kernel panic at %s:%d: ", file, line);
f010015b:	83 ec 04             	sub    $0x4,%esp
f010015e:	ff 75 0c             	pushl  0xc(%ebp)
f0100161:	ff 75 08             	pushl  0x8(%ebp)
f0100164:	8d 83 74 f9 fe ff    	lea    -0x1068c(%ebx),%eax
f010016a:	50                   	push   %eax
f010016b:	e8 d9 09 00 00       	call   f0100b49 <cprintf>
	vcprintf(fmt, ap);
f0100170:	83 c4 08             	add    $0x8,%esp
f0100173:	56                   	push   %esi
f0100174:	57                   	push   %edi
f0100175:	e8 94 09 00 00       	call   f0100b0e <vcprintf>
	cprintf("\n");
f010017a:	8d 83 b0 f9 fe ff    	lea    -0x10650(%ebx),%eax
f0100180:	89 04 24             	mov    %eax,(%esp)
f0100183:	e8 c1 09 00 00       	call   f0100b49 <cprintf>
f0100188:	83 c4 10             	add    $0x10,%esp
f010018b:	eb b8                	jmp    f0100145 <_panic+0x26>

f010018d <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f010018d:	f3 0f 1e fb          	endbr32 
f0100191:	55                   	push   %ebp
f0100192:	89 e5                	mov    %esp,%ebp
f0100194:	56                   	push   %esi
f0100195:	53                   	push   %ebx
f0100196:	e8 42 00 00 00       	call   f01001dd <__x86.get_pc_thunk.bx>
f010019b:	81 c3 6d 21 01 00    	add    $0x1216d,%ebx
	va_list ap;

	va_start(ap, fmt);
f01001a1:	8d 75 14             	lea    0x14(%ebp),%esi
	cprintf("kernel warning at %s:%d: ", file, line);
f01001a4:	83 ec 04             	sub    $0x4,%esp
f01001a7:	ff 75 0c             	pushl  0xc(%ebp)
f01001aa:	ff 75 08             	pushl  0x8(%ebp)
f01001ad:	8d 83 8c f9 fe ff    	lea    -0x10674(%ebx),%eax
f01001b3:	50                   	push   %eax
f01001b4:	e8 90 09 00 00       	call   f0100b49 <cprintf>
	vcprintf(fmt, ap);
f01001b9:	83 c4 08             	add    $0x8,%esp
f01001bc:	56                   	push   %esi
f01001bd:	ff 75 10             	pushl  0x10(%ebp)
f01001c0:	e8 49 09 00 00       	call   f0100b0e <vcprintf>
	cprintf("\n");
f01001c5:	8d 83 b0 f9 fe ff    	lea    -0x10650(%ebx),%eax
f01001cb:	89 04 24             	mov    %eax,(%esp)
f01001ce:	e8 76 09 00 00       	call   f0100b49 <cprintf>
	va_end(ap);
}
f01001d3:	83 c4 10             	add    $0x10,%esp
f01001d6:	8d 65 f8             	lea    -0x8(%ebp),%esp
f01001d9:	5b                   	pop    %ebx
f01001da:	5e                   	pop    %esi
f01001db:	5d                   	pop    %ebp
f01001dc:	c3                   	ret    

f01001dd <__x86.get_pc_thunk.bx>:
f01001dd:	8b 1c 24             	mov    (%esp),%ebx
f01001e0:	c3                   	ret    

f01001e1 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f01001e1:	f3 0f 1e fb          	endbr32 

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01001e5:	ba fd 03 00 00       	mov    $0x3fd,%edx
f01001ea:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f01001eb:	a8 01                	test   $0x1,%al
f01001ed:	74 0a                	je     f01001f9 <serial_proc_data+0x18>
f01001ef:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01001f4:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f01001f5:	0f b6 c0             	movzbl %al,%eax
f01001f8:	c3                   	ret    
		return -1;
f01001f9:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
f01001fe:	c3                   	ret    

f01001ff <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f01001ff:	55                   	push   %ebp
f0100200:	89 e5                	mov    %esp,%ebp
f0100202:	57                   	push   %edi
f0100203:	56                   	push   %esi
f0100204:	53                   	push   %ebx
f0100205:	83 ec 1c             	sub    $0x1c,%esp
f0100208:	e8 88 05 00 00       	call   f0100795 <__x86.get_pc_thunk.si>
f010020d:	81 c6 fb 20 01 00    	add    $0x120fb,%esi
f0100213:	89 c7                	mov    %eax,%edi
	int c;

	while ((c = (*proc)()) != -1) {
		if (c == 0)
			continue;
		cons.buf[cons.wpos++] = c;
f0100215:	8d 1d 78 1d 00 00    	lea    0x1d78,%ebx
f010021b:	8d 04 1e             	lea    (%esi,%ebx,1),%eax
f010021e:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0100221:	89 7d e4             	mov    %edi,-0x1c(%ebp)
	while ((c = (*proc)()) != -1) {
f0100224:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100227:	ff d0                	call   *%eax
f0100229:	83 f8 ff             	cmp    $0xffffffff,%eax
f010022c:	74 2b                	je     f0100259 <cons_intr+0x5a>
		if (c == 0)
f010022e:	85 c0                	test   %eax,%eax
f0100230:	74 f2                	je     f0100224 <cons_intr+0x25>
		cons.buf[cons.wpos++] = c;
f0100232:	8b 8c 1e 04 02 00 00 	mov    0x204(%esi,%ebx,1),%ecx
f0100239:	8d 51 01             	lea    0x1(%ecx),%edx
f010023c:	8b 7d e0             	mov    -0x20(%ebp),%edi
f010023f:	88 04 0f             	mov    %al,(%edi,%ecx,1)
		if (cons.wpos == CONSBUFSIZE)
f0100242:	81 fa 00 02 00 00    	cmp    $0x200,%edx
			cons.wpos = 0;
f0100248:	b8 00 00 00 00       	mov    $0x0,%eax
f010024d:	0f 44 d0             	cmove  %eax,%edx
f0100250:	89 94 1e 04 02 00 00 	mov    %edx,0x204(%esi,%ebx,1)
f0100257:	eb cb                	jmp    f0100224 <cons_intr+0x25>
	}
}
f0100259:	83 c4 1c             	add    $0x1c,%esp
f010025c:	5b                   	pop    %ebx
f010025d:	5e                   	pop    %esi
f010025e:	5f                   	pop    %edi
f010025f:	5d                   	pop    %ebp
f0100260:	c3                   	ret    

f0100261 <kbd_proc_data>:
{
f0100261:	f3 0f 1e fb          	endbr32 
f0100265:	55                   	push   %ebp
f0100266:	89 e5                	mov    %esp,%ebp
f0100268:	56                   	push   %esi
f0100269:	53                   	push   %ebx
f010026a:	e8 6e ff ff ff       	call   f01001dd <__x86.get_pc_thunk.bx>
f010026f:	81 c3 99 20 01 00    	add    $0x12099,%ebx
f0100275:	ba 64 00 00 00       	mov    $0x64,%edx
f010027a:	ec                   	in     (%dx),%al
	if ((stat & KBS_DIB) == 0)
f010027b:	a8 01                	test   $0x1,%al
f010027d:	0f 84 fb 00 00 00    	je     f010037e <kbd_proc_data+0x11d>
	if (stat & KBS_TERR)
f0100283:	a8 20                	test   $0x20,%al
f0100285:	0f 85 fa 00 00 00    	jne    f0100385 <kbd_proc_data+0x124>
f010028b:	ba 60 00 00 00       	mov    $0x60,%edx
f0100290:	ec                   	in     (%dx),%al
f0100291:	89 c2                	mov    %eax,%edx
	if (data == 0xE0) {
f0100293:	3c e0                	cmp    $0xe0,%al
f0100295:	74 64                	je     f01002fb <kbd_proc_data+0x9a>
	} else if (data & 0x80) {
f0100297:	84 c0                	test   %al,%al
f0100299:	78 75                	js     f0100310 <kbd_proc_data+0xaf>
	} else if (shift & E0ESC) {
f010029b:	8b 8b 58 1d 00 00    	mov    0x1d58(%ebx),%ecx
f01002a1:	f6 c1 40             	test   $0x40,%cl
f01002a4:	74 0e                	je     f01002b4 <kbd_proc_data+0x53>
		data |= 0x80;
f01002a6:	83 c8 80             	or     $0xffffff80,%eax
f01002a9:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f01002ab:	83 e1 bf             	and    $0xffffffbf,%ecx
f01002ae:	89 8b 58 1d 00 00    	mov    %ecx,0x1d58(%ebx)
	shift |= shiftcode[data];
f01002b4:	0f b6 d2             	movzbl %dl,%edx
f01002b7:	0f b6 84 13 d8 fa fe 	movzbl -0x10528(%ebx,%edx,1),%eax
f01002be:	ff 
f01002bf:	0b 83 58 1d 00 00    	or     0x1d58(%ebx),%eax
	shift ^= togglecode[data];
f01002c5:	0f b6 8c 13 d8 f9 fe 	movzbl -0x10628(%ebx,%edx,1),%ecx
f01002cc:	ff 
f01002cd:	31 c8                	xor    %ecx,%eax
f01002cf:	89 83 58 1d 00 00    	mov    %eax,0x1d58(%ebx)
	c = charcode[shift & (CTL | SHIFT)][data];
f01002d5:	89 c1                	mov    %eax,%ecx
f01002d7:	83 e1 03             	and    $0x3,%ecx
f01002da:	8b 8c 8b f8 1c 00 00 	mov    0x1cf8(%ebx,%ecx,4),%ecx
f01002e1:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f01002e5:	0f b6 f2             	movzbl %dl,%esi
	if (shift & CAPSLOCK) {
f01002e8:	a8 08                	test   $0x8,%al
f01002ea:	74 65                	je     f0100351 <kbd_proc_data+0xf0>
		if ('a' <= c && c <= 'z')
f01002ec:	89 f2                	mov    %esi,%edx
f01002ee:	8d 4e 9f             	lea    -0x61(%esi),%ecx
f01002f1:	83 f9 19             	cmp    $0x19,%ecx
f01002f4:	77 4f                	ja     f0100345 <kbd_proc_data+0xe4>
			c += 'A' - 'a';
f01002f6:	83 ee 20             	sub    $0x20,%esi
f01002f9:	eb 0c                	jmp    f0100307 <kbd_proc_data+0xa6>
		shift |= E0ESC;
f01002fb:	83 8b 58 1d 00 00 40 	orl    $0x40,0x1d58(%ebx)
		return 0;
f0100302:	be 00 00 00 00       	mov    $0x0,%esi
}
f0100307:	89 f0                	mov    %esi,%eax
f0100309:	8d 65 f8             	lea    -0x8(%ebp),%esp
f010030c:	5b                   	pop    %ebx
f010030d:	5e                   	pop    %esi
f010030e:	5d                   	pop    %ebp
f010030f:	c3                   	ret    
		data = (shift & E0ESC ? data : data & 0x7F);
f0100310:	8b 8b 58 1d 00 00    	mov    0x1d58(%ebx),%ecx
f0100316:	89 ce                	mov    %ecx,%esi
f0100318:	83 e6 40             	and    $0x40,%esi
f010031b:	83 e0 7f             	and    $0x7f,%eax
f010031e:	85 f6                	test   %esi,%esi
f0100320:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f0100323:	0f b6 d2             	movzbl %dl,%edx
f0100326:	0f b6 84 13 d8 fa fe 	movzbl -0x10528(%ebx,%edx,1),%eax
f010032d:	ff 
f010032e:	83 c8 40             	or     $0x40,%eax
f0100331:	0f b6 c0             	movzbl %al,%eax
f0100334:	f7 d0                	not    %eax
f0100336:	21 c8                	and    %ecx,%eax
f0100338:	89 83 58 1d 00 00    	mov    %eax,0x1d58(%ebx)
		return 0;
f010033e:	be 00 00 00 00       	mov    $0x0,%esi
f0100343:	eb c2                	jmp    f0100307 <kbd_proc_data+0xa6>
		else if ('A' <= c && c <= 'Z')
f0100345:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f0100348:	8d 4e 20             	lea    0x20(%esi),%ecx
f010034b:	83 fa 1a             	cmp    $0x1a,%edx
f010034e:	0f 42 f1             	cmovb  %ecx,%esi
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f0100351:	f7 d0                	not    %eax
f0100353:	a8 06                	test   $0x6,%al
f0100355:	75 b0                	jne    f0100307 <kbd_proc_data+0xa6>
f0100357:	81 fe e9 00 00 00    	cmp    $0xe9,%esi
f010035d:	75 a8                	jne    f0100307 <kbd_proc_data+0xa6>
		cprintf("Rebooting!\n");
f010035f:	83 ec 0c             	sub    $0xc,%esp
f0100362:	8d 83 a6 f9 fe ff    	lea    -0x1065a(%ebx),%eax
f0100368:	50                   	push   %eax
f0100369:	e8 db 07 00 00       	call   f0100b49 <cprintf>
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010036e:	b8 03 00 00 00       	mov    $0x3,%eax
f0100373:	ba 92 00 00 00       	mov    $0x92,%edx
f0100378:	ee                   	out    %al,(%dx)
}
f0100379:	83 c4 10             	add    $0x10,%esp
f010037c:	eb 89                	jmp    f0100307 <kbd_proc_data+0xa6>
		return -1;
f010037e:	be ff ff ff ff       	mov    $0xffffffff,%esi
f0100383:	eb 82                	jmp    f0100307 <kbd_proc_data+0xa6>
		return -1;
f0100385:	be ff ff ff ff       	mov    $0xffffffff,%esi
f010038a:	e9 78 ff ff ff       	jmp    f0100307 <kbd_proc_data+0xa6>

f010038f <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f010038f:	55                   	push   %ebp
f0100390:	89 e5                	mov    %esp,%ebp
f0100392:	57                   	push   %edi
f0100393:	56                   	push   %esi
f0100394:	53                   	push   %ebx
f0100395:	83 ec 1c             	sub    $0x1c,%esp
f0100398:	e8 40 fe ff ff       	call   f01001dd <__x86.get_pc_thunk.bx>
f010039d:	81 c3 6b 1f 01 00    	add    $0x11f6b,%ebx
f01003a3:	89 c7                	mov    %eax,%edi
	for (i = 0;
f01003a5:	be 00 00 00 00       	mov    $0x0,%esi
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01003aa:	b9 84 00 00 00       	mov    $0x84,%ecx
f01003af:	ba fd 03 00 00       	mov    $0x3fd,%edx
f01003b4:	ec                   	in     (%dx),%al
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f01003b5:	a8 20                	test   $0x20,%al
f01003b7:	75 13                	jne    f01003cc <cons_putc+0x3d>
f01003b9:	81 fe ff 31 00 00    	cmp    $0x31ff,%esi
f01003bf:	7f 0b                	jg     f01003cc <cons_putc+0x3d>
f01003c1:	89 ca                	mov    %ecx,%edx
f01003c3:	ec                   	in     (%dx),%al
f01003c4:	ec                   	in     (%dx),%al
f01003c5:	ec                   	in     (%dx),%al
f01003c6:	ec                   	in     (%dx),%al
	     i++)
f01003c7:	83 c6 01             	add    $0x1,%esi
f01003ca:	eb e3                	jmp    f01003af <cons_putc+0x20>
	outb(COM1 + COM_TX, c);
f01003cc:	89 f8                	mov    %edi,%eax
f01003ce:	88 45 e7             	mov    %al,-0x19(%ebp)
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01003d1:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01003d6:	ee                   	out    %al,(%dx)
	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f01003d7:	be 00 00 00 00       	mov    $0x0,%esi
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01003dc:	b9 84 00 00 00       	mov    $0x84,%ecx
f01003e1:	ba 79 03 00 00       	mov    $0x379,%edx
f01003e6:	ec                   	in     (%dx),%al
f01003e7:	81 fe ff 31 00 00    	cmp    $0x31ff,%esi
f01003ed:	7f 0f                	jg     f01003fe <cons_putc+0x6f>
f01003ef:	84 c0                	test   %al,%al
f01003f1:	78 0b                	js     f01003fe <cons_putc+0x6f>
f01003f3:	89 ca                	mov    %ecx,%edx
f01003f5:	ec                   	in     (%dx),%al
f01003f6:	ec                   	in     (%dx),%al
f01003f7:	ec                   	in     (%dx),%al
f01003f8:	ec                   	in     (%dx),%al
f01003f9:	83 c6 01             	add    $0x1,%esi
f01003fc:	eb e3                	jmp    f01003e1 <cons_putc+0x52>
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01003fe:	ba 78 03 00 00       	mov    $0x378,%edx
f0100403:	0f b6 45 e7          	movzbl -0x19(%ebp),%eax
f0100407:	ee                   	out    %al,(%dx)
f0100408:	ba 7a 03 00 00       	mov    $0x37a,%edx
f010040d:	b8 0d 00 00 00       	mov    $0xd,%eax
f0100412:	ee                   	out    %al,(%dx)
f0100413:	b8 08 00 00 00       	mov    $0x8,%eax
f0100418:	ee                   	out    %al,(%dx)
		c |= 0x0700;
f0100419:	89 f8                	mov    %edi,%eax
f010041b:	80 cc 07             	or     $0x7,%ah
f010041e:	f7 c7 00 ff ff ff    	test   $0xffffff00,%edi
f0100424:	0f 44 f8             	cmove  %eax,%edi
	switch (c & 0xff) {
f0100427:	89 f8                	mov    %edi,%eax
f0100429:	0f b6 c0             	movzbl %al,%eax
f010042c:	89 f9                	mov    %edi,%ecx
f010042e:	80 f9 0a             	cmp    $0xa,%cl
f0100431:	0f 84 e2 00 00 00    	je     f0100519 <cons_putc+0x18a>
f0100437:	83 f8 0a             	cmp    $0xa,%eax
f010043a:	7f 46                	jg     f0100482 <cons_putc+0xf3>
f010043c:	83 f8 08             	cmp    $0x8,%eax
f010043f:	0f 84 a8 00 00 00    	je     f01004ed <cons_putc+0x15e>
f0100445:	83 f8 09             	cmp    $0x9,%eax
f0100448:	0f 85 d8 00 00 00    	jne    f0100526 <cons_putc+0x197>
		cons_putc(' ');
f010044e:	b8 20 00 00 00       	mov    $0x20,%eax
f0100453:	e8 37 ff ff ff       	call   f010038f <cons_putc>
		cons_putc(' ');
f0100458:	b8 20 00 00 00       	mov    $0x20,%eax
f010045d:	e8 2d ff ff ff       	call   f010038f <cons_putc>
		cons_putc(' ');
f0100462:	b8 20 00 00 00       	mov    $0x20,%eax
f0100467:	e8 23 ff ff ff       	call   f010038f <cons_putc>
		cons_putc(' ');
f010046c:	b8 20 00 00 00       	mov    $0x20,%eax
f0100471:	e8 19 ff ff ff       	call   f010038f <cons_putc>
		cons_putc(' ');
f0100476:	b8 20 00 00 00       	mov    $0x20,%eax
f010047b:	e8 0f ff ff ff       	call   f010038f <cons_putc>
		break;
f0100480:	eb 26                	jmp    f01004a8 <cons_putc+0x119>
	switch (c & 0xff) {
f0100482:	83 f8 0d             	cmp    $0xd,%eax
f0100485:	0f 85 9b 00 00 00    	jne    f0100526 <cons_putc+0x197>
		crt_pos -= (crt_pos % CRT_COLS);
f010048b:	0f b7 83 80 1f 00 00 	movzwl 0x1f80(%ebx),%eax
f0100492:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100498:	c1 e8 16             	shr    $0x16,%eax
f010049b:	8d 04 80             	lea    (%eax,%eax,4),%eax
f010049e:	c1 e0 04             	shl    $0x4,%eax
f01004a1:	66 89 83 80 1f 00 00 	mov    %ax,0x1f80(%ebx)
	if (crt_pos >= CRT_SIZE) {
f01004a8:	66 81 bb 80 1f 00 00 	cmpw   $0x7cf,0x1f80(%ebx)
f01004af:	cf 07 
f01004b1:	0f 87 92 00 00 00    	ja     f0100549 <cons_putc+0x1ba>
	outb(addr_6845, 14);
f01004b7:	8b 8b 88 1f 00 00    	mov    0x1f88(%ebx),%ecx
f01004bd:	b8 0e 00 00 00       	mov    $0xe,%eax
f01004c2:	89 ca                	mov    %ecx,%edx
f01004c4:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f01004c5:	0f b7 9b 80 1f 00 00 	movzwl 0x1f80(%ebx),%ebx
f01004cc:	8d 71 01             	lea    0x1(%ecx),%esi
f01004cf:	89 d8                	mov    %ebx,%eax
f01004d1:	66 c1 e8 08          	shr    $0x8,%ax
f01004d5:	89 f2                	mov    %esi,%edx
f01004d7:	ee                   	out    %al,(%dx)
f01004d8:	b8 0f 00 00 00       	mov    $0xf,%eax
f01004dd:	89 ca                	mov    %ecx,%edx
f01004df:	ee                   	out    %al,(%dx)
f01004e0:	89 d8                	mov    %ebx,%eax
f01004e2:	89 f2                	mov    %esi,%edx
f01004e4:	ee                   	out    %al,(%dx)
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f01004e5:	8d 65 f4             	lea    -0xc(%ebp),%esp
f01004e8:	5b                   	pop    %ebx
f01004e9:	5e                   	pop    %esi
f01004ea:	5f                   	pop    %edi
f01004eb:	5d                   	pop    %ebp
f01004ec:	c3                   	ret    
		if (crt_pos > 0) {
f01004ed:	0f b7 83 80 1f 00 00 	movzwl 0x1f80(%ebx),%eax
f01004f4:	66 85 c0             	test   %ax,%ax
f01004f7:	74 be                	je     f01004b7 <cons_putc+0x128>
			crt_pos--;
f01004f9:	83 e8 01             	sub    $0x1,%eax
f01004fc:	66 89 83 80 1f 00 00 	mov    %ax,0x1f80(%ebx)
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100503:	0f b7 c0             	movzwl %ax,%eax
f0100506:	89 fa                	mov    %edi,%edx
f0100508:	b2 00                	mov    $0x0,%dl
f010050a:	83 ca 20             	or     $0x20,%edx
f010050d:	8b 8b 84 1f 00 00    	mov    0x1f84(%ebx),%ecx
f0100513:	66 89 14 41          	mov    %dx,(%ecx,%eax,2)
f0100517:	eb 8f                	jmp    f01004a8 <cons_putc+0x119>
		crt_pos += CRT_COLS;
f0100519:	66 83 83 80 1f 00 00 	addw   $0x50,0x1f80(%ebx)
f0100520:	50 
f0100521:	e9 65 ff ff ff       	jmp    f010048b <cons_putc+0xfc>
		crt_buf[crt_pos++] = c;		/* write the character */
f0100526:	0f b7 83 80 1f 00 00 	movzwl 0x1f80(%ebx),%eax
f010052d:	8d 50 01             	lea    0x1(%eax),%edx
f0100530:	66 89 93 80 1f 00 00 	mov    %dx,0x1f80(%ebx)
f0100537:	0f b7 c0             	movzwl %ax,%eax
f010053a:	8b 93 84 1f 00 00    	mov    0x1f84(%ebx),%edx
f0100540:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
f0100544:	e9 5f ff ff ff       	jmp    f01004a8 <cons_putc+0x119>
		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f0100549:	8b 83 84 1f 00 00    	mov    0x1f84(%ebx),%eax
f010054f:	83 ec 04             	sub    $0x4,%esp
f0100552:	68 00 0f 00 00       	push   $0xf00
f0100557:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f010055d:	52                   	push   %edx
f010055e:	50                   	push   %eax
f010055f:	e8 93 12 00 00       	call   f01017f7 <memmove>
			crt_buf[i] = 0x0700 | ' ';
f0100564:	8b 93 84 1f 00 00    	mov    0x1f84(%ebx),%edx
f010056a:	8d 82 00 0f 00 00    	lea    0xf00(%edx),%eax
f0100570:	81 c2 a0 0f 00 00    	add    $0xfa0,%edx
f0100576:	83 c4 10             	add    $0x10,%esp
f0100579:	66 c7 00 20 07       	movw   $0x720,(%eax)
f010057e:	83 c0 02             	add    $0x2,%eax
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100581:	39 d0                	cmp    %edx,%eax
f0100583:	75 f4                	jne    f0100579 <cons_putc+0x1ea>
		crt_pos -= CRT_COLS;
f0100585:	66 83 ab 80 1f 00 00 	subw   $0x50,0x1f80(%ebx)
f010058c:	50 
f010058d:	e9 25 ff ff ff       	jmp    f01004b7 <cons_putc+0x128>

f0100592 <serial_intr>:
{
f0100592:	f3 0f 1e fb          	endbr32 
f0100596:	e8 f6 01 00 00       	call   f0100791 <__x86.get_pc_thunk.ax>
f010059b:	05 6d 1d 01 00       	add    $0x11d6d,%eax
	if (serial_exists)
f01005a0:	80 b8 8c 1f 00 00 00 	cmpb   $0x0,0x1f8c(%eax)
f01005a7:	75 01                	jne    f01005aa <serial_intr+0x18>
f01005a9:	c3                   	ret    
{
f01005aa:	55                   	push   %ebp
f01005ab:	89 e5                	mov    %esp,%ebp
f01005ad:	83 ec 08             	sub    $0x8,%esp
		cons_intr(serial_proc_data);
f01005b0:	8d 80 d9 de fe ff    	lea    -0x12127(%eax),%eax
f01005b6:	e8 44 fc ff ff       	call   f01001ff <cons_intr>
}
f01005bb:	c9                   	leave  
f01005bc:	c3                   	ret    

f01005bd <kbd_intr>:
{
f01005bd:	f3 0f 1e fb          	endbr32 
f01005c1:	55                   	push   %ebp
f01005c2:	89 e5                	mov    %esp,%ebp
f01005c4:	83 ec 08             	sub    $0x8,%esp
f01005c7:	e8 c5 01 00 00       	call   f0100791 <__x86.get_pc_thunk.ax>
f01005cc:	05 3c 1d 01 00       	add    $0x11d3c,%eax
	cons_intr(kbd_proc_data);
f01005d1:	8d 80 59 df fe ff    	lea    -0x120a7(%eax),%eax
f01005d7:	e8 23 fc ff ff       	call   f01001ff <cons_intr>
}
f01005dc:	c9                   	leave  
f01005dd:	c3                   	ret    

f01005de <cons_getc>:
{
f01005de:	f3 0f 1e fb          	endbr32 
f01005e2:	55                   	push   %ebp
f01005e3:	89 e5                	mov    %esp,%ebp
f01005e5:	53                   	push   %ebx
f01005e6:	83 ec 04             	sub    $0x4,%esp
f01005e9:	e8 ef fb ff ff       	call   f01001dd <__x86.get_pc_thunk.bx>
f01005ee:	81 c3 1a 1d 01 00    	add    $0x11d1a,%ebx
	serial_intr();
f01005f4:	e8 99 ff ff ff       	call   f0100592 <serial_intr>
	kbd_intr();
f01005f9:	e8 bf ff ff ff       	call   f01005bd <kbd_intr>
	if (cons.rpos != cons.wpos) {
f01005fe:	8b 83 78 1f 00 00    	mov    0x1f78(%ebx),%eax
	return 0;
f0100604:	ba 00 00 00 00       	mov    $0x0,%edx
	if (cons.rpos != cons.wpos) {
f0100609:	3b 83 7c 1f 00 00    	cmp    0x1f7c(%ebx),%eax
f010060f:	74 1f                	je     f0100630 <cons_getc+0x52>
		c = cons.buf[cons.rpos++];
f0100611:	8d 48 01             	lea    0x1(%eax),%ecx
f0100614:	0f b6 94 03 78 1d 00 	movzbl 0x1d78(%ebx,%eax,1),%edx
f010061b:	00 
			cons.rpos = 0;
f010061c:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100622:	b8 00 00 00 00       	mov    $0x0,%eax
f0100627:	0f 44 c8             	cmove  %eax,%ecx
f010062a:	89 8b 78 1f 00 00    	mov    %ecx,0x1f78(%ebx)
}
f0100630:	89 d0                	mov    %edx,%eax
f0100632:	83 c4 04             	add    $0x4,%esp
f0100635:	5b                   	pop    %ebx
f0100636:	5d                   	pop    %ebp
f0100637:	c3                   	ret    

f0100638 <cons_init>:

// initialize the console devices
void
cons_init(void)
{
f0100638:	f3 0f 1e fb          	endbr32 
f010063c:	55                   	push   %ebp
f010063d:	89 e5                	mov    %esp,%ebp
f010063f:	57                   	push   %edi
f0100640:	56                   	push   %esi
f0100641:	53                   	push   %ebx
f0100642:	83 ec 1c             	sub    $0x1c,%esp
f0100645:	e8 93 fb ff ff       	call   f01001dd <__x86.get_pc_thunk.bx>
f010064a:	81 c3 be 1c 01 00    	add    $0x11cbe,%ebx
	was = *cp;
f0100650:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f0100657:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f010065e:	5a a5 
	if (*cp != 0xA55A) {
f0100660:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f0100667:	66 3d 5a a5          	cmp    $0xa55a,%ax
f010066b:	0f 84 bc 00 00 00    	je     f010072d <cons_init+0xf5>
		addr_6845 = MONO_BASE;
f0100671:	c7 83 88 1f 00 00 b4 	movl   $0x3b4,0x1f88(%ebx)
f0100678:	03 00 00 
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f010067b:	c7 45 e4 00 00 0b f0 	movl   $0xf00b0000,-0x1c(%ebp)
	outb(addr_6845, 14);
f0100682:	8b bb 88 1f 00 00    	mov    0x1f88(%ebx),%edi
f0100688:	b8 0e 00 00 00       	mov    $0xe,%eax
f010068d:	89 fa                	mov    %edi,%edx
f010068f:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f0100690:	8d 4f 01             	lea    0x1(%edi),%ecx
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100693:	89 ca                	mov    %ecx,%edx
f0100695:	ec                   	in     (%dx),%al
f0100696:	0f b6 f0             	movzbl %al,%esi
f0100699:	c1 e6 08             	shl    $0x8,%esi
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010069c:	b8 0f 00 00 00       	mov    $0xf,%eax
f01006a1:	89 fa                	mov    %edi,%edx
f01006a3:	ee                   	out    %al,(%dx)
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01006a4:	89 ca                	mov    %ecx,%edx
f01006a6:	ec                   	in     (%dx),%al
	crt_buf = (uint16_t*) cp;
f01006a7:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01006aa:	89 bb 84 1f 00 00    	mov    %edi,0x1f84(%ebx)
	pos |= inb(addr_6845 + 1);
f01006b0:	0f b6 c0             	movzbl %al,%eax
f01006b3:	09 c6                	or     %eax,%esi
	crt_pos = pos;
f01006b5:	66 89 b3 80 1f 00 00 	mov    %si,0x1f80(%ebx)
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01006bc:	b9 00 00 00 00       	mov    $0x0,%ecx
f01006c1:	89 c8                	mov    %ecx,%eax
f01006c3:	ba fa 03 00 00       	mov    $0x3fa,%edx
f01006c8:	ee                   	out    %al,(%dx)
f01006c9:	bf fb 03 00 00       	mov    $0x3fb,%edi
f01006ce:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f01006d3:	89 fa                	mov    %edi,%edx
f01006d5:	ee                   	out    %al,(%dx)
f01006d6:	b8 0c 00 00 00       	mov    $0xc,%eax
f01006db:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01006e0:	ee                   	out    %al,(%dx)
f01006e1:	be f9 03 00 00       	mov    $0x3f9,%esi
f01006e6:	89 c8                	mov    %ecx,%eax
f01006e8:	89 f2                	mov    %esi,%edx
f01006ea:	ee                   	out    %al,(%dx)
f01006eb:	b8 03 00 00 00       	mov    $0x3,%eax
f01006f0:	89 fa                	mov    %edi,%edx
f01006f2:	ee                   	out    %al,(%dx)
f01006f3:	ba fc 03 00 00       	mov    $0x3fc,%edx
f01006f8:	89 c8                	mov    %ecx,%eax
f01006fa:	ee                   	out    %al,(%dx)
f01006fb:	b8 01 00 00 00       	mov    $0x1,%eax
f0100700:	89 f2                	mov    %esi,%edx
f0100702:	ee                   	out    %al,(%dx)
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100703:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100708:	ec                   	in     (%dx),%al
f0100709:	89 c1                	mov    %eax,%ecx
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f010070b:	3c ff                	cmp    $0xff,%al
f010070d:	0f 95 83 8c 1f 00 00 	setne  0x1f8c(%ebx)
f0100714:	ba fa 03 00 00       	mov    $0x3fa,%edx
f0100719:	ec                   	in     (%dx),%al
f010071a:	ba f8 03 00 00       	mov    $0x3f8,%edx
f010071f:	ec                   	in     (%dx),%al
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f0100720:	80 f9 ff             	cmp    $0xff,%cl
f0100723:	74 25                	je     f010074a <cons_init+0x112>
		cprintf("Serial port does not exist!\n");
}
f0100725:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0100728:	5b                   	pop    %ebx
f0100729:	5e                   	pop    %esi
f010072a:	5f                   	pop    %edi
f010072b:	5d                   	pop    %ebp
f010072c:	c3                   	ret    
		*cp = was;
f010072d:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f0100734:	c7 83 88 1f 00 00 d4 	movl   $0x3d4,0x1f88(%ebx)
f010073b:	03 00 00 
	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f010073e:	c7 45 e4 00 80 0b f0 	movl   $0xf00b8000,-0x1c(%ebp)
f0100745:	e9 38 ff ff ff       	jmp    f0100682 <cons_init+0x4a>
		cprintf("Serial port does not exist!\n");
f010074a:	83 ec 0c             	sub    $0xc,%esp
f010074d:	8d 83 b2 f9 fe ff    	lea    -0x1064e(%ebx),%eax
f0100753:	50                   	push   %eax
f0100754:	e8 f0 03 00 00       	call   f0100b49 <cprintf>
f0100759:	83 c4 10             	add    $0x10,%esp
}
f010075c:	eb c7                	jmp    f0100725 <cons_init+0xed>

f010075e <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f010075e:	f3 0f 1e fb          	endbr32 
f0100762:	55                   	push   %ebp
f0100763:	89 e5                	mov    %esp,%ebp
f0100765:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f0100768:	8b 45 08             	mov    0x8(%ebp),%eax
f010076b:	e8 1f fc ff ff       	call   f010038f <cons_putc>
}
f0100770:	c9                   	leave  
f0100771:	c3                   	ret    

f0100772 <getchar>:

int
getchar(void)
{
f0100772:	f3 0f 1e fb          	endbr32 
f0100776:	55                   	push   %ebp
f0100777:	89 e5                	mov    %esp,%ebp
f0100779:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f010077c:	e8 5d fe ff ff       	call   f01005de <cons_getc>
f0100781:	85 c0                	test   %eax,%eax
f0100783:	74 f7                	je     f010077c <getchar+0xa>
		/* do nothing */;
	return c;
}
f0100785:	c9                   	leave  
f0100786:	c3                   	ret    

f0100787 <iscons>:

int
iscons(int fdnum)
{
f0100787:	f3 0f 1e fb          	endbr32 
	// used by readline
	return 1;
}
f010078b:	b8 01 00 00 00       	mov    $0x1,%eax
f0100790:	c3                   	ret    

f0100791 <__x86.get_pc_thunk.ax>:
f0100791:	8b 04 24             	mov    (%esp),%eax
f0100794:	c3                   	ret    

f0100795 <__x86.get_pc_thunk.si>:
f0100795:	8b 34 24             	mov    (%esp),%esi
f0100798:	c3                   	ret    

f0100799 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100799:	f3 0f 1e fb          	endbr32 
f010079d:	55                   	push   %ebp
f010079e:	89 e5                	mov    %esp,%ebp
f01007a0:	56                   	push   %esi
f01007a1:	53                   	push   %ebx
f01007a2:	e8 36 fa ff ff       	call   f01001dd <__x86.get_pc_thunk.bx>
f01007a7:	81 c3 61 1b 01 00    	add    $0x11b61,%ebx
	int i;

	for (i = 0; i < ARRAY_SIZE(commands); i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f01007ad:	83 ec 04             	sub    $0x4,%esp
f01007b0:	8d 83 d8 fb fe ff    	lea    -0x10428(%ebx),%eax
f01007b6:	50                   	push   %eax
f01007b7:	8d 83 f6 fb fe ff    	lea    -0x1040a(%ebx),%eax
f01007bd:	50                   	push   %eax
f01007be:	8d b3 fb fb fe ff    	lea    -0x10405(%ebx),%esi
f01007c4:	56                   	push   %esi
f01007c5:	e8 7f 03 00 00       	call   f0100b49 <cprintf>
f01007ca:	83 c4 0c             	add    $0xc,%esp
f01007cd:	8d 83 8c fc fe ff    	lea    -0x10374(%ebx),%eax
f01007d3:	50                   	push   %eax
f01007d4:	8d 83 04 fc fe ff    	lea    -0x103fc(%ebx),%eax
f01007da:	50                   	push   %eax
f01007db:	56                   	push   %esi
f01007dc:	e8 68 03 00 00       	call   f0100b49 <cprintf>
	return 0;
}
f01007e1:	b8 00 00 00 00       	mov    $0x0,%eax
f01007e6:	8d 65 f8             	lea    -0x8(%ebp),%esp
f01007e9:	5b                   	pop    %ebx
f01007ea:	5e                   	pop    %esi
f01007eb:	5d                   	pop    %ebp
f01007ec:	c3                   	ret    

f01007ed <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f01007ed:	f3 0f 1e fb          	endbr32 
f01007f1:	55                   	push   %ebp
f01007f2:	89 e5                	mov    %esp,%ebp
f01007f4:	57                   	push   %edi
f01007f5:	56                   	push   %esi
f01007f6:	53                   	push   %ebx
f01007f7:	83 ec 18             	sub    $0x18,%esp
f01007fa:	e8 de f9 ff ff       	call   f01001dd <__x86.get_pc_thunk.bx>
f01007ff:	81 c3 09 1b 01 00    	add    $0x11b09,%ebx
	extern char _start[], entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f0100805:	8d 83 0d fc fe ff    	lea    -0x103f3(%ebx),%eax
f010080b:	50                   	push   %eax
f010080c:	e8 38 03 00 00       	call   f0100b49 <cprintf>
	cprintf("  _start                  %08x (phys)\n", _start);
f0100811:	83 c4 08             	add    $0x8,%esp
f0100814:	ff b3 f8 ff ff ff    	pushl  -0x8(%ebx)
f010081a:	8d 83 b4 fc fe ff    	lea    -0x1034c(%ebx),%eax
f0100820:	50                   	push   %eax
f0100821:	e8 23 03 00 00       	call   f0100b49 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f0100826:	83 c4 0c             	add    $0xc,%esp
f0100829:	c7 c7 0c 00 10 f0    	mov    $0xf010000c,%edi
f010082f:	8d 87 00 00 00 10    	lea    0x10000000(%edi),%eax
f0100835:	50                   	push   %eax
f0100836:	57                   	push   %edi
f0100837:	8d 83 dc fc fe ff    	lea    -0x10324(%ebx),%eax
f010083d:	50                   	push   %eax
f010083e:	e8 06 03 00 00       	call   f0100b49 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f0100843:	83 c4 0c             	add    $0xc,%esp
f0100846:	c7 c0 1d 1c 10 f0    	mov    $0xf0101c1d,%eax
f010084c:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0100852:	52                   	push   %edx
f0100853:	50                   	push   %eax
f0100854:	8d 83 00 fd fe ff    	lea    -0x10300(%ebx),%eax
f010085a:	50                   	push   %eax
f010085b:	e8 e9 02 00 00       	call   f0100b49 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f0100860:	83 c4 0c             	add    $0xc,%esp
f0100863:	c7 c0 60 40 11 f0    	mov    $0xf0114060,%eax
f0100869:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f010086f:	52                   	push   %edx
f0100870:	50                   	push   %eax
f0100871:	8d 83 24 fd fe ff    	lea    -0x102dc(%ebx),%eax
f0100877:	50                   	push   %eax
f0100878:	e8 cc 02 00 00       	call   f0100b49 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f010087d:	83 c4 0c             	add    $0xc,%esp
f0100880:	c7 c6 a0 46 11 f0    	mov    $0xf01146a0,%esi
f0100886:	8d 86 00 00 00 10    	lea    0x10000000(%esi),%eax
f010088c:	50                   	push   %eax
f010088d:	56                   	push   %esi
f010088e:	8d 83 48 fd fe ff    	lea    -0x102b8(%ebx),%eax
f0100894:	50                   	push   %eax
f0100895:	e8 af 02 00 00       	call   f0100b49 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
f010089a:	83 c4 08             	add    $0x8,%esp
		ROUNDUP(end - entry, 1024) / 1024);
f010089d:	29 fe                	sub    %edi,%esi
f010089f:	81 c6 ff 03 00 00    	add    $0x3ff,%esi
	cprintf("Kernel executable memory footprint: %dKB\n",
f01008a5:	c1 fe 0a             	sar    $0xa,%esi
f01008a8:	56                   	push   %esi
f01008a9:	8d 83 6c fd fe ff    	lea    -0x10294(%ebx),%eax
f01008af:	50                   	push   %eax
f01008b0:	e8 94 02 00 00       	call   f0100b49 <cprintf>
	return 0;
}
f01008b5:	b8 00 00 00 00       	mov    $0x0,%eax
f01008ba:	8d 65 f4             	lea    -0xc(%ebp),%esp
f01008bd:	5b                   	pop    %ebx
f01008be:	5e                   	pop    %esi
f01008bf:	5f                   	pop    %edi
f01008c0:	5d                   	pop    %ebp
f01008c1:	c3                   	ret    

f01008c2 <mon_backtrace>:

int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f01008c2:	f3 0f 1e fb          	endbr32 
f01008c6:	55                   	push   %ebp
f01008c7:	89 e5                	mov    %esp,%ebp
f01008c9:	57                   	push   %edi
f01008ca:	56                   	push   %esi
f01008cb:	53                   	push   %ebx
f01008cc:	83 ec 48             	sub    $0x48,%esp
f01008cf:	e8 09 f9 ff ff       	call   f01001dd <__x86.get_pc_thunk.bx>
f01008d4:	81 c3 34 1a 01 00    	add    $0x11a34,%ebx

static inline uint32_t
read_ebp(void)
{
	uint32_t ebp;
	asm volatile("movl %%ebp,%0" : "=r" (ebp));
f01008da:	89 ee                	mov    %ebp,%esi
f01008dc:	89 f7                	mov    %esi,%edi
	uint32_t ebp = read_ebp();  // 拿到%EBP的值
	uint32_t *ptr_ebp = (uint32_t*)ebp;  // 指针
	struct Eipdebuginfo info;
	cprintf("Stack backtrace:\n");
f01008de:	8d 83 26 fc fe ff    	lea    -0x103da(%ebx),%eax
f01008e4:	50                   	push   %eax
f01008e5:	e8 5f 02 00 00       	call   f0100b49 <cprintf>
	while (ebp != 0 && debuginfo_eip(ptr_ebp[1], &info) == 0) {
f01008ea:	83 c4 10             	add    $0x10,%esp
		cprintf(" ebp %x  eip %x  args %08x %08x %08x %08x %08x\n", ebp, ptr_ebp[1], ptr_ebp[2], ptr_ebp[3], ptr_ebp[4], ptr_ebp[5], ptr_ebp[6]);
f01008ed:	8d 83 98 fd fe ff    	lea    -0x10268(%ebx),%eax
f01008f3:	89 45 c4             	mov    %eax,-0x3c(%ebp)
		cprintf("     %s:%d: %.*s+%d\n", info.eip_file, info.eip_line, info.eip_fn_namelen, info.eip_fn_name, ptr_ebp[1] - info.eip_fn_addr);
f01008f6:	8d 83 38 fc fe ff    	lea    -0x103c8(%ebx),%eax
f01008fc:	89 45 c0             	mov    %eax,-0x40(%ebp)
	while (ebp != 0 && debuginfo_eip(ptr_ebp[1], &info) == 0) {
f01008ff:	85 ff                	test   %edi,%edi
f0100901:	74 58                	je     f010095b <mon_backtrace+0x99>
f0100903:	83 ec 08             	sub    $0x8,%esp
f0100906:	8d 45 d0             	lea    -0x30(%ebp),%eax
f0100909:	50                   	push   %eax
f010090a:	ff 76 04             	pushl  0x4(%esi)
f010090d:	e8 44 03 00 00       	call   f0100c56 <debuginfo_eip>
f0100912:	83 c4 10             	add    $0x10,%esp
f0100915:	85 c0                	test   %eax,%eax
f0100917:	75 42                	jne    f010095b <mon_backtrace+0x99>
		cprintf(" ebp %x  eip %x  args %08x %08x %08x %08x %08x\n", ebp, ptr_ebp[1], ptr_ebp[2], ptr_ebp[3], ptr_ebp[4], ptr_ebp[5], ptr_ebp[6]);
f0100919:	ff 76 18             	pushl  0x18(%esi)
f010091c:	ff 76 14             	pushl  0x14(%esi)
f010091f:	ff 76 10             	pushl  0x10(%esi)
f0100922:	ff 76 0c             	pushl  0xc(%esi)
f0100925:	ff 76 08             	pushl  0x8(%esi)
f0100928:	ff 76 04             	pushl  0x4(%esi)
f010092b:	57                   	push   %edi
f010092c:	ff 75 c4             	pushl  -0x3c(%ebp)
f010092f:	e8 15 02 00 00       	call   f0100b49 <cprintf>
		cprintf("     %s:%d: %.*s+%d\n", info.eip_file, info.eip_line, info.eip_fn_namelen, info.eip_fn_name, ptr_ebp[1] - info.eip_fn_addr);
f0100934:	83 c4 18             	add    $0x18,%esp
f0100937:	8b 46 04             	mov    0x4(%esi),%eax
f010093a:	2b 45 e0             	sub    -0x20(%ebp),%eax
f010093d:	50                   	push   %eax
f010093e:	ff 75 d8             	pushl  -0x28(%ebp)
f0100941:	ff 75 dc             	pushl  -0x24(%ebp)
f0100944:	ff 75 d4             	pushl  -0x2c(%ebp)
f0100947:	ff 75 d0             	pushl  -0x30(%ebp)
f010094a:	ff 75 c0             	pushl  -0x40(%ebp)
f010094d:	e8 f7 01 00 00       	call   f0100b49 <cprintf>
		ebp = *ptr_ebp;
f0100952:	8b 3e                	mov    (%esi),%edi
		ptr_ebp = (uint32_t*)ebp;
f0100954:	89 fe                	mov    %edi,%esi
f0100956:	83 c4 20             	add    $0x20,%esp
f0100959:	eb a4                	jmp    f01008ff <mon_backtrace+0x3d>
	}
    
	cprintf("\n");
f010095b:	83 ec 0c             	sub    $0xc,%esp
f010095e:	8d 83 b0 f9 fe ff    	lea    -0x10650(%ebx),%eax
f0100964:	50                   	push   %eax
f0100965:	e8 df 01 00 00       	call   f0100b49 <cprintf>
	
	return 0;
}
f010096a:	b8 00 00 00 00       	mov    $0x0,%eax
f010096f:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0100972:	5b                   	pop    %ebx
f0100973:	5e                   	pop    %esi
f0100974:	5f                   	pop    %edi
f0100975:	5d                   	pop    %ebp
f0100976:	c3                   	ret    

f0100977 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f0100977:	f3 0f 1e fb          	endbr32 
f010097b:	55                   	push   %ebp
f010097c:	89 e5                	mov    %esp,%ebp
f010097e:	57                   	push   %edi
f010097f:	56                   	push   %esi
f0100980:	53                   	push   %ebx
f0100981:	83 ec 68             	sub    $0x68,%esp
f0100984:	e8 54 f8 ff ff       	call   f01001dd <__x86.get_pc_thunk.bx>
f0100989:	81 c3 7f 19 01 00    	add    $0x1197f,%ebx
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f010098f:	8d 83 c8 fd fe ff    	lea    -0x10238(%ebx),%eax
f0100995:	50                   	push   %eax
f0100996:	e8 ae 01 00 00       	call   f0100b49 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f010099b:	8d 83 ec fd fe ff    	lea    -0x10214(%ebx),%eax
f01009a1:	89 04 24             	mov    %eax,(%esp)
f01009a4:	e8 a0 01 00 00       	call   f0100b49 <cprintf>
f01009a9:	83 c4 10             	add    $0x10,%esp
		while (*buf && strchr(WHITESPACE, *buf))
f01009ac:	8d 83 51 fc fe ff    	lea    -0x103af(%ebx),%eax
f01009b2:	89 45 a0             	mov    %eax,-0x60(%ebp)
f01009b5:	e9 dc 00 00 00       	jmp    f0100a96 <monitor+0x11f>
f01009ba:	83 ec 08             	sub    $0x8,%esp
f01009bd:	0f be c0             	movsbl %al,%eax
f01009c0:	50                   	push   %eax
f01009c1:	ff 75 a0             	pushl  -0x60(%ebp)
f01009c4:	e8 9d 0d 00 00       	call   f0101766 <strchr>
f01009c9:	83 c4 10             	add    $0x10,%esp
f01009cc:	85 c0                	test   %eax,%eax
f01009ce:	74 74                	je     f0100a44 <monitor+0xcd>
			*buf++ = 0;
f01009d0:	c6 06 00             	movb   $0x0,(%esi)
f01009d3:	89 7d a4             	mov    %edi,-0x5c(%ebp)
f01009d6:	8d 76 01             	lea    0x1(%esi),%esi
f01009d9:	8b 7d a4             	mov    -0x5c(%ebp),%edi
		while (*buf && strchr(WHITESPACE, *buf))
f01009dc:	0f b6 06             	movzbl (%esi),%eax
f01009df:	84 c0                	test   %al,%al
f01009e1:	75 d7                	jne    f01009ba <monitor+0x43>
	argv[argc] = 0;
f01009e3:	c7 44 bd a8 00 00 00 	movl   $0x0,-0x58(%ebp,%edi,4)
f01009ea:	00 
	if (argc == 0)
f01009eb:	85 ff                	test   %edi,%edi
f01009ed:	0f 84 a3 00 00 00    	je     f0100a96 <monitor+0x11f>
		if (strcmp(argv[0], commands[i].name) == 0)
f01009f3:	83 ec 08             	sub    $0x8,%esp
f01009f6:	8d 83 f6 fb fe ff    	lea    -0x1040a(%ebx),%eax
f01009fc:	50                   	push   %eax
f01009fd:	ff 75 a8             	pushl  -0x58(%ebp)
f0100a00:	e8 fb 0c 00 00       	call   f0101700 <strcmp>
f0100a05:	83 c4 10             	add    $0x10,%esp
f0100a08:	85 c0                	test   %eax,%eax
f0100a0a:	0f 84 b4 00 00 00    	je     f0100ac4 <monitor+0x14d>
f0100a10:	83 ec 08             	sub    $0x8,%esp
f0100a13:	8d 83 04 fc fe ff    	lea    -0x103fc(%ebx),%eax
f0100a19:	50                   	push   %eax
f0100a1a:	ff 75 a8             	pushl  -0x58(%ebp)
f0100a1d:	e8 de 0c 00 00       	call   f0101700 <strcmp>
f0100a22:	83 c4 10             	add    $0x10,%esp
f0100a25:	85 c0                	test   %eax,%eax
f0100a27:	0f 84 92 00 00 00    	je     f0100abf <monitor+0x148>
	cprintf("Unknown command '%s'\n", argv[0]);
f0100a2d:	83 ec 08             	sub    $0x8,%esp
f0100a30:	ff 75 a8             	pushl  -0x58(%ebp)
f0100a33:	8d 83 73 fc fe ff    	lea    -0x1038d(%ebx),%eax
f0100a39:	50                   	push   %eax
f0100a3a:	e8 0a 01 00 00       	call   f0100b49 <cprintf>
	return 0;
f0100a3f:	83 c4 10             	add    $0x10,%esp
f0100a42:	eb 52                	jmp    f0100a96 <monitor+0x11f>
		if (*buf == 0)
f0100a44:	80 3e 00             	cmpb   $0x0,(%esi)
f0100a47:	74 9a                	je     f01009e3 <monitor+0x6c>
		if (argc == MAXARGS-1) {
f0100a49:	83 ff 0f             	cmp    $0xf,%edi
f0100a4c:	74 34                	je     f0100a82 <monitor+0x10b>
		argv[argc++] = buf;
f0100a4e:	8d 47 01             	lea    0x1(%edi),%eax
f0100a51:	89 45 a4             	mov    %eax,-0x5c(%ebp)
f0100a54:	89 74 bd a8          	mov    %esi,-0x58(%ebp,%edi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f0100a58:	0f b6 06             	movzbl (%esi),%eax
f0100a5b:	84 c0                	test   %al,%al
f0100a5d:	0f 84 76 ff ff ff    	je     f01009d9 <monitor+0x62>
f0100a63:	83 ec 08             	sub    $0x8,%esp
f0100a66:	0f be c0             	movsbl %al,%eax
f0100a69:	50                   	push   %eax
f0100a6a:	ff 75 a0             	pushl  -0x60(%ebp)
f0100a6d:	e8 f4 0c 00 00       	call   f0101766 <strchr>
f0100a72:	83 c4 10             	add    $0x10,%esp
f0100a75:	85 c0                	test   %eax,%eax
f0100a77:	0f 85 5c ff ff ff    	jne    f01009d9 <monitor+0x62>
			buf++;
f0100a7d:	83 c6 01             	add    $0x1,%esi
f0100a80:	eb d6                	jmp    f0100a58 <monitor+0xe1>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f0100a82:	83 ec 08             	sub    $0x8,%esp
f0100a85:	6a 10                	push   $0x10
f0100a87:	8d 83 56 fc fe ff    	lea    -0x103aa(%ebx),%eax
f0100a8d:	50                   	push   %eax
f0100a8e:	e8 b6 00 00 00       	call   f0100b49 <cprintf>
			return 0;
f0100a93:	83 c4 10             	add    $0x10,%esp


	while (1) {
		buf = readline("K> ");
f0100a96:	8d bb 4d fc fe ff    	lea    -0x103b3(%ebx),%edi
f0100a9c:	83 ec 0c             	sub    $0xc,%esp
f0100a9f:	57                   	push   %edi
f0100aa0:	e8 50 0a 00 00       	call   f01014f5 <readline>
f0100aa5:	89 c6                	mov    %eax,%esi
		if (buf != NULL)
f0100aa7:	83 c4 10             	add    $0x10,%esp
f0100aaa:	85 c0                	test   %eax,%eax
f0100aac:	74 ee                	je     f0100a9c <monitor+0x125>
	argv[argc] = 0;
f0100aae:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	argc = 0;
f0100ab5:	bf 00 00 00 00       	mov    $0x0,%edi
f0100aba:	e9 1d ff ff ff       	jmp    f01009dc <monitor+0x65>
	for (i = 0; i < ARRAY_SIZE(commands); i++) {
f0100abf:	b8 01 00 00 00       	mov    $0x1,%eax
			return commands[i].func(argc, argv, tf);
f0100ac4:	83 ec 04             	sub    $0x4,%esp
f0100ac7:	8d 04 40             	lea    (%eax,%eax,2),%eax
f0100aca:	ff 75 08             	pushl  0x8(%ebp)
f0100acd:	8d 55 a8             	lea    -0x58(%ebp),%edx
f0100ad0:	52                   	push   %edx
f0100ad1:	57                   	push   %edi
f0100ad2:	ff 94 83 10 1d 00 00 	call   *0x1d10(%ebx,%eax,4)
			if (runcmd(buf, tf) < 0)
f0100ad9:	83 c4 10             	add    $0x10,%esp
f0100adc:	85 c0                	test   %eax,%eax
f0100ade:	79 b6                	jns    f0100a96 <monitor+0x11f>
				break;
	}
}
f0100ae0:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0100ae3:	5b                   	pop    %ebx
f0100ae4:	5e                   	pop    %esi
f0100ae5:	5f                   	pop    %edi
f0100ae6:	5d                   	pop    %ebp
f0100ae7:	c3                   	ret    

f0100ae8 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0100ae8:	f3 0f 1e fb          	endbr32 
f0100aec:	55                   	push   %ebp
f0100aed:	89 e5                	mov    %esp,%ebp
f0100aef:	53                   	push   %ebx
f0100af0:	83 ec 10             	sub    $0x10,%esp
f0100af3:	e8 e5 f6 ff ff       	call   f01001dd <__x86.get_pc_thunk.bx>
f0100af8:	81 c3 10 18 01 00    	add    $0x11810,%ebx
	cputchar(ch);
f0100afe:	ff 75 08             	pushl  0x8(%ebp)
f0100b01:	e8 58 fc ff ff       	call   f010075e <cputchar>
	*cnt++;
}
f0100b06:	83 c4 10             	add    $0x10,%esp
f0100b09:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f0100b0c:	c9                   	leave  
f0100b0d:	c3                   	ret    

f0100b0e <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0100b0e:	f3 0f 1e fb          	endbr32 
f0100b12:	55                   	push   %ebp
f0100b13:	89 e5                	mov    %esp,%ebp
f0100b15:	53                   	push   %ebx
f0100b16:	83 ec 14             	sub    $0x14,%esp
f0100b19:	e8 bf f6 ff ff       	call   f01001dd <__x86.get_pc_thunk.bx>
f0100b1e:	81 c3 ea 17 01 00    	add    $0x117ea,%ebx
	int cnt = 0;
f0100b24:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0100b2b:	ff 75 0c             	pushl  0xc(%ebp)
f0100b2e:	ff 75 08             	pushl  0x8(%ebp)
f0100b31:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0100b34:	50                   	push   %eax
f0100b35:	8d 83 e0 e7 fe ff    	lea    -0x11820(%ebx),%eax
f0100b3b:	50                   	push   %eax
f0100b3c:	e8 7a 04 00 00       	call   f0100fbb <vprintfmt>
	return cnt;
}
f0100b41:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0100b44:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f0100b47:	c9                   	leave  
f0100b48:	c3                   	ret    

f0100b49 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0100b49:	f3 0f 1e fb          	endbr32 
f0100b4d:	55                   	push   %ebp
f0100b4e:	89 e5                	mov    %esp,%ebp
f0100b50:	83 ec 10             	sub    $0x10,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0100b53:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0100b56:	50                   	push   %eax
f0100b57:	ff 75 08             	pushl  0x8(%ebp)
f0100b5a:	e8 af ff ff ff       	call   f0100b0e <vcprintf>
	va_end(ap);
	
	return cnt;
}
f0100b5f:	c9                   	leave  
f0100b60:	c3                   	ret    

f0100b61 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0100b61:	55                   	push   %ebp
f0100b62:	89 e5                	mov    %esp,%ebp
f0100b64:	57                   	push   %edi
f0100b65:	56                   	push   %esi
f0100b66:	53                   	push   %ebx
f0100b67:	83 ec 14             	sub    $0x14,%esp
f0100b6a:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0100b6d:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f0100b70:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0100b73:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0100b76:	8b 1a                	mov    (%edx),%ebx
f0100b78:	8b 01                	mov    (%ecx),%eax
f0100b7a:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0100b7d:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)

	while (l <= r) {
f0100b84:	eb 23                	jmp    f0100ba9 <stab_binsearch+0x48>

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0100b86:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0100b89:	eb 1e                	jmp    f0100ba9 <stab_binsearch+0x48>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0100b8b:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0100b8e:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0100b91:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0100b95:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0100b98:	73 46                	jae    f0100be0 <stab_binsearch+0x7f>
			*region_left = m;
f0100b9a:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0100b9d:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0100b9f:	8d 5f 01             	lea    0x1(%edi),%ebx
		any_matches = 1;
f0100ba2:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
	while (l <= r) {
f0100ba9:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0100bac:	7f 5f                	jg     f0100c0d <stab_binsearch+0xac>
		int true_m = (l + r) / 2, m = true_m;
f0100bae:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0100bb1:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f0100bb4:	89 d0                	mov    %edx,%eax
f0100bb6:	c1 e8 1f             	shr    $0x1f,%eax
f0100bb9:	01 d0                	add    %edx,%eax
f0100bbb:	89 c7                	mov    %eax,%edi
f0100bbd:	d1 ff                	sar    %edi
f0100bbf:	83 e0 fe             	and    $0xfffffffe,%eax
f0100bc2:	01 f8                	add    %edi,%eax
f0100bc4:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0100bc7:	8d 54 81 04          	lea    0x4(%ecx,%eax,4),%edx
f0100bcb:	89 f8                	mov    %edi,%eax
		while (m >= l && stabs[m].n_type != type)
f0100bcd:	39 c3                	cmp    %eax,%ebx
f0100bcf:	7f b5                	jg     f0100b86 <stab_binsearch+0x25>
f0100bd1:	0f b6 0a             	movzbl (%edx),%ecx
f0100bd4:	83 ea 0c             	sub    $0xc,%edx
f0100bd7:	39 f1                	cmp    %esi,%ecx
f0100bd9:	74 b0                	je     f0100b8b <stab_binsearch+0x2a>
			m--;
f0100bdb:	83 e8 01             	sub    $0x1,%eax
f0100bde:	eb ed                	jmp    f0100bcd <stab_binsearch+0x6c>
		} else if (stabs[m].n_value > addr) {
f0100be0:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0100be3:	76 14                	jbe    f0100bf9 <stab_binsearch+0x98>
			*region_right = m - 1;
f0100be5:	83 e8 01             	sub    $0x1,%eax
f0100be8:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0100beb:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0100bee:	89 07                	mov    %eax,(%edi)
		any_matches = 1;
f0100bf0:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0100bf7:	eb b0                	jmp    f0100ba9 <stab_binsearch+0x48>
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0100bf9:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100bfc:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f0100bfe:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f0100c02:	89 c3                	mov    %eax,%ebx
		any_matches = 1;
f0100c04:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0100c0b:	eb 9c                	jmp    f0100ba9 <stab_binsearch+0x48>
		}
	}

	if (!any_matches)
f0100c0d:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f0100c11:	75 15                	jne    f0100c28 <stab_binsearch+0xc7>
		*region_right = *region_left - 1;
f0100c13:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100c16:	8b 00                	mov    (%eax),%eax
f0100c18:	83 e8 01             	sub    $0x1,%eax
f0100c1b:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0100c1e:	89 07                	mov    %eax,(%edi)
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0100c20:	83 c4 14             	add    $0x14,%esp
f0100c23:	5b                   	pop    %ebx
f0100c24:	5e                   	pop    %esi
f0100c25:	5f                   	pop    %edi
f0100c26:	5d                   	pop    %ebp
f0100c27:	c3                   	ret    
		for (l = *region_right;
f0100c28:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100c2b:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0100c2d:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100c30:	8b 0f                	mov    (%edi),%ecx
f0100c32:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0100c35:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0100c38:	8d 54 97 04          	lea    0x4(%edi,%edx,4),%edx
		for (l = *region_right;
f0100c3c:	eb 03                	jmp    f0100c41 <stab_binsearch+0xe0>
		     l--)
f0100c3e:	83 e8 01             	sub    $0x1,%eax
		for (l = *region_right;
f0100c41:	39 c1                	cmp    %eax,%ecx
f0100c43:	7d 0a                	jge    f0100c4f <stab_binsearch+0xee>
		     l > *region_left && stabs[l].n_type != type;
f0100c45:	0f b6 1a             	movzbl (%edx),%ebx
f0100c48:	83 ea 0c             	sub    $0xc,%edx
f0100c4b:	39 f3                	cmp    %esi,%ebx
f0100c4d:	75 ef                	jne    f0100c3e <stab_binsearch+0xdd>
		*region_left = l;
f0100c4f:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100c52:	89 07                	mov    %eax,(%edi)
}
f0100c54:	eb ca                	jmp    f0100c20 <stab_binsearch+0xbf>

f0100c56 <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0100c56:	f3 0f 1e fb          	endbr32 
f0100c5a:	55                   	push   %ebp
f0100c5b:	89 e5                	mov    %esp,%ebp
f0100c5d:	57                   	push   %edi
f0100c5e:	56                   	push   %esi
f0100c5f:	53                   	push   %ebx
f0100c60:	83 ec 3c             	sub    $0x3c,%esp
f0100c63:	e8 75 f5 ff ff       	call   f01001dd <__x86.get_pc_thunk.bx>
f0100c68:	81 c3 a0 16 01 00    	add    $0x116a0,%ebx
f0100c6e:	89 5d c4             	mov    %ebx,-0x3c(%ebp)
f0100c71:	8b 7d 08             	mov    0x8(%ebp),%edi
f0100c74:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0100c77:	8d 83 11 fe fe ff    	lea    -0x101ef(%ebx),%eax
f0100c7d:	89 06                	mov    %eax,(%esi)
	info->eip_line = 0;
f0100c7f:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0100c86:	89 46 08             	mov    %eax,0x8(%esi)
	info->eip_fn_namelen = 9;
f0100c89:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0100c90:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0100c93:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0100c9a:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0100ca0:	0f 86 38 01 00 00    	jbe    f0100dde <debuginfo_eip+0x188>
		// Can't search for user-level addresses yet!
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100ca6:	c7 c0 bd 67 10 f0    	mov    $0xf01067bd,%eax
f0100cac:	39 83 fc ff ff ff    	cmp    %eax,-0x4(%ebx)
f0100cb2:	0f 86 da 01 00 00    	jbe    f0100e92 <debuginfo_eip+0x23c>
f0100cb8:	8b 5d c4             	mov    -0x3c(%ebp),%ebx
f0100cbb:	c7 c0 80 81 10 f0    	mov    $0xf0108180,%eax
f0100cc1:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0100cc5:	0f 85 ce 01 00 00    	jne    f0100e99 <debuginfo_eip+0x243>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.

	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0100ccb:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0100cd2:	c7 c0 34 23 10 f0    	mov    $0xf0102334,%eax
f0100cd8:	c7 c2 bc 67 10 f0    	mov    $0xf01067bc,%edx
f0100cde:	29 c2                	sub    %eax,%edx
f0100ce0:	c1 fa 02             	sar    $0x2,%edx
f0100ce3:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f0100ce9:	83 ea 01             	sub    $0x1,%edx
f0100cec:	89 55 e0             	mov    %edx,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0100cef:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0100cf2:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0100cf5:	83 ec 08             	sub    $0x8,%esp
f0100cf8:	57                   	push   %edi
f0100cf9:	6a 64                	push   $0x64
f0100cfb:	e8 61 fe ff ff       	call   f0100b61 <stab_binsearch>
	if (lfile == 0)
f0100d00:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100d03:	83 c4 10             	add    $0x10,%esp
f0100d06:	85 c0                	test   %eax,%eax
f0100d08:	0f 84 92 01 00 00    	je     f0100ea0 <debuginfo_eip+0x24a>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0100d0e:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0100d11:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100d14:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0100d17:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0100d1a:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100d1d:	83 ec 08             	sub    $0x8,%esp
f0100d20:	57                   	push   %edi
f0100d21:	6a 24                	push   $0x24
f0100d23:	c7 c0 34 23 10 f0    	mov    $0xf0102334,%eax
f0100d29:	e8 33 fe ff ff       	call   f0100b61 <stab_binsearch>

	if (lfun <= rfun) {
f0100d2e:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0100d31:	8b 4d d8             	mov    -0x28(%ebp),%ecx
f0100d34:	89 4d c0             	mov    %ecx,-0x40(%ebp)
f0100d37:	83 c4 10             	add    $0x10,%esp
f0100d3a:	39 c8                	cmp    %ecx,%eax
f0100d3c:	0f 8f b7 00 00 00    	jg     f0100df9 <debuginfo_eip+0x1a3>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0100d42:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0100d45:	c7 c1 34 23 10 f0    	mov    $0xf0102334,%ecx
f0100d4b:	8d 0c 91             	lea    (%ecx,%edx,4),%ecx
f0100d4e:	8b 11                	mov    (%ecx),%edx
f0100d50:	89 55 bc             	mov    %edx,-0x44(%ebp)
f0100d53:	c7 c2 80 81 10 f0    	mov    $0xf0108180,%edx
f0100d59:	89 5d c4             	mov    %ebx,-0x3c(%ebp)
f0100d5c:	81 ea bd 67 10 f0    	sub    $0xf01067bd,%edx
f0100d62:	8b 5d bc             	mov    -0x44(%ebp),%ebx
f0100d65:	39 d3                	cmp    %edx,%ebx
f0100d67:	73 0c                	jae    f0100d75 <debuginfo_eip+0x11f>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0100d69:	8b 55 c4             	mov    -0x3c(%ebp),%edx
f0100d6c:	81 c3 bd 67 10 f0    	add    $0xf01067bd,%ebx
f0100d72:	89 5e 08             	mov    %ebx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0100d75:	8b 51 08             	mov    0x8(%ecx),%edx
f0100d78:	89 56 10             	mov    %edx,0x10(%esi)
		addr -= info->eip_fn_addr;
f0100d7b:	29 d7                	sub    %edx,%edi
		// Search within the function definition for the line number.
		lline = lfun;
f0100d7d:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		rline = rfun;
f0100d80:	8b 45 c0             	mov    -0x40(%ebp),%eax
f0100d83:	89 45 d0             	mov    %eax,-0x30(%ebp)
		info->eip_fn_addr = addr;
		lline = lfile;
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0100d86:	83 ec 08             	sub    $0x8,%esp
f0100d89:	6a 3a                	push   $0x3a
f0100d8b:	ff 76 08             	pushl  0x8(%esi)
f0100d8e:	8b 5d c4             	mov    -0x3c(%ebp),%ebx
f0100d91:	e8 f5 09 00 00       	call   f010178b <strfind>
f0100d96:	2b 46 08             	sub    0x8(%esi),%eax
f0100d99:	89 46 0c             	mov    %eax,0xc(%esi)
	// Hint:
	//	There's a particular stabs type used for line numbers.
	//	Look at the STABS documentation and <inc/stab.h> to find
	//	which one.
	// Your code here.
	stab_binsearch(stabs, &lline, &rline, N_SLINE, addr);
f0100d9c:	8d 4d d0             	lea    -0x30(%ebp),%ecx
f0100d9f:	8d 55 d4             	lea    -0x2c(%ebp),%edx
f0100da2:	83 c4 08             	add    $0x8,%esp
f0100da5:	57                   	push   %edi
f0100da6:	6a 44                	push   $0x44
f0100da8:	c7 c0 34 23 10 f0    	mov    $0xf0102334,%eax
f0100dae:	e8 ae fd ff ff       	call   f0100b61 <stab_binsearch>
		if (lline <= rline) {
f0100db3:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100db6:	83 c4 10             	add    $0x10,%esp
f0100db9:	3b 45 d0             	cmp    -0x30(%ebp),%eax
f0100dbc:	0f 8f e5 00 00 00    	jg     f0100ea7 <debuginfo_eip+0x251>
		    info->eip_line = stabs[lline].n_desc;
f0100dc2:	89 c2                	mov    %eax,%edx
f0100dc4:	8d 0c 40             	lea    (%eax,%eax,2),%ecx
f0100dc7:	c7 c0 34 23 10 f0    	mov    $0xf0102334,%eax
f0100dcd:	0f b7 5c 88 06       	movzwl 0x6(%eax,%ecx,4),%ebx
f0100dd2:	89 5e 04             	mov    %ebx,0x4(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100dd5:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100dd8:	8d 44 88 04          	lea    0x4(%eax,%ecx,4),%eax
f0100ddc:	eb 35                	jmp    f0100e13 <debuginfo_eip+0x1bd>
  	        panic("User address");
f0100dde:	83 ec 04             	sub    $0x4,%esp
f0100de1:	8b 5d c4             	mov    -0x3c(%ebp),%ebx
f0100de4:	8d 83 1b fe fe ff    	lea    -0x101e5(%ebx),%eax
f0100dea:	50                   	push   %eax
f0100deb:	6a 7f                	push   $0x7f
f0100ded:	8d 83 28 fe fe ff    	lea    -0x101d8(%ebx),%eax
f0100df3:	50                   	push   %eax
f0100df4:	e8 26 f3 ff ff       	call   f010011f <_panic>
		info->eip_fn_addr = addr;
f0100df9:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0100dfc:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100dff:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		rline = rfile;
f0100e02:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100e05:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0100e08:	e9 79 ff ff ff       	jmp    f0100d86 <debuginfo_eip+0x130>
f0100e0d:	83 ea 01             	sub    $0x1,%edx
f0100e10:	83 e8 0c             	sub    $0xc,%eax
	while (lline >= lfile
f0100e13:	39 d7                	cmp    %edx,%edi
f0100e15:	7f 3a                	jg     f0100e51 <debuginfo_eip+0x1fb>
	       && stabs[lline].n_type != N_SOL
f0100e17:	0f b6 08             	movzbl (%eax),%ecx
f0100e1a:	80 f9 84             	cmp    $0x84,%cl
f0100e1d:	74 0b                	je     f0100e2a <debuginfo_eip+0x1d4>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0100e1f:	80 f9 64             	cmp    $0x64,%cl
f0100e22:	75 e9                	jne    f0100e0d <debuginfo_eip+0x1b7>
f0100e24:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
f0100e28:	74 e3                	je     f0100e0d <debuginfo_eip+0x1b7>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0100e2a:	8d 14 52             	lea    (%edx,%edx,2),%edx
f0100e2d:	8b 7d c4             	mov    -0x3c(%ebp),%edi
f0100e30:	c7 c0 34 23 10 f0    	mov    $0xf0102334,%eax
f0100e36:	8b 14 90             	mov    (%eax,%edx,4),%edx
f0100e39:	c7 c0 80 81 10 f0    	mov    $0xf0108180,%eax
f0100e3f:	81 e8 bd 67 10 f0    	sub    $0xf01067bd,%eax
f0100e45:	39 c2                	cmp    %eax,%edx
f0100e47:	73 08                	jae    f0100e51 <debuginfo_eip+0x1fb>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0100e49:	81 c2 bd 67 10 f0    	add    $0xf01067bd,%edx
f0100e4f:	89 16                	mov    %edx,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100e51:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100e54:	8b 5d d8             	mov    -0x28(%ebp),%ebx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100e57:	b8 00 00 00 00       	mov    $0x0,%eax
	if (lfun < rfun)
f0100e5c:	39 da                	cmp    %ebx,%edx
f0100e5e:	7d 53                	jge    f0100eb3 <debuginfo_eip+0x25d>
		for (lline = lfun + 1;
f0100e60:	8d 42 01             	lea    0x1(%edx),%eax
f0100e63:	8d 0c 40             	lea    (%eax,%eax,2),%ecx
f0100e66:	8b 7d c4             	mov    -0x3c(%ebp),%edi
f0100e69:	c7 c2 34 23 10 f0    	mov    $0xf0102334,%edx
f0100e6f:	8d 54 8a 04          	lea    0x4(%edx,%ecx,4),%edx
f0100e73:	eb 04                	jmp    f0100e79 <debuginfo_eip+0x223>
			info->eip_fn_narg++;
f0100e75:	83 46 14 01          	addl   $0x1,0x14(%esi)
		for (lline = lfun + 1;
f0100e79:	39 c3                	cmp    %eax,%ebx
f0100e7b:	7e 31                	jle    f0100eae <debuginfo_eip+0x258>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0100e7d:	0f b6 0a             	movzbl (%edx),%ecx
f0100e80:	83 c0 01             	add    $0x1,%eax
f0100e83:	83 c2 0c             	add    $0xc,%edx
f0100e86:	80 f9 a0             	cmp    $0xa0,%cl
f0100e89:	74 ea                	je     f0100e75 <debuginfo_eip+0x21f>
	return 0;
f0100e8b:	b8 00 00 00 00       	mov    $0x0,%eax
f0100e90:	eb 21                	jmp    f0100eb3 <debuginfo_eip+0x25d>
		return -1;
f0100e92:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100e97:	eb 1a                	jmp    f0100eb3 <debuginfo_eip+0x25d>
f0100e99:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100e9e:	eb 13                	jmp    f0100eb3 <debuginfo_eip+0x25d>
		return -1;
f0100ea0:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100ea5:	eb 0c                	jmp    f0100eb3 <debuginfo_eip+0x25d>
		    return -1;
f0100ea7:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100eac:	eb 05                	jmp    f0100eb3 <debuginfo_eip+0x25d>
	return 0;
f0100eae:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0100eb3:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0100eb6:	5b                   	pop    %ebx
f0100eb7:	5e                   	pop    %esi
f0100eb8:	5f                   	pop    %edi
f0100eb9:	5d                   	pop    %ebp
f0100eba:	c3                   	ret    

f0100ebb <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0100ebb:	55                   	push   %ebp
f0100ebc:	89 e5                	mov    %esp,%ebp
f0100ebe:	57                   	push   %edi
f0100ebf:	56                   	push   %esi
f0100ec0:	53                   	push   %ebx
f0100ec1:	83 ec 2c             	sub    $0x2c,%esp
f0100ec4:	e8 28 06 00 00       	call   f01014f1 <__x86.get_pc_thunk.cx>
f0100ec9:	81 c1 3f 14 01 00    	add    $0x1143f,%ecx
f0100ecf:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0100ed2:	89 c7                	mov    %eax,%edi
f0100ed4:	89 d6                	mov    %edx,%esi
f0100ed6:	8b 45 08             	mov    0x8(%ebp),%eax
f0100ed9:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100edc:	89 d1                	mov    %edx,%ecx
f0100ede:	89 c2                	mov    %eax,%edx
f0100ee0:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0100ee3:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0100ee6:	8b 45 10             	mov    0x10(%ebp),%eax
f0100ee9:	8b 5d 14             	mov    0x14(%ebp),%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0100eec:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0100eef:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
f0100ef6:	39 c2                	cmp    %eax,%edx
f0100ef8:	1b 4d e4             	sbb    -0x1c(%ebp),%ecx
f0100efb:	72 41                	jb     f0100f3e <printnum+0x83>
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0100efd:	83 ec 0c             	sub    $0xc,%esp
f0100f00:	ff 75 18             	pushl  0x18(%ebp)
f0100f03:	83 eb 01             	sub    $0x1,%ebx
f0100f06:	53                   	push   %ebx
f0100f07:	50                   	push   %eax
f0100f08:	83 ec 08             	sub    $0x8,%esp
f0100f0b:	ff 75 e4             	pushl  -0x1c(%ebp)
f0100f0e:	ff 75 e0             	pushl  -0x20(%ebp)
f0100f11:	ff 75 d4             	pushl  -0x2c(%ebp)
f0100f14:	ff 75 d0             	pushl  -0x30(%ebp)
f0100f17:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0100f1a:	e8 a1 0a 00 00       	call   f01019c0 <__udivdi3>
f0100f1f:	83 c4 18             	add    $0x18,%esp
f0100f22:	52                   	push   %edx
f0100f23:	50                   	push   %eax
f0100f24:	89 f2                	mov    %esi,%edx
f0100f26:	89 f8                	mov    %edi,%eax
f0100f28:	e8 8e ff ff ff       	call   f0100ebb <printnum>
f0100f2d:	83 c4 20             	add    $0x20,%esp
f0100f30:	eb 13                	jmp    f0100f45 <printnum+0x8a>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0100f32:	83 ec 08             	sub    $0x8,%esp
f0100f35:	56                   	push   %esi
f0100f36:	ff 75 18             	pushl  0x18(%ebp)
f0100f39:	ff d7                	call   *%edi
f0100f3b:	83 c4 10             	add    $0x10,%esp
		while (--width > 0)
f0100f3e:	83 eb 01             	sub    $0x1,%ebx
f0100f41:	85 db                	test   %ebx,%ebx
f0100f43:	7f ed                	jg     f0100f32 <printnum+0x77>
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0100f45:	83 ec 08             	sub    $0x8,%esp
f0100f48:	56                   	push   %esi
f0100f49:	83 ec 04             	sub    $0x4,%esp
f0100f4c:	ff 75 e4             	pushl  -0x1c(%ebp)
f0100f4f:	ff 75 e0             	pushl  -0x20(%ebp)
f0100f52:	ff 75 d4             	pushl  -0x2c(%ebp)
f0100f55:	ff 75 d0             	pushl  -0x30(%ebp)
f0100f58:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0100f5b:	e8 70 0b 00 00       	call   f0101ad0 <__umoddi3>
f0100f60:	83 c4 14             	add    $0x14,%esp
f0100f63:	0f be 84 03 36 fe fe 	movsbl -0x101ca(%ebx,%eax,1),%eax
f0100f6a:	ff 
f0100f6b:	50                   	push   %eax
f0100f6c:	ff d7                	call   *%edi
}
f0100f6e:	83 c4 10             	add    $0x10,%esp
f0100f71:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0100f74:	5b                   	pop    %ebx
f0100f75:	5e                   	pop    %esi
f0100f76:	5f                   	pop    %edi
f0100f77:	5d                   	pop    %ebp
f0100f78:	c3                   	ret    

f0100f79 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0100f79:	f3 0f 1e fb          	endbr32 
f0100f7d:	55                   	push   %ebp
f0100f7e:	89 e5                	mov    %esp,%ebp
f0100f80:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0100f83:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0100f87:	8b 10                	mov    (%eax),%edx
f0100f89:	3b 50 04             	cmp    0x4(%eax),%edx
f0100f8c:	73 0a                	jae    f0100f98 <sprintputch+0x1f>
		*b->buf++ = ch;
f0100f8e:	8d 4a 01             	lea    0x1(%edx),%ecx
f0100f91:	89 08                	mov    %ecx,(%eax)
f0100f93:	8b 45 08             	mov    0x8(%ebp),%eax
f0100f96:	88 02                	mov    %al,(%edx)
}
f0100f98:	5d                   	pop    %ebp
f0100f99:	c3                   	ret    

f0100f9a <printfmt>:
{
f0100f9a:	f3 0f 1e fb          	endbr32 
f0100f9e:	55                   	push   %ebp
f0100f9f:	89 e5                	mov    %esp,%ebp
f0100fa1:	83 ec 08             	sub    $0x8,%esp
	va_start(ap, fmt);
f0100fa4:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0100fa7:	50                   	push   %eax
f0100fa8:	ff 75 10             	pushl  0x10(%ebp)
f0100fab:	ff 75 0c             	pushl  0xc(%ebp)
f0100fae:	ff 75 08             	pushl  0x8(%ebp)
f0100fb1:	e8 05 00 00 00       	call   f0100fbb <vprintfmt>
}
f0100fb6:	83 c4 10             	add    $0x10,%esp
f0100fb9:	c9                   	leave  
f0100fba:	c3                   	ret    

f0100fbb <vprintfmt>:
{
f0100fbb:	f3 0f 1e fb          	endbr32 
f0100fbf:	55                   	push   %ebp
f0100fc0:	89 e5                	mov    %esp,%ebp
f0100fc2:	57                   	push   %edi
f0100fc3:	56                   	push   %esi
f0100fc4:	53                   	push   %ebx
f0100fc5:	83 ec 3c             	sub    $0x3c,%esp
f0100fc8:	e8 c4 f7 ff ff       	call   f0100791 <__x86.get_pc_thunk.ax>
f0100fcd:	05 3b 13 01 00       	add    $0x1133b,%eax
f0100fd2:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0100fd5:	8b 75 08             	mov    0x8(%ebp),%esi
f0100fd8:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0100fdb:	8b 5d 10             	mov    0x10(%ebp),%ebx
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0100fde:	8d 80 20 1d 00 00    	lea    0x1d20(%eax),%eax
f0100fe4:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0100fe7:	e9 cd 03 00 00       	jmp    f01013b9 <.L25+0x48>
		padc = ' ';
f0100fec:	c6 45 cf 20          	movb   $0x20,-0x31(%ebp)
		altflag = 0;
f0100ff0:	c7 45 d0 00 00 00 00 	movl   $0x0,-0x30(%ebp)
		precision = -1;
f0100ff7:	c7 45 d8 ff ff ff ff 	movl   $0xffffffff,-0x28(%ebp)
		width = -1;
f0100ffe:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		lflag = 0;
f0101005:	b9 00 00 00 00       	mov    $0x0,%ecx
f010100a:	89 4d c8             	mov    %ecx,-0x38(%ebp)
f010100d:	89 75 08             	mov    %esi,0x8(%ebp)
		switch (ch = *(unsigned char *) fmt++) {
f0101010:	8d 43 01             	lea    0x1(%ebx),%eax
f0101013:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0101016:	0f b6 13             	movzbl (%ebx),%edx
f0101019:	8d 42 dd             	lea    -0x23(%edx),%eax
f010101c:	3c 55                	cmp    $0x55,%al
f010101e:	0f 87 21 04 00 00    	ja     f0101445 <.L20>
f0101024:	0f b6 c0             	movzbl %al,%eax
f0101027:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f010102a:	89 ce                	mov    %ecx,%esi
f010102c:	03 b4 81 c4 fe fe ff 	add    -0x1013c(%ecx,%eax,4),%esi
f0101033:	3e ff e6             	notrack jmp *%esi

f0101036 <.L68>:
f0101036:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			padc = '-';
f0101039:	c6 45 cf 2d          	movb   $0x2d,-0x31(%ebp)
f010103d:	eb d1                	jmp    f0101010 <vprintfmt+0x55>

f010103f <.L32>:
		switch (ch = *(unsigned char *) fmt++) {
f010103f:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0101042:	c6 45 cf 30          	movb   $0x30,-0x31(%ebp)
f0101046:	eb c8                	jmp    f0101010 <vprintfmt+0x55>

f0101048 <.L31>:
f0101048:	0f b6 d2             	movzbl %dl,%edx
f010104b:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			for (precision = 0; ; ++fmt) {
f010104e:	b8 00 00 00 00       	mov    $0x0,%eax
f0101053:	8b 75 08             	mov    0x8(%ebp),%esi
				precision = precision * 10 + ch - '0';
f0101056:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0101059:	8d 44 42 d0          	lea    -0x30(%edx,%eax,2),%eax
				ch = *fmt;
f010105d:	0f be 13             	movsbl (%ebx),%edx
				if (ch < '0' || ch > '9')
f0101060:	8d 4a d0             	lea    -0x30(%edx),%ecx
f0101063:	83 f9 09             	cmp    $0x9,%ecx
f0101066:	77 58                	ja     f01010c0 <.L36+0xf>
			for (precision = 0; ; ++fmt) {
f0101068:	83 c3 01             	add    $0x1,%ebx
				precision = precision * 10 + ch - '0';
f010106b:	eb e9                	jmp    f0101056 <.L31+0xe>

f010106d <.L34>:
			precision = va_arg(ap, int);
f010106d:	8b 45 14             	mov    0x14(%ebp),%eax
f0101070:	8b 00                	mov    (%eax),%eax
f0101072:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0101075:	8b 45 14             	mov    0x14(%ebp),%eax
f0101078:	8d 40 04             	lea    0x4(%eax),%eax
f010107b:	89 45 14             	mov    %eax,0x14(%ebp)
		switch (ch = *(unsigned char *) fmt++) {
f010107e:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			if (width < 0)
f0101081:	83 7d d4 00          	cmpl   $0x0,-0x2c(%ebp)
f0101085:	79 89                	jns    f0101010 <vprintfmt+0x55>
				width = precision, precision = -1;
f0101087:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010108a:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f010108d:	c7 45 d8 ff ff ff ff 	movl   $0xffffffff,-0x28(%ebp)
f0101094:	e9 77 ff ff ff       	jmp    f0101010 <vprintfmt+0x55>

f0101099 <.L33>:
f0101099:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010109c:	85 c0                	test   %eax,%eax
f010109e:	ba 00 00 00 00       	mov    $0x0,%edx
f01010a3:	0f 49 d0             	cmovns %eax,%edx
f01010a6:	89 55 d4             	mov    %edx,-0x2c(%ebp)
		switch (ch = *(unsigned char *) fmt++) {
f01010a9:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			goto reswitch;
f01010ac:	e9 5f ff ff ff       	jmp    f0101010 <vprintfmt+0x55>

f01010b1 <.L36>:
		switch (ch = *(unsigned char *) fmt++) {
f01010b1:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			altflag = 1;
f01010b4:	c7 45 d0 01 00 00 00 	movl   $0x1,-0x30(%ebp)
			goto reswitch;
f01010bb:	e9 50 ff ff ff       	jmp    f0101010 <vprintfmt+0x55>
f01010c0:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01010c3:	89 75 08             	mov    %esi,0x8(%ebp)
f01010c6:	eb b9                	jmp    f0101081 <.L34+0x14>

f01010c8 <.L27>:
			lflag++;
f01010c8:	83 45 c8 01          	addl   $0x1,-0x38(%ebp)
		switch (ch = *(unsigned char *) fmt++) {
f01010cc:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			goto reswitch;
f01010cf:	e9 3c ff ff ff       	jmp    f0101010 <vprintfmt+0x55>

f01010d4 <.L30>:
f01010d4:	8b 75 08             	mov    0x8(%ebp),%esi
			putch(va_arg(ap, int), putdat);
f01010d7:	8b 45 14             	mov    0x14(%ebp),%eax
f01010da:	8d 58 04             	lea    0x4(%eax),%ebx
f01010dd:	83 ec 08             	sub    $0x8,%esp
f01010e0:	57                   	push   %edi
f01010e1:	ff 30                	pushl  (%eax)
f01010e3:	ff d6                	call   *%esi
			break;
f01010e5:	83 c4 10             	add    $0x10,%esp
			putch(va_arg(ap, int), putdat);
f01010e8:	89 5d 14             	mov    %ebx,0x14(%ebp)
			break;
f01010eb:	e9 c6 02 00 00       	jmp    f01013b6 <.L25+0x45>

f01010f0 <.L28>:
f01010f0:	8b 75 08             	mov    0x8(%ebp),%esi
			err = va_arg(ap, int);
f01010f3:	8b 45 14             	mov    0x14(%ebp),%eax
f01010f6:	8d 58 04             	lea    0x4(%eax),%ebx
f01010f9:	8b 00                	mov    (%eax),%eax
f01010fb:	99                   	cltd   
f01010fc:	31 d0                	xor    %edx,%eax
f01010fe:	29 d0                	sub    %edx,%eax
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0101100:	83 f8 06             	cmp    $0x6,%eax
f0101103:	7f 27                	jg     f010112c <.L28+0x3c>
f0101105:	8b 55 c4             	mov    -0x3c(%ebp),%edx
f0101108:	8b 14 82             	mov    (%edx,%eax,4),%edx
f010110b:	85 d2                	test   %edx,%edx
f010110d:	74 1d                	je     f010112c <.L28+0x3c>
				printfmt(putch, putdat, "%s", p);
f010110f:	52                   	push   %edx
f0101110:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101113:	8d 80 57 fe fe ff    	lea    -0x101a9(%eax),%eax
f0101119:	50                   	push   %eax
f010111a:	57                   	push   %edi
f010111b:	56                   	push   %esi
f010111c:	e8 79 fe ff ff       	call   f0100f9a <printfmt>
f0101121:	83 c4 10             	add    $0x10,%esp
			err = va_arg(ap, int);
f0101124:	89 5d 14             	mov    %ebx,0x14(%ebp)
f0101127:	e9 8a 02 00 00       	jmp    f01013b6 <.L25+0x45>
				printfmt(putch, putdat, "error %d", err);
f010112c:	50                   	push   %eax
f010112d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101130:	8d 80 4e fe fe ff    	lea    -0x101b2(%eax),%eax
f0101136:	50                   	push   %eax
f0101137:	57                   	push   %edi
f0101138:	56                   	push   %esi
f0101139:	e8 5c fe ff ff       	call   f0100f9a <printfmt>
f010113e:	83 c4 10             	add    $0x10,%esp
			err = va_arg(ap, int);
f0101141:	89 5d 14             	mov    %ebx,0x14(%ebp)
				printfmt(putch, putdat, "error %d", err);
f0101144:	e9 6d 02 00 00       	jmp    f01013b6 <.L25+0x45>

f0101149 <.L24>:
f0101149:	8b 75 08             	mov    0x8(%ebp),%esi
			if ((p = va_arg(ap, char *)) == NULL)
f010114c:	8b 45 14             	mov    0x14(%ebp),%eax
f010114f:	83 c0 04             	add    $0x4,%eax
f0101152:	89 45 c0             	mov    %eax,-0x40(%ebp)
f0101155:	8b 45 14             	mov    0x14(%ebp),%eax
f0101158:	8b 10                	mov    (%eax),%edx
				p = "(null)";
f010115a:	85 d2                	test   %edx,%edx
f010115c:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010115f:	8d 80 47 fe fe ff    	lea    -0x101b9(%eax),%eax
f0101165:	0f 45 c2             	cmovne %edx,%eax
f0101168:	89 45 c8             	mov    %eax,-0x38(%ebp)
			if (width > 0 && padc != '-')
f010116b:	83 7d d4 00          	cmpl   $0x0,-0x2c(%ebp)
f010116f:	7e 06                	jle    f0101177 <.L24+0x2e>
f0101171:	80 7d cf 2d          	cmpb   $0x2d,-0x31(%ebp)
f0101175:	75 0d                	jne    f0101184 <.L24+0x3b>
				for (width -= strnlen(p, precision); width > 0; width--)
f0101177:	8b 45 c8             	mov    -0x38(%ebp),%eax
f010117a:	89 c3                	mov    %eax,%ebx
f010117c:	03 45 d4             	add    -0x2c(%ebp),%eax
f010117f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101182:	eb 58                	jmp    f01011dc <.L24+0x93>
f0101184:	83 ec 08             	sub    $0x8,%esp
f0101187:	ff 75 d8             	pushl  -0x28(%ebp)
f010118a:	ff 75 c8             	pushl  -0x38(%ebp)
f010118d:	8b 5d e0             	mov    -0x20(%ebp),%ebx
f0101190:	e8 85 04 00 00       	call   f010161a <strnlen>
f0101195:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101198:	29 c2                	sub    %eax,%edx
f010119a:	89 55 bc             	mov    %edx,-0x44(%ebp)
f010119d:	83 c4 10             	add    $0x10,%esp
f01011a0:	89 d3                	mov    %edx,%ebx
					putch(padc, putdat);
f01011a2:	0f be 45 cf          	movsbl -0x31(%ebp),%eax
f01011a6:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				for (width -= strnlen(p, precision); width > 0; width--)
f01011a9:	85 db                	test   %ebx,%ebx
f01011ab:	7e 11                	jle    f01011be <.L24+0x75>
					putch(padc, putdat);
f01011ad:	83 ec 08             	sub    $0x8,%esp
f01011b0:	57                   	push   %edi
f01011b1:	ff 75 d4             	pushl  -0x2c(%ebp)
f01011b4:	ff d6                	call   *%esi
				for (width -= strnlen(p, precision); width > 0; width--)
f01011b6:	83 eb 01             	sub    $0x1,%ebx
f01011b9:	83 c4 10             	add    $0x10,%esp
f01011bc:	eb eb                	jmp    f01011a9 <.L24+0x60>
f01011be:	8b 55 bc             	mov    -0x44(%ebp),%edx
f01011c1:	85 d2                	test   %edx,%edx
f01011c3:	b8 00 00 00 00       	mov    $0x0,%eax
f01011c8:	0f 49 c2             	cmovns %edx,%eax
f01011cb:	29 c2                	sub    %eax,%edx
f01011cd:	89 55 d4             	mov    %edx,-0x2c(%ebp)
f01011d0:	eb a5                	jmp    f0101177 <.L24+0x2e>
					putch(ch, putdat);
f01011d2:	83 ec 08             	sub    $0x8,%esp
f01011d5:	57                   	push   %edi
f01011d6:	52                   	push   %edx
f01011d7:	ff d6                	call   *%esi
f01011d9:	83 c4 10             	add    $0x10,%esp
f01011dc:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01011df:	29 d9                	sub    %ebx,%ecx
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01011e1:	83 c3 01             	add    $0x1,%ebx
f01011e4:	0f b6 43 ff          	movzbl -0x1(%ebx),%eax
f01011e8:	0f be d0             	movsbl %al,%edx
f01011eb:	85 d2                	test   %edx,%edx
f01011ed:	74 4b                	je     f010123a <.L24+0xf1>
f01011ef:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f01011f3:	78 06                	js     f01011fb <.L24+0xb2>
f01011f5:	83 6d d8 01          	subl   $0x1,-0x28(%ebp)
f01011f9:	78 1e                	js     f0101219 <.L24+0xd0>
				if (altflag && (ch < ' ' || ch > '~'))
f01011fb:	83 7d d0 00          	cmpl   $0x0,-0x30(%ebp)
f01011ff:	74 d1                	je     f01011d2 <.L24+0x89>
f0101201:	0f be c0             	movsbl %al,%eax
f0101204:	83 e8 20             	sub    $0x20,%eax
f0101207:	83 f8 5e             	cmp    $0x5e,%eax
f010120a:	76 c6                	jbe    f01011d2 <.L24+0x89>
					putch('?', putdat);
f010120c:	83 ec 08             	sub    $0x8,%esp
f010120f:	57                   	push   %edi
f0101210:	6a 3f                	push   $0x3f
f0101212:	ff d6                	call   *%esi
f0101214:	83 c4 10             	add    $0x10,%esp
f0101217:	eb c3                	jmp    f01011dc <.L24+0x93>
f0101219:	89 cb                	mov    %ecx,%ebx
f010121b:	eb 0e                	jmp    f010122b <.L24+0xe2>
				putch(' ', putdat);
f010121d:	83 ec 08             	sub    $0x8,%esp
f0101220:	57                   	push   %edi
f0101221:	6a 20                	push   $0x20
f0101223:	ff d6                	call   *%esi
			for (; width > 0; width--)
f0101225:	83 eb 01             	sub    $0x1,%ebx
f0101228:	83 c4 10             	add    $0x10,%esp
f010122b:	85 db                	test   %ebx,%ebx
f010122d:	7f ee                	jg     f010121d <.L24+0xd4>
			if ((p = va_arg(ap, char *)) == NULL)
f010122f:	8b 45 c0             	mov    -0x40(%ebp),%eax
f0101232:	89 45 14             	mov    %eax,0x14(%ebp)
f0101235:	e9 7c 01 00 00       	jmp    f01013b6 <.L25+0x45>
f010123a:	89 cb                	mov    %ecx,%ebx
f010123c:	eb ed                	jmp    f010122b <.L24+0xe2>

f010123e <.L29>:
f010123e:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0101241:	8b 75 08             	mov    0x8(%ebp),%esi
	if (lflag >= 2)
f0101244:	83 f9 01             	cmp    $0x1,%ecx
f0101247:	7f 1b                	jg     f0101264 <.L29+0x26>
	else if (lflag)
f0101249:	85 c9                	test   %ecx,%ecx
f010124b:	74 63                	je     f01012b0 <.L29+0x72>
		return va_arg(*ap, long);
f010124d:	8b 45 14             	mov    0x14(%ebp),%eax
f0101250:	8b 00                	mov    (%eax),%eax
f0101252:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0101255:	99                   	cltd   
f0101256:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0101259:	8b 45 14             	mov    0x14(%ebp),%eax
f010125c:	8d 40 04             	lea    0x4(%eax),%eax
f010125f:	89 45 14             	mov    %eax,0x14(%ebp)
f0101262:	eb 17                	jmp    f010127b <.L29+0x3d>
		return va_arg(*ap, long long);
f0101264:	8b 45 14             	mov    0x14(%ebp),%eax
f0101267:	8b 50 04             	mov    0x4(%eax),%edx
f010126a:	8b 00                	mov    (%eax),%eax
f010126c:	89 45 d8             	mov    %eax,-0x28(%ebp)
f010126f:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0101272:	8b 45 14             	mov    0x14(%ebp),%eax
f0101275:	8d 40 08             	lea    0x8(%eax),%eax
f0101278:	89 45 14             	mov    %eax,0x14(%ebp)
			if ((long long) num < 0) {
f010127b:	8b 55 d8             	mov    -0x28(%ebp),%edx
f010127e:	8b 4d dc             	mov    -0x24(%ebp),%ecx
			base = 10;
f0101281:	b8 0a 00 00 00       	mov    $0xa,%eax
			if ((long long) num < 0) {
f0101286:	85 c9                	test   %ecx,%ecx
f0101288:	0f 89 0e 01 00 00    	jns    f010139c <.L25+0x2b>
				putch('-', putdat);
f010128e:	83 ec 08             	sub    $0x8,%esp
f0101291:	57                   	push   %edi
f0101292:	6a 2d                	push   $0x2d
f0101294:	ff d6                	call   *%esi
				num = -(long long) num;
f0101296:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0101299:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f010129c:	f7 da                	neg    %edx
f010129e:	83 d1 00             	adc    $0x0,%ecx
f01012a1:	f7 d9                	neg    %ecx
f01012a3:	83 c4 10             	add    $0x10,%esp
			base = 10;
f01012a6:	b8 0a 00 00 00       	mov    $0xa,%eax
f01012ab:	e9 ec 00 00 00       	jmp    f010139c <.L25+0x2b>
		return va_arg(*ap, int);
f01012b0:	8b 45 14             	mov    0x14(%ebp),%eax
f01012b3:	8b 00                	mov    (%eax),%eax
f01012b5:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01012b8:	99                   	cltd   
f01012b9:	89 55 dc             	mov    %edx,-0x24(%ebp)
f01012bc:	8b 45 14             	mov    0x14(%ebp),%eax
f01012bf:	8d 40 04             	lea    0x4(%eax),%eax
f01012c2:	89 45 14             	mov    %eax,0x14(%ebp)
f01012c5:	eb b4                	jmp    f010127b <.L29+0x3d>

f01012c7 <.L23>:
f01012c7:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f01012ca:	8b 75 08             	mov    0x8(%ebp),%esi
	if (lflag >= 2)
f01012cd:	83 f9 01             	cmp    $0x1,%ecx
f01012d0:	7f 1e                	jg     f01012f0 <.L23+0x29>
	else if (lflag)
f01012d2:	85 c9                	test   %ecx,%ecx
f01012d4:	74 32                	je     f0101308 <.L23+0x41>
		return va_arg(*ap, unsigned long);
f01012d6:	8b 45 14             	mov    0x14(%ebp),%eax
f01012d9:	8b 10                	mov    (%eax),%edx
f01012db:	b9 00 00 00 00       	mov    $0x0,%ecx
f01012e0:	8d 40 04             	lea    0x4(%eax),%eax
f01012e3:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 10;
f01012e6:	b8 0a 00 00 00       	mov    $0xa,%eax
		return va_arg(*ap, unsigned long);
f01012eb:	e9 ac 00 00 00       	jmp    f010139c <.L25+0x2b>
		return va_arg(*ap, unsigned long long);
f01012f0:	8b 45 14             	mov    0x14(%ebp),%eax
f01012f3:	8b 10                	mov    (%eax),%edx
f01012f5:	8b 48 04             	mov    0x4(%eax),%ecx
f01012f8:	8d 40 08             	lea    0x8(%eax),%eax
f01012fb:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 10;
f01012fe:	b8 0a 00 00 00       	mov    $0xa,%eax
		return va_arg(*ap, unsigned long long);
f0101303:	e9 94 00 00 00       	jmp    f010139c <.L25+0x2b>
		return va_arg(*ap, unsigned int);
f0101308:	8b 45 14             	mov    0x14(%ebp),%eax
f010130b:	8b 10                	mov    (%eax),%edx
f010130d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101312:	8d 40 04             	lea    0x4(%eax),%eax
f0101315:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 10;
f0101318:	b8 0a 00 00 00       	mov    $0xa,%eax
		return va_arg(*ap, unsigned int);
f010131d:	eb 7d                	jmp    f010139c <.L25+0x2b>

f010131f <.L26>:
f010131f:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0101322:	8b 75 08             	mov    0x8(%ebp),%esi
	if (lflag >= 2)
f0101325:	83 f9 01             	cmp    $0x1,%ecx
f0101328:	7f 1b                	jg     f0101345 <.L26+0x26>
	else if (lflag)
f010132a:	85 c9                	test   %ecx,%ecx
f010132c:	74 2c                	je     f010135a <.L26+0x3b>
		return va_arg(*ap, unsigned long);
f010132e:	8b 45 14             	mov    0x14(%ebp),%eax
f0101331:	8b 10                	mov    (%eax),%edx
f0101333:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101338:	8d 40 04             	lea    0x4(%eax),%eax
f010133b:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 8;
f010133e:	b8 08 00 00 00       	mov    $0x8,%eax
		return va_arg(*ap, unsigned long);
f0101343:	eb 57                	jmp    f010139c <.L25+0x2b>
		return va_arg(*ap, unsigned long long);
f0101345:	8b 45 14             	mov    0x14(%ebp),%eax
f0101348:	8b 10                	mov    (%eax),%edx
f010134a:	8b 48 04             	mov    0x4(%eax),%ecx
f010134d:	8d 40 08             	lea    0x8(%eax),%eax
f0101350:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 8;
f0101353:	b8 08 00 00 00       	mov    $0x8,%eax
		return va_arg(*ap, unsigned long long);
f0101358:	eb 42                	jmp    f010139c <.L25+0x2b>
		return va_arg(*ap, unsigned int);
f010135a:	8b 45 14             	mov    0x14(%ebp),%eax
f010135d:	8b 10                	mov    (%eax),%edx
f010135f:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101364:	8d 40 04             	lea    0x4(%eax),%eax
f0101367:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 8;
f010136a:	b8 08 00 00 00       	mov    $0x8,%eax
		return va_arg(*ap, unsigned int);
f010136f:	eb 2b                	jmp    f010139c <.L25+0x2b>

f0101371 <.L25>:
f0101371:	8b 75 08             	mov    0x8(%ebp),%esi
			putch('0', putdat);
f0101374:	83 ec 08             	sub    $0x8,%esp
f0101377:	57                   	push   %edi
f0101378:	6a 30                	push   $0x30
f010137a:	ff d6                	call   *%esi
			putch('x', putdat);
f010137c:	83 c4 08             	add    $0x8,%esp
f010137f:	57                   	push   %edi
f0101380:	6a 78                	push   $0x78
f0101382:	ff d6                	call   *%esi
			num = (unsigned long long)
f0101384:	8b 45 14             	mov    0x14(%ebp),%eax
f0101387:	8b 10                	mov    (%eax),%edx
f0101389:	b9 00 00 00 00       	mov    $0x0,%ecx
			goto number;
f010138e:	83 c4 10             	add    $0x10,%esp
				(uintptr_t) va_arg(ap, void *);
f0101391:	8d 40 04             	lea    0x4(%eax),%eax
f0101394:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f0101397:	b8 10 00 00 00       	mov    $0x10,%eax
			printnum(putch, putdat, num, base, width, padc);
f010139c:	83 ec 0c             	sub    $0xc,%esp
f010139f:	0f be 5d cf          	movsbl -0x31(%ebp),%ebx
f01013a3:	53                   	push   %ebx
f01013a4:	ff 75 d4             	pushl  -0x2c(%ebp)
f01013a7:	50                   	push   %eax
f01013a8:	51                   	push   %ecx
f01013a9:	52                   	push   %edx
f01013aa:	89 fa                	mov    %edi,%edx
f01013ac:	89 f0                	mov    %esi,%eax
f01013ae:	e8 08 fb ff ff       	call   f0100ebb <printnum>
			break;
f01013b3:	83 c4 20             	add    $0x20,%esp
			if ((p = va_arg(ap, char *)) == NULL)
f01013b6:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01013b9:	83 c3 01             	add    $0x1,%ebx
f01013bc:	0f b6 43 ff          	movzbl -0x1(%ebx),%eax
f01013c0:	83 f8 25             	cmp    $0x25,%eax
f01013c3:	0f 84 23 fc ff ff    	je     f0100fec <vprintfmt+0x31>
			if (ch == '\0')
f01013c9:	85 c0                	test   %eax,%eax
f01013cb:	0f 84 97 00 00 00    	je     f0101468 <.L20+0x23>
			putch(ch, putdat);
f01013d1:	83 ec 08             	sub    $0x8,%esp
f01013d4:	57                   	push   %edi
f01013d5:	50                   	push   %eax
f01013d6:	ff d6                	call   *%esi
f01013d8:	83 c4 10             	add    $0x10,%esp
f01013db:	eb dc                	jmp    f01013b9 <.L25+0x48>

f01013dd <.L21>:
f01013dd:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f01013e0:	8b 75 08             	mov    0x8(%ebp),%esi
	if (lflag >= 2)
f01013e3:	83 f9 01             	cmp    $0x1,%ecx
f01013e6:	7f 1b                	jg     f0101403 <.L21+0x26>
	else if (lflag)
f01013e8:	85 c9                	test   %ecx,%ecx
f01013ea:	74 2c                	je     f0101418 <.L21+0x3b>
		return va_arg(*ap, unsigned long);
f01013ec:	8b 45 14             	mov    0x14(%ebp),%eax
f01013ef:	8b 10                	mov    (%eax),%edx
f01013f1:	b9 00 00 00 00       	mov    $0x0,%ecx
f01013f6:	8d 40 04             	lea    0x4(%eax),%eax
f01013f9:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f01013fc:	b8 10 00 00 00       	mov    $0x10,%eax
		return va_arg(*ap, unsigned long);
f0101401:	eb 99                	jmp    f010139c <.L25+0x2b>
		return va_arg(*ap, unsigned long long);
f0101403:	8b 45 14             	mov    0x14(%ebp),%eax
f0101406:	8b 10                	mov    (%eax),%edx
f0101408:	8b 48 04             	mov    0x4(%eax),%ecx
f010140b:	8d 40 08             	lea    0x8(%eax),%eax
f010140e:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f0101411:	b8 10 00 00 00       	mov    $0x10,%eax
		return va_arg(*ap, unsigned long long);
f0101416:	eb 84                	jmp    f010139c <.L25+0x2b>
		return va_arg(*ap, unsigned int);
f0101418:	8b 45 14             	mov    0x14(%ebp),%eax
f010141b:	8b 10                	mov    (%eax),%edx
f010141d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101422:	8d 40 04             	lea    0x4(%eax),%eax
f0101425:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f0101428:	b8 10 00 00 00       	mov    $0x10,%eax
		return va_arg(*ap, unsigned int);
f010142d:	e9 6a ff ff ff       	jmp    f010139c <.L25+0x2b>

f0101432 <.L35>:
f0101432:	8b 75 08             	mov    0x8(%ebp),%esi
			putch(ch, putdat);
f0101435:	83 ec 08             	sub    $0x8,%esp
f0101438:	57                   	push   %edi
f0101439:	6a 25                	push   $0x25
f010143b:	ff d6                	call   *%esi
			break;
f010143d:	83 c4 10             	add    $0x10,%esp
f0101440:	e9 71 ff ff ff       	jmp    f01013b6 <.L25+0x45>

f0101445 <.L20>:
f0101445:	8b 75 08             	mov    0x8(%ebp),%esi
			putch('%', putdat);
f0101448:	83 ec 08             	sub    $0x8,%esp
f010144b:	57                   	push   %edi
f010144c:	6a 25                	push   $0x25
f010144e:	ff d6                	call   *%esi
			for (fmt--; fmt[-1] != '%'; fmt--)
f0101450:	83 c4 10             	add    $0x10,%esp
f0101453:	89 d8                	mov    %ebx,%eax
f0101455:	80 78 ff 25          	cmpb   $0x25,-0x1(%eax)
f0101459:	74 05                	je     f0101460 <.L20+0x1b>
f010145b:	83 e8 01             	sub    $0x1,%eax
f010145e:	eb f5                	jmp    f0101455 <.L20+0x10>
f0101460:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0101463:	e9 4e ff ff ff       	jmp    f01013b6 <.L25+0x45>
}
f0101468:	8d 65 f4             	lea    -0xc(%ebp),%esp
f010146b:	5b                   	pop    %ebx
f010146c:	5e                   	pop    %esi
f010146d:	5f                   	pop    %edi
f010146e:	5d                   	pop    %ebp
f010146f:	c3                   	ret    

f0101470 <vsnprintf>:

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0101470:	f3 0f 1e fb          	endbr32 
f0101474:	55                   	push   %ebp
f0101475:	89 e5                	mov    %esp,%ebp
f0101477:	53                   	push   %ebx
f0101478:	83 ec 14             	sub    $0x14,%esp
f010147b:	e8 5d ed ff ff       	call   f01001dd <__x86.get_pc_thunk.bx>
f0101480:	81 c3 88 0e 01 00    	add    $0x10e88,%ebx
f0101486:	8b 45 08             	mov    0x8(%ebp),%eax
f0101489:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f010148c:	89 45 ec             	mov    %eax,-0x14(%ebp)
f010148f:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f0101493:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0101496:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f010149d:	85 c0                	test   %eax,%eax
f010149f:	74 2b                	je     f01014cc <vsnprintf+0x5c>
f01014a1:	85 d2                	test   %edx,%edx
f01014a3:	7e 27                	jle    f01014cc <vsnprintf+0x5c>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f01014a5:	ff 75 14             	pushl  0x14(%ebp)
f01014a8:	ff 75 10             	pushl  0x10(%ebp)
f01014ab:	8d 45 ec             	lea    -0x14(%ebp),%eax
f01014ae:	50                   	push   %eax
f01014af:	8d 83 71 ec fe ff    	lea    -0x1138f(%ebx),%eax
f01014b5:	50                   	push   %eax
f01014b6:	e8 00 fb ff ff       	call   f0100fbb <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f01014bb:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01014be:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f01014c1:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01014c4:	83 c4 10             	add    $0x10,%esp
}
f01014c7:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f01014ca:	c9                   	leave  
f01014cb:	c3                   	ret    
		return -E_INVAL;
f01014cc:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f01014d1:	eb f4                	jmp    f01014c7 <vsnprintf+0x57>

f01014d3 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f01014d3:	f3 0f 1e fb          	endbr32 
f01014d7:	55                   	push   %ebp
f01014d8:	89 e5                	mov    %esp,%ebp
f01014da:	83 ec 08             	sub    $0x8,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f01014dd:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f01014e0:	50                   	push   %eax
f01014e1:	ff 75 10             	pushl  0x10(%ebp)
f01014e4:	ff 75 0c             	pushl  0xc(%ebp)
f01014e7:	ff 75 08             	pushl  0x8(%ebp)
f01014ea:	e8 81 ff ff ff       	call   f0101470 <vsnprintf>
	va_end(ap);

	return rc;
}
f01014ef:	c9                   	leave  
f01014f0:	c3                   	ret    

f01014f1 <__x86.get_pc_thunk.cx>:
f01014f1:	8b 0c 24             	mov    (%esp),%ecx
f01014f4:	c3                   	ret    

f01014f5 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f01014f5:	f3 0f 1e fb          	endbr32 
f01014f9:	55                   	push   %ebp
f01014fa:	89 e5                	mov    %esp,%ebp
f01014fc:	57                   	push   %edi
f01014fd:	56                   	push   %esi
f01014fe:	53                   	push   %ebx
f01014ff:	83 ec 1c             	sub    $0x1c,%esp
f0101502:	e8 d6 ec ff ff       	call   f01001dd <__x86.get_pc_thunk.bx>
f0101507:	81 c3 01 0e 01 00    	add    $0x10e01,%ebx
f010150d:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f0101510:	85 c0                	test   %eax,%eax
f0101512:	74 13                	je     f0101527 <readline+0x32>
		cprintf("%s", prompt);
f0101514:	83 ec 08             	sub    $0x8,%esp
f0101517:	50                   	push   %eax
f0101518:	8d 83 57 fe fe ff    	lea    -0x101a9(%ebx),%eax
f010151e:	50                   	push   %eax
f010151f:	e8 25 f6 ff ff       	call   f0100b49 <cprintf>
f0101524:	83 c4 10             	add    $0x10,%esp

	i = 0;
	echoing = iscons(0);
f0101527:	83 ec 0c             	sub    $0xc,%esp
f010152a:	6a 00                	push   $0x0
f010152c:	e8 56 f2 ff ff       	call   f0100787 <iscons>
f0101531:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0101534:	83 c4 10             	add    $0x10,%esp
	i = 0;
f0101537:	bf 00 00 00 00       	mov    $0x0,%edi
				cputchar('\b');
			i--;
		} else if (c >= ' ' && i < BUFLEN-1) {
			if (echoing)
				cputchar(c);
			buf[i++] = c;
f010153c:	8d 83 98 1f 00 00    	lea    0x1f98(%ebx),%eax
f0101542:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0101545:	eb 51                	jmp    f0101598 <readline+0xa3>
			cprintf("read error: %e\n", c);
f0101547:	83 ec 08             	sub    $0x8,%esp
f010154a:	50                   	push   %eax
f010154b:	8d 83 1c 00 ff ff    	lea    -0xffe4(%ebx),%eax
f0101551:	50                   	push   %eax
f0101552:	e8 f2 f5 ff ff       	call   f0100b49 <cprintf>
			return NULL;
f0101557:	83 c4 10             	add    $0x10,%esp
f010155a:	b8 00 00 00 00       	mov    $0x0,%eax
				cputchar('\n');
			buf[i] = 0;
			return buf;
		}
	}
}
f010155f:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0101562:	5b                   	pop    %ebx
f0101563:	5e                   	pop    %esi
f0101564:	5f                   	pop    %edi
f0101565:	5d                   	pop    %ebp
f0101566:	c3                   	ret    
			if (echoing)
f0101567:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f010156b:	75 05                	jne    f0101572 <readline+0x7d>
			i--;
f010156d:	83 ef 01             	sub    $0x1,%edi
f0101570:	eb 26                	jmp    f0101598 <readline+0xa3>
				cputchar('\b');
f0101572:	83 ec 0c             	sub    $0xc,%esp
f0101575:	6a 08                	push   $0x8
f0101577:	e8 e2 f1 ff ff       	call   f010075e <cputchar>
f010157c:	83 c4 10             	add    $0x10,%esp
f010157f:	eb ec                	jmp    f010156d <readline+0x78>
				cputchar(c);
f0101581:	83 ec 0c             	sub    $0xc,%esp
f0101584:	56                   	push   %esi
f0101585:	e8 d4 f1 ff ff       	call   f010075e <cputchar>
f010158a:	83 c4 10             	add    $0x10,%esp
			buf[i++] = c;
f010158d:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0101590:	89 f0                	mov    %esi,%eax
f0101592:	88 04 39             	mov    %al,(%ecx,%edi,1)
f0101595:	8d 7f 01             	lea    0x1(%edi),%edi
		c = getchar();
f0101598:	e8 d5 f1 ff ff       	call   f0100772 <getchar>
f010159d:	89 c6                	mov    %eax,%esi
		if (c < 0) {
f010159f:	85 c0                	test   %eax,%eax
f01015a1:	78 a4                	js     f0101547 <readline+0x52>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f01015a3:	83 f8 08             	cmp    $0x8,%eax
f01015a6:	0f 94 c2             	sete   %dl
f01015a9:	83 f8 7f             	cmp    $0x7f,%eax
f01015ac:	0f 94 c0             	sete   %al
f01015af:	08 c2                	or     %al,%dl
f01015b1:	74 04                	je     f01015b7 <readline+0xc2>
f01015b3:	85 ff                	test   %edi,%edi
f01015b5:	7f b0                	jg     f0101567 <readline+0x72>
		} else if (c >= ' ' && i < BUFLEN-1) {
f01015b7:	83 fe 1f             	cmp    $0x1f,%esi
f01015ba:	7e 10                	jle    f01015cc <readline+0xd7>
f01015bc:	81 ff fe 03 00 00    	cmp    $0x3fe,%edi
f01015c2:	7f 08                	jg     f01015cc <readline+0xd7>
			if (echoing)
f01015c4:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01015c8:	74 c3                	je     f010158d <readline+0x98>
f01015ca:	eb b5                	jmp    f0101581 <readline+0x8c>
		} else if (c == '\n' || c == '\r') {
f01015cc:	83 fe 0a             	cmp    $0xa,%esi
f01015cf:	74 05                	je     f01015d6 <readline+0xe1>
f01015d1:	83 fe 0d             	cmp    $0xd,%esi
f01015d4:	75 c2                	jne    f0101598 <readline+0xa3>
			if (echoing)
f01015d6:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01015da:	75 13                	jne    f01015ef <readline+0xfa>
			buf[i] = 0;
f01015dc:	c6 84 3b 98 1f 00 00 	movb   $0x0,0x1f98(%ebx,%edi,1)
f01015e3:	00 
			return buf;
f01015e4:	8d 83 98 1f 00 00    	lea    0x1f98(%ebx),%eax
f01015ea:	e9 70 ff ff ff       	jmp    f010155f <readline+0x6a>
				cputchar('\n');
f01015ef:	83 ec 0c             	sub    $0xc,%esp
f01015f2:	6a 0a                	push   $0xa
f01015f4:	e8 65 f1 ff ff       	call   f010075e <cputchar>
f01015f9:	83 c4 10             	add    $0x10,%esp
f01015fc:	eb de                	jmp    f01015dc <readline+0xe7>

f01015fe <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f01015fe:	f3 0f 1e fb          	endbr32 
f0101602:	55                   	push   %ebp
f0101603:	89 e5                	mov    %esp,%ebp
f0101605:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0101608:	b8 00 00 00 00       	mov    $0x0,%eax
f010160d:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0101611:	74 05                	je     f0101618 <strlen+0x1a>
		n++;
f0101613:	83 c0 01             	add    $0x1,%eax
f0101616:	eb f5                	jmp    f010160d <strlen+0xf>
	return n;
}
f0101618:	5d                   	pop    %ebp
f0101619:	c3                   	ret    

f010161a <strnlen>:

int
strnlen(const char *s, size_t size)
{
f010161a:	f3 0f 1e fb          	endbr32 
f010161e:	55                   	push   %ebp
f010161f:	89 e5                	mov    %esp,%ebp
f0101621:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0101624:	8b 55 0c             	mov    0xc(%ebp),%edx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0101627:	b8 00 00 00 00       	mov    $0x0,%eax
f010162c:	39 d0                	cmp    %edx,%eax
f010162e:	74 0d                	je     f010163d <strnlen+0x23>
f0101630:	80 3c 01 00          	cmpb   $0x0,(%ecx,%eax,1)
f0101634:	74 05                	je     f010163b <strnlen+0x21>
		n++;
f0101636:	83 c0 01             	add    $0x1,%eax
f0101639:	eb f1                	jmp    f010162c <strnlen+0x12>
f010163b:	89 c2                	mov    %eax,%edx
	return n;
}
f010163d:	89 d0                	mov    %edx,%eax
f010163f:	5d                   	pop    %ebp
f0101640:	c3                   	ret    

f0101641 <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f0101641:	f3 0f 1e fb          	endbr32 
f0101645:	55                   	push   %ebp
f0101646:	89 e5                	mov    %esp,%ebp
f0101648:	53                   	push   %ebx
f0101649:	8b 4d 08             	mov    0x8(%ebp),%ecx
f010164c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f010164f:	b8 00 00 00 00       	mov    $0x0,%eax
f0101654:	0f b6 14 03          	movzbl (%ebx,%eax,1),%edx
f0101658:	88 14 01             	mov    %dl,(%ecx,%eax,1)
f010165b:	83 c0 01             	add    $0x1,%eax
f010165e:	84 d2                	test   %dl,%dl
f0101660:	75 f2                	jne    f0101654 <strcpy+0x13>
		/* do nothing */;
	return ret;
}
f0101662:	89 c8                	mov    %ecx,%eax
f0101664:	5b                   	pop    %ebx
f0101665:	5d                   	pop    %ebp
f0101666:	c3                   	ret    

f0101667 <strcat>:

char *
strcat(char *dst, const char *src)
{
f0101667:	f3 0f 1e fb          	endbr32 
f010166b:	55                   	push   %ebp
f010166c:	89 e5                	mov    %esp,%ebp
f010166e:	53                   	push   %ebx
f010166f:	83 ec 10             	sub    $0x10,%esp
f0101672:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0101675:	53                   	push   %ebx
f0101676:	e8 83 ff ff ff       	call   f01015fe <strlen>
f010167b:	83 c4 08             	add    $0x8,%esp
	strcpy(dst + len, src);
f010167e:	ff 75 0c             	pushl  0xc(%ebp)
f0101681:	01 d8                	add    %ebx,%eax
f0101683:	50                   	push   %eax
f0101684:	e8 b8 ff ff ff       	call   f0101641 <strcpy>
	return dst;
}
f0101689:	89 d8                	mov    %ebx,%eax
f010168b:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f010168e:	c9                   	leave  
f010168f:	c3                   	ret    

f0101690 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0101690:	f3 0f 1e fb          	endbr32 
f0101694:	55                   	push   %ebp
f0101695:	89 e5                	mov    %esp,%ebp
f0101697:	56                   	push   %esi
f0101698:	53                   	push   %ebx
f0101699:	8b 75 08             	mov    0x8(%ebp),%esi
f010169c:	8b 55 0c             	mov    0xc(%ebp),%edx
f010169f:	89 f3                	mov    %esi,%ebx
f01016a1:	03 5d 10             	add    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f01016a4:	89 f0                	mov    %esi,%eax
f01016a6:	39 d8                	cmp    %ebx,%eax
f01016a8:	74 11                	je     f01016bb <strncpy+0x2b>
		*dst++ = *src;
f01016aa:	83 c0 01             	add    $0x1,%eax
f01016ad:	0f b6 0a             	movzbl (%edx),%ecx
f01016b0:	88 48 ff             	mov    %cl,-0x1(%eax)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f01016b3:	80 f9 01             	cmp    $0x1,%cl
f01016b6:	83 da ff             	sbb    $0xffffffff,%edx
f01016b9:	eb eb                	jmp    f01016a6 <strncpy+0x16>
	}
	return ret;
}
f01016bb:	89 f0                	mov    %esi,%eax
f01016bd:	5b                   	pop    %ebx
f01016be:	5e                   	pop    %esi
f01016bf:	5d                   	pop    %ebp
f01016c0:	c3                   	ret    

f01016c1 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f01016c1:	f3 0f 1e fb          	endbr32 
f01016c5:	55                   	push   %ebp
f01016c6:	89 e5                	mov    %esp,%ebp
f01016c8:	56                   	push   %esi
f01016c9:	53                   	push   %ebx
f01016ca:	8b 75 08             	mov    0x8(%ebp),%esi
f01016cd:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01016d0:	8b 55 10             	mov    0x10(%ebp),%edx
f01016d3:	89 f0                	mov    %esi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f01016d5:	85 d2                	test   %edx,%edx
f01016d7:	74 21                	je     f01016fa <strlcpy+0x39>
f01016d9:	8d 44 16 ff          	lea    -0x1(%esi,%edx,1),%eax
f01016dd:	89 f2                	mov    %esi,%edx
		while (--size > 0 && *src != '\0')
f01016df:	39 c2                	cmp    %eax,%edx
f01016e1:	74 14                	je     f01016f7 <strlcpy+0x36>
f01016e3:	0f b6 19             	movzbl (%ecx),%ebx
f01016e6:	84 db                	test   %bl,%bl
f01016e8:	74 0b                	je     f01016f5 <strlcpy+0x34>
			*dst++ = *src++;
f01016ea:	83 c1 01             	add    $0x1,%ecx
f01016ed:	83 c2 01             	add    $0x1,%edx
f01016f0:	88 5a ff             	mov    %bl,-0x1(%edx)
f01016f3:	eb ea                	jmp    f01016df <strlcpy+0x1e>
f01016f5:	89 d0                	mov    %edx,%eax
		*dst = '\0';
f01016f7:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f01016fa:	29 f0                	sub    %esi,%eax
}
f01016fc:	5b                   	pop    %ebx
f01016fd:	5e                   	pop    %esi
f01016fe:	5d                   	pop    %ebp
f01016ff:	c3                   	ret    

f0101700 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f0101700:	f3 0f 1e fb          	endbr32 
f0101704:	55                   	push   %ebp
f0101705:	89 e5                	mov    %esp,%ebp
f0101707:	8b 4d 08             	mov    0x8(%ebp),%ecx
f010170a:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f010170d:	0f b6 01             	movzbl (%ecx),%eax
f0101710:	84 c0                	test   %al,%al
f0101712:	74 0c                	je     f0101720 <strcmp+0x20>
f0101714:	3a 02                	cmp    (%edx),%al
f0101716:	75 08                	jne    f0101720 <strcmp+0x20>
		p++, q++;
f0101718:	83 c1 01             	add    $0x1,%ecx
f010171b:	83 c2 01             	add    $0x1,%edx
f010171e:	eb ed                	jmp    f010170d <strcmp+0xd>
	return (int) ((unsigned char) *p - (unsigned char) *q);
f0101720:	0f b6 c0             	movzbl %al,%eax
f0101723:	0f b6 12             	movzbl (%edx),%edx
f0101726:	29 d0                	sub    %edx,%eax
}
f0101728:	5d                   	pop    %ebp
f0101729:	c3                   	ret    

f010172a <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f010172a:	f3 0f 1e fb          	endbr32 
f010172e:	55                   	push   %ebp
f010172f:	89 e5                	mov    %esp,%ebp
f0101731:	53                   	push   %ebx
f0101732:	8b 45 08             	mov    0x8(%ebp),%eax
f0101735:	8b 55 0c             	mov    0xc(%ebp),%edx
f0101738:	89 c3                	mov    %eax,%ebx
f010173a:	03 5d 10             	add    0x10(%ebp),%ebx
	while (n > 0 && *p && *p == *q)
f010173d:	eb 06                	jmp    f0101745 <strncmp+0x1b>
		n--, p++, q++;
f010173f:	83 c0 01             	add    $0x1,%eax
f0101742:	83 c2 01             	add    $0x1,%edx
	while (n > 0 && *p && *p == *q)
f0101745:	39 d8                	cmp    %ebx,%eax
f0101747:	74 16                	je     f010175f <strncmp+0x35>
f0101749:	0f b6 08             	movzbl (%eax),%ecx
f010174c:	84 c9                	test   %cl,%cl
f010174e:	74 04                	je     f0101754 <strncmp+0x2a>
f0101750:	3a 0a                	cmp    (%edx),%cl
f0101752:	74 eb                	je     f010173f <strncmp+0x15>
	if (n == 0)
		return 0;
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0101754:	0f b6 00             	movzbl (%eax),%eax
f0101757:	0f b6 12             	movzbl (%edx),%edx
f010175a:	29 d0                	sub    %edx,%eax
}
f010175c:	5b                   	pop    %ebx
f010175d:	5d                   	pop    %ebp
f010175e:	c3                   	ret    
		return 0;
f010175f:	b8 00 00 00 00       	mov    $0x0,%eax
f0101764:	eb f6                	jmp    f010175c <strncmp+0x32>

f0101766 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0101766:	f3 0f 1e fb          	endbr32 
f010176a:	55                   	push   %ebp
f010176b:	89 e5                	mov    %esp,%ebp
f010176d:	8b 45 08             	mov    0x8(%ebp),%eax
f0101770:	0f b6 4d 0c          	movzbl 0xc(%ebp),%ecx
	for (; *s; s++)
f0101774:	0f b6 10             	movzbl (%eax),%edx
f0101777:	84 d2                	test   %dl,%dl
f0101779:	74 09                	je     f0101784 <strchr+0x1e>
		if (*s == c)
f010177b:	38 ca                	cmp    %cl,%dl
f010177d:	74 0a                	je     f0101789 <strchr+0x23>
	for (; *s; s++)
f010177f:	83 c0 01             	add    $0x1,%eax
f0101782:	eb f0                	jmp    f0101774 <strchr+0xe>
			return (char *) s;
	return 0;
f0101784:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0101789:	5d                   	pop    %ebp
f010178a:	c3                   	ret    

f010178b <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f010178b:	f3 0f 1e fb          	endbr32 
f010178f:	55                   	push   %ebp
f0101790:	89 e5                	mov    %esp,%ebp
f0101792:	8b 45 08             	mov    0x8(%ebp),%eax
f0101795:	0f b6 4d 0c          	movzbl 0xc(%ebp),%ecx
	for (; *s; s++)
f0101799:	0f b6 10             	movzbl (%eax),%edx
		if (*s == c)
f010179c:	38 ca                	cmp    %cl,%dl
f010179e:	74 09                	je     f01017a9 <strfind+0x1e>
f01017a0:	84 d2                	test   %dl,%dl
f01017a2:	74 05                	je     f01017a9 <strfind+0x1e>
	for (; *s; s++)
f01017a4:	83 c0 01             	add    $0x1,%eax
f01017a7:	eb f0                	jmp    f0101799 <strfind+0xe>
			break;
	return (char *) s;
}
f01017a9:	5d                   	pop    %ebp
f01017aa:	c3                   	ret    

f01017ab <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f01017ab:	f3 0f 1e fb          	endbr32 
f01017af:	55                   	push   %ebp
f01017b0:	89 e5                	mov    %esp,%ebp
f01017b2:	57                   	push   %edi
f01017b3:	56                   	push   %esi
f01017b4:	53                   	push   %ebx
f01017b5:	8b 7d 08             	mov    0x8(%ebp),%edi
f01017b8:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f01017bb:	85 c9                	test   %ecx,%ecx
f01017bd:	74 31                	je     f01017f0 <memset+0x45>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f01017bf:	89 f8                	mov    %edi,%eax
f01017c1:	09 c8                	or     %ecx,%eax
f01017c3:	a8 03                	test   $0x3,%al
f01017c5:	75 23                	jne    f01017ea <memset+0x3f>
		c &= 0xFF;
f01017c7:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f01017cb:	89 d3                	mov    %edx,%ebx
f01017cd:	c1 e3 08             	shl    $0x8,%ebx
f01017d0:	89 d0                	mov    %edx,%eax
f01017d2:	c1 e0 18             	shl    $0x18,%eax
f01017d5:	89 d6                	mov    %edx,%esi
f01017d7:	c1 e6 10             	shl    $0x10,%esi
f01017da:	09 f0                	or     %esi,%eax
f01017dc:	09 c2                	or     %eax,%edx
f01017de:	09 da                	or     %ebx,%edx
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f01017e0:	c1 e9 02             	shr    $0x2,%ecx
		asm volatile("cld; rep stosl\n"
f01017e3:	89 d0                	mov    %edx,%eax
f01017e5:	fc                   	cld    
f01017e6:	f3 ab                	rep stos %eax,%es:(%edi)
f01017e8:	eb 06                	jmp    f01017f0 <memset+0x45>
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f01017ea:	8b 45 0c             	mov    0xc(%ebp),%eax
f01017ed:	fc                   	cld    
f01017ee:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f01017f0:	89 f8                	mov    %edi,%eax
f01017f2:	5b                   	pop    %ebx
f01017f3:	5e                   	pop    %esi
f01017f4:	5f                   	pop    %edi
f01017f5:	5d                   	pop    %ebp
f01017f6:	c3                   	ret    

f01017f7 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f01017f7:	f3 0f 1e fb          	endbr32 
f01017fb:	55                   	push   %ebp
f01017fc:	89 e5                	mov    %esp,%ebp
f01017fe:	57                   	push   %edi
f01017ff:	56                   	push   %esi
f0101800:	8b 45 08             	mov    0x8(%ebp),%eax
f0101803:	8b 75 0c             	mov    0xc(%ebp),%esi
f0101806:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;

	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0101809:	39 c6                	cmp    %eax,%esi
f010180b:	73 32                	jae    f010183f <memmove+0x48>
f010180d:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0101810:	39 c2                	cmp    %eax,%edx
f0101812:	76 2b                	jbe    f010183f <memmove+0x48>
		s += n;
		d += n;
f0101814:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0101817:	89 fe                	mov    %edi,%esi
f0101819:	09 ce                	or     %ecx,%esi
f010181b:	09 d6                	or     %edx,%esi
f010181d:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0101823:	75 0e                	jne    f0101833 <memmove+0x3c>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0101825:	83 ef 04             	sub    $0x4,%edi
f0101828:	8d 72 fc             	lea    -0x4(%edx),%esi
f010182b:	c1 e9 02             	shr    $0x2,%ecx
			asm volatile("std; rep movsl\n"
f010182e:	fd                   	std    
f010182f:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0101831:	eb 09                	jmp    f010183c <memmove+0x45>
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0101833:	83 ef 01             	sub    $0x1,%edi
f0101836:	8d 72 ff             	lea    -0x1(%edx),%esi
			asm volatile("std; rep movsb\n"
f0101839:	fd                   	std    
f010183a:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f010183c:	fc                   	cld    
f010183d:	eb 1a                	jmp    f0101859 <memmove+0x62>
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f010183f:	89 c2                	mov    %eax,%edx
f0101841:	09 ca                	or     %ecx,%edx
f0101843:	09 f2                	or     %esi,%edx
f0101845:	f6 c2 03             	test   $0x3,%dl
f0101848:	75 0a                	jne    f0101854 <memmove+0x5d>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f010184a:	c1 e9 02             	shr    $0x2,%ecx
			asm volatile("cld; rep movsl\n"
f010184d:	89 c7                	mov    %eax,%edi
f010184f:	fc                   	cld    
f0101850:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0101852:	eb 05                	jmp    f0101859 <memmove+0x62>
		else
			asm volatile("cld; rep movsb\n"
f0101854:	89 c7                	mov    %eax,%edi
f0101856:	fc                   	cld    
f0101857:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0101859:	5e                   	pop    %esi
f010185a:	5f                   	pop    %edi
f010185b:	5d                   	pop    %ebp
f010185c:	c3                   	ret    

f010185d <memcpy>:
}
#endif

void *
memcpy(void *dst, const void *src, size_t n)
{
f010185d:	f3 0f 1e fb          	endbr32 
f0101861:	55                   	push   %ebp
f0101862:	89 e5                	mov    %esp,%ebp
f0101864:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0101867:	ff 75 10             	pushl  0x10(%ebp)
f010186a:	ff 75 0c             	pushl  0xc(%ebp)
f010186d:	ff 75 08             	pushl  0x8(%ebp)
f0101870:	e8 82 ff ff ff       	call   f01017f7 <memmove>
}
f0101875:	c9                   	leave  
f0101876:	c3                   	ret    

f0101877 <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f0101877:	f3 0f 1e fb          	endbr32 
f010187b:	55                   	push   %ebp
f010187c:	89 e5                	mov    %esp,%ebp
f010187e:	56                   	push   %esi
f010187f:	53                   	push   %ebx
f0101880:	8b 45 08             	mov    0x8(%ebp),%eax
f0101883:	8b 55 0c             	mov    0xc(%ebp),%edx
f0101886:	89 c6                	mov    %eax,%esi
f0101888:	03 75 10             	add    0x10(%ebp),%esi
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f010188b:	39 f0                	cmp    %esi,%eax
f010188d:	74 1c                	je     f01018ab <memcmp+0x34>
		if (*s1 != *s2)
f010188f:	0f b6 08             	movzbl (%eax),%ecx
f0101892:	0f b6 1a             	movzbl (%edx),%ebx
f0101895:	38 d9                	cmp    %bl,%cl
f0101897:	75 08                	jne    f01018a1 <memcmp+0x2a>
			return (int) *s1 - (int) *s2;
		s1++, s2++;
f0101899:	83 c0 01             	add    $0x1,%eax
f010189c:	83 c2 01             	add    $0x1,%edx
f010189f:	eb ea                	jmp    f010188b <memcmp+0x14>
			return (int) *s1 - (int) *s2;
f01018a1:	0f b6 c1             	movzbl %cl,%eax
f01018a4:	0f b6 db             	movzbl %bl,%ebx
f01018a7:	29 d8                	sub    %ebx,%eax
f01018a9:	eb 05                	jmp    f01018b0 <memcmp+0x39>
	}

	return 0;
f01018ab:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01018b0:	5b                   	pop    %ebx
f01018b1:	5e                   	pop    %esi
f01018b2:	5d                   	pop    %ebp
f01018b3:	c3                   	ret    

f01018b4 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f01018b4:	f3 0f 1e fb          	endbr32 
f01018b8:	55                   	push   %ebp
f01018b9:	89 e5                	mov    %esp,%ebp
f01018bb:	8b 45 08             	mov    0x8(%ebp),%eax
f01018be:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	const void *ends = (const char *) s + n;
f01018c1:	89 c2                	mov    %eax,%edx
f01018c3:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f01018c6:	39 d0                	cmp    %edx,%eax
f01018c8:	73 09                	jae    f01018d3 <memfind+0x1f>
		if (*(const unsigned char *) s == (unsigned char) c)
f01018ca:	38 08                	cmp    %cl,(%eax)
f01018cc:	74 05                	je     f01018d3 <memfind+0x1f>
	for (; s < ends; s++)
f01018ce:	83 c0 01             	add    $0x1,%eax
f01018d1:	eb f3                	jmp    f01018c6 <memfind+0x12>
			break;
	return (void *) s;
}
f01018d3:	5d                   	pop    %ebp
f01018d4:	c3                   	ret    

f01018d5 <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f01018d5:	f3 0f 1e fb          	endbr32 
f01018d9:	55                   	push   %ebp
f01018da:	89 e5                	mov    %esp,%ebp
f01018dc:	57                   	push   %edi
f01018dd:	56                   	push   %esi
f01018de:	53                   	push   %ebx
f01018df:	8b 4d 08             	mov    0x8(%ebp),%ecx
f01018e2:	8b 5d 10             	mov    0x10(%ebp),%ebx
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f01018e5:	eb 03                	jmp    f01018ea <strtol+0x15>
		s++;
f01018e7:	83 c1 01             	add    $0x1,%ecx
	while (*s == ' ' || *s == '\t')
f01018ea:	0f b6 01             	movzbl (%ecx),%eax
f01018ed:	3c 20                	cmp    $0x20,%al
f01018ef:	74 f6                	je     f01018e7 <strtol+0x12>
f01018f1:	3c 09                	cmp    $0x9,%al
f01018f3:	74 f2                	je     f01018e7 <strtol+0x12>

	// plus/minus sign
	if (*s == '+')
f01018f5:	3c 2b                	cmp    $0x2b,%al
f01018f7:	74 2a                	je     f0101923 <strtol+0x4e>
	int neg = 0;
f01018f9:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;
	else if (*s == '-')
f01018fe:	3c 2d                	cmp    $0x2d,%al
f0101900:	74 2b                	je     f010192d <strtol+0x58>
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0101902:	f7 c3 ef ff ff ff    	test   $0xffffffef,%ebx
f0101908:	75 0f                	jne    f0101919 <strtol+0x44>
f010190a:	80 39 30             	cmpb   $0x30,(%ecx)
f010190d:	74 28                	je     f0101937 <strtol+0x62>
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
		s++, base = 8;
	else if (base == 0)
		base = 10;
f010190f:	85 db                	test   %ebx,%ebx
f0101911:	b8 0a 00 00 00       	mov    $0xa,%eax
f0101916:	0f 44 d8             	cmove  %eax,%ebx
f0101919:	b8 00 00 00 00       	mov    $0x0,%eax
f010191e:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0101921:	eb 46                	jmp    f0101969 <strtol+0x94>
		s++;
f0101923:	83 c1 01             	add    $0x1,%ecx
	int neg = 0;
f0101926:	bf 00 00 00 00       	mov    $0x0,%edi
f010192b:	eb d5                	jmp    f0101902 <strtol+0x2d>
		s++, neg = 1;
f010192d:	83 c1 01             	add    $0x1,%ecx
f0101930:	bf 01 00 00 00       	mov    $0x1,%edi
f0101935:	eb cb                	jmp    f0101902 <strtol+0x2d>
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0101937:	80 79 01 78          	cmpb   $0x78,0x1(%ecx)
f010193b:	74 0e                	je     f010194b <strtol+0x76>
	else if (base == 0 && s[0] == '0')
f010193d:	85 db                	test   %ebx,%ebx
f010193f:	75 d8                	jne    f0101919 <strtol+0x44>
		s++, base = 8;
f0101941:	83 c1 01             	add    $0x1,%ecx
f0101944:	bb 08 00 00 00       	mov    $0x8,%ebx
f0101949:	eb ce                	jmp    f0101919 <strtol+0x44>
		s += 2, base = 16;
f010194b:	83 c1 02             	add    $0x2,%ecx
f010194e:	bb 10 00 00 00       	mov    $0x10,%ebx
f0101953:	eb c4                	jmp    f0101919 <strtol+0x44>
	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
			dig = *s - '0';
f0101955:	0f be d2             	movsbl %dl,%edx
f0101958:	83 ea 30             	sub    $0x30,%edx
			dig = *s - 'a' + 10;
		else if (*s >= 'A' && *s <= 'Z')
			dig = *s - 'A' + 10;
		else
			break;
		if (dig >= base)
f010195b:	3b 55 10             	cmp    0x10(%ebp),%edx
f010195e:	7d 3a                	jge    f010199a <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f0101960:	83 c1 01             	add    $0x1,%ecx
f0101963:	0f af 45 10          	imul   0x10(%ebp),%eax
f0101967:	01 d0                	add    %edx,%eax
		if (*s >= '0' && *s <= '9')
f0101969:	0f b6 11             	movzbl (%ecx),%edx
f010196c:	8d 72 d0             	lea    -0x30(%edx),%esi
f010196f:	89 f3                	mov    %esi,%ebx
f0101971:	80 fb 09             	cmp    $0x9,%bl
f0101974:	76 df                	jbe    f0101955 <strtol+0x80>
		else if (*s >= 'a' && *s <= 'z')
f0101976:	8d 72 9f             	lea    -0x61(%edx),%esi
f0101979:	89 f3                	mov    %esi,%ebx
f010197b:	80 fb 19             	cmp    $0x19,%bl
f010197e:	77 08                	ja     f0101988 <strtol+0xb3>
			dig = *s - 'a' + 10;
f0101980:	0f be d2             	movsbl %dl,%edx
f0101983:	83 ea 57             	sub    $0x57,%edx
f0101986:	eb d3                	jmp    f010195b <strtol+0x86>
		else if (*s >= 'A' && *s <= 'Z')
f0101988:	8d 72 bf             	lea    -0x41(%edx),%esi
f010198b:	89 f3                	mov    %esi,%ebx
f010198d:	80 fb 19             	cmp    $0x19,%bl
f0101990:	77 08                	ja     f010199a <strtol+0xc5>
			dig = *s - 'A' + 10;
f0101992:	0f be d2             	movsbl %dl,%edx
f0101995:	83 ea 37             	sub    $0x37,%edx
f0101998:	eb c1                	jmp    f010195b <strtol+0x86>
		// we don't properly detect overflow!
	}

	if (endptr)
f010199a:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f010199e:	74 05                	je     f01019a5 <strtol+0xd0>
		*endptr = (char *) s;
f01019a0:	8b 75 0c             	mov    0xc(%ebp),%esi
f01019a3:	89 0e                	mov    %ecx,(%esi)
	return (neg ? -val : val);
f01019a5:	89 c2                	mov    %eax,%edx
f01019a7:	f7 da                	neg    %edx
f01019a9:	85 ff                	test   %edi,%edi
f01019ab:	0f 45 c2             	cmovne %edx,%eax
}
f01019ae:	5b                   	pop    %ebx
f01019af:	5e                   	pop    %esi
f01019b0:	5f                   	pop    %edi
f01019b1:	5d                   	pop    %ebp
f01019b2:	c3                   	ret    
f01019b3:	66 90                	xchg   %ax,%ax
f01019b5:	66 90                	xchg   %ax,%ax
f01019b7:	66 90                	xchg   %ax,%ax
f01019b9:	66 90                	xchg   %ax,%ax
f01019bb:	66 90                	xchg   %ax,%ax
f01019bd:	66 90                	xchg   %ax,%ax
f01019bf:	90                   	nop

f01019c0 <__udivdi3>:
f01019c0:	f3 0f 1e fb          	endbr32 
f01019c4:	55                   	push   %ebp
f01019c5:	57                   	push   %edi
f01019c6:	56                   	push   %esi
f01019c7:	53                   	push   %ebx
f01019c8:	83 ec 1c             	sub    $0x1c,%esp
f01019cb:	8b 54 24 3c          	mov    0x3c(%esp),%edx
f01019cf:	8b 6c 24 30          	mov    0x30(%esp),%ebp
f01019d3:	8b 74 24 34          	mov    0x34(%esp),%esi
f01019d7:	8b 5c 24 38          	mov    0x38(%esp),%ebx
f01019db:	85 d2                	test   %edx,%edx
f01019dd:	75 19                	jne    f01019f8 <__udivdi3+0x38>
f01019df:	39 f3                	cmp    %esi,%ebx
f01019e1:	76 4d                	jbe    f0101a30 <__udivdi3+0x70>
f01019e3:	31 ff                	xor    %edi,%edi
f01019e5:	89 e8                	mov    %ebp,%eax
f01019e7:	89 f2                	mov    %esi,%edx
f01019e9:	f7 f3                	div    %ebx
f01019eb:	89 fa                	mov    %edi,%edx
f01019ed:	83 c4 1c             	add    $0x1c,%esp
f01019f0:	5b                   	pop    %ebx
f01019f1:	5e                   	pop    %esi
f01019f2:	5f                   	pop    %edi
f01019f3:	5d                   	pop    %ebp
f01019f4:	c3                   	ret    
f01019f5:	8d 76 00             	lea    0x0(%esi),%esi
f01019f8:	39 f2                	cmp    %esi,%edx
f01019fa:	76 14                	jbe    f0101a10 <__udivdi3+0x50>
f01019fc:	31 ff                	xor    %edi,%edi
f01019fe:	31 c0                	xor    %eax,%eax
f0101a00:	89 fa                	mov    %edi,%edx
f0101a02:	83 c4 1c             	add    $0x1c,%esp
f0101a05:	5b                   	pop    %ebx
f0101a06:	5e                   	pop    %esi
f0101a07:	5f                   	pop    %edi
f0101a08:	5d                   	pop    %ebp
f0101a09:	c3                   	ret    
f0101a0a:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0101a10:	0f bd fa             	bsr    %edx,%edi
f0101a13:	83 f7 1f             	xor    $0x1f,%edi
f0101a16:	75 48                	jne    f0101a60 <__udivdi3+0xa0>
f0101a18:	39 f2                	cmp    %esi,%edx
f0101a1a:	72 06                	jb     f0101a22 <__udivdi3+0x62>
f0101a1c:	31 c0                	xor    %eax,%eax
f0101a1e:	39 eb                	cmp    %ebp,%ebx
f0101a20:	77 de                	ja     f0101a00 <__udivdi3+0x40>
f0101a22:	b8 01 00 00 00       	mov    $0x1,%eax
f0101a27:	eb d7                	jmp    f0101a00 <__udivdi3+0x40>
f0101a29:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101a30:	89 d9                	mov    %ebx,%ecx
f0101a32:	85 db                	test   %ebx,%ebx
f0101a34:	75 0b                	jne    f0101a41 <__udivdi3+0x81>
f0101a36:	b8 01 00 00 00       	mov    $0x1,%eax
f0101a3b:	31 d2                	xor    %edx,%edx
f0101a3d:	f7 f3                	div    %ebx
f0101a3f:	89 c1                	mov    %eax,%ecx
f0101a41:	31 d2                	xor    %edx,%edx
f0101a43:	89 f0                	mov    %esi,%eax
f0101a45:	f7 f1                	div    %ecx
f0101a47:	89 c6                	mov    %eax,%esi
f0101a49:	89 e8                	mov    %ebp,%eax
f0101a4b:	89 f7                	mov    %esi,%edi
f0101a4d:	f7 f1                	div    %ecx
f0101a4f:	89 fa                	mov    %edi,%edx
f0101a51:	83 c4 1c             	add    $0x1c,%esp
f0101a54:	5b                   	pop    %ebx
f0101a55:	5e                   	pop    %esi
f0101a56:	5f                   	pop    %edi
f0101a57:	5d                   	pop    %ebp
f0101a58:	c3                   	ret    
f0101a59:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101a60:	89 f9                	mov    %edi,%ecx
f0101a62:	b8 20 00 00 00       	mov    $0x20,%eax
f0101a67:	29 f8                	sub    %edi,%eax
f0101a69:	d3 e2                	shl    %cl,%edx
f0101a6b:	89 54 24 08          	mov    %edx,0x8(%esp)
f0101a6f:	89 c1                	mov    %eax,%ecx
f0101a71:	89 da                	mov    %ebx,%edx
f0101a73:	d3 ea                	shr    %cl,%edx
f0101a75:	8b 4c 24 08          	mov    0x8(%esp),%ecx
f0101a79:	09 d1                	or     %edx,%ecx
f0101a7b:	89 f2                	mov    %esi,%edx
f0101a7d:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101a81:	89 f9                	mov    %edi,%ecx
f0101a83:	d3 e3                	shl    %cl,%ebx
f0101a85:	89 c1                	mov    %eax,%ecx
f0101a87:	d3 ea                	shr    %cl,%edx
f0101a89:	89 f9                	mov    %edi,%ecx
f0101a8b:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0101a8f:	89 eb                	mov    %ebp,%ebx
f0101a91:	d3 e6                	shl    %cl,%esi
f0101a93:	89 c1                	mov    %eax,%ecx
f0101a95:	d3 eb                	shr    %cl,%ebx
f0101a97:	09 de                	or     %ebx,%esi
f0101a99:	89 f0                	mov    %esi,%eax
f0101a9b:	f7 74 24 08          	divl   0x8(%esp)
f0101a9f:	89 d6                	mov    %edx,%esi
f0101aa1:	89 c3                	mov    %eax,%ebx
f0101aa3:	f7 64 24 0c          	mull   0xc(%esp)
f0101aa7:	39 d6                	cmp    %edx,%esi
f0101aa9:	72 15                	jb     f0101ac0 <__udivdi3+0x100>
f0101aab:	89 f9                	mov    %edi,%ecx
f0101aad:	d3 e5                	shl    %cl,%ebp
f0101aaf:	39 c5                	cmp    %eax,%ebp
f0101ab1:	73 04                	jae    f0101ab7 <__udivdi3+0xf7>
f0101ab3:	39 d6                	cmp    %edx,%esi
f0101ab5:	74 09                	je     f0101ac0 <__udivdi3+0x100>
f0101ab7:	89 d8                	mov    %ebx,%eax
f0101ab9:	31 ff                	xor    %edi,%edi
f0101abb:	e9 40 ff ff ff       	jmp    f0101a00 <__udivdi3+0x40>
f0101ac0:	8d 43 ff             	lea    -0x1(%ebx),%eax
f0101ac3:	31 ff                	xor    %edi,%edi
f0101ac5:	e9 36 ff ff ff       	jmp    f0101a00 <__udivdi3+0x40>
f0101aca:	66 90                	xchg   %ax,%ax
f0101acc:	66 90                	xchg   %ax,%ax
f0101ace:	66 90                	xchg   %ax,%ax

f0101ad0 <__umoddi3>:
f0101ad0:	f3 0f 1e fb          	endbr32 
f0101ad4:	55                   	push   %ebp
f0101ad5:	57                   	push   %edi
f0101ad6:	56                   	push   %esi
f0101ad7:	53                   	push   %ebx
f0101ad8:	83 ec 1c             	sub    $0x1c,%esp
f0101adb:	8b 44 24 3c          	mov    0x3c(%esp),%eax
f0101adf:	8b 74 24 30          	mov    0x30(%esp),%esi
f0101ae3:	8b 5c 24 34          	mov    0x34(%esp),%ebx
f0101ae7:	8b 7c 24 38          	mov    0x38(%esp),%edi
f0101aeb:	85 c0                	test   %eax,%eax
f0101aed:	75 19                	jne    f0101b08 <__umoddi3+0x38>
f0101aef:	39 df                	cmp    %ebx,%edi
f0101af1:	76 5d                	jbe    f0101b50 <__umoddi3+0x80>
f0101af3:	89 f0                	mov    %esi,%eax
f0101af5:	89 da                	mov    %ebx,%edx
f0101af7:	f7 f7                	div    %edi
f0101af9:	89 d0                	mov    %edx,%eax
f0101afb:	31 d2                	xor    %edx,%edx
f0101afd:	83 c4 1c             	add    $0x1c,%esp
f0101b00:	5b                   	pop    %ebx
f0101b01:	5e                   	pop    %esi
f0101b02:	5f                   	pop    %edi
f0101b03:	5d                   	pop    %ebp
f0101b04:	c3                   	ret    
f0101b05:	8d 76 00             	lea    0x0(%esi),%esi
f0101b08:	89 f2                	mov    %esi,%edx
f0101b0a:	39 d8                	cmp    %ebx,%eax
f0101b0c:	76 12                	jbe    f0101b20 <__umoddi3+0x50>
f0101b0e:	89 f0                	mov    %esi,%eax
f0101b10:	89 da                	mov    %ebx,%edx
f0101b12:	83 c4 1c             	add    $0x1c,%esp
f0101b15:	5b                   	pop    %ebx
f0101b16:	5e                   	pop    %esi
f0101b17:	5f                   	pop    %edi
f0101b18:	5d                   	pop    %ebp
f0101b19:	c3                   	ret    
f0101b1a:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0101b20:	0f bd e8             	bsr    %eax,%ebp
f0101b23:	83 f5 1f             	xor    $0x1f,%ebp
f0101b26:	75 50                	jne    f0101b78 <__umoddi3+0xa8>
f0101b28:	39 d8                	cmp    %ebx,%eax
f0101b2a:	0f 82 e0 00 00 00    	jb     f0101c10 <__umoddi3+0x140>
f0101b30:	89 d9                	mov    %ebx,%ecx
f0101b32:	39 f7                	cmp    %esi,%edi
f0101b34:	0f 86 d6 00 00 00    	jbe    f0101c10 <__umoddi3+0x140>
f0101b3a:	89 d0                	mov    %edx,%eax
f0101b3c:	89 ca                	mov    %ecx,%edx
f0101b3e:	83 c4 1c             	add    $0x1c,%esp
f0101b41:	5b                   	pop    %ebx
f0101b42:	5e                   	pop    %esi
f0101b43:	5f                   	pop    %edi
f0101b44:	5d                   	pop    %ebp
f0101b45:	c3                   	ret    
f0101b46:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101b4d:	8d 76 00             	lea    0x0(%esi),%esi
f0101b50:	89 fd                	mov    %edi,%ebp
f0101b52:	85 ff                	test   %edi,%edi
f0101b54:	75 0b                	jne    f0101b61 <__umoddi3+0x91>
f0101b56:	b8 01 00 00 00       	mov    $0x1,%eax
f0101b5b:	31 d2                	xor    %edx,%edx
f0101b5d:	f7 f7                	div    %edi
f0101b5f:	89 c5                	mov    %eax,%ebp
f0101b61:	89 d8                	mov    %ebx,%eax
f0101b63:	31 d2                	xor    %edx,%edx
f0101b65:	f7 f5                	div    %ebp
f0101b67:	89 f0                	mov    %esi,%eax
f0101b69:	f7 f5                	div    %ebp
f0101b6b:	89 d0                	mov    %edx,%eax
f0101b6d:	31 d2                	xor    %edx,%edx
f0101b6f:	eb 8c                	jmp    f0101afd <__umoddi3+0x2d>
f0101b71:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101b78:	89 e9                	mov    %ebp,%ecx
f0101b7a:	ba 20 00 00 00       	mov    $0x20,%edx
f0101b7f:	29 ea                	sub    %ebp,%edx
f0101b81:	d3 e0                	shl    %cl,%eax
f0101b83:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101b87:	89 d1                	mov    %edx,%ecx
f0101b89:	89 f8                	mov    %edi,%eax
f0101b8b:	d3 e8                	shr    %cl,%eax
f0101b8d:	8b 4c 24 08          	mov    0x8(%esp),%ecx
f0101b91:	89 54 24 04          	mov    %edx,0x4(%esp)
f0101b95:	8b 54 24 04          	mov    0x4(%esp),%edx
f0101b99:	09 c1                	or     %eax,%ecx
f0101b9b:	89 d8                	mov    %ebx,%eax
f0101b9d:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101ba1:	89 e9                	mov    %ebp,%ecx
f0101ba3:	d3 e7                	shl    %cl,%edi
f0101ba5:	89 d1                	mov    %edx,%ecx
f0101ba7:	d3 e8                	shr    %cl,%eax
f0101ba9:	89 e9                	mov    %ebp,%ecx
f0101bab:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0101baf:	d3 e3                	shl    %cl,%ebx
f0101bb1:	89 c7                	mov    %eax,%edi
f0101bb3:	89 d1                	mov    %edx,%ecx
f0101bb5:	89 f0                	mov    %esi,%eax
f0101bb7:	d3 e8                	shr    %cl,%eax
f0101bb9:	89 e9                	mov    %ebp,%ecx
f0101bbb:	89 fa                	mov    %edi,%edx
f0101bbd:	d3 e6                	shl    %cl,%esi
f0101bbf:	09 d8                	or     %ebx,%eax
f0101bc1:	f7 74 24 08          	divl   0x8(%esp)
f0101bc5:	89 d1                	mov    %edx,%ecx
f0101bc7:	89 f3                	mov    %esi,%ebx
f0101bc9:	f7 64 24 0c          	mull   0xc(%esp)
f0101bcd:	89 c6                	mov    %eax,%esi
f0101bcf:	89 d7                	mov    %edx,%edi
f0101bd1:	39 d1                	cmp    %edx,%ecx
f0101bd3:	72 06                	jb     f0101bdb <__umoddi3+0x10b>
f0101bd5:	75 10                	jne    f0101be7 <__umoddi3+0x117>
f0101bd7:	39 c3                	cmp    %eax,%ebx
f0101bd9:	73 0c                	jae    f0101be7 <__umoddi3+0x117>
f0101bdb:	2b 44 24 0c          	sub    0xc(%esp),%eax
f0101bdf:	1b 54 24 08          	sbb    0x8(%esp),%edx
f0101be3:	89 d7                	mov    %edx,%edi
f0101be5:	89 c6                	mov    %eax,%esi
f0101be7:	89 ca                	mov    %ecx,%edx
f0101be9:	0f b6 4c 24 04       	movzbl 0x4(%esp),%ecx
f0101bee:	29 f3                	sub    %esi,%ebx
f0101bf0:	19 fa                	sbb    %edi,%edx
f0101bf2:	89 d0                	mov    %edx,%eax
f0101bf4:	d3 e0                	shl    %cl,%eax
f0101bf6:	89 e9                	mov    %ebp,%ecx
f0101bf8:	d3 eb                	shr    %cl,%ebx
f0101bfa:	d3 ea                	shr    %cl,%edx
f0101bfc:	09 d8                	or     %ebx,%eax
f0101bfe:	83 c4 1c             	add    $0x1c,%esp
f0101c01:	5b                   	pop    %ebx
f0101c02:	5e                   	pop    %esi
f0101c03:	5f                   	pop    %edi
f0101c04:	5d                   	pop    %ebp
f0101c05:	c3                   	ret    
f0101c06:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101c0d:	8d 76 00             	lea    0x0(%esi),%esi
f0101c10:	29 fe                	sub    %edi,%esi
f0101c12:	19 c3                	sbb    %eax,%ebx
f0101c14:	89 f2                	mov    %esi,%edx
f0101c16:	89 d9                	mov    %ebx,%ecx
f0101c18:	e9 1d ff ff ff       	jmp    f0101b3a <__umoddi3+0x6a>
