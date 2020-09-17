# Linux Assembly
# AT&T Standard

.section .data
msg:
.ascii "Hello, world!\n"

.section .text
.globl _start
_start :
movl $0x04, %eax # sys_write
movl $0x01, %ebx # stdout
movl $msg, %ecx # the address of string
movl $0x0E, %edx # string length
int $0x80

movl $0x01, %eax # sys_exit
movl $0, %ebx # return code
int $0x80
