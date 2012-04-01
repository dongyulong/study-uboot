有两个宏需要注意一下

#ifndef CONFIG_SKIP_LOWLEVEL_INIT
#ifndef CONFIG_SKIP_RELOCATE_UBOOT

从include/configs/smdk2410.h中没有发现相关定义
所以所选代码应该会走，调试汇编最好的方法
是点灯，在代码中点个灯看看。

#undef CONFIG_USE_IRQ			/* we don't need IRQ/FIQ stuff */
应该是没有使用irq，相关代码应该可以删减


@文件包含处理

 

#include <config.h>

@由顶层的mkconfig生成，其中只包含了一个文件：configs/<顶层makefile中6个参数的第1个参数>.h  

#include <version.h>  


/*

*************************************************************************

*

* Jump vector table as in table 3.1 in [1]

*

*************************************************************************

*/

@向量跳转表，每条占一字节，地址范围为0x0000 0000～0x0000 0020

@ARM体系结构规定在上电复位后的起始位置，必须有8条连续的跳转指令，通过硬件实现。他们就是异常向量表。ARM在上电复位后，是从 0x00000000开始启动的，其实如果bootloader存在，在执行下面第一条指令后，就无条件跳转到start_code，下面一部分并没执 行。设置异常向量表的作用是识别bootloader。以后系统每当有异常出现，则CPU会根据异常号，从内存的0x00000000处开始查表做相应的 处理

 

.globl _start

@_start是GNU汇编器的默认入口标签，.globl将_start声明为外部程序可访问的标签，.globl是GNU汇编的保留关键字，前面加点是GNU汇编的语法

_start: b       start_code   @0x00

@ARM上电后执行的第一条指令，也即复位向量，跳转到start_code

ldr pc, _undefined_instruction @0x04

ldr pc, _software_interrupt  @0x08

ldr pc, _prefetch_abort  @0x0c

ldr pc, _data_abort   @0x10

ldr pc, _not_used   @0x14

ldr pc, _irq    @0x18

ldr pc, _fiq    @0x1c

@对于ARM数据从内存到CPU之间的移动只能通过L/S指令，如：ldr r0,0x12345678为把0x12345678内存中的数据写到r0中，还有一个就是ldr伪指令，如：ldr r0,=0x12345678为把0x12345678地址写到r0中，mov只能完成寄存器间数据的移动，而且立即数长度限制在8位

 

_undefined_instruction: .word undefined_instruction

_software_interrupt: .word software_interrupt

_prefetch_abort: .word prefetch_abort

_data_abort:  .word data_abort

_not_used:  .word not_used

_irq:   .word irq

_fiq:   .word fiq

@.word为GNU ARM汇编特有的伪操作，为分配一段字内存单元（分配的单元为字对齐的），可以使用.word把标志符作为常量使用。如_fiq:.word fiq即把fiq存入内存变量_fiq中，也即是把fiq放到地址_fiq中。

 

 .balignl 16,0xdeadbeef

@.balignl是.balign的变体，为伪操作符，控制对齐方式。它的意思是以当前地址开始，地址计数器必须是以第一个参数为整数倍的地址为尾，在 前面记录一个长字长度的信息，信息为第二个参数.

/*

*************************************************************************

*

* Startup Code (called from the ARM reset exception vector)

*

* do important init only if we don't start from memory!

* relocate armboot to ram

* setup stack

* jump to second stage

*

*************************************************************************

*/

@代码数据地址的初始化（不知道理解的对不对）

 

_TEXT_BASE:

.word TEXT_BASE

@TEXT_BASE在开发板相关的目录中的config.mk文档中定义,他定义了代码在运行时所在的地址,那么_TEXT_BASE中保存了这个地址（这个TEXT_BASE怎么来的还不清楚）

 

.globl _armboot_start

_armboot_start:

.word _start

@用_start来初始化_armboot_start。

 

/*

* These are defined in the board-specific linker script.

*/

@下面这些是定义在开发板目录链接脚本中的

 

.globl _bss_start

_bss_start:

.word __bss_start

@__bss_start定义在和开发板相关的u-boot.lds中，_bss_start保存的是__bss_start标号所在的地址。

 

.globl _bss_end

_bss_end:

.word _end

@同上，这样赋值是因为代码所在地址非编译时的地址，直接取得该标号对应地址。


/*

* the actual start code

*/

@复位后执行程序

@真正的初始化从这里开始了。其实在CPU一上电以后就是跳到这里执行的

