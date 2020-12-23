
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
f0100039:	e8 02 00 00 00       	call   f0100040 <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <i386_init>:
#include <kern/kclock.h>


void
i386_init(void)
{
f0100040:	f3 0f 1e fb          	endbr32 
f0100044:	55                   	push   %ebp
f0100045:	89 e5                	mov    %esp,%ebp
f0100047:	53                   	push   %ebx
f0100048:	83 ec 08             	sub    $0x8,%esp
f010004b:	e8 1c 01 00 00       	call   f010016c <__x86.get_pc_thunk.bx>
f0100050:	81 c3 b8 22 01 00    	add    $0x122b8,%ebx
	extern char edata[], end[];

	// Before doing anything else, complete the ELF loading process.
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);
f0100056:	c7 c2 60 40 11 f0    	mov    $0xf0114060,%edx
f010005c:	c7 c0 a0 46 11 f0    	mov    $0xf01146a0,%eax
f0100062:	29 d0                	sub    %edx,%eax
f0100064:	50                   	push   %eax
f0100065:	6a 00                	push   $0x0
f0100067:	52                   	push   %edx
f0100068:	e8 89 18 00 00       	call   f01018f6 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f010006d:	e8 55 05 00 00       	call   f01005c7 <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f0100072:	83 c4 08             	add    $0x8,%esp
f0100075:	68 ac 1a 00 00       	push   $0x1aac
f010007a:	8d 83 58 fa fe ff    	lea    -0x105a8(%ebx),%eax
f0100080:	50                   	push   %eax
f0100081:	e8 0e 0c 00 00       	call   f0100c94 <cprintf>
	cprintf("x=%d y=%d", 3);
f0100086:	83 c4 08             	add    $0x8,%esp
f0100089:	6a 03                	push   $0x3
f010008b:	8d 83 73 fa fe ff    	lea    -0x1058d(%ebx),%eax
f0100091:	50                   	push   %eax
f0100092:	e8 fd 0b 00 00       	call   f0100c94 <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f0100097:	e8 11 0a 00 00       	call   f0100aad <mem_init>
f010009c:	83 c4 10             	add    $0x10,%esp

	// Drop into the kernel monitor.
	while (1)
		monitor(NULL);
f010009f:	83 ec 0c             	sub    $0xc,%esp
f01000a2:	6a 00                	push   $0x0
f01000a4:	e8 5d 08 00 00       	call   f0100906 <monitor>
f01000a9:	83 c4 10             	add    $0x10,%esp
f01000ac:	eb f1                	jmp    f010009f <i386_init+0x5f>

f01000ae <_panic>:
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
f01000ae:	f3 0f 1e fb          	endbr32 
f01000b2:	55                   	push   %ebp
f01000b3:	89 e5                	mov    %esp,%ebp
f01000b5:	57                   	push   %edi
f01000b6:	56                   	push   %esi
f01000b7:	53                   	push   %ebx
f01000b8:	83 ec 0c             	sub    $0xc,%esp
f01000bb:	e8 ac 00 00 00       	call   f010016c <__x86.get_pc_thunk.bx>
f01000c0:	81 c3 48 22 01 00    	add    $0x12248,%ebx
f01000c6:	8b 7d 10             	mov    0x10(%ebp),%edi
	va_list ap;

	if (panicstr)
f01000c9:	c7 c0 a4 46 11 f0    	mov    $0xf01146a4,%eax
f01000cf:	83 38 00             	cmpl   $0x0,(%eax)
f01000d2:	74 0f                	je     f01000e3 <_panic+0x35>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f01000d4:	83 ec 0c             	sub    $0xc,%esp
f01000d7:	6a 00                	push   $0x0
f01000d9:	e8 28 08 00 00       	call   f0100906 <monitor>
f01000de:	83 c4 10             	add    $0x10,%esp
f01000e1:	eb f1                	jmp    f01000d4 <_panic+0x26>
	panicstr = fmt;
f01000e3:	89 38                	mov    %edi,(%eax)
	asm volatile("cli; cld");
f01000e5:	fa                   	cli    
f01000e6:	fc                   	cld    
	va_start(ap, fmt);
f01000e7:	8d 75 14             	lea    0x14(%ebp),%esi
	cprintf("kernel panic at %s:%d: ", file, line);
f01000ea:	83 ec 04             	sub    $0x4,%esp
f01000ed:	ff 75 0c             	pushl  0xc(%ebp)
f01000f0:	ff 75 08             	pushl  0x8(%ebp)
f01000f3:	8d 83 7d fa fe ff    	lea    -0x10583(%ebx),%eax
f01000f9:	50                   	push   %eax
f01000fa:	e8 95 0b 00 00       	call   f0100c94 <cprintf>
	vcprintf(fmt, ap);
f01000ff:	83 c4 08             	add    $0x8,%esp
f0100102:	56                   	push   %esi
f0100103:	57                   	push   %edi
f0100104:	e8 50 0b 00 00       	call   f0100c59 <vcprintf>
	cprintf("\n");
f0100109:	8d 83 b9 fa fe ff    	lea    -0x10547(%ebx),%eax
f010010f:	89 04 24             	mov    %eax,(%esp)
f0100112:	e8 7d 0b 00 00       	call   f0100c94 <cprintf>
f0100117:	83 c4 10             	add    $0x10,%esp
f010011a:	eb b8                	jmp    f01000d4 <_panic+0x26>

f010011c <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f010011c:	f3 0f 1e fb          	endbr32 
f0100120:	55                   	push   %ebp
f0100121:	89 e5                	mov    %esp,%ebp
f0100123:	56                   	push   %esi
f0100124:	53                   	push   %ebx
f0100125:	e8 42 00 00 00       	call   f010016c <__x86.get_pc_thunk.bx>
f010012a:	81 c3 de 21 01 00    	add    $0x121de,%ebx
	va_list ap;

	va_start(ap, fmt);
f0100130:	8d 75 14             	lea    0x14(%ebp),%esi
	cprintf("kernel warning at %s:%d: ", file, line);
f0100133:	83 ec 04             	sub    $0x4,%esp
f0100136:	ff 75 0c             	pushl  0xc(%ebp)
f0100139:	ff 75 08             	pushl  0x8(%ebp)
f010013c:	8d 83 95 fa fe ff    	lea    -0x1056b(%ebx),%eax
f0100142:	50                   	push   %eax
f0100143:	e8 4c 0b 00 00       	call   f0100c94 <cprintf>
	vcprintf(fmt, ap);
f0100148:	83 c4 08             	add    $0x8,%esp
f010014b:	56                   	push   %esi
f010014c:	ff 75 10             	pushl  0x10(%ebp)
f010014f:	e8 05 0b 00 00       	call   f0100c59 <vcprintf>
	cprintf("\n");
f0100154:	8d 83 b9 fa fe ff    	lea    -0x10547(%ebx),%eax
f010015a:	89 04 24             	mov    %eax,(%esp)
f010015d:	e8 32 0b 00 00       	call   f0100c94 <cprintf>
	va_end(ap);
}
f0100162:	83 c4 10             	add    $0x10,%esp
f0100165:	8d 65 f8             	lea    -0x8(%ebp),%esp
f0100168:	5b                   	pop    %ebx
f0100169:	5e                   	pop    %esi
f010016a:	5d                   	pop    %ebp
f010016b:	c3                   	ret    

f010016c <__x86.get_pc_thunk.bx>:
f010016c:	8b 1c 24             	mov    (%esp),%ebx
f010016f:	c3                   	ret    

f0100170 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f0100170:	f3 0f 1e fb          	endbr32 

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100174:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100179:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f010017a:	a8 01                	test   $0x1,%al
f010017c:	74 0a                	je     f0100188 <serial_proc_data+0x18>
f010017e:	ba f8 03 00 00       	mov    $0x3f8,%edx
f0100183:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f0100184:	0f b6 c0             	movzbl %al,%eax
f0100187:	c3                   	ret    
		return -1;
f0100188:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
}
f010018d:	c3                   	ret    

f010018e <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f010018e:	55                   	push   %ebp
f010018f:	89 e5                	mov    %esp,%ebp
f0100191:	57                   	push   %edi
f0100192:	56                   	push   %esi
f0100193:	53                   	push   %ebx
f0100194:	83 ec 1c             	sub    $0x1c,%esp
f0100197:	e8 88 05 00 00       	call   f0100724 <__x86.get_pc_thunk.si>
f010019c:	81 c6 6c 21 01 00    	add    $0x1216c,%esi
f01001a2:	89 c7                	mov    %eax,%edi
	int c;

	while ((c = (*proc)()) != -1) {
		if (c == 0)
			continue;
		cons.buf[cons.wpos++] = c;
f01001a4:	8d 1d 78 1d 00 00    	lea    0x1d78,%ebx
f01001aa:	8d 04 1e             	lea    (%esi,%ebx,1),%eax
f01001ad:	89 45 e0             	mov    %eax,-0x20(%ebp)
f01001b0:	89 7d e4             	mov    %edi,-0x1c(%ebp)
	while ((c = (*proc)()) != -1) {
f01001b3:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01001b6:	ff d0                	call   *%eax
f01001b8:	83 f8 ff             	cmp    $0xffffffff,%eax
f01001bb:	74 2b                	je     f01001e8 <cons_intr+0x5a>
		if (c == 0)
f01001bd:	85 c0                	test   %eax,%eax
f01001bf:	74 f2                	je     f01001b3 <cons_intr+0x25>
		cons.buf[cons.wpos++] = c;
f01001c1:	8b 8c 1e 04 02 00 00 	mov    0x204(%esi,%ebx,1),%ecx
f01001c8:	8d 51 01             	lea    0x1(%ecx),%edx
f01001cb:	8b 7d e0             	mov    -0x20(%ebp),%edi
f01001ce:	88 04 0f             	mov    %al,(%edi,%ecx,1)
		if (cons.wpos == CONSBUFSIZE)
f01001d1:	81 fa 00 02 00 00    	cmp    $0x200,%edx
			cons.wpos = 0;
f01001d7:	b8 00 00 00 00       	mov    $0x0,%eax
f01001dc:	0f 44 d0             	cmove  %eax,%edx
f01001df:	89 94 1e 04 02 00 00 	mov    %edx,0x204(%esi,%ebx,1)
f01001e6:	eb cb                	jmp    f01001b3 <cons_intr+0x25>
	}
}
f01001e8:	83 c4 1c             	add    $0x1c,%esp
f01001eb:	5b                   	pop    %ebx
f01001ec:	5e                   	pop    %esi
f01001ed:	5f                   	pop    %edi
f01001ee:	5d                   	pop    %ebp
f01001ef:	c3                   	ret    

