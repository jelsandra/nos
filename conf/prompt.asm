[bits 16]
[org 0]

%include "kdef.inc"
%include "disk.inc"

xh_magic db XMAGIC
xh_pname db 'PROMPT'
xh_dseg dw 0
xh_servlist dw services
xh_listlen dw 2
xh_size dw (length / 512) + 1

servinf:
    .size dw 0
    .seg dw 0
    .msgptr dw 0

struc proto_PROMPT
    .buffer:
        .seg resw 1
        .offset resw 1
endstruc

; TODO build an actual display driver instead of relying on BIOS

start:
    loadint 0,PROMPT_ADDR >> 4,expt_divbyzero

    ; Allocate one block
    allocate 1

    mov word [alloc_msg + proto_ALLOC.seg], es
    mov word [alloc_msg + proto_ALLOC.offset], bx

    dosearch 'PR','OM','PT'
    doservice ax,2,proto_PROMPT_size,ds,prompt_msg

    xor bx, bx
    xor si, si
.1:
    xor ax, ax
    int 0x16 ; BIOS call to receive input

    cmp ah, 0xE ; Backspace
    jne .2

    test si, si
    jz .1

    ; Kind of an ugly kludge
    call .bkspc

    mov ah, 0xE
    mov al, 0
    int 0x10

    call .bkspc

    mov es, [alloc_msg + proto_ALLOC.seg]
    mov bx, [alloc_msg + proto_ALLOC.offset]
    dec si
    mov byte [es:bx + si], 0

    jmp .1

.bkspc:
    mov ah, 3
    int 0x10

    test dl, dl
    jnz .over
    dec dh
    mov dl, 80
.over:
    dec dl

    mov ah, 2
    int 0x10
    ret

.2:
    cmp ah, 0x1c ; Return
    jne .3
    mov es, [alloc_msg + proto_ALLOC.seg]
    mov bx, [alloc_msg + proto_ALLOC.offset]
    mov byte [es:bx + si], 0

    test si, si
    jz .4

    mov ax, 0x0E0D
    int 0x10
    mov al, 10
    int 0x10

    xor si, si
    call parse_command

.4:
    mov ah, 0xE
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    mov al, '>'
    int 0x10
    mov al, ' '
    int 0x10

    jmp .1
.3:
    mov ah, 0xE
    int 0x10

    mov es, [alloc_msg + proto_ALLOC.seg]
    mov bx, [alloc_msg + proto_ALLOC.offset]
    mov byte [es:bx + si], al
    inc si

    jmp .1
    hang

expt_divbyzero:
    ;mov word [prompt_msg + proto_PROMPT.seg], 0x160
    ;mov word [prompt_msg + proto_PROMPT.offset], str_divbyzero
    ;dosearch 'PR','OM','PT'
    ;doservice ax,2,proto_PROMPT_size,ds,prompt_msg
    dumpw 0xE001
    hang

; TODO: numbers greater than 65535 (must have bigint support)
; es:si=string
; bx=int
toint:
    ; "100" -> "\x31\x30\x30\x0"
    ; "65535" -> "\x36\x35\x35\x33\x35\x0"
    ; 100 -> 0x0064
    ; 65535 -> 0xFFFF
    pushm si, ax, cx, dx, ds
    push es
    pop ds

    cld
    mov cx, si
.1:
    lodsb
    test al, al
    jz .9

    cmp al, 0x30
    jge .6
.8:
    xor bx, bx
    jmp .10
.6:
    cmp al, 0x39
    jg .8
    jmp .1
.9:
    dec si

    xchg cx, si
    sub cx, si

    test cx, cx
    jz .8

    xor bx, bx
    xor ax, ax
.2:
    lodsb
    xor ah, ah
    sub al, 0x30
    mov dx, 10

    push cx
    dec cx
    test cx, cx
    jz .4
.3:
    mul dx
    mov dx, 10
    loop .3
.4:
    pop cx

    add bx, ax
    jc .8
    loop .2
.10:
    popm si, ax, cx, dx, ds
    ret

parse_command:
    mov es, [alloc_msg + proto_ALLOC.seg]
    mov bx, [alloc_msg + proto_ALLOC.offset]
    mov al, [es:bx]

    cmp al, 'd' ; Command 'd' - print first two bytes of sector from disk
    jne .1

    pushm si,bx
    mov si, bx
    inc si
    call toint
    mov dx, bx
    popm si,bx

    add bx, 512

    mov word [disk_msg + proto_DISK.buffer.seg], es
    mov word [disk_msg + proto_DISK.buffer.offset], bx
    mov word [disk_msg + proto_DISK.lba], dx
    mov word [disk_msg + proto_DISK.sectors], 1
    dosearch 'DI','SK','IO'
    doservice ax,DISKIO_READ_LBA,proto_DISK_size,ds,disk_msg
    push word [es:bx + proto_DISK.buffer.seg]
    mov bx, [es:bx + proto_DISK.buffer.offset]
    pop es

    dumpw word [es:bx]

.1:
    cmp al, 'c' ; Command 'c' - print hex equivalent of base-10 integer argument
    jne .2
    push si
    mov si, bx
    inc si
    call toint
    pop si
    dumpw bx
.2:
    ret

ctrl_break_handler:
    iret

sysrq_handler:
    iret

exec:
    retf

print_text:
    cmp word [servinf.size], proto_PROMPT_size
    je .1
    mov word [servinf.size], 0
    mov word [servinf.seg], 0
    mov word [servinf.msgptr], 0
    retf
.1:
    push word [servinf.seg]
    pop es
    mov bx, [servinf.msgptr]

    push word [es:bx + proto_PROMPT.seg]
    mov si, [es:bx + proto_PROMPT.offset]
    pop es

    xor bx, bx
    mov ah, 0xE
.2:
    lodsb
    int 0x10
    test al, al
    jnz .2

    mov al, 8
    int 0x10

    retf

services:
    dw exec       ; 1
    dw print_text ; 2

welcome: db 'N/OS PROMPT v1.0',13,10,'> ',0
str_divbyzero: db 'Divide by zero =(',0

prompt_msg:
dw PROMPT_ADDR >> 4
dw welcome
times proto_PROMPT_size - ($ - prompt_msg) db 0

alloc_msg:
db 0
dw 1 ; one block (512 bytes)
times proto_ALLOC_size - ($ - alloc_msg) db 0

disk_msg: times proto_DISK_size - ($ - disk_msg) db 0

length equ $ - start
