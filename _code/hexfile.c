/* ���뼰���в���:
�Ѵ��ļ����Ƶ�xp�����d:\tc��
����tc��:
Alt+Fѡ��File->Load->hexfile.c
Alt+Cѡ��Compile->Compile to OBJ ����
Alt+Cѡ��Compile->Line EXE file ����
Alt+Rѡ��Run->Run ����

    ��

�Ѵ��ļ����Ƶ�dosbox86\tc��, 
����dosbox86
File->DOS Shell
cd \tc
tc
Alt+Fѡ��File->Load->hexfile.c
Alt+Cѡ��Compile->Compile to OBJ ����
Alt+Cѡ��Compile->Line EXE file ����
Alt+Rѡ��Run->Run ����
 */
#include <stdio.h>
#include <stdlib.h>
#include <bios.h>
#include <io.h>
#define PageUp   0x4900
#define PageDown 0x5100
#define Home     0x4700
#define End      0x4F00
#define Esc      0x011B

void char2hex(char xx, char s[]) /* ��8λ��ת����16���Ƹ�ʽ */
{
   char t[] = "0123456789ABCDEF";
   s[0] = t[(xx >> 4) & 0x0F]; /* ��4λ */
   s[1] = t[xx & 0x0F];        /* ��4λ */
}

void long2hex(long offset, char s[]) /* ��32λ��ת����16���Ƹ�ʽ */
{
   int i;
   char xx;
   for(i=0; i<4; i++)
   {
      offset = _lrotl(offset, 8); /* ѭ������8λ, �Ѹ�8λ�Ƶ���8λ */
      xx = offset & 0xFF;         /* ��24λ��0, ������8λ */
      char2hex(xx, &s[i*2]);      /* ��8λ��ת����16���Ƹ�ʽ */
   }
}

void show_this_row(int row, long offset, char buf[], int bytes_on_row)
{  /* ��ʾ��ǰһ��:   �к�       ƫ��    �����׵�ַ      ��ǰ���ֽ��� */
   char far *vp = (char far *)0xB8000000;
   char s[]= 
      "00000000: xx xx xx xx|xx xx xx xx|xx xx xx xx|xx xx xx xx  ................";
   /*  |         |                                                |
       |         |                                                |
       00        10                                               59
       ����3�����������߶�Ӧλ��Ԫ�ص��±�;
       ����s�����ݾ���ÿ�е������ʽ:
       �������8��0��ʾ��ǰƫ�Ƶ�ַ;
       ����xx����16���Ƹ�ʽ��һ���ֽ�;
       ����s[59]��ʼ��16�����������buf����Ԫ�ض�Ӧ��ASCII�ַ���
    */
   char pattern[] = 
      "00000000:            |           |           |                             ";
   int i;
   strcpy(s, pattern);
   long2hex(offset, s); /* ��32λƫ�Ƶ�ַת����16���Ƹ�ʽ����s���8��'0'�� */
   for(i=0; i<bytes_on_row; i++) /* ��buf�и����ֽ�ת����16���Ƹ�ʽ����s�е�xx�� */
   {
      char2hex(buf[i], s+10+i*3);
   }
   for(i=0; i<bytes_on_row; i++) /* ��buf�и����ֽ�����s�Ҳ�С���㴦 */
   {
      s[59+i] = buf[i];
   }
   vp = vp + row*80*2;           /* ����row�ж�Ӧ����Ƶ��ַ */
   for(i=0; i<sizeof(s)-1; i++)  /* ���s */
   {
      vp[i*2] = s[i];
      if(i<59 && s[i] == '|')    /* �����ߵ�ǰ��ɫ��Ϊ�����Ȱ�ɫ */
         vp[i*2+1] = 0x0F;
      else                       /* �����ַ���ǰ��ɫ��Ϊ��ɫ */
         vp[i*2+1] = 0x07;
   }
}

void clear_this_page(void)       /* �����Ļ0~15�� */
{
   char far *vp = (char far *)0xB8000000;
   int i, j;
   for(i=0; i<16; i++)           /* ����п���ʹ��rep stosw����80*16��0020h */
   {
      for(j=0; j<80; j++)
      {
         *(vp+(i*80+j)*2) = ' ';
         *(vp+(i*80+j)*2+1) = 0;
      }
   }
}