f01001f0 <kbd_proc_data>:
{
f01001f0:	f3 0f 1e fb          	endbr32 
f01001f4:	55                   	push   %ebp
f01001f5:	89 e5                	mov    %esp,%ebp
f01001f7:	56                   	push   %esi
f01001f8:	53                   	push   %ebx
f01001f9:	e8 6e ff ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f01001fe:	81 c3 0a 21 01 00    	add    $0x1210a,%ebx
f0100204:	ba 64 00 00 00       	mov    $0x64,%edx
f0100209:	ec                   	in     (%dx),%al
	if ((stat & KBS_DIB) == 0)
f010020a:	a8 01                	test   $0x1,%al
f010020c:	0f 84 fb 00 00 00    	je     f010030d <kbd_proc_data+0x11d>
	if (stat & KBS_TERR)
f0100212:	a8 20                	test   $0x20,%al
f0100214:	0f 85 fa 00 00 00    	jne    f0100314 <kbd_proc_data+0x124>
f010021a:	ba 60 00 00 00       	mov    $0x60,%edx
f010021f:	ec                   	in     (%dx),%al
f0100220:	89 c2                	mov    %eax,%edx
	if (data == 0xE0) {
f0100222:	3c e0                	cmp    $0xe0,%al
f0100224:	74 64                	je     f010028a <kbd_proc_data+0x9a>
	} else if (data & 0x80) {
f0100226:	84 c0                	test   %al,%al
f0100228:	78 75                	js     f010029f <kbd_proc_data+0xaf>
	} else if (shift & E0ESC) {
f010022a:	8b 8b 58 1d 00 00    	mov    0x1d58(%ebx),%ecx
f0100230:	f6 c1 40             	test   $0x40,%cl
f0100233:	74 0e                	je     f0100243 <kbd_proc_data+0x53>
		data |= 0x80;
f0100235:	83 c8 80             	or     $0xffffff80,%eax
f0100238:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f010023a:	83 e1 bf             	and    $0xffffffbf,%ecx
f010023d:	89 8b 58 1d 00 00    	mov    %ecx,0x1d58(%ebx)
	shift |= shiftcode[data];
f0100243:	0f b6 d2             	movzbl %dl,%edx
f0100246:	0f b6 84 13 d8 fb fe 	movzbl -0x10428(%ebx,%edx,1),%eax
f010024d:	ff 
f010024e:	0b 83 58 1d 00 00    	or     0x1d58(%ebx),%eax
	shift ^= togglecode[data];
f0100254:	0f b6 8c 13 d8 fa fe 	movzbl -0x10528(%ebx,%edx,1),%ecx
f010025b:	ff 
f010025c:	31 c8                	xor    %ecx,%eax
f010025e:	89 83 58 1d 00 00    	mov    %eax,0x1d58(%ebx)
	c = charcode[shift & (CTL | SHIFT)][data];
f0100264:	89 c1                	mov    %eax,%ecx
f0100266:	83 e1 03             	and    $0x3,%ecx
f0100269:	8b 8c 8b f8 1c 00 00 	mov    0x1cf8(%ebx,%ecx,4),%ecx
f0100270:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f0100274:	0f b6 f2             	movzbl %dl,%esi
	if (shift & CAPSLOCK) {
f0100277:	a8 08                	test   $0x8,%al
f0100279:	74 65                	je     f01002e0 <kbd_proc_data+0xf0>
		if ('a' <= c && c <= 'z')
f010027b:	89 f2                	mov    %esi,%edx
f010027d:	8d 4e 9f             	lea    -0x61(%esi),%ecx
f0100280:	83 f9 19             	cmp    $0x19,%ecx
f0100283:	77 4f                	ja     f01002d4 <kbd_proc_data+0xe4>
			c += 'A' - 'a';
f0100285:	83 ee 20             	sub    $0x20,%esi
f0100288:	eb 0c                	jmp    f0100296 <kbd_proc_data+0xa6>
		shift |= E0ESC;
f010028a:	83 8b 58 1d 00 00 40 	orl    $0x40,0x1d58(%ebx)
		return 0;
f0100291:	be 00 00 00 00       	mov    $0x0,%esi
}
f0100296:	89 f0                	mov    %esi,%eax
f0100298:	8d 65 f8             	lea    -0x8(%ebp),%esp
f010029b:	5b                   	pop    %ebx
f010029c:	5e                   	pop    %esi
f010029d:	5d                   	pop    %ebp
f010029e:	c3                   	ret    
		data = (shift & E0ESC ? data : data & 0x7F);
f010029f:	8b 8b 58 1d 00 00    	mov    0x1d58(%ebx),%ecx
f01002a5:	89 ce                	mov    %ecx,%esi
f01002a7:	83 e6 40             	and    $0x40,%esi
f01002aa:	83 e0 7f             	and    $0x7f,%eax
f01002ad:	85 f6                	test   %esi,%esi
f01002af:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f01002b2:	0f b6 d2             	movzbl %dl,%edx
f01002b5:	0f b6 84 13 d8 fb fe 	movzbl -0x10428(%ebx,%edx,1),%eax
f01002bc:	ff 
f01002bd:	83 c8 40             	or     $0x40,%eax
f01002c0:	0f b6 c0             	movzbl %al,%eax
f01002c3:	f7 d0                	not    %eax
f01002c5:	21 c8                	and    %ecx,%eax
f01002c7:	89 83 58 1d 00 00    	mov    %eax,0x1d58(%ebx)
		return 0;
f01002cd:	be 00 00 00 00       	mov    $0x0,%esi
f01002d2:	eb c2                	jmp    f0100296 <kbd_proc_data+0xa6>
		else if ('A' <= c && c <= 'Z')
f01002d4:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f01002d7:	8d 4e 20             	lea    0x20(%esi),%ecx
f01002da:	83 fa 1a             	cmp    $0x1a,%edx
f01002dd:	0f 42 f1             	cmovb  %ecx,%esi
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f01002e0:	f7 d0                	not    %eax
f01002e2:	a8 06                	test   $0x6,%al
f01002e4:	75 b0                	jne    f0100296 <kbd_proc_data+0xa6>
f01002e6:	81 fe e9 00 00 00    	cmp    $0xe9,%esi
f01002ec:	75 a8                	jne    f0100296 <kbd_proc_data+0xa6>
		cprintf("Rebooting!\n");
f01002ee:	83 ec 0c             	sub    $0xc,%esp
f01002f1:	8d 83 af fa fe ff    	lea    -0x10551(%ebx),%eax
f01002f7:	50                   	push   %eax
f01002f8:	e8 97 09 00 00       	call   f0100c94 <cprintf>
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01002fd:	b8 03 00 00 00       	mov    $0x3,%eax
f0100302:	ba 92 00 00 00       	mov    $0x92,%edx
f0100307:	ee                   	out    %al,(%dx)
}
f0100308:	83 c4 10             	add    $0x10,%esp
f010030b:	eb 89                	jmp    f0100296 <kbd_proc_data+0xa6>
		return -1;
f010030d:	be ff ff ff ff       	mov    $0xffffffff,%esi
f0100312:	eb 82                	jmp    f0100296 <kbd_proc_data+0xa6>
		return -1;
f0100314:	be ff ff ff ff       	mov    $0xffffffff,%esi
f0100319:	e9 78 ff ff ff       	jmp    f0100296 <kbd_proc_data+0xa6>

f010031e <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f010031e:	55                   	push   %ebp
f010031f:	89 e5                	mov    %esp,%ebp
f0100321:	57                   	push   %edi
f0100322:	56                   	push   %esi
f0100323:	53                   	push   %ebx
f0100324:	83 ec 1c             	sub    $0x1c,%esp
f0100327:	e8 40 fe ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f010032c:	81 c3 dc 1f 01 00    	add    $0x11fdc,%ebx
f0100332:	89 c7                	mov    %eax,%edi
	for (i = 0;
f0100334:	be 00 00 00 00       	mov    $0x0,%esi
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100339:	b9 84 00 00 00       	mov    $0x84,%ecx
f010033e:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100343:	ec                   	in     (%dx),%al
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f0100344:	a8 20                	test   $0x20,%al
f0100346:	75 13                	jne    f010035b <cons_putc+0x3d>
f0100348:	81 fe ff 31 00 00    	cmp    $0x31ff,%esi
f010034e:	7f 0b                	jg     f010035b <cons_putc+0x3d>
f0100350:	89 ca                	mov    %ecx,%edx
f0100352:	ec                   	in     (%dx),%al
f0100353:	ec                   	in     (%dx),%al
f0100354:	ec                   	in     (%dx),%al
f0100355:	ec                   	in     (%dx),%al
	     i++)
f0100356:	83 c6 01             	add    $0x1,%esi
f0100359:	eb e3                	jmp    f010033e <cons_putc+0x20>
	outb(COM1 + COM_TX, c);
f010035b:	89 f8                	mov    %edi,%eax
f010035d:	88 45 e7             	mov    %al,-0x19(%ebp)
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100360:	ba f8 03 00 00       	mov    $0x3f8,%edx
f0100365:	ee                   	out    %al,(%dx)
	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f0100366:	be 00 00 00 00       	mov    $0x0,%esi
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010036b:	b9 84 00 00 00       	mov    $0x84,%ecx
f0100370:	ba 79 03 00 00       	mov    $0x379,%edx
f0100375:	ec                   	in     (%dx),%al
f0100376:	81 fe ff 31 00 00    	cmp    $0x31ff,%esi
f010037c:	7f 0f                	jg     f010038d <cons_putc+0x6f>
f010037e:	84 c0                	test   %al,%al
f0100380:	78 0b                	js     f010038d <cons_putc+0x6f>
f0100382:	89 ca                	mov    %ecx,%edx
f0100384:	ec                   	in     (%dx),%al
f0100385:	ec                   	in     (%dx),%al
f0100386:	ec                   	in     (%dx),%al
f0100387:	ec                   	in     (%dx),%al
f0100388:	83 c6 01             	add    $0x1,%esi
f010038b:	eb e3                	jmp    f0100370 <cons_putc+0x52>
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010038d:	ba 78 03 00 00       	mov    $0x378,%edx
f0100392:	0f b6 45 e7          	movzbl -0x19(%ebp),%eax
f0100396:	ee                   	out    %al,(%dx)
f0100397:	ba 7a 03 00 00       	mov    $0x37a,%edx
f010039c:	b8 0d 00 00 00       	mov    $0xd,%eax
f01003a1:	ee                   	out    %al,(%dx)
f01003a2:	b8 08 00 00 00       	mov    $0x8,%eax
f01003a7:	ee                   	out    %al,(%dx)
		c |= 0x0700;
f01003a8:	89 f8                	mov    %edi,%eax
f01003aa:	80 cc 07             	or     $0x7,%ah
f01003ad:	f7 c7 00 ff ff ff    	test   $0xffffff00,%edi
f01003b3:	0f 44 f8             	cmove  %eax,%edi
	switch (c & 0xff) {
f01003b6:	89 f8                	mov    %edi,%eax
f01003b8:	0f b6 c0             	movzbl %al,%eax
f01003bb:	89 f9                	mov    %edi,%ecx
f01003bd:	80 f9 0a             	cmp    $0xa,%cl
f01003c0:	0f 84 e2 00 00 00    	je     f01004a8 <cons_putc+0x18a>
f01003c6:	83 f8 0a             	cmp    $0xa,%eax
f01003c9:	7f 46                	jg     f0100411 <cons_putc+0xf3>
f01003cb:	83 f8 08             	cmp    $0x8,%eax
f01003ce:	0f 84 a8 00 00 00    	je     f010047c <cons_putc+0x15e>
f01003d4:	83 f8 09             	cmp    $0x9,%eax
f01003d7:	0f 85 d8 00 00 00    	jne    f01004b5 <cons_putc+0x197>
		cons_putc(' ');
f01003dd:	b8 20 00 00 00       	mov    $0x20,%eax
f01003e2:	e8 37 ff ff ff       	call   f010031e <cons_putc>
		cons_putc(' ');
f01003e7:	b8 20 00 00 00       	mov    $0x20,%eax
f01003ec:	e8 2d ff ff ff       	call   f010031e <cons_putc>
		cons_putc(' ');
f01003f1:	b8 20 00 00 00       	mov    $0x20,%eax
f01003f6:	e8 23 ff ff ff       	call   f010031e <cons_putc>
		cons_putc(' ');
f01003fb:	b8 20 00 00 00       	mov    $0x20,%eax
f0100400:	e8 19 ff ff ff       	call   f010031e <cons_putc>
		cons_putc(' ');
f0100405:	b8 20 00 00 00       	mov    $0x20,%eax
f010040a:	e8 0f ff ff ff       	call   f010031e <cons_putc>
		break;
f010040f:	eb 26                	jmp    f0100437 <cons_putc+0x119>
	switch (c & 0xff) {
f0100411:	83 f8 0d             	cmp    $0xd,%eax
f0100414:	0f 85 9b 00 00 00    	jne    f01004b5 <cons_putc+0x197>
		crt_pos -= (crt_pos % CRT_COLS);
f010041a:	0f b7 83 80 1f 00 00 	movzwl 0x1f80(%ebx),%eax
f0100421:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100427:	c1 e8 16             	shr    $0x16,%eax
f010042a:	8d 04 80             	lea    (%eax,%eax,4),%eax
f010042d:	c1 e0 04             	shl    $0x4,%eax
f0100430:	66 89 83 80 1f 00 00 	mov    %ax,0x1f80(%ebx)
	if (crt_pos >= CRT_SIZE) {
f0100437:	66 81 bb 80 1f 00 00 	cmpw   $0x7cf,0x1f80(%ebx)
f010043e:	cf 07 
f0100440:	0f 87 92 00 00 00    	ja     f01004d8 <cons_putc+0x1ba>
	outb(addr_6845, 14);
f0100446:	8b 8b 88 1f 00 00    	mov    0x1f88(%ebx),%ecx
f010044c:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100451:	89 ca                	mov    %ecx,%edx
f0100453:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f0100454:	0f b7 9b 80 1f 00 00 	movzwl 0x1f80(%ebx),%ebx
f010045b:	8d 71 01             	lea    0x1(%ecx),%esi
f010045e:	89 d8                	mov    %ebx,%eax
f0100460:	66 c1 e8 08          	shr    $0x8,%ax
f0100464:	89 f2                	mov    %esi,%edx
f0100466:	ee                   	out    %al,(%dx)
f0100467:	b8 0f 00 00 00       	mov    $0xf,%eax
f010046c:	89 ca                	mov    %ecx,%edx
f010046e:	ee                   	out    %al,(%dx)
f010046f:	89 d8                	mov    %ebx,%eax
f0100471:	89 f2                	mov    %esi,%edx
f0100473:	ee                   	out    %al,(%dx)
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f0100474:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0100477:	5b                   	pop    %ebx
f0100478:	5e                   	pop    %esi
f0100479:	5f                   	pop    %edi
f010047a:	5d                   	pop    %ebp
f010047b:	c3                   	ret    
		if (crt_pos > 0) {
f010047c:	0f b7 83 80 1f 00 00 	movzwl 0x1f80(%ebx),%eax
f0100483:	66 85 c0             	test   %ax,%ax
f0100486:	74 be                	je     f0100446 <cons_putc+0x128>
			crt_pos--;
f0100488:	83 e8 01             	sub    $0x1,%eax
f010048b:	66 89 83 80 1f 00 00 	mov    %ax,0x1f80(%ebx)
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100492:	0f b7 c0             	movzwl %ax,%eax
f0100495:	89 fa                	mov    %edi,%edx
f0100497:	b2 00                	mov    $0x0,%dl
f0100499:	83 ca 20             	or     $0x20,%edx
f010049c:	8b 8b 84 1f 00 00    	mov    0x1f84(%ebx),%ecx
f01004a2:	66 89 14 41          	mov    %dx,(%ecx,%eax,2)
f01004a6:	eb 8f                	jmp    f0100437 <cons_putc+0x119>
		crt_pos += CRT_COLS;
f01004a8:	66 83 83 80 1f 00 00 	addw   $0x50,0x1f80(%ebx)
f01004af:	50 
f01004b0:	e9 65 ff ff ff       	jmp    f010041a <cons_putc+0xfc>
		crt_buf[crt_pos++] = c;		/* write the character */
f01004b5:	0f b7 83 80 1f 00 00 	movzwl 0x1f80(%ebx),%eax
f01004bc:	8d 50 01             	lea    0x1(%eax),%edx
f01004bf:	66 89 93 80 1f 00 00 	mov    %dx,0x1f80(%ebx)
f01004c6:	0f b7 c0             	movzwl %ax,%eax
f01004c9:	8b 93 84 1f 00 00    	mov    0x1f84(%ebx),%edx
f01004cf:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
f01004d3:	e9 5f ff ff ff       	jmp    f0100437 <cons_putc+0x119>
		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f01004d8:	8b 83 84 1f 00 00    	mov    0x1f84(%ebx),%eax
f01004de:	83 ec 04             	sub    $0x4,%esp
f01004e1:	68 00 0f 00 00       	push   $0xf00
f01004e6:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f01004ec:	52                   	push   %edx
f01004ed:	50                   	push   %eax
f01004ee:	e8 4f 14 00 00       	call   f0101942 <memmove>
			crt_buf[i] = 0x0700 | ' ';
f01004f3:	8b 93 84 1f 00 00    	mov    0x1f84(%ebx),%edx
f01004f9:	8d 82 00 0f 00 00    	lea    0xf00(%edx),%eax
f01004ff:	81 c2 a0 0f 00 00    	add    $0xfa0,%edx
f0100505:	83 c4 10             	add    $0x10,%esp
f0100508:	66 c7 00 20 07       	movw   $0x720,(%eax)
f010050d:	83 c0 02             	add    $0x2,%eax
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100510:	39 d0                	cmp    %edx,%eax
f0100512:	75 f4                	jne    f0100508 <cons_putc+0x1ea>
		crt_pos -= CRT_COLS;
f0100514:	66 83 ab 80 1f 00 00 	subw   $0x50,0x1f80(%ebx)
f010051b:	50 
f010051c:	e9 25 ff ff ff       	jmp    f0100446 <cons_putc+0x128>

f0100521 <serial_intr>:
{
f0100521:	f3 0f 1e fb          	endbr32 
f0100525:	e8 f6 01 00 00       	call   f0100720 <__x86.get_pc_thunk.ax>
f010052a:	05 de 1d 01 00       	add    $0x11dde,%eax
	if (serial_exists)
f010052f:	80 b8 8c 1f 00 00 00 	cmpb   $0x0,0x1f8c(%eax)
f0100536:	75 01                	jne    f0100539 <serial_intr+0x18>
f0100538:	c3                   	ret    
{
f0100539:	55                   	push   %ebp
f010053a:	89 e5                	mov    %esp,%ebp
f010053c:	83 ec 08             	sub    $0x8,%esp
		cons_intr(serial_proc_data);
f010053f:	8d 80 68 de fe ff    	lea    -0x12198(%eax),%eax
f0100545:	e8 44 fc ff ff       	call   f010018e <cons_intr>
}
f010054a:	c9                   	leave  
f010054b:	c3                   	ret    

f010054c <kbd_intr>:
{
f010054c:	f3 0f 1e fb          	endbr32 
f0100550:	55                   	push   %ebp
f0100551:	89 e5                	mov    %esp,%ebp
f0100553:	83 ec 08             	sub    $0x8,%esp
f0100556:	e8 c5 01 00 00       	call   f0100720 <__x86.get_pc_thunk.ax>
f010055b:	05 ad 1d 01 00       	add    $0x11dad,%eax
	cons_intr(kbd_proc_data);
f0100560:	8d 80 e8 de fe ff    	lea    -0x12118(%eax),%eax
f0100566:	e8 23 fc ff ff       	call   f010018e <cons_intr>
}
f010056b:	c9                   	leave  
f010056c:	c3                   	ret    

f010056d <cons_getc>:
{
f010056d:	f3 0f 1e fb          	endbr32 
f0100571:	55                   	push   %ebp
f0100572:	89 e5                	mov    %esp,%ebp
f0100574:	53                   	push   %ebx
f0100575:	83 ec 04             	sub    $0x4,%esp
f0100578:	e8 ef fb ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f010057d:	81 c3 8b 1d 01 00    	add    $0x11d8b,%ebx
	serial_intr();
f0100583:	e8 99 ff ff ff       	call   f0100521 <serial_intr>
	kbd_intr();
f0100588:	e8 bf ff ff ff       	call   f010054c <kbd_intr>
	if (cons.rpos != cons.wpos) {
f010058d:	8b 83 78 1f 00 00    	mov    0x1f78(%ebx),%eax
	return 0;
f0100593:	ba 00 00 00 00       	mov    $0x0,%edx
	if (cons.rpos != cons.wpos) {
f0100598:	3b 83 7c 1f 00 00    	cmp    0x1f7c(%ebx),%eax
f010059e:	74 1f                	je     f01005bf <cons_getc+0x52>
		c = cons.buf[cons.rpos++];
f01005a0:	8d 48 01             	lea    0x1(%eax),%ecx
f01005a3:	0f b6 94 03 78 1d 00 	movzbl 0x1d78(%ebx,%eax,1),%edx
f01005aa:	00 
			cons.rpos = 0;
f01005ab:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f01005b1:	b8 00 00 00 00       	mov    $0x0,%eax
f01005b6:	0f 44 c8             	cmove  %eax,%ecx
f01005b9:	89 8b 78 1f 00 00    	mov    %ecx,0x1f78(%ebx)
}
f01005bf:	89 d0                	mov    %edx,%eax
f01005c1:	83 c4 04             	add    $0x4,%esp
f01005c4:	5b                   	pop    %ebx
f01005c5:	5d                   	pop    %ebp
f01005c6:	c3                   	ret    

f01005c7 <cons_init>:

// initialize the console devices
void
cons_init(void)
{
f01005c7:	f3 0f 1e fb          	endbr32 
f01005cb:	55                   	push   %ebp
f01005cc:	89 e5                	mov    %esp,%ebp
f01005ce:	57                   	push   %edi
f01005cf:	56                   	push   %esi
f01005d0:	53                   	push   %ebx
f01005d1:	83 ec 1c             	sub    $0x1c,%esp
f01005d4:	e8 93 fb ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f01005d9:	81 c3 2f 1d 01 00    	add    $0x11d2f,%ebx
	was = *cp;
f01005df:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f01005e6:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f01005ed:	5a a5 
	if (*cp != 0xA55A) {
f01005ef:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f01005f6:	66 3d 5a a5          	cmp    $0xa55a,%ax
f01005fa:	0f 84 bc 00 00 00    	je     f01006bc <cons_init+0xf5>
		addr_6845 = MONO_BASE;
f0100600:	c7 83 88 1f 00 00 b4 	movl   $0x3b4,0x1f88(%ebx)
f0100607:	03 00 00 
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f010060a:	c7 45 e4 00 00 0b f0 	movl   $0xf00b0000,-0x1c(%ebp)
	outb(addr_6845, 14);
f0100611:	8b bb 88 1f 00 00    	mov    0x1f88(%ebx),%edi
f0100617:	b8 0e 00 00 00       	mov    $0xe,%eax
f010061c:	89 fa                	mov    %edi,%edx
f010061e:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f010061f:	8d 4f 01             	lea    0x1(%edi),%ecx
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100622:	89 ca                	mov    %ecx,%edx
f0100624:	ec                   	in     (%dx),%al
f0100625:	0f b6 f0             	movzbl %al,%esi
f0100628:	c1 e6 08             	shl    $0x8,%esi
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010062b:	b8 0f 00 00 00       	mov    $0xf,%eax
f0100630:	89 fa                	mov    %edi,%edx
f0100632:	ee                   	out    %al,(%dx)
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100633:	89 ca                	mov    %ecx,%edx
f0100635:	ec                   	in     (%dx),%al
	crt_buf = (uint16_t*) cp;
f0100636:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100639:	89 bb 84 1f 00 00    	mov    %edi,0x1f84(%ebx)
	pos |= inb(addr_6845 + 1);
f010063f:	0f b6 c0             	movzbl %al,%eax
f0100642:	09 c6                	or     %eax,%esi
	crt_pos = pos;
f0100644:	66 89 b3 80 1f 00 00 	mov    %si,0x1f80(%ebx)
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010064b:	b9 00 00 00 00       	mov    $0x0,%ecx
f0100650:	89 c8                	mov    %ecx,%eax
f0100652:	ba fa 03 00 00       	mov    $0x3fa,%edx
f0100657:	ee                   	out    %al,(%dx)
f0100658:	bf fb 03 00 00       	mov    $0x3fb,%edi
f010065d:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f0100662:	89 fa                	mov    %edi,%edx
f0100664:	ee                   	out    %al,(%dx)
f0100665:	b8 0c 00 00 00       	mov    $0xc,%eax
f010066a:	ba f8 03 00 00       	mov    $0x3f8,%edx
f010066f:	ee                   	out    %al,(%dx)
f0100670:	be f9 03 00 00       	mov    $0x3f9,%esi
f0100675:	89 c8                	mov    %ecx,%eax
f0100677:	89 f2                	mov    %esi,%edx
f0100679:	ee                   	out    %al,(%dx)
f010067a:	b8 03 00 00 00       	mov    $0x3,%eax
f010067f:	89 fa                	mov    %edi,%edx
f0100681:	ee                   	out    %al,(%dx)
f0100682:	ba fc 03 00 00       	mov    $0x3fc,%edx
f0100687:	89 c8                	mov    %ecx,%eax
f0100689:	ee                   	out    %al,(%dx)
f010068a:	b8 01 00 00 00       	mov    $0x1,%eax
f010068f:	89 f2                	mov    %esi,%edx
f0100691:	ee                   	out    %al,(%dx)
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100692:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100697:	ec                   	in     (%dx),%al
f0100698:	89 c1                	mov    %eax,%ecx
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f010069a:	3c ff                	cmp    $0xff,%al
f010069c:	0f 95 83 8c 1f 00 00 	setne  0x1f8c(%ebx)
f01006a3:	ba fa 03 00 00       	mov    $0x3fa,%edx
f01006a8:	ec                   	in     (%dx),%al
f01006a9:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01006ae:	ec                   	in     (%dx),%al
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f01006af:	80 f9 ff             	cmp    $0xff,%cl
f01006b2:	74 25                	je     f01006d9 <cons_init+0x112>
		cprintf("Serial port does not exist!\n");
}
f01006b4:	8d 65 f4             	lea    -0xc(%ebp),%esp
f01006b7:	5b                   	pop    %ebx
f01006b8:	5e                   	pop    %esi
f01006b9:	5f                   	pop    %edi
f01006ba:	5d                   	pop    %ebp
f01006bb:	c3                   	ret    
		*cp = was;
f01006bc:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f01006c3:	c7 83 88 1f 00 00 d4 	movl   $0x3d4,0x1f88(%ebx)
f01006ca:	03 00 00 
	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f01006cd:	c7 45 e4 00 80 0b f0 	movl   $0xf00b8000,-0x1c(%ebp)
f01006d4:	e9 38 ff ff ff       	jmp    f0100611 <cons_init+0x4a>
		cprintf("Serial port does not exist!\n");
f01006d9:	83 ec 0c             	sub    $0xc,%esp
f01006dc:	8d 83 bb fa fe ff    	lea    -0x10545(%ebx),%eax
f01006e2:	50                   	push   %eax
f01006e3:	e8 ac 05 00 00       	call   f0100c94 <cprintf>
f01006e8:	83 c4 10             	add    $0x10,%esp
}
f01006eb:	eb c7                	jmp    f01006b4 <cons_init+0xed>

f01006ed <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f01006ed:	f3 0f 1e fb          	endbr32 
f01006f1:	55                   	push   %ebp
f01006f2:	89 e5                	mov    %esp,%ebp
f01006f4:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f01006f7:	8b 45 08             	mov    0x8(%ebp),%eax
f01006fa:	e8 1f fc ff ff       	call   f010031e <cons_putc>
}
f01006ff:	c9                   	leave  
f0100700:	c3                   	ret    

f0100701 <getchar>:

int
getchar(void)
{
f0100701:	f3 0f 1e fb          	endbr32 
f0100705:	55                   	push   %ebp
f0100706:	89 e5                	mov    %esp,%ebp
f0100708:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f010070b:	e8 5d fe ff ff       	call   f010056d <cons_getc>
f0100710:	85 c0                	test   %eax,%eax
f0100712:	74 f7                	je     f010070b <getchar+0xa>
		/* do nothing */;
	return c;
}
f0100714:	c9                   	leave  
f0100715:	c3                   	ret    

f0100716 <iscons>:

int
iscons(int fdnum)
{
f0100716:	f3 0f 1e fb          	endbr32 
	// used by readline
	return 1;
}
f010071a:	b8 01 00 00 00       	mov    $0x1,%eax
f010071f:	c3                   	ret    

f0100720 <__x86.get_pc_thunk.ax>:
f0100720:	8b 04 24             	mov    (%esp),%eax
f0100723:	c3                   	ret    

f0100724 <__x86.get_pc_thunk.si>:
f0100724:	8b 34 24             	mov    (%esp),%esi
f0100727:	c3                   	ret    

f0100728 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100728:	f3 0f 1e fb          	endbr32 
f010072c:	55                   	push   %ebp
f010072d:	89 e5                	mov    %esp,%ebp
f010072f:	56                   	push   %esi
f0100730:	53                   	push   %ebx
f0100731:	e8 36 fa ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f0100736:	81 c3 d2 1b 01 00    	add    $0x11bd2,%ebx
	int i;

	for (i = 0; i < ARRAY_SIZE(commands); i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f010073c:	83 ec 04             	sub    $0x4,%esp
f010073f:	8d 83 d8 fc fe ff    	lea    -0x10328(%ebx),%eax
f0100745:	50                   	push   %eax
f0100746:	8d 83 f6 fc fe ff    	lea    -0x1030a(%ebx),%eax
f010074c:	50                   	push   %eax
f010074d:	8d b3 fb fc fe ff    	lea    -0x10305(%ebx),%esi
f0100753:	56                   	push   %esi
f0100754:	e8 3b 05 00 00       	call   f0100c94 <cprintf>
f0100759:	83 c4 0c             	add    $0xc,%esp
f010075c:	8d 83 8c fd fe ff    	lea    -0x10274(%ebx),%eax
f0100762:	50                   	push   %eax
f0100763:	8d 83 04 fd fe ff    	lea    -0x102fc(%ebx),%eax
f0100769:	50                   	push   %eax
f010076a:	56                   	push   %esi
f010076b:	e8 24 05 00 00       	call   f0100c94 <cprintf>
	return 0;
}
f0100770:	b8 00 00 00 00       	mov    $0x0,%eax
f0100775:	8d 65 f8             	lea    -0x8(%ebp),%esp
f0100778:	5b                   	pop    %ebx
f0100779:	5e                   	pop    %esi
f010077a:	5d                   	pop    %ebp
f010077b:	c3                   	ret    

f010077c <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f010077c:	f3 0f 1e fb          	endbr32 
f0100780:	55                   	push   %ebp
f0100781:	89 e5                	mov    %esp,%ebp
f0100783:	57                   	push   %edi
f0100784:	56                   	push   %esi
f0100785:	53                   	push   %ebx
f0100786:	83 ec 18             	sub    $0x18,%esp
f0100789:	e8 de f9 ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f010078e:	81 c3 7a 1b 01 00    	add    $0x11b7a,%ebx
	extern char _start[], entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f0100794:	8d 83 0d fd fe ff    	lea    -0x102f3(%ebx),%eax
f010079a:	50                   	push   %eax
f010079b:	e8 f4 04 00 00       	call   f0100c94 <cprintf>
	cprintf("  _start                  %08x (phys)\n", _start);
f01007a0:	83 c4 08             	add    $0x8,%esp
f01007a3:	ff b3 f8 ff ff ff    	pushl  -0x8(%ebx)
f01007a9:	8d 83 b4 fd fe ff    	lea    -0x1024c(%ebx),%eax
f01007af:	50                   	push   %eax
f01007b0:	e8 df 04 00 00       	call   f0100c94 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f01007b5:	83 c4 0c             	add    $0xc,%esp
f01007b8:	c7 c7 0c 00 10 f0    	mov    $0xf010000c,%edi
f01007be:	8d 87 00 00 00 10    	lea    0x10000000(%edi),%eax
f01007c4:	50                   	push   %eax
f01007c5:	57                   	push   %edi
f01007c6:	8d 83 dc fd fe ff    	lea    -0x10224(%ebx),%eax
f01007cc:	50                   	push   %eax
f01007cd:	e8 c2 04 00 00       	call   f0100c94 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01007d2:	83 c4 0c             	add    $0xc,%esp
f01007d5:	c7 c0 5d 1d 10 f0    	mov    $0xf0101d5d,%eax
f01007db:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01007e1:	52                   	push   %edx
f01007e2:	50                   	push   %eax
f01007e3:	8d 83 00 fe fe ff    	lea    -0x10200(%ebx),%eax
f01007e9:	50                   	push   %eax
f01007ea:	e8 a5 04 00 00       	call   f0100c94 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01007ef:	83 c4 0c             	add    $0xc,%esp
f01007f2:	c7 c0 60 40 11 f0    	mov    $0xf0114060,%eax
f01007f8:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01007fe:	52                   	push   %edx
f01007ff:	50                   	push   %eax
f0100800:	8d 83 24 fe fe ff    	lea    -0x101dc(%ebx),%eax
f0100806:	50                   	push   %eax
f0100807:	e8 88 04 00 00       	call   f0100c94 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f010080c:	83 c4 0c             	add    $0xc,%esp
f010080f:	c7 c6 a0 46 11 f0    	mov    $0xf01146a0,%esi
f0100815:	8d 86 00 00 00 10    	lea    0x10000000(%esi),%eax
f010081b:	50                   	push   %eax
f010081c:	56                   	push   %esi
f010081d:	8d 83 48 fe fe ff    	lea    -0x101b8(%ebx),%eax
f0100823:	50                   	push   %eax
f0100824:	e8 6b 04 00 00       	call   f0100c94 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
f0100829:	83 c4 08             	add    $0x8,%esp
		ROUNDUP(end - entry, 1024) / 1024);
f010082c:	29 fe                	sub    %edi,%esi
f010082e:	81 c6 ff 03 00 00    	add    $0x3ff,%esi
	cprintf("Kernel executable memory footprint: %dKB\n",
f0100834:	c1 fe 0a             	sar    $0xa,%esi
f0100837:	56                   	push   %esi
f0100838:	8d 83 6c fe fe ff    	lea    -0x10194(%ebx),%eax
f010083e:	50                   	push   %eax
f010083f:	e8 50 04 00 00       	call   f0100c94 <cprintf>
	return 0;
}
f0100844:	b8 00 00 00 00       	mov    $0x0,%eax
f0100849:	8d 65 f4             	lea    -0xc(%ebp),%esp
f010084c:	5b                   	pop    %ebx
f010084d:	5e                   	pop    %esi
f010084e:	5f                   	pop    %edi
f010084f:	5d                   	pop    %ebp
f0100850:	c3                   	ret    

f0100851 <mon_backtrace>:

int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f0100851:	f3 0f 1e fb          	endbr32 
f0100855:	55                   	push   %ebp
f0100856:	89 e5                	mov    %esp,%ebp
f0100858:	57                   	push   %edi
f0100859:	56                   	push   %esi
f010085a:	53                   	push   %ebx
f010085b:	83 ec 48             	sub    $0x48,%esp
f010085e:	e8 09 f9 ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f0100863:	81 c3 a5 1a 01 00    	add    $0x11aa5,%ebx

static inline uint32_t
read_ebp(void)
{
	uint32_t ebp;
	asm volatile("movl %%ebp,%0" : "=r" (ebp));
f0100869:	89 ee                	mov    %ebp,%esi
f010086b:	89 f7                	mov    %esi,%edi
	uint32_t ebp = read_ebp();  // 拿到%EBP的值
	uint32_t *ptr_ebp = (uint32_t*)ebp;  // 指针
	struct Eipdebuginfo info;
	cprintf("Stack backtrace:\n");
f010086d:	8d 83 26 fd fe ff    	lea    -0x102da(%ebx),%eax
f0100873:	50                   	push   %eax
f0100874:	e8 1b 04 00 00       	call   f0100c94 <cprintf>
	while (ebp != 0 && debuginfo_eip(ptr_ebp[1], &info) == 0) {
f0100879:	83 c4 10             	add    $0x10,%esp
		cprintf(" ebp %x  eip %x  args %08x %08x %08x %08x %08x\n", ebp, ptr_ebp[1], ptr_ebp[2], ptr_ebp[3], ptr_ebp[4], ptr_ebp[5], ptr_ebp[6]);
f010087c:	8d 83 98 fe fe ff    	lea    -0x10168(%ebx),%eax
f0100882:	89 45 c4             	mov    %eax,-0x3c(%ebp)
		cprintf("     %s:%d: %.*s+%d\n", info.eip_file, info.eip_line, info.eip_fn_namelen, info.eip_fn_name, ptr_ebp[1] - info.eip_fn_addr);
f0100885:	8d 83 38 fd fe ff    	lea    -0x102c8(%ebx),%eax
f010088b:	89 45 c0             	mov    %eax,-0x40(%ebp)
	while (ebp != 0 && debuginfo_eip(ptr_ebp[1], &info) == 0) {
f010088e:	85 ff                	test   %edi,%edi
f0100890:	74 58                	je     f01008ea <mon_backtrace+0x99>
f0100892:	83 ec 08             	sub    $0x8,%esp
f0100895:	8d 45 d0             	lea    -0x30(%ebp),%eax
f0100898:	50                   	push   %eax
f0100899:	ff 76 04             	pushl  0x4(%esi)
f010089c:	e8 00 05 00 00       	call   f0100da1 <debuginfo_eip>
f01008a1:	83 c4 10             	add    $0x10,%esp
f01008a4:	85 c0                	test   %eax,%eax
f01008a6:	75 42                	jne    f01008ea <mon_backtrace+0x99>
		cprintf(" ebp %x  eip %x  args %08x %08x %08x %08x %08x\n", ebp, ptr_ebp[1], ptr_ebp[2], ptr_ebp[3], ptr_ebp[4], ptr_ebp[5], ptr_ebp[6]);
f01008a8:	ff 76 18             	pushl  0x18(%esi)
f01008ab:	ff 76 14             	pushl  0x14(%esi)
f01008ae:	ff 76 10             	pushl  0x10(%esi)
f01008b1:	ff 76 0c             	pushl  0xc(%esi)
f01008b4:	ff 76 08             	pushl  0x8(%esi)
f01008b7:	ff 76 04             	pushl  0x4(%esi)
f01008ba:	57                   	push   %edi
f01008bb:	ff 75 c4             	pushl  -0x3c(%ebp)
f01008be:	e8 d1 03 00 00       	call   f0100c94 <cprintf>
		cprintf("     %s:%d: %.*s+%d\n", info.eip_file, info.eip_line, info.eip_fn_namelen, info.eip_fn_name, ptr_ebp[1] - info.eip_fn_addr);
f01008c3:	83 c4 18             	add    $0x18,%esp
f01008c6:	8b 46 04             	mov    0x4(%esi),%eax
f01008c9:	2b 45 e0             	sub    -0x20(%ebp),%eax
f01008cc:	50                   	push   %eax
f01008cd:	ff 75 d8             	pushl  -0x28(%ebp)
f01008d0:	ff 75 dc             	pushl  -0x24(%ebp)
f01008d3:	ff 75 d4             	pushl  -0x2c(%ebp)
f01008d6:	ff 75 d0             	pushl  -0x30(%ebp)
f01008d9:	ff 75 c0             	pushl  -0x40(%ebp)
f01008dc:	e8 b3 03 00 00       	call   f0100c94 <cprintf>
		ebp = *ptr_ebp;
f01008e1:	8b 3e                	mov    (%esi),%edi
		ptr_ebp = (uint32_t*)ebp;
f01008e3:	89 fe                	mov    %edi,%esi
f01008e5:	83 c4 20             	add    $0x20,%esp
f01008e8:	eb a4                	jmp    f010088e <mon_backtrace+0x3d>
	}
    
	cprintf("\n");
f01008ea:	83 ec 0c             	sub    $0xc,%esp
f01008ed:	8d 83 b9 fa fe ff    	lea    -0x10547(%ebx),%eax
f01008f3:	50                   	push   %eax
f01008f4:	e8 9b 03 00 00       	call   f0100c94 <cprintf>
	
	return 0;
}
f01008f9:	b8 00 00 00 00       	mov    $0x0,%eax
f01008fe:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0100901:	5b                   	pop    %ebx
f0100902:	5e                   	pop    %esi
f0100903:	5f                   	pop    %edi
f0100904:	5d                   	pop    %ebp
f0100905:	c3                   	ret    

f0100906 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f0100906:	f3 0f 1e fb          	endbr32 
f010090a:	55                   	push   %ebp
f010090b:	89 e5                	mov    %esp,%ebp
f010090d:	57                   	push   %edi
f010090e:	56                   	push   %esi
f010090f:	53                   	push   %ebx
f0100910:	83 ec 68             	sub    $0x68,%esp
f0100913:	e8 54 f8 ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f0100918:	81 c3 f0 19 01 00    	add    $0x119f0,%ebx
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f010091e:	8d 83 c8 fe fe ff    	lea    -0x10138(%ebx),%eax
f0100924:	50                   	push   %eax
f0100925:	e8 6a 03 00 00       	call   f0100c94 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f010092a:	8d 83 ec fe fe ff    	lea    -0x10114(%ebx),%eax
f0100930:	89 04 24             	mov    %eax,(%esp)
f0100933:	e8 5c 03 00 00       	call   f0100c94 <cprintf>
f0100938:	83 c4 10             	add    $0x10,%esp
		while (*buf && strchr(WHITESPACE, *buf))
f010093b:	8d 83 51 fd fe ff    	lea    -0x102af(%ebx),%eax
f0100941:	89 45 a0             	mov    %eax,-0x60(%ebp)
f0100944:	e9 dc 00 00 00       	jmp    f0100a25 <monitor+0x11f>
f0100949:	83 ec 08             	sub    $0x8,%esp
f010094c:	0f be c0             	movsbl %al,%eax
f010094f:	50                   	push   %eax
f0100950:	ff 75 a0             	pushl  -0x60(%ebp)
f0100953:	e8 59 0f 00 00       	call   f01018b1 <strchr>
f0100958:	83 c4 10             	add    $0x10,%esp
f010095b:	85 c0                	test   %eax,%eax
f010095d:	74 74                	je     f01009d3 <monitor+0xcd>
			*buf++ = 0;
f010095f:	c6 06 00             	movb   $0x0,(%esi)
f0100962:	89 7d a4             	mov    %edi,-0x5c(%ebp)
f0100965:	8d 76 01             	lea    0x1(%esi),%esi
f0100968:	8b 7d a4             	mov    -0x5c(%ebp),%edi
		while (*buf && strchr(WHITESPACE, *buf))
f010096b:	0f b6 06             	movzbl (%esi),%eax
f010096e:	84 c0                	test   %al,%al
f0100970:	75 d7                	jne    f0100949 <monitor+0x43>
	argv[argc] = 0;
f0100972:	c7 44 bd a8 00 00 00 	movl   $0x0,-0x58(%ebp,%edi,4)
f0100979:	00 
	if (argc == 0)
f010097a:	85 ff                	test   %edi,%edi
f010097c:	0f 84 a3 00 00 00    	je     f0100a25 <monitor+0x11f>
		if (strcmp(argv[0], commands[i].name) == 0)
f0100982:	83 ec 08             	sub    $0x8,%esp
f0100985:	8d 83 f6 fc fe ff    	lea    -0x1030a(%ebx),%eax
f010098b:	50                   	push   %eax
f010098c:	ff 75 a8             	pushl  -0x58(%ebp)
f010098f:	e8 b7 0e 00 00       	call   f010184b <strcmp>
f0100994:	83 c4 10             	add    $0x10,%esp
f0100997:	85 c0                	test   %eax,%eax
f0100999:	0f 84 b4 00 00 00    	je     f0100a53 <monitor+0x14d>
f010099f:	83 ec 08             	sub    $0x8,%esp
f01009a2:	8d 83 04 fd fe ff    	lea    -0x102fc(%ebx),%eax
f01009a8:	50                   	push   %eax
f01009a9:	ff 75 a8             	pushl  -0x58(%ebp)
f01009ac:	e8 9a 0e 00 00       	call   f010184b <strcmp>
f01009b1:	83 c4 10             	add    $0x10,%esp
f01009b4:	85 c0                	test   %eax,%eax
f01009b6:	0f 84 92 00 00 00    	je     f0100a4e <monitor+0x148>
	cprintf("Unknown command '%s'\n", argv[0]);
f01009bc:	83 ec 08             	sub    $0x8,%esp
f01009bf:	ff 75 a8             	pushl  -0x58(%ebp)
f01009c2:	8d 83 73 fd fe ff    	lea    -0x1028d(%ebx),%eax
f01009c8:	50                   	push   %eax
f01009c9:	e8 c6 02 00 00       	call   f0100c94 <cprintf>
	return 0;
f01009ce:	83 c4 10             	add    $0x10,%esp
f01009d1:	eb 52                	jmp    f0100a25 <monitor+0x11f>
		if (*buf == 0)
f01009d3:	80 3e 00             	cmpb   $0x0,(%esi)
f01009d6:	74 9a                	je     f0100972 <monitor+0x6c>
		if (argc == MAXARGS-1) {
f01009d8:	83 ff 0f             	cmp    $0xf,%edi
f01009db:	74 34                	je     f0100a11 <monitor+0x10b>
		argv[argc++] = buf;
f01009dd:	8d 47 01             	lea    0x1(%edi),%eax
f01009e0:	89 45 a4             	mov    %eax,-0x5c(%ebp)
f01009e3:	89 74 bd a8          	mov    %esi,-0x58(%ebp,%edi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f01009e7:	0f b6 06             	movzbl (%esi),%eax
f01009ea:	84 c0                	test   %al,%al
f01009ec:	0f 84 76 ff ff ff    	je     f0100968 <monitor+0x62>
f01009f2:	83 ec 08             	sub    $0x8,%esp
f01009f5:	0f be c0             	movsbl %al,%eax
f01009f8:	50                   	push   %eax
f01009f9:	ff 75 a0             	pushl  -0x60(%ebp)
f01009fc:	e8 b0 0e 00 00       	call   f01018b1 <strchr>
f0100a01:	83 c4 10             	add    $0x10,%esp
f0100a04:	85 c0                	test   %eax,%eax
f0100a06:	0f 85 5c ff ff ff    	jne    f0100968 <monitor+0x62>
			buf++;
f0100a0c:	83 c6 01             	add    $0x1,%esi
f0100a0f:	eb d6                	jmp    f01009e7 <monitor+0xe1>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f0100a11:	83 ec 08             	sub    $0x8,%esp
f0100a14:	6a 10                	push   $0x10
f0100a16:	8d 83 56 fd fe ff    	lea    -0x102aa(%ebx),%eax
f0100a1c:	50                   	push   %eax
f0100a1d:	e8 72 02 00 00       	call   f0100c94 <cprintf>
			return 0;
f0100a22:	83 c4 10             	add    $0x10,%esp


	while (1) {
		buf = readline("K> ");
f0100a25:	8d bb 4d fd fe ff    	lea    -0x102b3(%ebx),%edi
f0100a2b:	83 ec 0c             	sub    $0xc,%esp
f0100a2e:	57                   	push   %edi
f0100a2f:	e8 0c 0c 00 00       	call   f0101640 <readline>
f0100a34:	89 c6                	mov    %eax,%esi
		if (buf != NULL)
f0100a36:	83 c4 10             	add    $0x10,%esp
f0100a39:	85 c0                	test   %eax,%eax
f0100a3b:	74 ee                	je     f0100a2b <monitor+0x125>
	argv[argc] = 0;
f0100a3d:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	argc = 0;
f0100a44:	bf 00 00 00 00       	mov    $0x0,%edi
f0100a49:	e9 1d ff ff ff       	jmp    f010096b <monitor+0x65>
	for (i = 0; i < ARRAY_SIZE(commands); i++) {
f0100a4e:	b8 01 00 00 00       	mov    $0x1,%eax
			return commands[i].func(argc, argv, tf);
f0100a53:	83 ec 04             	sub    $0x4,%esp
f0100a56:	8d 04 40             	lea    (%eax,%eax,2),%eax
f0100a59:	ff 75 08             	pushl  0x8(%ebp)
f0100a5c:	8d 55 a8             	lea    -0x58(%ebp),%edx
f0100a5f:	52                   	push   %edx
f0100a60:	57                   	push   %edi
f0100a61:	ff 94 83 10 1d 00 00 	call   *0x1d10(%ebx,%eax,4)
			if (runcmd(buf, tf) < 0)
f0100a68:	83 c4 10             	add    $0x10,%esp
f0100a6b:	85 c0                	test   %eax,%eax
f0100a6d:	79 b6                	jns    f0100a25 <monitor+0x11f>
				break;
	}
}
f0100a6f:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0100a72:	5b                   	pop    %ebx
f0100a73:	5e                   	pop    %esi
f0100a74:	5f                   	pop    %edi
f0100a75:	5d                   	pop    %ebp
f0100a76:	c3                   	ret    

f0100a77 <nvram_read>:
// Detect machine's physical memory setup.
// --------------------------------------------------------------

static int
nvram_read(int r)
{
f0100a77:	55                   	push   %ebp
f0100a78:	89 e5                	mov    %esp,%ebp
f0100a7a:	57                   	push   %edi
f0100a7b:	56                   	push   %esi
f0100a7c:	53                   	push   %ebx
f0100a7d:	83 ec 18             	sub    $0x18,%esp
f0100a80:	e8 e7 f6 ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f0100a85:	81 c3 83 18 01 00    	add    $0x11883,%ebx
f0100a8b:	89 c6                	mov    %eax,%esi
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0100a8d:	50                   	push   %eax
f0100a8e:	e8 6a 01 00 00       	call   f0100bfd <mc146818_read>
f0100a93:	89 c7                	mov    %eax,%edi
f0100a95:	83 c6 01             	add    $0x1,%esi
f0100a98:	89 34 24             	mov    %esi,(%esp)
f0100a9b:	e8 5d 01 00 00       	call   f0100bfd <mc146818_read>
f0100aa0:	c1 e0 08             	shl    $0x8,%eax
f0100aa3:	09 f8                	or     %edi,%eax
}
f0100aa5:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0100aa8:	5b                   	pop    %ebx
f0100aa9:	5e                   	pop    %esi
f0100aaa:	5f                   	pop    %edi
f0100aab:	5d                   	pop    %ebp
f0100aac:	c3                   	ret    

f0100aad <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f0100aad:	f3 0f 1e fb          	endbr32 
f0100ab1:	55                   	push   %ebp
f0100ab2:	89 e5                	mov    %esp,%ebp
f0100ab4:	57                   	push   %edi
f0100ab5:	56                   	push   %esi
f0100ab6:	53                   	push   %ebx
f0100ab7:	83 ec 0c             	sub    $0xc,%esp
f0100aba:	e8 ad f6 ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f0100abf:	81 c3 49 18 01 00    	add    $0x11849,%ebx
	basemem = nvram_read(NVRAM_BASELO);
f0100ac5:	b8 15 00 00 00       	mov    $0x15,%eax
f0100aca:	e8 a8 ff ff ff       	call   f0100a77 <nvram_read>
f0100acf:	89 c6                	mov    %eax,%esi
	extmem = nvram_read(NVRAM_EXTLO);
f0100ad1:	b8 17 00 00 00       	mov    $0x17,%eax
f0100ad6:	e8 9c ff ff ff       	call   f0100a77 <nvram_read>
f0100adb:	89 c7                	mov    %eax,%edi
	ext16mem = nvram_read(NVRAM_EXT16LO) * 64;
f0100add:	b8 34 00 00 00       	mov    $0x34,%eax
f0100ae2:	e8 90 ff ff ff       	call   f0100a77 <nvram_read>
	if (ext16mem)
f0100ae7:	c1 e0 06             	shl    $0x6,%eax
f0100aea:	74 40                	je     f0100b2c <mem_init+0x7f>
		totalmem = 16 * 1024 + ext16mem;
f0100aec:	05 00 40 00 00       	add    $0x4000,%eax
	npages = totalmem / (PGSIZE / 1024);
f0100af1:	89 c1                	mov    %eax,%ecx
f0100af3:	c1 e9 02             	shr    $0x2,%ecx
f0100af6:	c7 c2 a8 46 11 f0    	mov    $0xf01146a8,%edx
f0100afc:	89 0a                	mov    %ecx,(%edx)
	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0100afe:	89 c2                	mov    %eax,%edx
f0100b00:	29 f2                	sub    %esi,%edx
f0100b02:	52                   	push   %edx
f0100b03:	56                   	push   %esi
f0100b04:	50                   	push   %eax
f0100b05:	8d 83 14 ff fe ff    	lea    -0x100ec(%ebx),%eax
f0100b0b:	50                   	push   %eax
f0100b0c:	e8 83 01 00 00       	call   f0100c94 <cprintf>

	// Find out how much memory the machine has (npages & npages_basemem).
	i386_detect_memory();

	// Remove this line when you're ready to test this function.
	panic("mem_init: This function is not finished\n");
f0100b11:	83 c4 0c             	add    $0xc,%esp
f0100b14:	8d 83 50 ff fe ff    	lea    -0x100b0(%ebx),%eax
f0100b1a:	50                   	push   %eax
f0100b1b:	68 80 00 00 00       	push   $0x80
f0100b20:	8d 83 79 ff fe ff    	lea    -0x10087(%ebx),%eax
f0100b26:	50                   	push   %eax
f0100b27:	e8 82 f5 ff ff       	call   f01000ae <_panic>
		totalmem = basemem;
f0100b2c:	89 f0                	mov    %esi,%eax
	else if (extmem)
f0100b2e:	85 ff                	test   %edi,%edi
f0100b30:	74 bf                	je     f0100af1 <mem_init+0x44>
		totalmem = 1 * 1024 + extmem;
f0100b32:	8d 87 00 04 00 00    	lea    0x400(%edi),%eax
f0100b38:	eb b7                	jmp    f0100af1 <mem_init+0x44>

f0100b3a <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100b3a:	f3 0f 1e fb          	endbr32 
f0100b3e:	55                   	push   %ebp
f0100b3f:	89 e5                	mov    %esp,%ebp
f0100b41:	57                   	push   %edi
f0100b42:	56                   	push   %esi
f0100b43:	53                   	push   %ebx
f0100b44:	83 ec 04             	sub    $0x4,%esp
f0100b47:	e8 d8 fb ff ff       	call   f0100724 <__x86.get_pc_thunk.si>
f0100b4c:	81 c6 bc 17 01 00    	add    $0x117bc,%esi
f0100b52:	89 75 f0             	mov    %esi,-0x10(%ebp)
f0100b55:	8b 9e 90 1f 00 00    	mov    0x1f90(%esi),%ebx
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100b5b:	ba 00 00 00 00       	mov    $0x0,%edx
f0100b60:	b8 00 00 00 00       	mov    $0x0,%eax
f0100b65:	c7 c7 a8 46 11 f0    	mov    $0xf01146a8,%edi
		pages[i].pp_ref = 0;
f0100b6b:	c7 c6 b0 46 11 f0    	mov    $0xf01146b0,%esi
	for (i = 0; i < npages; i++) {
f0100b71:	39 07                	cmp    %eax,(%edi)
f0100b73:	76 21                	jbe    f0100b96 <page_init+0x5c>
f0100b75:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
		pages[i].pp_ref = 0;
f0100b7c:	89 d1                	mov    %edx,%ecx
f0100b7e:	03 0e                	add    (%esi),%ecx
f0100b80:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0100b86:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0100b88:	89 d3                	mov    %edx,%ebx
f0100b8a:	03 1e                	add    (%esi),%ebx
	for (i = 0; i < npages; i++) {
f0100b8c:	83 c0 01             	add    $0x1,%eax
f0100b8f:	ba 01 00 00 00       	mov    $0x1,%edx
f0100b94:	eb db                	jmp    f0100b71 <page_init+0x37>
f0100b96:	84 d2                	test   %dl,%dl
f0100b98:	74 09                	je     f0100ba3 <page_init+0x69>
f0100b9a:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0100b9d:	89 98 90 1f 00 00    	mov    %ebx,0x1f90(%eax)
	}
}
f0100ba3:	83 c4 04             	add    $0x4,%esp
f0100ba6:	5b                   	pop    %ebx
f0100ba7:	5e                   	pop    %esi
f0100ba8:	5f                   	pop    %edi
f0100ba9:	5d                   	pop    %ebp
f0100baa:	c3                   	ret    

f0100bab <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct PageInfo *
page_alloc(int alloc_flags)
{
f0100bab:	f3 0f 1e fb          	endbr32 
	// Fill this function in
	return 0;
}
f0100baf:	b8 00 00 00 00       	mov    $0x0,%eax
f0100bb4:	c3                   	ret    

f0100bb5 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct PageInfo *pp)
{
f0100bb5:	f3 0f 1e fb          	endbr32 
	// Fill this function in
	// Hint: You may want to panic if pp->pp_ref is nonzero or
	// pp->pp_link is not NULL.
}
f0100bb9:	c3                   	ret    

f0100bba <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct PageInfo* pp)
{
f0100bba:	f3 0f 1e fb          	endbr32 
f0100bbe:	55                   	push   %ebp
f0100bbf:	89 e5                	mov    %esp,%ebp
f0100bc1:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f0100bc4:	66 83 68 04 01       	subw   $0x1,0x4(%eax)
		page_free(pp);
}
f0100bc9:	5d                   	pop    %ebp
f0100bca:	c3                   	ret    

f0100bcb <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that manipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f0100bcb:	f3 0f 1e fb          	endbr32 
	// Fill this function in
	return NULL;
}
f0100bcf:	b8 00 00 00 00       	mov    $0x0,%eax
f0100bd4:	c3                   	ret    

f0100bd5 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct PageInfo *pp, void *va, int perm)
{
f0100bd5:	f3 0f 1e fb          	endbr32 
	// Fill this function in
	return 0;
}
f0100bd9:	b8 00 00 00 00       	mov    $0x0,%eax
f0100bde:	c3                   	ret    

f0100bdf <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct PageInfo *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0100bdf:	f3 0f 1e fb          	endbr32 
	// Fill this function in
	return NULL;
}
f0100be3:	b8 00 00 00 00       	mov    $0x0,%eax
f0100be8:	c3                   	ret    

f0100be9 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f0100be9:	f3 0f 1e fb          	endbr32 
	// Fill this function in
}
f0100bed:	c3                   	ret    

f0100bee <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f0100bee:	f3 0f 1e fb          	endbr32 
f0100bf2:	55                   	push   %ebp
f0100bf3:	89 e5                	mov    %esp,%ebp
	asm volatile("invlpg (%0)" : : "r" (addr) : "memory");
f0100bf5:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100bf8:	0f 01 38             	invlpg (%eax)
	// Flush the entry only if we're modifying the current address space.
	// For now, there is only one address space, so always invalidate.
	invlpg(va);
}
f0100bfb:	5d                   	pop    %ebp
f0100bfc:	c3                   	ret    

f0100bfd <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0100bfd:	f3 0f 1e fb          	endbr32 
f0100c01:	55                   	push   %ebp
f0100c02:	89 e5                	mov    %esp,%ebp
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100c04:	8b 45 08             	mov    0x8(%ebp),%eax
f0100c07:	ba 70 00 00 00       	mov    $0x70,%edx
f0100c0c:	ee                   	out    %al,(%dx)
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100c0d:	ba 71 00 00 00       	mov    $0x71,%edx
f0100c12:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0100c13:	0f b6 c0             	movzbl %al,%eax
}
f0100c16:	5d                   	pop    %ebp
f0100c17:	c3                   	ret    

f0100c18 <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0100c18:	f3 0f 1e fb          	endbr32 
f0100c1c:	55                   	push   %ebp
f0100c1d:	89 e5                	mov    %esp,%ebp
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100c1f:	8b 45 08             	mov    0x8(%ebp),%eax
f0100c22:	ba 70 00 00 00       	mov    $0x70,%edx
f0100c27:	ee                   	out    %al,(%dx)
f0100c28:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100c2b:	ba 71 00 00 00       	mov    $0x71,%edx
f0100c30:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0100c31:	5d                   	pop    %ebp
f0100c32:	c3                   	ret    

f0100c33 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0100c33:	f3 0f 1e fb          	endbr32 
f0100c37:	55                   	push   %ebp
f0100c38:	89 e5                	mov    %esp,%ebp
f0100c3a:	53                   	push   %ebx
f0100c3b:	83 ec 10             	sub    $0x10,%esp
f0100c3e:	e8 29 f5 ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f0100c43:	81 c3 c5 16 01 00    	add    $0x116c5,%ebx
	cputchar(ch);
f0100c49:	ff 75 08             	pushl  0x8(%ebp)
f0100c4c:	e8 9c fa ff ff       	call   f01006ed <cputchar>
	*cnt++;
}
f0100c51:	83 c4 10             	add    $0x10,%esp
f0100c54:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f0100c57:	c9                   	leave  
f0100c58:	c3                   	ret    

