[bits 16]
[org 0]

%include "kdef.inc"
%include "disk.inc"

xh_magic db XMAGIC
xh_pname db 'INIT  '
xh_dseg dw 0
xh_servlist dw 0
xh_listlen dw 0
xh_size dw (length / 512) + 1

servinf:
    .size dw 0
    .seg dw 0
    .msgptr dw 0

start:
jmp main

printhex: ; Referred to by macros such as dumpw
    push ax
    mov ah, 0xe
    mov al, '\'
    int 0x10
    pop ax
    mov dl, 1
    mov cx, 4
.1:
    rol ax, 4
    push ax
    and al, 0x0f
    test dl, dl
    jz .2
    test al, al
    jnz .2
    pop ax
    loop .1
    mov ah, 0xE
    mov al, '0'
    int 0x10
    retf
.2:
    xor dl, dl
    cmp al, 0x0A
    sbb al, 0x69 ; exquisite instructions
    das
    mov ah, 0xE
    int 0x10
    pop ax
    loop .1
    retf

main:
    ; This is how we clear the screen and change the foreground color to green.
    ; You could expand on this in order to build an actual display driver
    ; someday...
    push 0xB800
    pop es
    ; Could be blue BG white FG, but it doesn't survive past scrollback
    ;mov ax, 0x1f00
    mov ax, 0x0700 ; Black BG grey FG (default)
    mov di, 0
    mov cx, 0x7d0
    rep stosw

    ; This resets the position of the cursor to 0,0. Again, would be nice to
    ; figure out how to do this without using the BIOS.
    mov ah, 2
    xor bh, bh
    xor dx, dx
    int 0x10

    ; TODO the filesystem driver doesn't quite work yet. It may not make sense
    ; to invoke any of its methods here either, rather to modify the prompt so
    ; that it must invoke the FAT12 service as opposed to using DISKIO directly.
    ;dosearch 'FA','T1','2 '
    ;doservice ax,FAT12_READ,proto_FAT12_size,ds,fat12_msg

    ; Transfer control to the prompt
    dosearch 'PR','OM','PT'
    doexec ax

    ; Error-out in case we cannot execute PROMPT
    dumpw 0xE001
    hang

disk_msg:
db 0
dd 0
dw 1
dw 0
dw 0x7000
times proto_DISK_size - ($ - disk_msg) db 0

fat12_msg:

times proto_FAT12_size - ($ - fat12_msg) db 0

length equ $ - start