void show_this_page(char buf[], long offset, int bytes_in_buf)
{  /* ��ʾ��ǰҳ:   �����׵�ַ       ƫ��        ��ǰҳ�ֽ��� */
   int i, rows, bytes_on_row;
   clear_this_page();
   rows = (bytes_in_buf + 15) / 16; /* ���㵱ǰҳ������ */
   for(i=0; i< rows; i++)
   {
      bytes_on_row = (i == rows-1) ? (bytes_in_buf - i*16) : 16; /* ��ǰ�е��ֽ��� */
      show_this_row(i, offset+i*16, &buf[i*16], bytes_on_row); /* ��ʾ��һ�� */
   }
}

main()
{
   char filename[100];
   char buf[256];
   int  handle, key, bytes_in_buf;
   long file_size, offset, n;
   puts("Please input filename:");
   gets(filename); /* �����ļ���; ����п��Ե���int 21h��0Ah���� */
   handle = _open(filename, 0); /* ���ļ�, ���ؾ��; 
                                   ����Ӧ����: 
                                   mov ah, 3Dh
                                   mov al, 0; ��Ӧ_open()�ĵ�2������, ��ʾֻ����ʽ
                                   mov dx, offset filename
                                   int 21h
                                   mov handle, ax
                                 */
   if(handle == -1)              /* ����п���ͨ�����CF==1���ж��������ļ��з�ɹ� */
   {
      puts("Cannot open file!");
      exit(0); /* ����Ӧ����: 
                  mov ah, 4Ch
                  mov al, 0; ��Ӧexit()�еĲ���
                  int 21h
                */
   }
   file_size = lseek(handle, 0, 2); /* �ƶ��ļ�ָ��;
                                       ����Ӧ����:
                                       mov ah, 42h
                                       mov al, 2; ��Ӧlseek()�ĵ�3������,
                                                ; ��ʾ��EOFΪ���յ�����ƶ�
                                       mov bx, handle
                                       mov cx, 0; \ ��Ӧlseek()�ĵ�2������
                                       mov dx, 0; /
                                       int 21h
                                       mov word ptr file_size[2], dx
                                       mov word ptr file_size[0], ax
                                     */
   offset = 0;
   do
   {
      n = file_size - offset;
      if(n >= 256)
         bytes_in_buf = 256;
      else
         bytes_in_buf = n;
      lseek(handle, offset, 0);      /* �ƶ��ļ�ָ��;
                                       ����Ӧ����:
                                       mov ah, 42h
                                       mov al, 0; ��Ӧlseek()�ĵ�3������,
                                                ; ��ʾ��ƫ��0��Ϊ���յ�����ƶ�
                                       mov bx, handle
                                       mov cx, word ptr offset[2]; \cx:dx��һ�𹹳�
                                       mov dx, word ptr offset[0]; /32λֵ=offset
                                       int 21h
                                     */
      _read(handle, buf, bytes_in_buf); /* ��ȡ�ļ��е�bytes_in_buf���ֽڵ�buf�� 
                                           ����Ӧ����:
                                           mov ah, 3Fh
                                           mov bx, handle
                                           mov cx, bytes_in_buf
                                           mov dx, data
                                           mov ds, dx
                                           mov dx, offset buf
                                           int 21h
                                         */
      show_this_page(buf, offset, bytes_in_buf);
      key = bioskey(0); /* ��������;
                           ����Ӧ����:
                           mov ah, 0
                           int 16h
                         */
      switch(key)
      {
      case PageUp:
         offset = offset - 256;
         if(offset < 0)
            offset = 0;
         break;
      case PageDown:
         if(offset + 256 < file_size)
            offset = offset + 256;
         break;
      case Home:
         offset = 0;
         break;
      case End:
         offset = file_size - file_size % 256;
         if(offset == file_size)
            offset = file_size - 256;
         break;
      }
   } while(key != Esc);
   _close(handle); /* �ر��ļ�; 
                      ����Ӧ����:
                      mov ah, 3Eh
                      mov bx, handle
                      int 21h
                    */
}