f0100c59 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0100c59:	f3 0f 1e fb          	endbr32 
f0100c5d:	55                   	push   %ebp
f0100c5e:	89 e5                	mov    %esp,%ebp
f0100c60:	53                   	push   %ebx
f0100c61:	83 ec 14             	sub    $0x14,%esp
f0100c64:	e8 03 f5 ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f0100c69:	81 c3 9f 16 01 00    	add    $0x1169f,%ebx
	int cnt = 0;
f0100c6f:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0100c76:	ff 75 0c             	pushl  0xc(%ebp)
f0100c79:	ff 75 08             	pushl  0x8(%ebp)
f0100c7c:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0100c7f:	50                   	push   %eax
f0100c80:	8d 83 2b e9 fe ff    	lea    -0x116d5(%ebx),%eax
f0100c86:	50                   	push   %eax
f0100c87:	e8 7a 04 00 00       	call   f0101106 <vprintfmt>
	return cnt;
}
f0100c8c:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0100c8f:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f0100c92:	c9                   	leave  
f0100c93:	c3                   	ret    

f0100c94 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0100c94:	f3 0f 1e fb          	endbr32 
f0100c98:	55                   	push   %ebp
f0100c99:	89 e5                	mov    %esp,%ebp
f0100c9b:	83 ec 10             	sub    $0x10,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0100c9e:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0100ca1:	50                   	push   %eax
f0100ca2:	ff 75 08             	pushl  0x8(%ebp)
f0100ca5:	e8 af ff ff ff       	call   f0100c59 <vcprintf>
	va_end(ap);
	
	return cnt;
}
f0100caa:	c9                   	leave  
f0100cab:	c3                   	ret    

