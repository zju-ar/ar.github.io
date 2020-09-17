;===========================================Copyright Information===========================================
; author: ar @ AAA
; stu_num: 3180104466
; E-mail: ar@zju.edu.cn
; Designed by ar in ZJU 2020 *All Rights Preserved*
; In honor of Mr. M.K. Hu and his professional, patient and persistent guidance in programming since 2010
;===========================================================================================================
.386
data segment use16
 file_name db 20h dup(0) ; "8.3" file name format in DOS
 fp dw 0
 file_len dd 0
 file_offset dd 0
 page_offset dd 0
 n dd 0
 bytes_in_buffer dw 0
 bytes_on_line dw 0
 banner db "Please input filename:", 0Dh, 0Ah, '$'
 hex db "0123456789ABCDEF", 0
 warning_no_input db "Empty input? Please try to input again!", 0Dh, 0Ah, "Please input filename:", 0Dh, 0Ah, '$'
 error_cannot_open db 0Dh, 0Ah, "Cannot open file or the file is empty!", 0Dh, 0Ah, "Press any key to exit...", 0Dh, 0Ah, '$'
 instructions dw 075Bh, 0745h, 0773h, 0763h, 075Dh, 0720h, 072Dh, 0720h, 0745h, 0778h, 0769h, 0774h, 68 dup (0020h) 
              dw 075Bh, 0748h, 076Fh, 076Dh, 0765h, 075Dh, 0720h, 072Dh, 0720h, 0754h, 0768h, 0765h
	            dw 0720h, 0746h, 0769h, 0772h, 0773h, 0774h, 0720h, 0750h, 0761h, 0767h, 0765h, 57 dup (0020h)
	            dw 075Bh, 0745h, 076Eh, 0764h, 075Dh, 0720h, 072Dh, 0720h, 0754h, 0768h, 0765h, 0720h
	            dw 074Ch, 0761h, 0773h, 0774h, 0720h, 0750h, 0761h, 0767h, 0765h, 59 dup (0020h)
	            dw 075Bh, 0750h, 0761h, 0767h, 0765h, 0755h, 0770h, 075Dh, 0720h, 072Dh, 0720h, 0754h
	            dw 0768h, 0765h, 0720h, 0750h, 0772h, 0765h, 0776h, 0769h, 076Fh, 0775h, 0773h, 0720h, 0750h, 0761h, 0767h, 0765h, 52 dup (0020h)
	            dw 075Bh, 0750h, 0761h, 0767h, 0765h, 0744h, 076Fh, 0777h, 076Eh, 075Dh, 0720h, 072Dh, 0720h, 0754h, 0768h
	            dw 0765h, 0720h, 074Eh, 0765h, 0778h, 0774h, 0720h, 0750h, 0761h, 0767h, 0765h, 54 dup (0020h)
 buffer db 50h, 0, 50h dup(0)
 file_buffer db 400h dup(0)
data ends
code segment use16
 assume cs: code, ds: data, ss: stk
input_string proc
 push ebp
 push ebx
 push esi
 push edi
 mov ecx, 0
 mov ah, 0Ah
 mov dx, si
 int 21h
 mov ah, 02h
 mov dl, 0Dh
 int 21h
 mov dl, 0Ah
 int 21h
 mov cl, [si+01h]
 jcxz input_string_error
 lea si, [si+02h]
 cld
 rep movsb ; transfer filename from buffer to file_name string
input_string_finish:
 pop edi
 pop esi
 pop ebx
 pop ebp
 ret
input_string_error: ; repeat reading if no input
 mov ah, 09h
 mov dx, offset warning_no_input
 int 21h
 pop edi
 pop esi
 pop ebx
 pop ebp
 jmp input_string
input_string endp
clear_screen proc ; command *cls*
 push ebp
 push ebx
 push ecx
 push edx
 push esi
 push edi
 cld
 mov eax, 20h
 mov ecx, 80*25 ; 80 characters per line & 25 lines per page
 mov edi, 0 ; ES == 0xB800
 rep stosw
 mov si, offset instructions
 mov di, 2*18*80 ; to line 18
 mov cx, (offset buffer - offset instructions)/2
 rep movsw
 pop edi
 pop esi
 pop edx
 pop ecx
 pop ebx
 pop ebp
 ret
clear_screen endp
print_line proc
 mov ecx, 08h
 mov ebx, 0
 mov bx, offset hex
print_separation_symbols:
 mov word ptr es:[di+21*2], 0F7Ch ; '|'
 mov word ptr es:[di+21*2+12*2], 0F7Ch
 mov word ptr es:[di+21*2+12*4], 0F7Ch
 mov eax, page_offset 
 add eax, ebp ; EAX == page_offset (page offset) + EBP (line offset) == real offset
print_offset:
 rol eax, 04h
 push eax
 and eax, 0Fh
 xlat
 mov ah, 07h
 mov word ptr es:[di], ax
 pop eax
 add di, 02h
 dec cx
 jnz print_offset
 mov word ptr es:[di], 073Ah ; ':'
 add di, 04h
 mov esi, 0
 mov eax, 0700h
 push di ; the last line may be not full, but offset always occupies 32-bit long
print_char_hex:
 mov al, file_buffer[bp+si]
 rol al, 04h
 push ax
 and al, 0Fh
 xlat
 mov word ptr es:[di], ax
 pop ax
 rol al, 04h
 and al, 0Fh
 xlat
 mov word ptr es:[di+02h], ax
 add di, 06h
 inc si
 cmp si, bytes_on_line
 jb print_char_hex
 pop di
 add di, (59-10)*2 ; to ascii character area
 mov esi, 0
 mov eax, 0700h