start_code:

/*

* set the cpu to SVC32 mode

*/

@更改处理器模式为管理模式

@对状态寄存器的修改要按照：读出-修改-写回的顺序来执行

@

31 30 29 28 ---   7   6   -   4    3   2   1   0

N  Z  C  V        I   F       M4  M3  M2 M1 M0

0   0   0  0   0     User26模式

0   0   0  0   1     FIQ26模式

0   0   0  1   0     IRQ26模式

0   0   0  1   1     SVC26模式

1   0   0  0   0     User模式

1   0   0  0   1     FIQ模式

1   0   0  1   0     IRQ模式

1   0   0  1   1     SVC模式

1   0   1  1   1     ABT模式

1   1   0  1   1     UND模式

1   1   1  1   1     SYS模式

 

 mrs r0,cpsr

@将cpsr的值读到r0中

bic r0,r0,#0x1f

@清除M0~M4

 orr r0,r0,#0xd3

@禁止IRQ,FIQ中断，并将处理器置于管理模式

msr cpsr,r0


@针对S3C2400和S3C2410进行特殊处理

@CONFIG_S3C2400、CONFIG_S3C2410等定义在include/configs/下不同开发板的头文件中

#if defined(CONFIG_S3C2400) || defined(CONFIG_S3C2410)

/* turn off the watchdog */

 

@关闭看门狗定时器的自动复位功能并屏蔽所有中断，上电后看门狗为开，中断为关

# if defined(CONFIG_S3C2400)

#  define pWTCON  0x15300000

#  define INTMSK  0x14400008 /* Interupt-Controller base addresses */

#  define CLKDIVN 0x14800014 /* clock divisor register */

#else @s3c2410的配置

#  define pWTCON  0x53000000  

@pWTCON定义为看门狗控制寄存器的地址（s3c2410和s3c2440相同）

#  define INTMSK  0x4A000008 /* Interupt-Controller base addresses */

@INTMSK定义为主中断屏蔽寄存器的地址（s3c2410和s3c2440相同）

#  define INTSUBMSK  0x4A00001C

@INTSUBMSK定义为副中断屏蔽寄存器的地址（s3c2410和s3c2440相同）

#  define CLKDIVN  0x4C000014 /* clock divisor register */

@CLKDIVN定义为时钟分频控制寄存器的地址（s3c2410和s3c2440相同）

# endif

@至此寄存器地址设置完毕

 

 ldr     r0, =pWTCON

mov     r1, #0x0

str     r1, [r0]

@对于S3C2440和S3C2410的WTCON寄存器的[0]控制允许或禁止看门狗定时器的复位输出功能，设置为“0”禁止复位功能。

 

 /*

* mask all IRQs by setting all bits in the INTMR - default

*/

mov r1, #0xffffffff

ldr r0, =INTMSK

str r1, [r0]

# if defined(CONFIG_S3C2410)

ldr r1, =0x3ff  @2410好像应该为7ff才对（不理解uboot为何是这个数字）

 ldr r0, =INTSUBMSK

str r1, [r0]

# endif

@对于S3C2410的INTMSK寄存器的32位和INTSUBMSK寄存器的低11位每一位对应一个中断，相应位置“1”为不响应相应的中断。对于S3C2440的INTSUBMSK有15位可用，所以应该为0x7fff了。

 

 /* FCLK:HCLK:PCLK = 1:2:4 */

/* default FCLK is 120 MHz ! */

ldr r0, =CLKDIVN

mov r1, #3

str r1, [r0]

@时钟分频设置，FCLK为核心提供时钟，HCLK为AHB（ARM920T,内存控制器，中断控制 器，LCD控制器，DMA和主USB模块）提供时钟，PCLK为APB（看门狗、IIS、I2C、PWM、MMC、ADC、UART、GPIO、RTC、 SPI）提供时钟。分频数一般选择1：4：8，所以HDIVN=2,PDIVN=1，CLKDIVN=5，这里仅仅是配置了分频寄存器，关于 MPLLCON的配置肯定写在lowlevel_init.S中了哦。

@归纳出CLKDIVN的值跟分频的关系：

@0x0 = 1:1:1  ,  0x1 = 1:1:2 , 0x2 = 1:2:2  ,  0x3 = 1:2:4,  0x4 = 1:4:4,  0x5 = 1:4:8, 0x6 = 1:3:3, 

0x7 = 1:3:6

@S3C2440的输出时钟计算式为:Mpll=(2*m*Fin)/(p*2^s)