f0100cac <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0100cac:	55                   	push   %ebp
f0100cad:	89 e5                	mov    %esp,%ebp
f0100caf:	57                   	push   %edi
f0100cb0:	56                   	push   %esi
f0100cb1:	53                   	push   %ebx
f0100cb2:	83 ec 14             	sub    $0x14,%esp
f0100cb5:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0100cb8:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f0100cbb:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0100cbe:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0100cc1:	8b 1a                	mov    (%edx),%ebx
f0100cc3:	8b 01                	mov    (%ecx),%eax
f0100cc5:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0100cc8:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)

	while (l <= r) {
f0100ccf:	eb 23                	jmp    f0100cf4 <stab_binsearch+0x48>

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0100cd1:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0100cd4:	eb 1e                	jmp    f0100cf4 <stab_binsearch+0x48>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0100cd6:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0100cd9:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0100cdc:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0100ce0:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0100ce3:	73 46                	jae    f0100d2b <stab_binsearch+0x7f>
			*region_left = m;
f0100ce5:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0100ce8:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0100cea:	8d 5f 01             	lea    0x1(%edi),%ebx
		any_matches = 1;
f0100ced:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
	while (l <= r) {
f0100cf4:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0100cf7:	7f 5f                	jg     f0100d58 <stab_binsearch+0xac>
		int true_m = (l + r) / 2, m = true_m;
f0100cf9:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0100cfc:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f0100cff:	89 d0                	mov    %edx,%eax
f0100d01:	c1 e8 1f             	shr    $0x1f,%eax
f0100d04:	01 d0                	add    %edx,%eax
f0100d06:	89 c7                	mov    %eax,%edi
f0100d08:	d1 ff                	sar    %edi
f0100d0a:	83 e0 fe             	and    $0xfffffffe,%eax
f0100d0d:	01 f8                	add    %edi,%eax
f0100d0f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0100d12:	8d 54 81 04          	lea    0x4(%ecx,%eax,4),%edx
f0100d16:	89 f8                	mov    %edi,%eax
		while (m >= l && stabs[m].n_type != type)
f0100d18:	39 c3                	cmp    %eax,%ebx
f0100d1a:	7f b5                	jg     f0100cd1 <stab_binsearch+0x25>
f0100d1c:	0f b6 0a             	movzbl (%edx),%ecx
f0100d1f:	83 ea 0c             	sub    $0xc,%edx
f0100d22:	39 f1                	cmp    %esi,%ecx
f0100d24:	74 b0                	je     f0100cd6 <stab_binsearch+0x2a>
			m--;
f0100d26:	83 e8 01             	sub    $0x1,%eax
f0100d29:	eb ed                	jmp    f0100d18 <stab_binsearch+0x6c>
		} else if (stabs[m].n_value > addr) {
f0100d2b:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0100d2e:	76 14                	jbe    f0100d44 <stab_binsearch+0x98>
			*region_right = m - 1;
f0100d30:	83 e8 01             	sub    $0x1,%eax
f0100d33:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0100d36:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0100d39:	89 07                	mov    %eax,(%edi)
		any_matches = 1;
f0100d3b:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0100d42:	eb b0                	jmp    f0100cf4 <stab_binsearch+0x48>
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0100d44:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100d47:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f0100d49:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f0100d4d:	89 c3                	mov    %eax,%ebx
		any_matches = 1;
f0100d4f:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0100d56:	eb 9c                	jmp    f0100cf4 <stab_binsearch+0x48>
		}
	}

	if (!any_matches)
f0100d58:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f0100d5c:	75 15                	jne    f0100d73 <stab_binsearch+0xc7>
		*region_right = *region_left - 1;