print_char:
 mov al, file_buffer[bp+si]
 mov word ptr es:[di], ax
 add di, 02h
 inc si
 cmp si, bytes_on_line
 jb print_char
 add ebp, 10h ; locate next line
print_line_done:
 ret
print_line endp
print_page proc
calculate_rows:
 mov ecx, 0
 mov cx, bytes_in_buffer
 add cx, 0Fh
 shr cx, 04h ; rows = (bytes_in_buffer + 15) / 16
 dec cx ; except the last line (maybe not full)
 push cx
 jcxz only_one_line ; default: if only one line on the last page
 mov word ptr bytes_on_line, 10h
cls:
 call clear_screen
 mov edi, 0
writeln:
 push cx
 call print_line
next_line:
 pop cx
 add di, 5*2 ; to the next line
 dec cx
 jnz writeln
final_line:
 pop cx
 shl cx, 04h
 mov ax, bytes_in_buffer
 sub ax, cx ; bytes_on_line = (CX == rows-1) ? (bytes_in_buffer - (CX-1) * 16) : 16
 mov word ptr bytes_on_line, ax
 call print_line
done:
 ret
only_one_line:
 call clear_screen
 mov edi, 0
 jmp final_line
print_page endp
main:
 mov ax, data
 mov ds, ax
 mov es, ax
read_file_name:
 mov ah, 09h
 mov dx, offset banner
 int 21h
 mov si, offset buffer
 mov di, offset file_name
 mov ecx, 0
 call input_string ; gets(file_name)
 mov ebx, 0
 mov edi, 0
 mov eax, 0B800h
 mov es, ax ; 80*25 text mode
open_file:
 mov ax, 3D00h ; open file: AH = 3Dh, AL = 0
 mov dx, offset file_name
 int 21h ; *stc* will occur with any occurred error
 jc open_error
 mov word ptr fp, ax
 jmp move_fp_to_eof
open_error:
 mov ah, 09h
 mov dx, offset error_cannot_open
 int 21h
 mov eax, 0
 int 16h
 mov eax, 4C01h ; exit(1) means error in *opening file*
 int 21h
move_fp_to_eof:
 mov ax, 4202h ; move to EOF: AH = 42h, AL = 02h
 mov bx, fp
 xor cx, cx
 xor dx, dx ; *xor* sets CF & OF zero
 int 21h
 jc open_error
store_file_length:
 mov word ptr file_len[0], ax
 mov word ptr file_len[2], dx ; long int file_len = DX:AX (little-endian rule)
 cmp dword ptr file_len, 0 ; default: empty file
 je open_error
move_fp_to_the_head:
 mov ax, 4200h ; move to head: AH = 42h, AL = 0
 mov bx, fp
 xor cx, cx
 xor dx, dx
 int 21h
 jc open_error
 mov eax, 03h
 int 10h
calculate_n:
 mov eax, file_len
 sub eax, file_offset
 mov dword ptr n, eax
 mov eax, 0
 cmp dword ptr n, 100h
 jae bytes_in_buffer_full
 jmp bytes_in_buffer_not_full
bytes_in_buffer_full:
 mov word ptr bytes_in_buffer, 100h
 jmp move_fp_to_offset
bytes_in_buffer_not_full:
 mov eax, n
 mov word ptr bytes_in_buffer, ax
move_fp_to_offset:
 mov ax, 4200h ; move to head: AH = 42h, AL = 0
 mov bx, fp
 mov cx, word ptr file_offset[2]
 mov dx, word ptr file_offset[0]
 int 21h
 jc open_error
transfer_into_file_buffer:
 mov ah, 3Fh
 mov bx, fp
 mov cx, bytes_in_buffer
 mov dx, offset file_buffer
 int 21h
show:
 mov ebp, 0
 call print_page
 mov eax, 0
 int 16h
case_bioskey_of:
 cmp ax, 011Bh ; *Esc*
 je close_file
 cmp ax, 4900h ; *PageUp*
 je press_pageup
 cmp ax, 5100h ; *PageDown*
 je press_pagedown
 cmp ax, 4700h ; *Home*
 je press_home
 cmp ax, 4F00h ; *End*
 je press_end
default:
 nop
 jmp calculate_n
press_pageup:
 sub dword ptr page_offset, 100h
 sub dword ptr file_offset, 100h
 cmp dword ptr file_offset, 0
 jl press_home ; must use *jl* instead of *jb* , correction: mov dword ptr file_offset, 0
 jmp default
press_pagedown:
 add dword ptr page_offset, 100h
 add dword ptr file_offset, 100h
 mov eax, file_offset
 cmp eax, file_len
 jae press_pageup ; correction: sub dword ptr file_offset, 100h
 jmp default
press_home:
 mov dword ptr page_offset, 0
 mov dword ptr file_offset, 0
 jmp default
press_end:
 mov eax, file_len
 mov edx, eax
 mov dword ptr file_offset, eax
 shr eax, 08h
 shl eax, 08h
 mov dword ptr page_offset, eax ; page_offset == last page offset
 sub edx, eax ;  EDX == file_len % 0x100
 sub dword ptr file_offset, edx
 mov eax, file_offset
 cmp eax, file_len
 je press_pageup ; correction: sub dword ptr file_offset, 100h
 jmp default
close_file:
 mov ah, 3Eh
 mov bx, fp
 int 21h
exit:
 mov eax, 03h
 int 10h
 mov eax, 4C00h
 int 21h
code ends
stk segment stack use16
 db 400h dup(?)
stk ends
end main