S3C2410的输出时钟计算式为:Mpll=(m*Fin)/(p*2^s)

m=M(the value for divider M)+8;p=P(the value for divider P)+2

M,P,S的选择根据datasheet中PLL VALUE SELECTION TABLE表格进行，

 

我的开发板晶振为16.9344M，所以输出频率选为：399.65M的话M=0x6e,P=3,S=1

@s3c2440增加了摄像头,其FCLK、HCLK、PCLK的分频数还受到CAMDIVN[9]（默认为0）,CAMDIVN[8]（默认为0）的影响

#endif /* CONFIG_S3C2400 || CONFIG_S3C2410 */

 

 /*

* we do sys-critical inits only at reboot,

* not when booting from ram!

*/

@选择是否初始化CPU

#ifndef CONFIG_SKIP_LOWLEVEL_INIT

bl cpu_init_crit

@执行CPU初始化，BL完成跳转的同时会把后面紧跟的一条指令地址保存到连接寄存器LR（R14）中。以使子程序执行完后正常返回。

#endif

 

@UBOOT将自己从FLASH中转移到RAM中

#ifndef CONFIG_SKIP_RELOCATE_UBOOT

relocate:    /* relocate U-Boot to RAM     */

adr r0, _start  /* r0 <- current position of code   */

ldr r1, _TEXT_BASE  /* test if we run from flash or RAM */

cmp     r0, r1                  /* don't reloc during debug         */

beq     stack_setup

@通过比较_start和_TEXT_BASE值来确定uboot当前所在位置是否在内存中，若两值不同则表示在内存中运行，因为_start为uboot当前地址，_TEXT_BASE为连接时存放地址

 

 ldr r2, _armboot_start

@_armboot_start为_start地址

ldr r3, _bss_start

@_bss_start为数据段地址

sub r2, r3, r2  /* r2 <- size of armboot            */

add r2, r0, r2  /* r2 <- source end address         */

 

copy_loop:

ldmia r0!, {r3-r10}  /* copy from source address [r0]    */

stmia r1!, {r3-r10}  /* copy to   target address [r1]    */

@LDM(STM)用于在寄存器所指的一片连续存储器和寄存器列表的寄存器间进行数据移动，或是进行压栈和出栈操作。

格式为：LDM(STM){条件}{类型}基址寄存器{！}，寄存器列表{^}

对于类型有以下几种情况： IA 每次传送后地址加1，用于移动数据块

IB 每次传送前地址加1，用于移动数据块

DA 每次传送后地址减1，用于移动数据块

DB 每次传送前地址减1，用于移动数据块

FD 满递减堆栈，用于操作堆栈（即先移动指针再操作数据，相当于DB）

ED 空递减堆栈，用于操作堆栈（即先操作数据再移动指针，相当于DA）

FA 满递增堆栈，用于操作堆栈（即先移动指针再操作数据，相当于IB）

EA 空递增堆栈，用于操作堆栈（即先操作数据再移动指针，相当于IA）

（这里是不是应该要涉及到NAND或者NOR的读写？没有看出来）

 

 cmp r0, r2   /* until source end addreee [r2]    */

ble copy_loop

#endif /* CONFIG_SKIP_RELOCATE_UBOOT */

 

 /* Set up the stack          */

@初始化堆栈

stack_setup:

ldr r0, _TEXT_BASE  /* upper 128 KiB: relocated uboot   */
sub r0, r0, #CONFIG_SYS_MALLOC_LEN /* malloc area                      */
sub r0, r0, #CONFIG_SYS_GBL_DATA_SIZE /* bdinfo                        */
#ifdef CONFIG_USE_IRQ
sub r0, r0, #(CONFIG_STACKSIZE_IRQ+CONFIG_STACKSIZE_FIQ)
#endif
sub sp, r0, #12  /* leave 3 words for abort-stack    */

 

@初始化数据段

clear_bss:
ldr r0, _bss_start  /* find start of bss segment        */
ldr r1, _bss_end  /* stop here                        */
mov r2, #0x00000000  /* clear                            */

 

clbss_l:str r2, [r0]  /* clear loop...                    */
add r0, r0, #4
cmp r0, r1
ble clbss_l

 

@跳到阶段二C语言中去

ldr pc, _start_armboot

 

_start_armboot: .word start_armboot

@start_armboot在/lib_arm/中，到这里因该是第一阶段已经完成了吧，下面就要去C语言中执行第二阶段了吧