f0100d5e:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100d61:	8b 00                	mov    (%eax),%eax
f0100d63:	83 e8 01             	sub    $0x1,%eax
f0100d66:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0100d69:	89 07                	mov    %eax,(%edi)
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0100d6b:	83 c4 14             	add    $0x14,%esp
f0100d6e:	5b                   	pop    %ebx
f0100d6f:	5e                   	pop    %esi
f0100d70:	5f                   	pop    %edi
f0100d71:	5d                   	pop    %ebp
f0100d72:	c3                   	ret    
		for (l = *region_right;
f0100d73:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100d76:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0100d78:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100d7b:	8b 0f                	mov    (%edi),%ecx
f0100d7d:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0100d80:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0100d83:	8d 54 97 04          	lea    0x4(%edi,%edx,4),%edx
		for (l = *region_right;
f0100d87:	eb 03                	jmp    f0100d8c <stab_binsearch+0xe0>
		     l--)
f0100d89:	83 e8 01             	sub    $0x1,%eax
		for (l = *region_right;
f0100d8c:	39 c1                	cmp    %eax,%ecx
f0100d8e:	7d 0a                	jge    f0100d9a <stab_binsearch+0xee>
		     l > *region_left && stabs[l].n_type != type;
f0100d90:	0f b6 1a             	movzbl (%edx),%ebx
f0100d93:	83 ea 0c             	sub    $0xc,%edx
f0100d96:	39 f3                	cmp    %esi,%ebx
f0100d98:	75 ef                	jne    f0100d89 <stab_binsearch+0xdd>
		*region_left = l;
f0100d9a:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100d9d:	89 07                	mov    %eax,(%edi)
}
f0100d9f:	eb ca                	jmp    f0100d6b <stab_binsearch+0xbf>

f0100da1 <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0100da1:	f3 0f 1e fb          	endbr32 
f0100da5:	55                   	push   %ebp
f0100da6:	89 e5                	mov    %esp,%ebp
f0100da8:	57                   	push   %edi
f0100da9:	56                   	push   %esi
f0100daa:	53                   	push   %ebx
f0100dab:	83 ec 3c             	sub    $0x3c,%esp
f0100dae:	e8 b9 f3 ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f0100db3:	81 c3 55 15 01 00    	add    $0x11555,%ebx
f0100db9:	89 5d c4             	mov    %ebx,-0x3c(%ebp)
f0100dbc:	8b 7d 08             	mov    0x8(%ebp),%edi
f0100dbf:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0100dc2:	8d 83 85 ff fe ff    	lea    -0x1007b(%ebx),%eax
f0100dc8:	89 06                	mov    %eax,(%esi)
	info->eip_line = 0;
f0100dca:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0100dd1:	89 46 08             	mov    %eax,0x8(%esi)
	info->eip_fn_namelen = 9;
f0100dd4:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0100ddb:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0100dde:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0100de5:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0100deb:	0f 86 38 01 00 00    	jbe    f0100f29 <debuginfo_eip+0x188>
		// Can't search for user-level addresses yet!
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100df1:	c7 c0 b9 71 10 f0    	mov    $0xf01071b9,%eax
f0100df7:	39 83 fc ff ff ff    	cmp    %eax,-0x4(%ebx)
f0100dfd:	0f 86 da 01 00 00    	jbe    f0100fdd <debuginfo_eip+0x23c>
f0100e03:	8b 5d c4             	mov    -0x3c(%ebp),%ebx
f0100e06:	c7 c0 4d 8e 10 f0    	mov    $0xf0108e4d,%eax
f0100e0c:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0100e10:	0f 85 ce 01 00 00    	jne    f0100fe4 <debuginfo_eip+0x243>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.

	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0100e16:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0100e1d:	c7 c0 a8 24 10 f0    	mov    $0xf01024a8,%eax
f0100e23:	c7 c2 b8 71 10 f0    	mov    $0xf01071b8,%edx
f0100e29:	29 c2                	sub    %eax,%edx
f0100e2b:	c1 fa 02             	sar    $0x2,%edx
f0100e2e:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f0100e34:	83 ea 01             	sub    $0x1,%edx
f0100e37:	89 55 e0             	mov    %edx,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0100e3a:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0100e3d:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0100e40:	83 ec 08             	sub    $0x8,%esp
f0100e43:	57                   	push   %edi
f0100e44:	6a 64                	push   $0x64
f0100e46:	e8 61 fe ff ff       	call   f0100cac <stab_binsearch>
	if (lfile == 0)
f0100e4b:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100e4e:	83 c4 10             	add    $0x10,%esp
f0100e51:	85 c0                	test   %eax,%eax
f0100e53:	0f 84 92 01 00 00    	je     f0100feb <debuginfo_eip+0x24a>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0100e59:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0100e5c:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100e5f:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0100e62:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0100e65:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100e68:	83 ec 08             	sub    $0x8,%esp
f0100e6b:	57                   	push   %edi
f0100e6c:	6a 24                	push   $0x24
f0100e6e:	c7 c0 a8 24 10 f0    	mov    $0xf01024a8,%eax
f0100e74:	e8 33 fe ff ff       	call   f0100cac <stab_binsearch>

	if (lfun <= rfun) {
f0100e79:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0100e7c:	8b 4d d8             	mov    -0x28(%ebp),%ecx
f0100e7f:	89 4d c0             	mov    %ecx,-0x40(%ebp)
f0100e82:	83 c4 10             	add    $0x10,%esp
f0100e85:	39 c8                	cmp    %ecx,%eax
f0100e87:	0f 8f b7 00 00 00    	jg     f0100f44 <debuginfo_eip+0x1a3>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0100e8d:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0100e90:	c7 c1 a8 24 10 f0    	mov    $0xf01024a8,%ecx
f0100e96:	8d 0c 91             	lea    (%ecx,%edx,4),%ecx
f0100e99:	8b 11                	mov    (%ecx),%edx
f0100e9b:	89 55 bc             	mov    %edx,-0x44(%ebp)
f0100e9e:	c7 c2 4d 8e 10 f0    	mov    $0xf0108e4d,%edx
f0100ea4:	89 5d c4             	mov    %ebx,-0x3c(%ebp)
f0100ea7:	81 ea b9 71 10 f0    	sub    $0xf01071b9,%edx
f0100ead:	8b 5d bc             	mov    -0x44(%ebp),%ebx
f0100eb0:	39 d3                	cmp    %edx,%ebx
f0100eb2:	73 0c                	jae    f0100ec0 <debuginfo_eip+0x11f>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0100eb4:	8b 55 c4             	mov    -0x3c(%ebp),%edx
f0100eb7:	81 c3 b9 71 10 f0    	add    $0xf01071b9,%ebx
f0100ebd:	89 5e 08             	mov    %ebx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0100ec0:	8b 51 08             	mov    0x8(%ecx),%edx
f0100ec3:	89 56 10             	mov    %edx,0x10(%esi)
		addr -= info->eip_fn_addr;
f0100ec6:	29 d7                	sub    %edx,%edi
		// Search within the function definition for the line number.
		lline = lfun;
f0100ec8:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		rline = rfun;
f0100ecb:	8b 45 c0             	mov    -0x40(%ebp),%eax
f0100ece:	89 45 d0             	mov    %eax,-0x30(%ebp)
		info->eip_fn_addr = addr;
		lline = lfile;
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0100ed1:	83 ec 08             	sub    $0x8,%esp
f0100ed4:	6a 3a                	push   $0x3a
f0100ed6:	ff 76 08             	pushl  0x8(%esi)
f0100ed9:	8b 5d c4             	mov    -0x3c(%ebp),%ebx
f0100edc:	e8 f5 09 00 00       	call   f01018d6 <strfind>
f0100ee1:	2b 46 08             	sub    0x8(%esi),%eax
f0100ee4:	89 46 0c             	mov    %eax,0xc(%esi)
	// Hint:
	//	There's a particular stabs type used for line numbers.
	//	Look at the STABS documentation and <inc/stab.h> to find
	//	which one.
	// Your code here.
	stab_binsearch(stabs, &lline, &rline, N_SLINE, addr);
f0100ee7:	8d 4d d0             	lea    -0x30(%ebp),%ecx
f0100eea:	8d 55 d4             	lea    -0x2c(%ebp),%edx
f0100eed:	83 c4 08             	add    $0x8,%esp
f0100ef0:	57                   	push   %edi
f0100ef1:	6a 44                	push   $0x44
f0100ef3:	c7 c0 a8 24 10 f0    	mov    $0xf01024a8,%eax
f0100ef9:	e8 ae fd ff ff       	call   f0100cac <stab_binsearch>
		if (lline <= rline) {
f0100efe:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100f01:	83 c4 10             	add    $0x10,%esp
f0100f04:	3b 45 d0             	cmp    -0x30(%ebp),%eax
f0100f07:	0f 8f e5 00 00 00    	jg     f0100ff2 <debuginfo_eip+0x251>
		    info->eip_line = stabs[lline].n_desc;
f0100f0d:	89 c2                	mov    %eax,%edx
f0100f0f:	8d 0c 40             	lea    (%eax,%eax,2),%ecx
f0100f12:	c7 c0 a8 24 10 f0    	mov    $0xf01024a8,%eax
f0100f18:	0f b7 5c 88 06       	movzwl 0x6(%eax,%ecx,4),%ebx
f0100f1d:	89 5e 04             	mov    %ebx,0x4(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100f20:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100f23:	8d 44 88 04          	lea    0x4(%eax,%ecx,4),%eax
f0100f27:	eb 35                	jmp    f0100f5e <debuginfo_eip+0x1bd>
  	        panic("User address");
f0100f29:	83 ec 04             	sub    $0x4,%esp
f0100f2c:	8b 5d c4             	mov    -0x3c(%ebp),%ebx
f0100f2f:	8d 83 8f ff fe ff    	lea    -0x10071(%ebx),%eax
f0100f35:	50                   	push   %eax
f0100f36:	6a 7f                	push   $0x7f
f0100f38:	8d 83 9c ff fe ff    	lea    -0x10064(%ebx),%eax
f0100f3e:	50                   	push   %eax
f0100f3f:	e8 6a f1 ff ff       	call   f01000ae <_panic>
		info->eip_fn_addr = addr;
f0100f44:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0100f47:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100f4a:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		rline = rfile;
f0100f4d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100f50:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0100f53:	e9 79 ff ff ff       	jmp    f0100ed1 <debuginfo_eip+0x130>
f0100f58:	83 ea 01             	sub    $0x1,%edx
f0100f5b:	83 e8 0c             	sub    $0xc,%eax
	while (lline >= lfile
f0100f5e:	39 d7                	cmp    %edx,%edi
f0100f60:	7f 3a                	jg     f0100f9c <debuginfo_eip+0x1fb>
	       && stabs[lline].n_type != N_SOL
f0100f62:	0f b6 08             	movzbl (%eax),%ecx
f0100f65:	80 f9 84             	cmp    $0x84,%cl
f0100f68:	74 0b                	je     f0100f75 <debuginfo_eip+0x1d4>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0100f6a:	80 f9 64             	cmp    $0x64,%cl
f0100f6d:	75 e9                	jne    f0100f58 <debuginfo_eip+0x1b7>
f0100f6f:	83 78 04 00          	cmpl   $0x0,0x4(%eax)
f0100f73:	74 e3                	je     f0100f58 <debuginfo_eip+0x1b7>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0100f75:	8d 14 52             	lea    (%edx,%edx,2),%edx
f0100f78:	8b 7d c4             	mov    -0x3c(%ebp),%edi
f0100f7b:	c7 c0 a8 24 10 f0    	mov    $0xf01024a8,%eax
f0100f81:	8b 14 90             	mov    (%eax,%edx,4),%edx
f0100f84:	c7 c0 4d 8e 10 f0    	mov    $0xf0108e4d,%eax
f0100f8a:	81 e8 b9 71 10 f0    	sub    $0xf01071b9,%eax
f0100f90:	39 c2                	cmp    %eax,%edx
f0100f92:	73 08                	jae    f0100f9c <debuginfo_eip+0x1fb>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0100f94:	81 c2 b9 71 10 f0    	add    $0xf01071b9,%edx
f0100f9a:	89 16                	mov    %edx,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100f9c:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100f9f:	8b 5d d8             	mov    -0x28(%ebp),%ebx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100fa2:	b8 00 00 00 00       	mov    $0x0,%eax
	if (lfun < rfun)
f0100fa7:	39 da                	cmp    %ebx,%edx
f0100fa9:	7d 53                	jge    f0100ffe <debuginfo_eip+0x25d>
		for (lline = lfun + 1;
f0100fab:	8d 42 01             	lea    0x1(%edx),%eax
f0100fae:	8d 0c 40             	lea    (%eax,%eax,2),%ecx
f0100fb1:	8b 7d c4             	mov    -0x3c(%ebp),%edi
f0100fb4:	c7 c2 a8 24 10 f0    	mov    $0xf01024a8,%edx
f0100fba:	8d 54 8a 04          	lea    0x4(%edx,%ecx,4),%edx
f0100fbe:	eb 04                	jmp    f0100fc4 <debuginfo_eip+0x223>
			info->eip_fn_narg++;
f0100fc0:	83 46 14 01          	addl   $0x1,0x14(%esi)
		for (lline = lfun + 1;
f0100fc4:	39 c3                	cmp    %eax,%ebx
f0100fc6:	7e 31                	jle    f0100ff9 <debuginfo_eip+0x258>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0100fc8:	0f b6 0a             	movzbl (%edx),%ecx
f0100fcb:	83 c0 01             	add    $0x1,%eax
f0100fce:	83 c2 0c             	add    $0xc,%edx
f0100fd1:	80 f9 a0             	cmp    $0xa0,%cl
f0100fd4:	74 ea                	je     f0100fc0 <debuginfo_eip+0x21f>
	return 0;
f0100fd6:	b8 00 00 00 00       	mov    $0x0,%eax
f0100fdb:	eb 21                	jmp    f0100ffe <debuginfo_eip+0x25d>
		return -1;
f0100fdd:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100fe2:	eb 1a                	jmp    f0100ffe <debuginfo_eip+0x25d>
f0100fe4:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100fe9:	eb 13                	jmp    f0100ffe <debuginfo_eip+0x25d>
		return -1;
f0100feb:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100ff0:	eb 0c                	jmp    f0100ffe <debuginfo_eip+0x25d>
		    return -1;
f0100ff2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100ff7:	eb 05                	jmp    f0100ffe <debuginfo_eip+0x25d>
	return 0;
f0100ff9:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0100ffe:	8d 65 f4             	lea    -0xc(%ebp),%esp
f0101001:	5b                   	pop    %ebx
f0101002:	5e                   	pop    %esi
f0101003:	5f                   	pop    %edi
f0101004:	5d                   	pop    %ebp
f0101005:	c3                   	ret    

f0101006 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0101006:	55                   	push   %ebp
f0101007:	89 e5                	mov    %esp,%ebp
f0101009:	57                   	push   %edi
f010100a:	56                   	push   %esi
f010100b:	53                   	push   %ebx
f010100c:	83 ec 2c             	sub    $0x2c,%esp
f010100f:	e8 28 06 00 00       	call   f010163c <__x86.get_pc_thunk.cx>
f0101014:	81 c1 f4 12 01 00    	add    $0x112f4,%ecx
f010101a:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f010101d:	89 c7                	mov    %eax,%edi
f010101f:	89 d6                	mov    %edx,%esi
f0101021:	8b 45 08             	mov    0x8(%ebp),%eax
f0101024:	8b 55 0c             	mov    0xc(%ebp),%edx
f0101027:	89 d1                	mov    %edx,%ecx
f0101029:	89 c2                	mov    %eax,%edx
f010102b:	89 45 d0             	mov    %eax,-0x30(%ebp)
f010102e:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0101031:	8b 45 10             	mov    0x10(%ebp),%eax
f0101034:	8b 5d 14             	mov    0x14(%ebp),%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0101037:	89 45 e0             	mov    %eax,-0x20(%ebp)
f010103a:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
f0101041:	39 c2                	cmp    %eax,%edx
f0101043:	1b 4d e4             	sbb    -0x1c(%ebp),%ecx
f0101046:	72 41                	jb     f0101089 <printnum+0x83>
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0101048:	83 ec 0c             	sub    $0xc,%esp
f010104b:	ff 75 18             	pushl  0x18(%ebp)
f010104e:	83 eb 01             	sub    $0x1,%ebx
f0101051:	53                   	push   %ebx
f0101052:	50                   	push   %eax
f0101053:	83 ec 08             	sub    $0x8,%esp
f0101056:	ff 75 e4             	pushl  -0x1c(%ebp)
f0101059:	ff 75 e0             	pushl  -0x20(%ebp)
f010105c:	ff 75 d4             	pushl  -0x2c(%ebp)
f010105f:	ff 75 d0             	pushl  -0x30(%ebp)
f0101062:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0101065:	e8 96 0a 00 00       	call   f0101b00 <__udivdi3>
f010106a:	83 c4 18             	add    $0x18,%esp
f010106d:	52                   	push   %edx
f010106e:	50                   	push   %eax
f010106f:	89 f2                	mov    %esi,%edx
f0101071:	89 f8                	mov    %edi,%eax
f0101073:	e8 8e ff ff ff       	call   f0101006 <printnum>
f0101078:	83 c4 20             	add    $0x20,%esp
f010107b:	eb 13                	jmp    f0101090 <printnum+0x8a>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f010107d:	83 ec 08             	sub    $0x8,%esp
f0101080:	56                   	push   %esi
f0101081:	ff 75 18             	pushl  0x18(%ebp)
f0101084:	ff d7                	call   *%edi
f0101086:	83 c4 10             	add    $0x10,%esp
		while (--width > 0)
f0101089:	83 eb 01             	sub    $0x1,%ebx
f010108c:	85 db                	test   %ebx,%ebx
f010108e:	7f ed                	jg     f010107d <printnum+0x77>
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0101090:	83 ec 08             	sub    $0x8,%esp
f0101093:	56                   	push   %esi
f0101094:	83 ec 04             	sub    $0x4,%esp
f0101097:	ff 75 e4             	pushl  -0x1c(%ebp)
f010109a:	ff 75 e0             	pushl  -0x20(%ebp)
f010109d:	ff 75 d4             	pushl  -0x2c(%ebp)
f01010a0:	ff 75 d0             	pushl  -0x30(%ebp)
f01010a3:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f01010a6:	e8 65 0b 00 00       	call   f0101c10 <__umoddi3>
f01010ab:	83 c4 14             	add    $0x14,%esp
f01010ae:	0f be 84 03 aa ff fe 	movsbl -0x10056(%ebx,%eax,1),%eax
f01010b5:	ff 
f01010b6:	50                   	push   %eax
f01010b7:	ff d7                	call   *%edi
}
f01010b9:	83 c4 10             	add    $0x10,%esp
f01010bc:	8d 65 f4             	lea    -0xc(%ebp),%esp
f01010bf:	5b                   	pop    %ebx
f01010c0:	5e                   	pop    %esi
f01010c1:	5f                   	pop    %edi
f01010c2:	5d                   	pop    %ebp
f01010c3:	c3                   	ret    

f01010c4 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f01010c4:	f3 0f 1e fb          	endbr32 
f01010c8:	55                   	push   %ebp
f01010c9:	89 e5                	mov    %esp,%ebp
f01010cb:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f01010ce:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f01010d2:	8b 10                	mov    (%eax),%edx
f01010d4:	3b 50 04             	cmp    0x4(%eax),%edx
f01010d7:	73 0a                	jae    f01010e3 <sprintputch+0x1f>
		*b->buf++ = ch;
f01010d9:	8d 4a 01             	lea    0x1(%edx),%ecx
f01010dc:	89 08                	mov    %ecx,(%eax)
f01010de:	8b 45 08             	mov    0x8(%ebp),%eax
f01010e1:	88 02                	mov    %al,(%edx)
}
f01010e3:	5d                   	pop    %ebp
f01010e4:	c3                   	ret    

f01010e5 <printfmt>:
{
f01010e5:	f3 0f 1e fb          	endbr32 
f01010e9:	55                   	push   %ebp
f01010ea:	89 e5                	mov    %esp,%ebp
f01010ec:	83 ec 08             	sub    $0x8,%esp
	va_start(ap, fmt);
f01010ef:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f01010f2:	50                   	push   %eax
f01010f3:	ff 75 10             	pushl  0x10(%ebp)
f01010f6:	ff 75 0c             	pushl  0xc(%ebp)
f01010f9:	ff 75 08             	pushl  0x8(%ebp)
f01010fc:	e8 05 00 00 00       	call   f0101106 <vprintfmt>
}
f0101101:	83 c4 10             	add    $0x10,%esp
f0101104:	c9                   	leave  
f0101105:	c3                   	ret    

f0101106 <vprintfmt>:
{
f0101106:	f3 0f 1e fb          	endbr32 
f010110a:	55                   	push   %ebp
f010110b:	89 e5                	mov    %esp,%ebp
f010110d:	57                   	push   %edi
f010110e:	56                   	push   %esi
f010110f:	53                   	push   %ebx
f0101110:	83 ec 3c             	sub    $0x3c,%esp
f0101113:	e8 08 f6 ff ff       	call   f0100720 <__x86.get_pc_thunk.ax>
f0101118:	05 f0 11 01 00       	add    $0x111f0,%eax
f010111d:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0101120:	8b 75 08             	mov    0x8(%ebp),%esi
f0101123:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0101126:	8b 5d 10             	mov    0x10(%ebp),%ebx
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0101129:	8d 80 20 1d 00 00    	lea    0x1d20(%eax),%eax
f010112f:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0101132:	e9 cd 03 00 00       	jmp    f0101504 <.L25+0x48>
		padc = ' ';
f0101137:	c6 45 cf 20          	movb   $0x20,-0x31(%ebp)
		altflag = 0;
f010113b:	c7 45 d0 00 00 00 00 	movl   $0x0,-0x30(%ebp)
		precision = -1;
f0101142:	c7 45 d8 ff ff ff ff 	movl   $0xffffffff,-0x28(%ebp)
		width = -1;
f0101149:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		lflag = 0;
f0101150:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101155:	89 4d c8             	mov    %ecx,-0x38(%ebp)
f0101158:	89 75 08             	mov    %esi,0x8(%ebp)
		switch (ch = *(unsigned char *) fmt++) {
f010115b:	8d 43 01             	lea    0x1(%ebx),%eax
f010115e:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0101161:	0f b6 13             	movzbl (%ebx),%edx
f0101164:	8d 42 dd             	lea    -0x23(%edx),%eax
f0101167:	3c 55                	cmp    $0x55,%al
f0101169:	0f 87 21 04 00 00    	ja     f0101590 <.L20>
f010116f:	0f b6 c0             	movzbl %al,%eax
f0101172:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0101175:	89 ce                	mov    %ecx,%esi
f0101177:	03 b4 81 38 00 ff ff 	add    -0xffc8(%ecx,%eax,4),%esi
f010117e:	3e ff e6             	notrack jmp *%esi

f0101181 <.L68>:
f0101181:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			padc = '-';
f0101184:	c6 45 cf 2d          	movb   $0x2d,-0x31(%ebp)
f0101188:	eb d1                	jmp    f010115b <vprintfmt+0x55>

f010118a <.L32>:
		switch (ch = *(unsigned char *) fmt++) {
f010118a:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f010118d:	c6 45 cf 30          	movb   $0x30,-0x31(%ebp)
f0101191:	eb c8                	jmp    f010115b <vprintfmt+0x55>

f0101193 <.L31>:
f0101193:	0f b6 d2             	movzbl %dl,%edx
f0101196:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			for (precision = 0; ; ++fmt) {
f0101199:	b8 00 00 00 00       	mov    $0x0,%eax
f010119e:	8b 75 08             	mov    0x8(%ebp),%esi
				precision = precision * 10 + ch - '0';
f01011a1:	8d 04 80             	lea    (%eax,%eax,4),%eax
f01011a4:	8d 44 42 d0          	lea    -0x30(%edx,%eax,2),%eax
				ch = *fmt;
f01011a8:	0f be 13             	movsbl (%ebx),%edx
				if (ch < '0' || ch > '9')
f01011ab:	8d 4a d0             	lea    -0x30(%edx),%ecx
f01011ae:	83 f9 09             	cmp    $0x9,%ecx
f01011b1:	77 58                	ja     f010120b <.L36+0xf>
			for (precision = 0; ; ++fmt) {
f01011b3:	83 c3 01             	add    $0x1,%ebx
				precision = precision * 10 + ch - '0';
f01011b6:	eb e9                	jmp    f01011a1 <.L31+0xe>

f01011b8 <.L34>:
			precision = va_arg(ap, int);
f01011b8:	8b 45 14             	mov    0x14(%ebp),%eax
f01011bb:	8b 00                	mov    (%eax),%eax
f01011bd:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01011c0:	8b 45 14             	mov    0x14(%ebp),%eax
f01011c3:	8d 40 04             	lea    0x4(%eax),%eax
f01011c6:	89 45 14             	mov    %eax,0x14(%ebp)
		switch (ch = *(unsigned char *) fmt++) {
f01011c9:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			if (width < 0)
f01011cc:	83 7d d4 00          	cmpl   $0x0,-0x2c(%ebp)
f01011d0:	79 89                	jns    f010115b <vprintfmt+0x55>
				width = precision, precision = -1;
f01011d2:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01011d5:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01011d8:	c7 45 d8 ff ff ff ff 	movl   $0xffffffff,-0x28(%ebp)
f01011df:	e9 77 ff ff ff       	jmp    f010115b <vprintfmt+0x55>

f01011e4 <.L33>:
f01011e4:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01011e7:	85 c0                	test   %eax,%eax
f01011e9:	ba 00 00 00 00       	mov    $0x0,%edx
f01011ee:	0f 49 d0             	cmovns %eax,%edx
f01011f1:	89 55 d4             	mov    %edx,-0x2c(%ebp)
		switch (ch = *(unsigned char *) fmt++) {
f01011f4:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			goto reswitch;
f01011f7:	e9 5f ff ff ff       	jmp    f010115b <vprintfmt+0x55>

f01011fc <.L36>:
		switch (ch = *(unsigned char *) fmt++) {
f01011fc:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			altflag = 1;
f01011ff:	c7 45 d0 01 00 00 00 	movl   $0x1,-0x30(%ebp)
			goto reswitch;
f0101206:	e9 50 ff ff ff       	jmp    f010115b <vprintfmt+0x55>
f010120b:	89 45 d8             	mov    %eax,-0x28(%ebp)
f010120e:	89 75 08             	mov    %esi,0x8(%ebp)
f0101211:	eb b9                	jmp    f01011cc <.L34+0x14>

f0101213 <.L27>:
			lflag++;
f0101213:	83 45 c8 01          	addl   $0x1,-0x38(%ebp)
		switch (ch = *(unsigned char *) fmt++) {
f0101217:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			goto reswitch;
f010121a:	e9 3c ff ff ff       	jmp    f010115b <vprintfmt+0x55>

f010121f <.L30>:
f010121f:	8b 75 08             	mov    0x8(%ebp),%esi
			putch(va_arg(ap, int), putdat);
f0101222:	8b 45 14             	mov    0x14(%ebp),%eax
f0101225:	8d 58 04             	lea    0x4(%eax),%ebx
f0101228:	83 ec 08             	sub    $0x8,%esp
f010122b:	57                   	push   %edi
f010122c:	ff 30                	pushl  (%eax)
f010122e:	ff d6                	call   *%esi
			break;
f0101230:	83 c4 10             	add    $0x10,%esp
			putch(va_arg(ap, int), putdat);
f0101233:	89 5d 14             	mov    %ebx,0x14(%ebp)
			break;
f0101236:	e9 c6 02 00 00       	jmp    f0101501 <.L25+0x45>

f010123b <.L28>:
f010123b:	8b 75 08             	mov    0x8(%ebp),%esi
			err = va_arg(ap, int);
f010123e:	8b 45 14             	mov    0x14(%ebp),%eax
f0101241:	8d 58 04             	lea    0x4(%eax),%ebx
f0101244:	8b 00                	mov    (%eax),%eax
f0101246:	99                   	cltd   
f0101247:	31 d0                	xor    %edx,%eax
f0101249:	29 d0                	sub    %edx,%eax
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f010124b:	83 f8 06             	cmp    $0x6,%eax
f010124e:	7f 27                	jg     f0101277 <.L28+0x3c>
f0101250:	8b 55 c4             	mov    -0x3c(%ebp),%edx
f0101253:	8b 14 82             	mov    (%edx,%eax,4),%edx
f0101256:	85 d2                	test   %edx,%edx
f0101258:	74 1d                	je     f0101277 <.L28+0x3c>
				printfmt(putch, putdat, "%s", p);
f010125a:	52                   	push   %edx
f010125b:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010125e:	8d 80 cb ff fe ff    	lea    -0x10035(%eax),%eax
f0101264:	50                   	push   %eax
f0101265:	57                   	push   %edi
f0101266:	56                   	push   %esi
f0101267:	e8 79 fe ff ff       	call   f01010e5 <printfmt>
f010126c:	83 c4 10             	add    $0x10,%esp
			err = va_arg(ap, int);
f010126f:	89 5d 14             	mov    %ebx,0x14(%ebp)
f0101272:	e9 8a 02 00 00       	jmp    f0101501 <.L25+0x45>
				printfmt(putch, putdat, "error %d", err);
f0101277:	50                   	push   %eax
f0101278:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010127b:	8d 80 c2 ff fe ff    	lea    -0x1003e(%eax),%eax
f0101281:	50                   	push   %eax
f0101282:	57                   	push   %edi
f0101283:	56                   	push   %esi
f0101284:	e8 5c fe ff ff       	call   f01010e5 <printfmt>
f0101289:	83 c4 10             	add    $0x10,%esp
			err = va_arg(ap, int);
f010128c:	89 5d 14             	mov    %ebx,0x14(%ebp)
				printfmt(putch, putdat, "error %d", err);
f010128f:	e9 6d 02 00 00       	jmp    f0101501 <.L25+0x45>

f0101294 <.L24>:
f0101294:	8b 75 08             	mov    0x8(%ebp),%esi
			if ((p = va_arg(ap, char *)) == NULL)
f0101297:	8b 45 14             	mov    0x14(%ebp),%eax
f010129a:	83 c0 04             	add    $0x4,%eax
f010129d:	89 45 c0             	mov    %eax,-0x40(%ebp)
f01012a0:	8b 45 14             	mov    0x14(%ebp),%eax
f01012a3:	8b 10                	mov    (%eax),%edx
				p = "(null)";
f01012a5:	85 d2                	test   %edx,%edx
f01012a7:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01012aa:	8d 80 bb ff fe ff    	lea    -0x10045(%eax),%eax
f01012b0:	0f 45 c2             	cmovne %edx,%eax
f01012b3:	89 45 c8             	mov    %eax,-0x38(%ebp)
			if (width > 0 && padc != '-')
f01012b6:	83 7d d4 00          	cmpl   $0x0,-0x2c(%ebp)
f01012ba:	7e 06                	jle    f01012c2 <.L24+0x2e>
f01012bc:	80 7d cf 2d          	cmpb   $0x2d,-0x31(%ebp)
f01012c0:	75 0d                	jne    f01012cf <.L24+0x3b>
				for (width -= strnlen(p, precision); width > 0; width--)
f01012c2:	8b 45 c8             	mov    -0x38(%ebp),%eax
f01012c5:	89 c3                	mov    %eax,%ebx
f01012c7:	03 45 d4             	add    -0x2c(%ebp),%eax
f01012ca:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01012cd:	eb 58                	jmp    f0101327 <.L24+0x93>
f01012cf:	83 ec 08             	sub    $0x8,%esp
f01012d2:	ff 75 d8             	pushl  -0x28(%ebp)
f01012d5:	ff 75 c8             	pushl  -0x38(%ebp)
f01012d8:	8b 5d e0             	mov    -0x20(%ebp),%ebx
f01012db:	e8 85 04 00 00       	call   f0101765 <strnlen>
f01012e0:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f01012e3:	29 c2                	sub    %eax,%edx
f01012e5:	89 55 bc             	mov    %edx,-0x44(%ebp)
f01012e8:	83 c4 10             	add    $0x10,%esp
f01012eb:	89 d3                	mov    %edx,%ebx
					putch(padc, putdat);
f01012ed:	0f be 45 cf          	movsbl -0x31(%ebp),%eax
f01012f1:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				for (width -= strnlen(p, precision); width > 0; width--)
f01012f4:	85 db                	test   %ebx,%ebx
f01012f6:	7e 11                	jle    f0101309 <.L24+0x75>
					putch(padc, putdat);
f01012f8:	83 ec 08             	sub    $0x8,%esp
f01012fb:	57                   	push   %edi
f01012fc:	ff 75 d4             	pushl  -0x2c(%ebp)
f01012ff:	ff d6                	call   *%esi
				for (width -= strnlen(p, precision); width > 0; width--)
f0101301:	83 eb 01             	sub    $0x1,%ebx
f0101304:	83 c4 10             	add    $0x10,%esp
f0101307:	eb eb                	jmp    f01012f4 <.L24+0x60>
f0101309:	8b 55 bc             	mov    -0x44(%ebp),%edx
f010130c:	85 d2                	test   %edx,%edx
f010130e:	b8 00 00 00 00       	mov    $0x0,%eax
f0101313:	0f 49 c2             	cmovns %edx,%eax
f0101316:	29 c2                	sub    %eax,%edx
f0101318:	89 55 d4             	mov    %edx,-0x2c(%ebp)
f010131b:	eb a5                	jmp    f01012c2 <.L24+0x2e>
					putch(ch, putdat);
f010131d:	83 ec 08             	sub    $0x8,%esp
f0101320:	57                   	push   %edi
f0101321:	52                   	push   %edx
f0101322:	ff d6                	call   *%esi
f0101324:	83 c4 10             	add    $0x10,%esp
f0101327:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010132a:	29 d9                	sub    %ebx,%ecx
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f010132c:	83 c3 01             	add    $0x1,%ebx
f010132f:	0f b6 43 ff          	movzbl -0x1(%ebx),%eax
f0101333:	0f be d0             	movsbl %al,%edx
f0101336:	85 d2                	test   %edx,%edx
f0101338:	74 4b                	je     f0101385 <.L24+0xf1>
f010133a:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f010133e:	78 06                	js     f0101346 <.L24+0xb2>
f0101340:	83 6d d8 01          	subl   $0x1,-0x28(%ebp)
f0101344:	78 1e                	js     f0101364 <.L24+0xd0>
				if (altflag && (ch < ' ' || ch > '~'))
f0101346:	83 7d d0 00          	cmpl   $0x0,-0x30(%ebp)
f010134a:	74 d1                	je     f010131d <.L24+0x89>
f010134c:	0f be c0             	movsbl %al,%eax
f010134f:	83 e8 20             	sub    $0x20,%eax
f0101352:	83 f8 5e             	cmp    $0x5e,%eax
f0101355:	76 c6                	jbe    f010131d <.L24+0x89>
					putch('?', putdat);
f0101357:	83 ec 08             	sub    $0x8,%esp
f010135a:	57                   	push   %edi
f010135b:	6a 3f                	push   $0x3f
f010135d:	ff d6                	call   *%esi
f010135f:	83 c4 10             	add    $0x10,%esp
f0101362:	eb c3                	jmp    f0101327 <.L24+0x93>
f0101364:	89 cb                	mov    %ecx,%ebx
f0101366:	eb 0e                	jmp    f0101376 <.L24+0xe2>
				putch(' ', putdat);
f0101368:	83 ec 08             	sub    $0x8,%esp
f010136b:	57                   	push   %edi
f010136c:	6a 20                	push   $0x20
f010136e:	ff d6                	call   *%esi
			for (; width > 0; width--)
f0101370:	83 eb 01             	sub    $0x1,%ebx
f0101373:	83 c4 10             	add    $0x10,%esp
f0101376:	85 db                	test   %ebx,%ebx
f0101378:	7f ee                	jg     f0101368 <.L24+0xd4>
			if ((p = va_arg(ap, char *)) == NULL)
f010137a:	8b 45 c0             	mov    -0x40(%ebp),%eax
f010137d:	89 45 14             	mov    %eax,0x14(%ebp)
f0101380:	e9 7c 01 00 00       	jmp    f0101501 <.L25+0x45>
f0101385:	89 cb                	mov    %ecx,%ebx
f0101387:	eb ed                	jmp    f0101376 <.L24+0xe2>

f0101389 <.L29>:
f0101389:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f010138c:	8b 75 08             	mov    0x8(%ebp),%esi
	if (lflag >= 2)
f010138f:	83 f9 01             	cmp    $0x1,%ecx
f0101392:	7f 1b                	jg     f01013af <.L29+0x26>
	else if (lflag)
f0101394:	85 c9                	test   %ecx,%ecx
f0101396:	74 63                	je     f01013fb <.L29+0x72>
		return va_arg(*ap, long);
f0101398:	8b 45 14             	mov    0x14(%ebp),%eax
f010139b:	8b 00                	mov    (%eax),%eax
f010139d:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01013a0:	99                   	cltd   
f01013a1:	89 55 dc             	mov    %edx,-0x24(%ebp)
f01013a4:	8b 45 14             	mov    0x14(%ebp),%eax
f01013a7:	8d 40 04             	lea    0x4(%eax),%eax
f01013aa:	89 45 14             	mov    %eax,0x14(%ebp)
f01013ad:	eb 17                	jmp    f01013c6 <.L29+0x3d>
		return va_arg(*ap, long long);
f01013af:	8b 45 14             	mov    0x14(%ebp),%eax
f01013b2:	8b 50 04             	mov    0x4(%eax),%edx
f01013b5:	8b 00                	mov    (%eax),%eax
f01013b7:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01013ba:	89 55 dc             	mov    %edx,-0x24(%ebp)
f01013bd:	8b 45 14             	mov    0x14(%ebp),%eax
f01013c0:	8d 40 08             	lea    0x8(%eax),%eax
f01013c3:	89 45 14             	mov    %eax,0x14(%ebp)
			if ((long long) num < 0) {
f01013c6:	8b 55 d8             	mov    -0x28(%ebp),%edx
f01013c9:	8b 4d dc             	mov    -0x24(%ebp),%ecx
			base = 10;
f01013cc:	b8 0a 00 00 00       	mov    $0xa,%eax
			if ((long long) num < 0) {
f01013d1:	85 c9                	test   %ecx,%ecx
f01013d3:	0f 89 0e 01 00 00    	jns    f01014e7 <.L25+0x2b>
				putch('-', putdat);
f01013d9:	83 ec 08             	sub    $0x8,%esp
f01013dc:	57                   	push   %edi
f01013dd:	6a 2d                	push   $0x2d
f01013df:	ff d6                	call   *%esi
				num = -(long long) num;
f01013e1:	8b 55 d8             	mov    -0x28(%ebp),%edx
f01013e4:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f01013e7:	f7 da                	neg    %edx
f01013e9:	83 d1 00             	adc    $0x0,%ecx
f01013ec:	f7 d9                	neg    %ecx
f01013ee:	83 c4 10             	add    $0x10,%esp
			base = 10;
f01013f1:	b8 0a 00 00 00       	mov    $0xa,%eax
f01013f6:	e9 ec 00 00 00       	jmp    f01014e7 <.L25+0x2b>
		return va_arg(*ap, int);
f01013fb:	8b 45 14             	mov    0x14(%ebp),%eax
f01013fe:	8b 00                	mov    (%eax),%eax
f0101400:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0101403:	99                   	cltd   
f0101404:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0101407:	8b 45 14             	mov    0x14(%ebp),%eax
f010140a:	8d 40 04             	lea    0x4(%eax),%eax
f010140d:	89 45 14             	mov    %eax,0x14(%ebp)
f0101410:	eb b4                	jmp    f01013c6 <.L29+0x3d>

f0101412 <.L23>:
f0101412:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0101415:	8b 75 08             	mov    0x8(%ebp),%esi
	if (lflag >= 2)
f0101418:	83 f9 01             	cmp    $0x1,%ecx
f010141b:	7f 1e                	jg     f010143b <.L23+0x29>
	else if (lflag)
f010141d:	85 c9                	test   %ecx,%ecx
f010141f:	74 32                	je     f0101453 <.L23+0x41>
		return va_arg(*ap, unsigned long);
f0101421:	8b 45 14             	mov    0x14(%ebp),%eax
f0101424:	8b 10                	mov    (%eax),%edx
f0101426:	b9 00 00 00 00       	mov    $0x0,%ecx
f010142b:	8d 40 04             	lea    0x4(%eax),%eax
f010142e:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 10;
f0101431:	b8 0a 00 00 00       	mov    $0xa,%eax
		return va_arg(*ap, unsigned long);
f0101436:	e9 ac 00 00 00       	jmp    f01014e7 <.L25+0x2b>
		return va_arg(*ap, unsigned long long);
f010143b:	8b 45 14             	mov    0x14(%ebp),%eax
f010143e:	8b 10                	mov    (%eax),%edx
f0101440:	8b 48 04             	mov    0x4(%eax),%ecx
f0101443:	8d 40 08             	lea    0x8(%eax),%eax
f0101446:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 10;
f0101449:	b8 0a 00 00 00       	mov    $0xa,%eax
		return va_arg(*ap, unsigned long long);
f010144e:	e9 94 00 00 00       	jmp    f01014e7 <.L25+0x2b>
		return va_arg(*ap, unsigned int);
f0101453:	8b 45 14             	mov    0x14(%ebp),%eax
f0101456:	8b 10                	mov    (%eax),%edx
f0101458:	b9 00 00 00 00       	mov    $0x0,%ecx
f010145d:	8d 40 04             	lea    0x4(%eax),%eax
f0101460:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 10;
f0101463:	b8 0a 00 00 00       	mov    $0xa,%eax
		return va_arg(*ap, unsigned int);
f0101468:	eb 7d                	jmp    f01014e7 <.L25+0x2b>

f010146a <.L26>:
f010146a:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f010146d:	8b 75 08             	mov    0x8(%ebp),%esi
	if (lflag >= 2)
f0101470:	83 f9 01             	cmp    $0x1,%ecx
f0101473:	7f 1b                	jg     f0101490 <.L26+0x26>
	else if (lflag)
f0101475:	85 c9                	test   %ecx,%ecx
f0101477:	74 2c                	je     f01014a5 <.L26+0x3b>
		return va_arg(*ap, unsigned long);
f0101479:	8b 45 14             	mov    0x14(%ebp),%eax
f010147c:	8b 10                	mov    (%eax),%edx
f010147e:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101483:	8d 40 04             	lea    0x4(%eax),%eax
f0101486:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 8;
f0101489:	b8 08 00 00 00       	mov    $0x8,%eax
		return va_arg(*ap, unsigned long);
f010148e:	eb 57                	jmp    f01014e7 <.L25+0x2b>
		return va_arg(*ap, unsigned long long);
f0101490:	8b 45 14             	mov    0x14(%ebp),%eax
f0101493:	8b 10                	mov    (%eax),%edx
f0101495:	8b 48 04             	mov    0x4(%eax),%ecx
f0101498:	8d 40 08             	lea    0x8(%eax),%eax
f010149b:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 8;
f010149e:	b8 08 00 00 00       	mov    $0x8,%eax
		return va_arg(*ap, unsigned long long);
f01014a3:	eb 42                	jmp    f01014e7 <.L25+0x2b>
		return va_arg(*ap, unsigned int);
f01014a5:	8b 45 14             	mov    0x14(%ebp),%eax
f01014a8:	8b 10                	mov    (%eax),%edx
f01014aa:	b9 00 00 00 00       	mov    $0x0,%ecx
f01014af:	8d 40 04             	lea    0x4(%eax),%eax
f01014b2:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 8;
f01014b5:	b8 08 00 00 00       	mov    $0x8,%eax
		return va_arg(*ap, unsigned int);
f01014ba:	eb 2b                	jmp    f01014e7 <.L25+0x2b>

f01014bc <.L25>:
f01014bc:	8b 75 08             	mov    0x8(%ebp),%esi
			putch('0', putdat);
f01014bf:	83 ec 08             	sub    $0x8,%esp
f01014c2:	57                   	push   %edi
f01014c3:	6a 30                	push   $0x30
f01014c5:	ff d6                	call   *%esi
			putch('x', putdat);
f01014c7:	83 c4 08             	add    $0x8,%esp
f01014ca:	57                   	push   %edi
f01014cb:	6a 78                	push   $0x78
f01014cd:	ff d6                	call   *%esi
			num = (unsigned long long)
f01014cf:	8b 45 14             	mov    0x14(%ebp),%eax
f01014d2:	8b 10                	mov    (%eax),%edx
f01014d4:	b9 00 00 00 00       	mov    $0x0,%ecx
			goto number;
f01014d9:	83 c4 10             	add    $0x10,%esp
				(uintptr_t) va_arg(ap, void *);
f01014dc:	8d 40 04             	lea    0x4(%eax),%eax
f01014df:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f01014e2:	b8 10 00 00 00       	mov    $0x10,%eax
			printnum(putch, putdat, num, base, width, padc);
f01014e7:	83 ec 0c             	sub    $0xc,%esp
f01014ea:	0f be 5d cf          	movsbl -0x31(%ebp),%ebx
f01014ee:	53                   	push   %ebx
f01014ef:	ff 75 d4             	pushl  -0x2c(%ebp)
f01014f2:	50                   	push   %eax
f01014f3:	51                   	push   %ecx
f01014f4:	52                   	push   %edx
f01014f5:	89 fa                	mov    %edi,%edx
f01014f7:	89 f0                	mov    %esi,%eax
f01014f9:	e8 08 fb ff ff       	call   f0101006 <printnum>
			break;
f01014fe:	83 c4 20             	add    $0x20,%esp
			if ((p = va_arg(ap, char *)) == NULL)
f0101501:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0101504:	83 c3 01             	add    $0x1,%ebx
f0101507:	0f b6 43 ff          	movzbl -0x1(%ebx),%eax
f010150b:	83 f8 25             	cmp    $0x25,%eax
f010150e:	0f 84 23 fc ff ff    	je     f0101137 <vprintfmt+0x31>
			if (ch == '\0')
f0101514:	85 c0                	test   %eax,%eax
f0101516:	0f 84 97 00 00 00    	je     f01015b3 <.L20+0x23>
			putch(ch, putdat);
f010151c:	83 ec 08             	sub    $0x8,%esp
f010151f:	57                   	push   %edi
f0101520:	50                   	push   %eax
f0101521:	ff d6                	call   *%esi
f0101523:	83 c4 10             	add    $0x10,%esp
f0101526:	eb dc                	jmp    f0101504 <.L25+0x48>

f0101528 <.L21>:
f0101528:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f010152b:	8b 75 08             	mov    0x8(%ebp),%esi
	if (lflag >= 2)
f010152e:	83 f9 01             	cmp    $0x1,%ecx
f0101531:	7f 1b                	jg     f010154e <.L21+0x26>
	else if (lflag)
f0101533:	85 c9                	test   %ecx,%ecx
f0101535:	74 2c                	je     f0101563 <.L21+0x3b>
		return va_arg(*ap, unsigned long);
f0101537:	8b 45 14             	mov    0x14(%ebp),%eax
f010153a:	8b 10                	mov    (%eax),%edx
f010153c:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101541:	8d 40 04             	lea    0x4(%eax),%eax
f0101544:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f0101547:	b8 10 00 00 00       	mov    $0x10,%eax
		return va_arg(*ap, unsigned long);
f010154c:	eb 99                	jmp    f01014e7 <.L25+0x2b>
		return va_arg(*ap, unsigned long long);
f010154e:	8b 45 14             	mov    0x14(%ebp),%eax
f0101551:	8b 10                	mov    (%eax),%edx
f0101553:	8b 48 04             	mov    0x4(%eax),%ecx
f0101556:	8d 40 08             	lea    0x8(%eax),%eax
f0101559:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f010155c:	b8 10 00 00 00       	mov    $0x10,%eax
		return va_arg(*ap, unsigned long long);
f0101561:	eb 84                	jmp    f01014e7 <.L25+0x2b>
		return va_arg(*ap, unsigned int);
f0101563:	8b 45 14             	mov    0x14(%ebp),%eax
f0101566:	8b 10                	mov    (%eax),%edx
f0101568:	b9 00 00 00 00       	mov    $0x0,%ecx
f010156d:	8d 40 04             	lea    0x4(%eax),%eax
f0101570:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f0101573:	b8 10 00 00 00       	mov    $0x10,%eax
		return va_arg(*ap, unsigned int);
f0101578:	e9 6a ff ff ff       	jmp    f01014e7 <.L25+0x2b>

f010157d <.L35>:
f010157d:	8b 75 08             	mov    0x8(%ebp),%esi
			putch(ch, putdat);
f0101580:	83 ec 08             	sub    $0x8,%esp
f0101583:	57                   	push   %edi
f0101584:	6a 25                	push   $0x25
f0101586:	ff d6                	call   *%esi
			break;
f0101588:	83 c4 10             	add    $0x10,%esp
f010158b:	e9 71 ff ff ff       	jmp    f0101501 <.L25+0x45>

f0101590 <.L20>:
f0101590:	8b 75 08             	mov    0x8(%ebp),%esi
			putch('%', putdat);
f0101593:	83 ec 08             	sub    $0x8,%esp
f0101596:	57                   	push   %edi
f0101597:	6a 25                	push   $0x25
f0101599:	ff d6                	call   *%esi
			for (fmt--; fmt[-1] != '%'; fmt--)
f010159b:	83 c4 10             	add    $0x10,%esp
f010159e:	89 d8                	mov    %ebx,%eax
f01015a0:	80 78 ff 25          	cmpb   $0x25,-0x1(%eax)
f01015a4:	74 05                	je     f01015ab <.L20+0x1b>
f01015a6:	83 e8 01             	sub    $0x1,%eax
f01015a9:	eb f5                	jmp    f01015a0 <.L20+0x10>
f01015ab:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01015ae:	e9 4e ff ff ff       	jmp    f0101501 <.L25+0x45>
}
f01015b3:	8d 65 f4             	lea    -0xc(%ebp),%esp
f01015b6:	5b                   	pop    %ebx
f01015b7:	5e                   	pop    %esi
f01015b8:	5f                   	pop    %edi
f01015b9:	5d                   	pop    %ebp
f01015ba:	c3                   	ret    

f01015bb <vsnprintf>:

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f01015bb:	f3 0f 1e fb          	endbr32 
f01015bf:	55                   	push   %ebp
f01015c0:	89 e5                	mov    %esp,%ebp
f01015c2:	53                   	push   %ebx
f01015c3:	83 ec 14             	sub    $0x14,%esp
f01015c6:	e8 a1 eb ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f01015cb:	81 c3 3d 0d 01 00    	add    $0x10d3d,%ebx
f01015d1:	8b 45 08             	mov    0x8(%ebp),%eax
f01015d4:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f01015d7:	89 45 ec             	mov    %eax,-0x14(%ebp)
f01015da:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f01015de:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f01015e1:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f01015e8:	85 c0                	test   %eax,%eax
f01015ea:	74 2b                	je     f0101617 <vsnprintf+0x5c>
f01015ec:	85 d2                	test   %edx,%edx
f01015ee:	7e 27                	jle    f0101617 <vsnprintf+0x5c>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f01015f0:	ff 75 14             	pushl  0x14(%ebp)
f01015f3:	ff 75 10             	pushl  0x10(%ebp)
f01015f6:	8d 45 ec             	lea    -0x14(%ebp),%eax
f01015f9:	50                   	push   %eax
f01015fa:	8d 83 bc ed fe ff    	lea    -0x11244(%ebx),%eax
f0101600:	50                   	push   %eax
f0101601:	e8 00 fb ff ff       	call   f0101106 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0101606:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0101609:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f010160c:	8b 45 f4             	mov    -0xc(%ebp),%eax
f010160f:	83 c4 10             	add    $0x10,%esp
}
f0101612:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f0101615:	c9                   	leave  
f0101616:	c3                   	ret    
		return -E_INVAL;
f0101617:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f010161c:	eb f4                	jmp    f0101612 <vsnprintf+0x57>

f010161e <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f010161e:	f3 0f 1e fb          	endbr32 
f0101622:	55                   	push   %ebp
f0101623:	89 e5                	mov    %esp,%ebp
f0101625:	83 ec 08             	sub    $0x8,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0101628:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f010162b:	50                   	push   %eax
f010162c:	ff 75 10             	pushl  0x10(%ebp)
f010162f:	ff 75 0c             	pushl  0xc(%ebp)
f0101632:	ff 75 08             	pushl  0x8(%ebp)
f0101635:	e8 81 ff ff ff       	call   f01015bb <vsnprintf>
	va_end(ap);

	return rc;
}
f010163a:	c9                   	leave  
f010163b:	c3                   	ret    

f010163c <__x86.get_pc_thunk.cx>:
f010163c:	8b 0c 24             	mov    (%esp),%ecx
f010163f:	c3                   	ret    

f0101640 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0101640:	f3 0f 1e fb          	endbr32 
f0101644:	55                   	push   %ebp
f0101645:	89 e5                	mov    %esp,%ebp
f0101647:	57                   	push   %edi
f0101648:	56                   	push   %esi
f0101649:	53                   	push   %ebx
f010164a:	83 ec 1c             	sub    $0x1c,%esp
f010164d:	e8 1a eb ff ff       	call   f010016c <__x86.get_pc_thunk.bx>
f0101652:	81 c3 b6 0c 01 00    	add    $0x10cb6,%ebx
f0101658:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f010165b:	85 c0                	test   %eax,%eax
f010165d:	74 13                	je     f0101672 <readline+0x32>
		cprintf("%s", prompt);
f010165f:	83 ec 08             	sub    $0x8,%esp
f0101662:	50                   	push   %eax
f0101663:	8d 83 cb ff fe ff    	lea    -0x10035(%ebx),%eax
f0101669:	50                   	push   %eax
f010166a:	e8 25 f6 ff ff       	call   f0100c94 <cprintf>
f010166f:	83 c4 10             	add    $0x10,%esp

	i = 0;
	echoing = iscons(0);
f0101672:	83 ec 0c             	sub    $0xc,%esp
f0101675:	6a 00                	push   $0x0
f0101677:	e8 9a f0 ff ff       	call   f0100716 <iscons>
f010167c:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010167f:	83 c4 10             	add    $0x10,%esp
	i = 0;
f0101682:	bf 00 00 00 00       	mov    $0x0,%edi
				cputchar('\b');
			i--;
		} else if (c >= ' ' && i < BUFLEN-1) {
			if (echoing)
				cputchar(c);
			buf[i++] = c;
f0101687:	8d 83 98 1f 00 00    	lea    0x1f98(%ebx),%eax
f010168d:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0101690:	eb 51                	jmp    f01016e3 <readline+0xa3>
			cprintf("read error: %e\n", c);
f0101692:	83 ec 08             	sub    $0x8,%esp
f0101695:	50                   	push   %eax
f0101696:	8d 83 90 01 ff ff    	lea    -0xfe70(%ebx),%eax
f010169c:	50                   	push   %eax
f010169d:	e8 f2 f5 ff ff       	call   f0100c94 <cprintf>
			return NULL;
f01016a2:	83 c4 10             	add    $0x10,%esp
f01016a5:	b8 00 00 00 00       	mov    $0x0,%eax
				cputchar('\n');
			buf[i] = 0;
			return buf;
		}
	}
}
f01016aa:	8d 65 f4             	lea    -0xc(%ebp),%esp
f01016ad:	5b                   	pop    %ebx
f01016ae:	5e                   	pop    %esi
f01016af:	5f                   	pop    %edi
f01016b0:	5d                   	pop    %ebp
f01016b1:	c3                   	ret    
			if (echoing)
f01016b2:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01016b6:	75 05                	jne    f01016bd <readline+0x7d>
			i--;
f01016b8:	83 ef 01             	sub    $0x1,%edi
f01016bb:	eb 26                	jmp    f01016e3 <readline+0xa3>
				cputchar('\b');
f01016bd:	83 ec 0c             	sub    $0xc,%esp
f01016c0:	6a 08                	push   $0x8
f01016c2:	e8 26 f0 ff ff       	call   f01006ed <cputchar>
f01016c7:	83 c4 10             	add    $0x10,%esp
f01016ca:	eb ec                	jmp    f01016b8 <readline+0x78>
				cputchar(c);
f01016cc:	83 ec 0c             	sub    $0xc,%esp
f01016cf:	56                   	push   %esi
f01016d0:	e8 18 f0 ff ff       	call   f01006ed <cputchar>
f01016d5:	83 c4 10             	add    $0x10,%esp
			buf[i++] = c;
f01016d8:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f01016db:	89 f0                	mov    %esi,%eax
f01016dd:	88 04 39             	mov    %al,(%ecx,%edi,1)
f01016e0:	8d 7f 01             	lea    0x1(%edi),%edi
		c = getchar();
f01016e3:	e8 19 f0 ff ff       	call   f0100701 <getchar>
f01016e8:	89 c6                	mov    %eax,%esi
		if (c < 0) {
f01016ea:	85 c0                	test   %eax,%eax
f01016ec:	78 a4                	js     f0101692 <readline+0x52>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f01016ee:	83 f8 08             	cmp    $0x8,%eax
f01016f1:	0f 94 c2             	sete   %dl
f01016f4:	83 f8 7f             	cmp    $0x7f,%eax
f01016f7:	0f 94 c0             	sete   %al
f01016fa:	08 c2                	or     %al,%dl
f01016fc:	74 04                	je     f0101702 <readline+0xc2>
f01016fe:	85 ff                	test   %edi,%edi
f0101700:	7f b0                	jg     f01016b2 <readline+0x72>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0101702:	83 fe 1f             	cmp    $0x1f,%esi
f0101705:	7e 10                	jle    f0101717 <readline+0xd7>
f0101707:	81 ff fe 03 00 00    	cmp    $0x3fe,%edi
f010170d:	7f 08                	jg     f0101717 <readline+0xd7>
			if (echoing)
f010170f:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0101713:	74 c3                	je     f01016d8 <readline+0x98>
f0101715:	eb b5                	jmp    f01016cc <readline+0x8c>
		} else if (c == '\n' || c == '\r') {
f0101717:	83 fe 0a             	cmp    $0xa,%esi
f010171a:	74 05                	je     f0101721 <readline+0xe1>
f010171c:	83 fe 0d             	cmp    $0xd,%esi
f010171f:	75 c2                	jne    f01016e3 <readline+0xa3>
			if (echoing)
f0101721:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0101725:	75 13                	jne    f010173a <readline+0xfa>
			buf[i] = 0;
f0101727:	c6 84 3b 98 1f 00 00 	movb   $0x0,0x1f98(%ebx,%edi,1)
f010172e:	00 
			return buf;
f010172f:	8d 83 98 1f 00 00    	lea    0x1f98(%ebx),%eax
f0101735:	e9 70 ff ff ff       	jmp    f01016aa <readline+0x6a>
				cputchar('\n');
f010173a:	83 ec 0c             	sub    $0xc,%esp
f010173d:	6a 0a                	push   $0xa
f010173f:	e8 a9 ef ff ff       	call   f01006ed <cputchar>
f0101744:	83 c4 10             	add    $0x10,%esp
f0101747:	eb de                	jmp    f0101727 <readline+0xe7>

f0101749 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0101749:	f3 0f 1e fb          	endbr32 
f010174d:	55                   	push   %ebp
f010174e:	89 e5                	mov    %esp,%ebp
f0101750:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0101753:	b8 00 00 00 00       	mov    $0x0,%eax
f0101758:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f010175c:	74 05                	je     f0101763 <strlen+0x1a>
		n++;
f010175e:	83 c0 01             	add    $0x1,%eax
f0101761:	eb f5                	jmp    f0101758 <strlen+0xf>
	return n;
}
f0101763:	5d                   	pop    %ebp
f0101764:	c3                   	ret    

f0101765 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0101765:	f3 0f 1e fb          	endbr32 
f0101769:	55                   	push   %ebp
f010176a:	89 e5                	mov    %esp,%ebp
f010176c:	8b 4d 08             	mov    0x8(%ebp),%ecx
f010176f:	8b 55 0c             	mov    0xc(%ebp),%edx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0101772:	b8 00 00 00 00       	mov    $0x0,%eax
f0101777:	39 d0                	cmp    %edx,%eax
f0101779:	74 0d                	je     f0101788 <strnlen+0x23>
f010177b:	80 3c 01 00          	cmpb   $0x0,(%ecx,%eax,1)
f010177f:	74 05                	je     f0101786 <strnlen+0x21>
		n++;
f0101781:	83 c0 01             	add    $0x1,%eax
f0101784:	eb f1                	jmp    f0101777 <strnlen+0x12>
f0101786:	89 c2                	mov    %eax,%edx
	return n;
}
f0101788:	89 d0                	mov    %edx,%eax
f010178a:	5d                   	pop    %ebp
f010178b:	c3                   	ret    

f010178c <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f010178c:	f3 0f 1e fb          	endbr32 
f0101790:	55                   	push   %ebp
f0101791:	89 e5                	mov    %esp,%ebp
f0101793:	53                   	push   %ebx
f0101794:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0101797:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f010179a:	b8 00 00 00 00       	mov    $0x0,%eax
f010179f:	0f b6 14 03          	movzbl (%ebx,%eax,1),%edx
f01017a3:	88 14 01             	mov    %dl,(%ecx,%eax,1)
f01017a6:	83 c0 01             	add    $0x1,%eax
f01017a9:	84 d2                	test   %dl,%dl
f01017ab:	75 f2                	jne    f010179f <strcpy+0x13>
		/* do nothing */;
	return ret;
}
f01017ad:	89 c8                	mov    %ecx,%eax
f01017af:	5b                   	pop    %ebx
f01017b0:	5d                   	pop    %ebp
f01017b1:	c3                   	ret    

f01017b2 <strcat>:

char *
strcat(char *dst, const char *src)
{
f01017b2:	f3 0f 1e fb          	endbr32 
f01017b6:	55                   	push   %ebp
f01017b7:	89 e5                	mov    %esp,%ebp
f01017b9:	53                   	push   %ebx
f01017ba:	83 ec 10             	sub    $0x10,%esp
f01017bd:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f01017c0:	53                   	push   %ebx
f01017c1:	e8 83 ff ff ff       	call   f0101749 <strlen>
f01017c6:	83 c4 08             	add    $0x8,%esp
	strcpy(dst + len, src);
f01017c9:	ff 75 0c             	pushl  0xc(%ebp)
f01017cc:	01 d8                	add    %ebx,%eax
f01017ce:	50                   	push   %eax
f01017cf:	e8 b8 ff ff ff       	call   f010178c <strcpy>
	return dst;
}
f01017d4:	89 d8                	mov    %ebx,%eax
f01017d6:	8b 5d fc             	mov    -0x4(%ebp),%ebx
f01017d9:	c9                   	leave  
f01017da:	c3                   	ret    

f01017db <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f01017db:	f3 0f 1e fb          	endbr32 
f01017df:	55                   	push   %ebp
f01017e0:	89 e5                	mov    %esp,%ebp
f01017e2:	56                   	push   %esi
f01017e3:	53                   	push   %ebx
f01017e4:	8b 75 08             	mov    0x8(%ebp),%esi
f01017e7:	8b 55 0c             	mov    0xc(%ebp),%edx
f01017ea:	89 f3                	mov    %esi,%ebx
f01017ec:	03 5d 10             	add    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f01017ef:	89 f0                	mov    %esi,%eax
f01017f1:	39 d8                	cmp    %ebx,%eax
f01017f3:	74 11                	je     f0101806 <strncpy+0x2b>
		*dst++ = *src;
f01017f5:	83 c0 01             	add    $0x1,%eax
f01017f8:	0f b6 0a             	movzbl (%edx),%ecx
f01017fb:	88 48 ff             	mov    %cl,-0x1(%eax)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f01017fe:	80 f9 01             	cmp    $0x1,%cl
f0101801:	83 da ff             	sbb    $0xffffffff,%edx
f0101804:	eb eb                	jmp    f01017f1 <strncpy+0x16>
	}
	return ret;
}
f0101806:	89 f0                	mov    %esi,%eax
f0101808:	5b                   	pop    %ebx
f0101809:	5e                   	pop    %esi
f010180a:	5d                   	pop    %ebp
f010180b:	c3                   	ret    

f010180c <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f010180c:	f3 0f 1e fb          	endbr32 
f0101810:	55                   	push   %ebp
f0101811:	89 e5                	mov    %esp,%ebp
f0101813:	56                   	push   %esi
f0101814:	53                   	push   %ebx
f0101815:	8b 75 08             	mov    0x8(%ebp),%esi
f0101818:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f010181b:	8b 55 10             	mov    0x10(%ebp),%edx
f010181e:	89 f0                	mov    %esi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0101820:	85 d2                	test   %edx,%edx
f0101822:	74 21                	je     f0101845 <strlcpy+0x39>
f0101824:	8d 44 16 ff          	lea    -0x1(%esi,%edx,1),%eax
f0101828:	89 f2                	mov    %esi,%edx
		while (--size > 0 && *src != '\0')
f010182a:	39 c2                	cmp    %eax,%edx
f010182c:	74 14                	je     f0101842 <strlcpy+0x36>
f010182e:	0f b6 19             	movzbl (%ecx),%ebx
f0101831:	84 db                	test   %bl,%bl
f0101833:	74 0b                	je     f0101840 <strlcpy+0x34>
			*dst++ = *src++;
f0101835:	83 c1 01             	add    $0x1,%ecx
f0101838:	83 c2 01             	add    $0x1,%edx
f010183b:	88 5a ff             	mov    %bl,-0x1(%edx)
f010183e:	eb ea                	jmp    f010182a <strlcpy+0x1e>
f0101840:	89 d0                	mov    %edx,%eax
		*dst = '\0';
f0101842:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f0101845:	29 f0                	sub    %esi,%eax
}
f0101847:	5b                   	pop    %ebx
f0101848:	5e                   	pop    %esi
f0101849:	5d                   	pop    %ebp
f010184a:	c3                   	ret    

f010184b <strcmp>:

int
strcmp(const char *p, const char *q)
{
f010184b:	f3 0f 1e fb          	endbr32 
f010184f:	55                   	push   %ebp
f0101850:	89 e5                	mov    %esp,%ebp
f0101852:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0101855:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0101858:	0f b6 01             	movzbl (%ecx),%eax
f010185b:	84 c0                	test   %al,%al
f010185d:	74 0c                	je     f010186b <strcmp+0x20>
f010185f:	3a 02                	cmp    (%edx),%al
f0101861:	75 08                	jne    f010186b <strcmp+0x20>
		p++, q++;
f0101863:	83 c1 01             	add    $0x1,%ecx
f0101866:	83 c2 01             	add    $0x1,%edx
f0101869:	eb ed                	jmp    f0101858 <strcmp+0xd>
	return (int) ((unsigned char) *p - (unsigned char) *q);
f010186b:	0f b6 c0             	movzbl %al,%eax
f010186e:	0f b6 12             	movzbl (%edx),%edx
f0101871:	29 d0                	sub    %edx,%eax
}
f0101873:	5d                   	pop    %ebp
f0101874:	c3                   	ret    

f0101875 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0101875:	f3 0f 1e fb          	endbr32 
f0101879:	55                   	push   %ebp
f010187a:	89 e5                	mov    %esp,%ebp
f010187c:	53                   	push   %ebx
f010187d:	8b 45 08             	mov    0x8(%ebp),%eax
f0101880:	8b 55 0c             	mov    0xc(%ebp),%edx
f0101883:	89 c3                	mov    %eax,%ebx
f0101885:	03 5d 10             	add    0x10(%ebp),%ebx
	while (n > 0 && *p && *p == *q)
f0101888:	eb 06                	jmp    f0101890 <strncmp+0x1b>
		n--, p++, q++;
f010188a:	83 c0 01             	add    $0x1,%eax
f010188d:	83 c2 01             	add    $0x1,%edx
	while (n > 0 && *p && *p == *q)
f0101890:	39 d8                	cmp    %ebx,%eax
f0101892:	74 16                	je     f01018aa <strncmp+0x35>
f0101894:	0f b6 08             	movzbl (%eax),%ecx
f0101897:	84 c9                	test   %cl,%cl
f0101899:	74 04                	je     f010189f <strncmp+0x2a>
f010189b:	3a 0a                	cmp    (%edx),%cl
f010189d:	74 eb                	je     f010188a <strncmp+0x15>
	if (n == 0)
		return 0;
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f010189f:	0f b6 00             	movzbl (%eax),%eax
f01018a2:	0f b6 12             	movzbl (%edx),%edx
f01018a5:	29 d0                	sub    %edx,%eax
}
f01018a7:	5b                   	pop    %ebx
f01018a8:	5d                   	pop    %ebp
f01018a9:	c3                   	ret    
		return 0;
f01018aa:	b8 00 00 00 00       	mov    $0x0,%eax
f01018af:	eb f6                	jmp    f01018a7 <strncmp+0x32>

f01018b1 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f01018b1:	f3 0f 1e fb          	endbr32 
f01018b5:	55                   	push   %ebp
f01018b6:	89 e5                	mov    %esp,%ebp
f01018b8:	8b 45 08             	mov    0x8(%ebp),%eax
f01018bb:	0f b6 4d 0c          	movzbl 0xc(%ebp),%ecx
	for (; *s; s++)
f01018bf:	0f b6 10             	movzbl (%eax),%edx
f01018c2:	84 d2                	test   %dl,%dl
f01018c4:	74 09                	je     f01018cf <strchr+0x1e>
		if (*s == c)
f01018c6:	38 ca                	cmp    %cl,%dl
f01018c8:	74 0a                	je     f01018d4 <strchr+0x23>
	for (; *s; s++)
f01018ca:	83 c0 01             	add    $0x1,%eax
f01018cd:	eb f0                	jmp    f01018bf <strchr+0xe>
			return (char *) s;
	return 0;
f01018cf:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01018d4:	5d                   	pop    %ebp
f01018d5:	c3                   	ret    

f01018d6 <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f01018d6:	f3 0f 1e fb          	endbr32 
f01018da:	55                   	push   %ebp
f01018db:	89 e5                	mov    %esp,%ebp
f01018dd:	8b 45 08             	mov    0x8(%ebp),%eax
f01018e0:	0f b6 4d 0c          	movzbl 0xc(%ebp),%ecx
	for (; *s; s++)
f01018e4:	0f b6 10             	movzbl (%eax),%edx
		if (*s == c)
f01018e7:	38 ca                	cmp    %cl,%dl
f01018e9:	74 09                	je     f01018f4 <strfind+0x1e>
f01018eb:	84 d2                	test   %dl,%dl
f01018ed:	74 05                	je     f01018f4 <strfind+0x1e>
	for (; *s; s++)
f01018ef:	83 c0 01             	add    $0x1,%eax
f01018f2:	eb f0                	jmp    f01018e4 <strfind+0xe>
			break;
	return (char *) s;
}
f01018f4:	5d                   	pop    %ebp
f01018f5:	c3                   	ret    

f01018f6 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f01018f6:	f3 0f 1e fb          	endbr32 
f01018fa:	55                   	push   %ebp
f01018fb:	89 e5                	mov    %esp,%ebp
f01018fd:	57                   	push   %edi
f01018fe:	56                   	push   %esi
f01018ff:	53                   	push   %ebx
f0101900:	8b 7d 08             	mov    0x8(%ebp),%edi
f0101903:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0101906:	85 c9                	test   %ecx,%ecx
f0101908:	74 31                	je     f010193b <memset+0x45>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f010190a:	89 f8                	mov    %edi,%eax
f010190c:	09 c8                	or     %ecx,%eax
f010190e:	a8 03                	test   $0x3,%al
f0101910:	75 23                	jne    f0101935 <memset+0x3f>
		c &= 0xFF;
f0101912:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0101916:	89 d3                	mov    %edx,%ebx
f0101918:	c1 e3 08             	shl    $0x8,%ebx
f010191b:	89 d0                	mov    %edx,%eax
f010191d:	c1 e0 18             	shl    $0x18,%eax
f0101920:	89 d6                	mov    %edx,%esi
f0101922:	c1 e6 10             	shl    $0x10,%esi
f0101925:	09 f0                	or     %esi,%eax
f0101927:	09 c2                	or     %eax,%edx
f0101929:	09 da                	or     %ebx,%edx
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f010192b:	c1 e9 02             	shr    $0x2,%ecx
		asm volatile("cld; rep stosl\n"
f010192e:	89 d0                	mov    %edx,%eax
f0101930:	fc                   	cld    
f0101931:	f3 ab                	rep stos %eax,%es:(%edi)
f0101933:	eb 06                	jmp    f010193b <memset+0x45>
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0101935:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101938:	fc                   	cld    
f0101939:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f010193b:	89 f8                	mov    %edi,%eax
f010193d:	5b                   	pop    %ebx
f010193e:	5e                   	pop    %esi
f010193f:	5f                   	pop    %edi
f0101940:	5d                   	pop    %ebp
f0101941:	c3                   	ret    

f0101942 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0101942:	f3 0f 1e fb          	endbr32 
f0101946:	55                   	push   %ebp
f0101947:	89 e5                	mov    %esp,%ebp
f0101949:	57                   	push   %edi
f010194a:	56                   	push   %esi
f010194b:	8b 45 08             	mov    0x8(%ebp),%eax
f010194e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0101951:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;

	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0101954:	39 c6                	cmp    %eax,%esi
f0101956:	73 32                	jae    f010198a <memmove+0x48>
f0101958:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f010195b:	39 c2                	cmp    %eax,%edx
f010195d:	76 2b                	jbe    f010198a <memmove+0x48>
		s += n;
		d += n;
f010195f:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0101962:	89 fe                	mov    %edi,%esi
f0101964:	09 ce                	or     %ecx,%esi
f0101966:	09 d6                	or     %edx,%esi
f0101968:	f7 c6 03 00 00 00    	test   $0x3,%esi
f010196e:	75 0e                	jne    f010197e <memmove+0x3c>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0101970:	83 ef 04             	sub    $0x4,%edi
f0101973:	8d 72 fc             	lea    -0x4(%edx),%esi
f0101976:	c1 e9 02             	shr    $0x2,%ecx
			asm volatile("std; rep movsl\n"
f0101979:	fd                   	std    
f010197a:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f010197c:	eb 09                	jmp    f0101987 <memmove+0x45>
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f010197e:	83 ef 01             	sub    $0x1,%edi
f0101981:	8d 72 ff             	lea    -0x1(%edx),%esi
			asm volatile("std; rep movsb\n"
f0101984:	fd                   	std    
f0101985:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0101987:	fc                   	cld    
f0101988:	eb 1a                	jmp    f01019a4 <memmove+0x62>
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f010198a:	89 c2                	mov    %eax,%edx
f010198c:	09 ca                	or     %ecx,%edx
f010198e:	09 f2                	or     %esi,%edx
f0101990:	f6 c2 03             	test   $0x3,%dl
f0101993:	75 0a                	jne    f010199f <memmove+0x5d>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0101995:	c1 e9 02             	shr    $0x2,%ecx
			asm volatile("cld; rep movsl\n"
f0101998:	89 c7                	mov    %eax,%edi
f010199a:	fc                   	cld    
f010199b:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f010199d:	eb 05                	jmp    f01019a4 <memmove+0x62>
		else
			asm volatile("cld; rep movsb\n"
f010199f:	89 c7                	mov    %eax,%edi
f01019a1:	fc                   	cld    
f01019a2:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f01019a4:	5e                   	pop    %esi
f01019a5:	5f                   	pop    %edi
f01019a6:	5d                   	pop    %ebp
f01019a7:	c3                   	ret    

f01019a8 <memcpy>:
}
#endif

void *
memcpy(void *dst, const void *src, size_t n)
{
f01019a8:	f3 0f 1e fb          	endbr32 
f01019ac:	55                   	push   %ebp
f01019ad:	89 e5                	mov    %esp,%ebp
f01019af:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f01019b2:	ff 75 10             	pushl  0x10(%ebp)
f01019b5:	ff 75 0c             	pushl  0xc(%ebp)
f01019b8:	ff 75 08             	pushl  0x8(%ebp)
f01019bb:	e8 82 ff ff ff       	call   f0101942 <memmove>
}
f01019c0:	c9                   	leave  
f01019c1:	c3                   	ret    

f01019c2 <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f01019c2:	f3 0f 1e fb          	endbr32 
f01019c6:	55                   	push   %ebp
f01019c7:	89 e5                	mov    %esp,%ebp
f01019c9:	56                   	push   %esi
f01019ca:	53                   	push   %ebx
f01019cb:	8b 45 08             	mov    0x8(%ebp),%eax
f01019ce:	8b 55 0c             	mov    0xc(%ebp),%edx
f01019d1:	89 c6                	mov    %eax,%esi
f01019d3:	03 75 10             	add    0x10(%ebp),%esi
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01019d6:	39 f0                	cmp    %esi,%eax
f01019d8:	74 1c                	je     f01019f6 <memcmp+0x34>
		if (*s1 != *s2)
f01019da:	0f b6 08             	movzbl (%eax),%ecx
f01019dd:	0f b6 1a             	movzbl (%edx),%ebx
f01019e0:	38 d9                	cmp    %bl,%cl
f01019e2:	75 08                	jne    f01019ec <memcmp+0x2a>
			return (int) *s1 - (int) *s2;
		s1++, s2++;
f01019e4:	83 c0 01             	add    $0x1,%eax
f01019e7:	83 c2 01             	add    $0x1,%edx
f01019ea:	eb ea                	jmp    f01019d6 <memcmp+0x14>
			return (int) *s1 - (int) *s2;
f01019ec:	0f b6 c1             	movzbl %cl,%eax
f01019ef:	0f b6 db             	movzbl %bl,%ebx
f01019f2:	29 d8                	sub    %ebx,%eax
f01019f4:	eb 05                	jmp    f01019fb <memcmp+0x39>
	}

	return 0;
f01019f6:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01019fb:	5b                   	pop    %ebx
f01019fc:	5e                   	pop    %esi
f01019fd:	5d                   	pop    %ebp
f01019fe:	c3                   	ret    

f01019ff <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f01019ff:	f3 0f 1e fb          	endbr32 
f0101a03:	55                   	push   %ebp
f0101a04:	89 e5                	mov    %esp,%ebp
f0101a06:	8b 45 08             	mov    0x8(%ebp),%eax
f0101a09:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	const void *ends = (const char *) s + n;
f0101a0c:	89 c2                	mov    %eax,%edx
f0101a0e:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0101a11:	39 d0                	cmp    %edx,%eax
f0101a13:	73 09                	jae    f0101a1e <memfind+0x1f>
		if (*(const unsigned char *) s == (unsigned char) c)
f0101a15:	38 08                	cmp    %cl,(%eax)
f0101a17:	74 05                	je     f0101a1e <memfind+0x1f>
	for (; s < ends; s++)
f0101a19:	83 c0 01             	add    $0x1,%eax
f0101a1c:	eb f3                	jmp    f0101a11 <memfind+0x12>
			break;
	return (void *) s;
}
f0101a1e:	5d                   	pop    %ebp
f0101a1f:	c3                   	ret    

f0101a20 <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0101a20:	f3 0f 1e fb          	endbr32 
f0101a24:	55                   	push   %ebp
f0101a25:	89 e5                	mov    %esp,%ebp
f0101a27:	57                   	push   %edi
f0101a28:	56                   	push   %esi
f0101a29:	53                   	push   %ebx
f0101a2a:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0101a2d:	8b 5d 10             	mov    0x10(%ebp),%ebx
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0101a30:	eb 03                	jmp    f0101a35 <strtol+0x15>
		s++;
f0101a32:	83 c1 01             	add    $0x1,%ecx
	while (*s == ' ' || *s == '\t')
f0101a35:	0f b6 01             	movzbl (%ecx),%eax
f0101a38:	3c 20                	cmp    $0x20,%al
f0101a3a:	74 f6                	je     f0101a32 <strtol+0x12>
f0101a3c:	3c 09                	cmp    $0x9,%al
f0101a3e:	74 f2                	je     f0101a32 <strtol+0x12>

	// plus/minus sign
	if (*s == '+')
f0101a40:	3c 2b                	cmp    $0x2b,%al
f0101a42:	74 2a                	je     f0101a6e <strtol+0x4e>
	int neg = 0;
f0101a44:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;
	else if (*s == '-')
f0101a49:	3c 2d                	cmp    $0x2d,%al
f0101a4b:	74 2b                	je     f0101a78 <strtol+0x58>
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0101a4d:	f7 c3 ef ff ff ff    	test   $0xffffffef,%ebx
f0101a53:	75 0f                	jne    f0101a64 <strtol+0x44>
f0101a55:	80 39 30             	cmpb   $0x30,(%ecx)
f0101a58:	74 28                	je     f0101a82 <strtol+0x62>
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0101a5a:	85 db                	test   %ebx,%ebx
f0101a5c:	b8 0a 00 00 00       	mov    $0xa,%eax
f0101a61:	0f 44 d8             	cmove  %eax,%ebx
f0101a64:	b8 00 00 00 00       	mov    $0x0,%eax
f0101a69:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0101a6c:	eb 46                	jmp    f0101ab4 <strtol+0x94>
		s++;
f0101a6e:	83 c1 01             	add    $0x1,%ecx
	int neg = 0;
f0101a71:	bf 00 00 00 00       	mov    $0x0,%edi
f0101a76:	eb d5                	jmp    f0101a4d <strtol+0x2d>
		s++, neg = 1;
f0101a78:	83 c1 01             	add    $0x1,%ecx
f0101a7b:	bf 01 00 00 00       	mov    $0x1,%edi
f0101a80:	eb cb                	jmp    f0101a4d <strtol+0x2d>
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0101a82:	80 79 01 78          	cmpb   $0x78,0x1(%ecx)
f0101a86:	74 0e                	je     f0101a96 <strtol+0x76>
	else if (base == 0 && s[0] == '0')
f0101a88:	85 db                	test   %ebx,%ebx
f0101a8a:	75 d8                	jne    f0101a64 <strtol+0x44>
		s++, base = 8;
f0101a8c:	83 c1 01             	add    $0x1,%ecx
f0101a8f:	bb 08 00 00 00       	mov    $0x8,%ebx
f0101a94:	eb ce                	jmp    f0101a64 <strtol+0x44>
		s += 2, base = 16;
f0101a96:	83 c1 02             	add    $0x2,%ecx
f0101a99:	bb 10 00 00 00       	mov    $0x10,%ebx
f0101a9e:	eb c4                	jmp    f0101a64 <strtol+0x44>
	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
			dig = *s - '0';
f0101aa0:	0f be d2             	movsbl %dl,%edx
f0101aa3:	83 ea 30             	sub    $0x30,%edx
			dig = *s - 'a' + 10;
		else if (*s >= 'A' && *s <= 'Z')
			dig = *s - 'A' + 10;
		else
			break;
		if (dig >= base)
f0101aa6:	3b 55 10             	cmp    0x10(%ebp),%edx
f0101aa9:	7d 3a                	jge    f0101ae5 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f0101aab:	83 c1 01             	add    $0x1,%ecx
f0101aae:	0f af 45 10          	imul   0x10(%ebp),%eax
f0101ab2:	01 d0                	add    %edx,%eax
		if (*s >= '0' && *s <= '9')
f0101ab4:	0f b6 11             	movzbl (%ecx),%edx
f0101ab7:	8d 72 d0             	lea    -0x30(%edx),%esi
f0101aba:	89 f3                	mov    %esi,%ebx
f0101abc:	80 fb 09             	cmp    $0x9,%bl
f0101abf:	76 df                	jbe    f0101aa0 <strtol+0x80>
		else if (*s >= 'a' && *s <= 'z')
f0101ac1:	8d 72 9f             	lea    -0x61(%edx),%esi
f0101ac4:	89 f3                	mov    %esi,%ebx
f0101ac6:	80 fb 19             	cmp    $0x19,%bl
f0101ac9:	77 08                	ja     f0101ad3 <strtol+0xb3>
			dig = *s - 'a' + 10;
f0101acb:	0f be d2             	movsbl %dl,%edx
f0101ace:	83 ea 57             	sub    $0x57,%edx
f0101ad1:	eb d3                	jmp    f0101aa6 <strtol+0x86>
		else if (*s >= 'A' && *s <= 'Z')
f0101ad3:	8d 72 bf             	lea    -0x41(%edx),%esi
f0101ad6:	89 f3                	mov    %esi,%ebx
f0101ad8:	80 fb 19             	cmp    $0x19,%bl
f0101adb:	77 08                	ja     f0101ae5 <strtol+0xc5>
			dig = *s - 'A' + 10;
f0101add:	0f be d2             	movsbl %dl,%edx
f0101ae0:	83 ea 37             	sub    $0x37,%edx
f0101ae3:	eb c1                	jmp    f0101aa6 <strtol+0x86>
		// we don't properly detect overflow!
	}

	if (endptr)
f0101ae5:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0101ae9:	74 05                	je     f0101af0 <strtol+0xd0>
		*endptr = (char *) s;
f0101aeb:	8b 75 0c             	mov    0xc(%ebp),%esi
f0101aee:	89 0e                	mov    %ecx,(%esi)
	return (neg ? -val : val);
f0101af0:	89 c2                	mov    %eax,%edx
f0101af2:	f7 da                	neg    %edx
f0101af4:	85 ff                	test   %edi,%edi
f0101af6:	0f 45 c2             	cmovne %edx,%eax
}
f0101af9:	5b                   	pop    %ebx
f0101afa:	5e                   	pop    %esi
f0101afb:	5f                   	pop    %edi
f0101afc:	5d                   	pop    %ebp
f0101afd:	c3                   	ret    
f0101afe:	66 90                	xchg   %ax,%ax

f0101b00 <__udivdi3>:
f0101b00:	f3 0f 1e fb          	endbr32 
f0101b04:	55                   	push   %ebp
f0101b05:	57                   	push   %edi
f0101b06:	56                   	push   %esi
f0101b07:	53                   	push   %ebx
f0101b08:	83 ec 1c             	sub    $0x1c,%esp
f0101b0b:	8b 54 24 3c          	mov    0x3c(%esp),%edx
f0101b0f:	8b 6c 24 30          	mov    0x30(%esp),%ebp
f0101b13:	8b 74 24 34          	mov    0x34(%esp),%esi
f0101b17:	8b 5c 24 38          	mov    0x38(%esp),%ebx
f0101b1b:	85 d2                	test   %edx,%edx
f0101b1d:	75 19                	jne    f0101b38 <__udivdi3+0x38>
f0101b1f:	39 f3                	cmp    %esi,%ebx
f0101b21:	76 4d                	jbe    f0101b70 <__udivdi3+0x70>
f0101b23:	31 ff                	xor    %edi,%edi
f0101b25:	89 e8                	mov    %ebp,%eax
f0101b27:	89 f2                	mov    %esi,%edx
f0101b29:	f7 f3                	div    %ebx
f0101b2b:	89 fa                	mov    %edi,%edx
f0101b2d:	83 c4 1c             	add    $0x1c,%esp
f0101b30:	5b                   	pop    %ebx
f0101b31:	5e                   	pop    %esi
f0101b32:	5f                   	pop    %edi
f0101b33:	5d                   	pop    %ebp
f0101b34:	c3                   	ret    
f0101b35:	8d 76 00             	lea    0x0(%esi),%esi
f0101b38:	39 f2                	cmp    %esi,%edx
f0101b3a:	76 14                	jbe    f0101b50 <__udivdi3+0x50>
f0101b3c:	31 ff                	xor    %edi,%edi
f0101b3e:	31 c0                	xor    %eax,%eax
f0101b40:	89 fa                	mov    %edi,%edx
f0101b42:	83 c4 1c             	add    $0x1c,%esp
f0101b45:	5b                   	pop    %ebx
f0101b46:	5e                   	pop    %esi
f0101b47:	5f                   	pop    %edi
f0101b48:	5d                   	pop    %ebp
f0101b49:	c3                   	ret    
f0101b4a:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0101b50:	0f bd fa             	bsr    %edx,%edi
f0101b53:	83 f7 1f             	xor    $0x1f,%edi
f0101b56:	75 48                	jne    f0101ba0 <__udivdi3+0xa0>
f0101b58:	39 f2                	cmp    %esi,%edx
f0101b5a:	72 06                	jb     f0101b62 <__udivdi3+0x62>
f0101b5c:	31 c0                	xor    %eax,%eax
f0101b5e:	39 eb                	cmp    %ebp,%ebx
f0101b60:	77 de                	ja     f0101b40 <__udivdi3+0x40>
f0101b62:	b8 01 00 00 00       	mov    $0x1,%eax
f0101b67:	eb d7                	jmp    f0101b40 <__udivdi3+0x40>
f0101b69:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101b70:	89 d9                	mov    %ebx,%ecx
f0101b72:	85 db                	test   %ebx,%ebx
f0101b74:	75 0b                	jne    f0101b81 <__udivdi3+0x81>
f0101b76:	b8 01 00 00 00       	mov    $0x1,%eax
f0101b7b:	31 d2                	xor    %edx,%edx
f0101b7d:	f7 f3                	div    %ebx
f0101b7f:	89 c1                	mov    %eax,%ecx
f0101b81:	31 d2                	xor    %edx,%edx
f0101b83:	89 f0                	mov    %esi,%eax
f0101b85:	f7 f1                	div    %ecx
f0101b87:	89 c6                	mov    %eax,%esi
f0101b89:	89 e8                	mov    %ebp,%eax
f0101b8b:	89 f7                	mov    %esi,%edi
f0101b8d:	f7 f1                	div    %ecx
f0101b8f:	89 fa                	mov    %edi,%edx
f0101b91:	83 c4 1c             	add    $0x1c,%esp
f0101b94:	5b                   	pop    %ebx
f0101b95:	5e                   	pop    %esi
f0101b96:	5f                   	pop    %edi
f0101b97:	5d                   	pop    %ebp
f0101b98:	c3                   	ret    
f0101b99:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101ba0:	89 f9                	mov    %edi,%ecx
f0101ba2:	b8 20 00 00 00       	mov    $0x20,%eax
f0101ba7:	29 f8                	sub    %edi,%eax
f0101ba9:	d3 e2                	shl    %cl,%edx
f0101bab:	89 54 24 08          	mov    %edx,0x8(%esp)
f0101baf:	89 c1                	mov    %eax,%ecx
f0101bb1:	89 da                	mov    %ebx,%edx
f0101bb3:	d3 ea                	shr    %cl,%edx
f0101bb5:	8b 4c 24 08          	mov    0x8(%esp),%ecx
f0101bb9:	09 d1                	or     %edx,%ecx
f0101bbb:	89 f2                	mov    %esi,%edx
f0101bbd:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101bc1:	89 f9                	mov    %edi,%ecx
f0101bc3:	d3 e3                	shl    %cl,%ebx
f0101bc5:	89 c1                	mov    %eax,%ecx
f0101bc7:	d3 ea                	shr    %cl,%edx
f0101bc9:	89 f9                	mov    %edi,%ecx
f0101bcb:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0101bcf:	89 eb                	mov    %ebp,%ebx
f0101bd1:	d3 e6                	shl    %cl,%esi
f0101bd3:	89 c1                	mov    %eax,%ecx
f0101bd5:	d3 eb                	shr    %cl,%ebx
f0101bd7:	09 de                	or     %ebx,%esi
f0101bd9:	89 f0                	mov    %esi,%eax
f0101bdb:	f7 74 24 08          	divl   0x8(%esp)
f0101bdf:	89 d6                	mov    %edx,%esi
f0101be1:	89 c3                	mov    %eax,%ebx
f0101be3:	f7 64 24 0c          	mull   0xc(%esp)
f0101be7:	39 d6                	cmp    %edx,%esi
f0101be9:	72 15                	jb     f0101c00 <__udivdi3+0x100>
f0101beb:	89 f9                	mov    %edi,%ecx
f0101bed:	d3 e5                	shl    %cl,%ebp
f0101bef:	39 c5                	cmp    %eax,%ebp
f0101bf1:	73 04                	jae    f0101bf7 <__udivdi3+0xf7>
f0101bf3:	39 d6                	cmp    %edx,%esi
f0101bf5:	74 09                	je     f0101c00 <__udivdi3+0x100>
f0101bf7:	89 d8                	mov    %ebx,%eax
f0101bf9:	31 ff                	xor    %edi,%edi
f0101bfb:	e9 40 ff ff ff       	jmp    f0101b40 <__udivdi3+0x40>
f0101c00:	8d 43 ff             	lea    -0x1(%ebx),%eax
f0101c03:	31 ff                	xor    %edi,%edi
f0101c05:	e9 36 ff ff ff       	jmp    f0101b40 <__udivdi3+0x40>
f0101c0a:	66 90                	xchg   %ax,%ax
f0101c0c:	66 90                	xchg   %ax,%ax
f0101c0e:	66 90                	xchg   %ax,%ax

f0101c10 <__umoddi3>:
f0101c10:	f3 0f 1e fb          	endbr32 
f0101c14:	55                   	push   %ebp
f0101c15:	57                   	push   %edi
f0101c16:	56                   	push   %esi
f0101c17:	53                   	push   %ebx
f0101c18:	83 ec 1c             	sub    $0x1c,%esp
f0101c1b:	8b 44 24 3c          	mov    0x3c(%esp),%eax
f0101c1f:	8b 74 24 30          	mov    0x30(%esp),%esi
f0101c23:	8b 5c 24 34          	mov    0x34(%esp),%ebx
f0101c27:	8b 7c 24 38          	mov    0x38(%esp),%edi
f0101c2b:	85 c0                	test   %eax,%eax
f0101c2d:	75 19                	jne    f0101c48 <__umoddi3+0x38>
f0101c2f:	39 df                	cmp    %ebx,%edi
f0101c31:	76 5d                	jbe    f0101c90 <__umoddi3+0x80>
f0101c33:	89 f0                	mov    %esi,%eax
f0101c35:	89 da                	mov    %ebx,%edx
f0101c37:	f7 f7                	div    %edi
f0101c39:	89 d0                	mov    %edx,%eax
f0101c3b:	31 d2                	xor    %edx,%edx
f0101c3d:	83 c4 1c             	add    $0x1c,%esp
f0101c40:	5b                   	pop    %ebx
f0101c41:	5e                   	pop    %esi
f0101c42:	5f                   	pop    %edi
f0101c43:	5d                   	pop    %ebp
f0101c44:	c3                   	ret    
f0101c45:	8d 76 00             	lea    0x0(%esi),%esi
f0101c48:	89 f2                	mov    %esi,%edx
f0101c4a:	39 d8                	cmp    %ebx,%eax
f0101c4c:	76 12                	jbe    f0101c60 <__umoddi3+0x50>
f0101c4e:	89 f0                	mov    %esi,%eax
f0101c50:	89 da                	mov    %ebx,%edx
f0101c52:	83 c4 1c             	add    $0x1c,%esp
f0101c55:	5b                   	pop    %ebx
f0101c56:	5e                   	pop    %esi
f0101c57:	5f                   	pop    %edi
f0101c58:	5d                   	pop    %ebp
f0101c59:	c3                   	ret    
f0101c5a:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0101c60:	0f bd e8             	bsr    %eax,%ebp
f0101c63:	83 f5 1f             	xor    $0x1f,%ebp
f0101c66:	75 50                	jne    f0101cb8 <__umoddi3+0xa8>
f0101c68:	39 d8                	cmp    %ebx,%eax
f0101c6a:	0f 82 e0 00 00 00    	jb     f0101d50 <__umoddi3+0x140>
f0101c70:	89 d9                	mov    %ebx,%ecx
f0101c72:	39 f7                	cmp    %esi,%edi
f0101c74:	0f 86 d6 00 00 00    	jbe    f0101d50 <__umoddi3+0x140>
f0101c7a:	89 d0                	mov    %edx,%eax
f0101c7c:	89 ca                	mov    %ecx,%edx
f0101c7e:	83 c4 1c             	add    $0x1c,%esp
f0101c81:	5b                   	pop    %ebx
f0101c82:	5e                   	pop    %esi
f0101c83:	5f                   	pop    %edi
f0101c84:	5d                   	pop    %ebp
f0101c85:	c3                   	ret    
f0101c86:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101c8d:	8d 76 00             	lea    0x0(%esi),%esi
f0101c90:	89 fd                	mov    %edi,%ebp
f0101c92:	85 ff                	test   %edi,%edi
f0101c94:	75 0b                	jne    f0101ca1 <__umoddi3+0x91>
f0101c96:	b8 01 00 00 00       	mov    $0x1,%eax
f0101c9b:	31 d2                	xor    %edx,%edx
f0101c9d:	f7 f7                	div    %edi
f0101c9f:	89 c5                	mov    %eax,%ebp
f0101ca1:	89 d8                	mov    %ebx,%eax
f0101ca3:	31 d2                	xor    %edx,%edx
f0101ca5:	f7 f5                	div    %ebp
f0101ca7:	89 f0                	mov    %esi,%eax
f0101ca9:	f7 f5                	div    %ebp
f0101cab:	89 d0                	mov    %edx,%eax
f0101cad:	31 d2                	xor    %edx,%edx
f0101caf:	eb 8c                	jmp    f0101c3d <__umoddi3+0x2d>
f0101cb1:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101cb8:	89 e9                	mov    %ebp,%ecx
f0101cba:	ba 20 00 00 00       	mov    $0x20,%edx
f0101cbf:	29 ea                	sub    %ebp,%edx
f0101cc1:	d3 e0                	shl    %cl,%eax
f0101cc3:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101cc7:	89 d1                	mov    %edx,%ecx
f0101cc9:	89 f8                	mov    %edi,%eax
f0101ccb:	d3 e8                	shr    %cl,%eax
f0101ccd:	8b 4c 24 08          	mov    0x8(%esp),%ecx
f0101cd1:	89 54 24 04          	mov    %edx,0x4(%esp)
f0101cd5:	8b 54 24 04          	mov    0x4(%esp),%edx
f0101cd9:	09 c1                	or     %eax,%ecx
f0101cdb:	89 d8                	mov    %ebx,%eax
f0101cdd:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101ce1:	89 e9                	mov    %ebp,%ecx
f0101ce3:	d3 e7                	shl    %cl,%edi
f0101ce5:	89 d1                	mov    %edx,%ecx
f0101ce7:	d3 e8                	shr    %cl,%eax
f0101ce9:	89 e9                	mov    %ebp,%ecx
f0101ceb:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0101cef:	d3 e3                	shl    %cl,%ebx
f0101cf1:	89 c7                	mov    %eax,%edi
f0101cf3:	89 d1                	mov    %edx,%ecx
f0101cf5:	89 f0                	mov    %esi,%eax
f0101cf7:	d3 e8                	shr    %cl,%eax
f0101cf9:	89 e9                	mov    %ebp,%ecx
f0101cfb:	89 fa                	mov    %edi,%edx
f0101cfd:	d3 e6                	shl    %cl,%esi
f0101cff:	09 d8                	or     %ebx,%eax
f0101d01:	f7 74 24 08          	divl   0x8(%esp)
f0101d05:	89 d1                	mov    %edx,%ecx
f0101d07:	89 f3                	mov    %esi,%ebx
f0101d09:	f7 64 24 0c          	mull   0xc(%esp)
f0101d0d:	89 c6                	mov    %eax,%esi
f0101d0f:	89 d7                	mov    %edx,%edi
f0101d11:	39 d1                	cmp    %edx,%ecx
f0101d13:	72 06                	jb     f0101d1b <__umoddi3+0x10b>
f0101d15:	75 10                	jne    f0101d27 <__umoddi3+0x117>
f0101d17:	39 c3                	cmp    %eax,%ebx
f0101d19:	73 0c                	jae    f0101d27 <__umoddi3+0x117>
f0101d1b:	2b 44 24 0c          	sub    0xc(%esp),%eax
f0101d1f:	1b 54 24 08          	sbb    0x8(%esp),%edx
f0101d23:	89 d7                	mov    %edx,%edi
f0101d25:	89 c6                	mov    %eax,%esi
f0101d27:	89 ca                	mov    %ecx,%edx
f0101d29:	0f b6 4c 24 04       	movzbl 0x4(%esp),%ecx
f0101d2e:	29 f3                	sub    %esi,%ebx
f0101d30:	19 fa                	sbb    %edi,%edx
f0101d32:	89 d0                	mov    %edx,%eax
f0101d34:	d3 e0                	shl    %cl,%eax
f0101d36:	89 e9                	mov    %ebp,%ecx
f0101d38:	d3 eb                	shr    %cl,%ebx
f0101d3a:	d3 ea                	shr    %cl,%edx
f0101d3c:	09 d8                	or     %ebx,%eax
f0101d3e:	83 c4 1c             	add    $0x1c,%esp
f0101d41:	5b                   	pop    %ebx
f0101d42:	5e                   	pop    %esi
f0101d43:	5f                   	pop    %edi
f0101d44:	5d                   	pop    %ebp
f0101d45:	c3                   	ret    
f0101d46:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101d4d:	8d 76 00             	lea    0x0(%esi),%esi
f0101d50:	29 fe                	sub    %edi,%esi
f0101d52:	19 c3                	sbb    %eax,%ebx
f0101d54:	89 f2                	mov    %esi,%edx
f0101d56:	89 d9                	mov    %ebx,%ecx
f0101d58:	e9 1d ff ff ff       	jmp    f0101c7a <__umoddi3+0x6a>
