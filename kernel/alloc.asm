[bits 16]
[org 0]

%include "kdef.inc"

xh_magic db XMAGIC
xh_pname db 'ALLOC '
xh_dseg dw 0
xh_servlist dw services
xh_listlen dw 3
xh_size dw (length / 512) + 1

servinf:
    .size dw 0
    .seg dw 0
    .msgptr dw 0

start:
    push ds
    pop es
    mov cx, ALLOC_MAX_BLOCKS
    xor ax, ax
    mov di, blocks_list
    rep stosw
    retf

; al = needle, es:di = haystack
; es:di = findings
scan_free_blocks:
    push cx
    mov cx, ALLOC_MAX_BLOCKS
    repne scasb
    cmp di, blocks_list + (ALLOC_MAX_BLOCKS * 2)
    jne .1
    xor di, di
.1:
    dec di
    pop cx
    ret

memalloc:
    cmp word [servinf.size], proto_ALLOC_size
    je .1
.2: ; Allocation failure
    mov word [servinf.size], 0
    mov word [servinf.seg], 0
    mov word [servinf.msgptr], 0
    retf
.1:
    mov es, [servinf.seg]
    mov bx, [servinf.msgptr]

    mov ax, [es:bx + proto_ALLOC.size]

    push ds
    pop es
    cld

    mov word [alloc_msg + proto_ALLOC.size], ax
    ; Since each bit means 512 bytes, a byte is 4096 (assuming ALLOC_BLOCK_SIZE is 512)
    ; The code below means it's a good policy for programs to allocate 1,2 or 4 blocks
    ; on their own or 8 blocks at a time.
    mov bl, 8
    div bl
    test ah, ah
    jnz .4

    mov di, blocks_list
    xor ax, ax
.3:
    call scan_free_blocks
    test di, di
    jz .2

    push di
    mov cx, [alloc_msg + proto_ALLOC.size]
    repe scasb
    pop di
    test cx, cx
    jnz .3

    ; Reserve blocks
    push di
    mov cx, [alloc_msg + proto_ALLOC.size]
    mov al, 0xff
    rep stosb
    pop di

    ; Resolve to ALLOC_FIRST_BLOCK + (di - blocks_list) * ALLOC_BLOCK_SIZE
    mov ax, di
    sub ax, blocks_list
    mov bx, ALLOC_BLOCK_SIZE*8
    mul bx

    ; NOTE: ALLOC_FIRST_BLOCK must be aligned on 0x10 bytes
    add dx, (ALLOC_FIRST_BLOCK >> 4)

    mov word [alloc_msg + proto_ALLOC.seg], dx
    mov word [alloc_msg + proto_ALLOC.offset], ax

    mov word [servinf.size], proto_ALLOC_size
    mov word [servinf.msgptr], alloc_msg
    mov word [servinf.seg], ds

    retf

.4: ; TODO: I'm too lazy to implement these right now. Maybe tomorrow
    mov ax, [alloc_msg + proto_ALLOC.size]
    cmp ax, 4
    jne .5
    ; alloc 4*512
.5:
    cmp ax, 2
    jne .6
    ; alloc 2*512
.6:
    cmp ax, 1
    jne .7

    mov al, 0xFF
    mov cx, ALLOC_MAX_BLOCKS
    mov di, blocks_list
    repe scasb
    cmp di, blocks_list + (ALLOC_MAX_BLOCKS * 2)
    je .2
    dec di

    mov ax, di
    sub ax, blocks_list
    mov bx, ALLOC_BLOCK_SIZE*8
    mul bx
    push ax

    add dx, (ALLOC_FIRST_BLOCK >> 4)
    push dx

    mov al, [es:di]
    not al
    xor ah, ah
    bsf cx, ax
    btr ax, cx
    not al
    mov byte [es:di], al

    mov ax, cx
    mov bx, ALLOC_BLOCK_SIZE
    mul bx

    pop dx
    pop bx

    not bx
    cmp bx, ax
    jle .8

    ; carry over to segment
    push ax
    shr ax, 4
    add dx, ax
    pop ax

    and ax, 0xf
.8:
    not bx
    add bx, ax

    mov word [alloc_msg + proto_ALLOC.seg], dx
    mov word [alloc_msg + proto_ALLOC.offset], bx

    mov word [servinf.size], proto_ALLOC_size
    mov word [servinf.msgptr], alloc_msg
    mov word [servinf.seg], ds

    retf

.7: ; TODO: worst policy for this type of allocation scheme.
    ; in fact, it's so bad we won't even honor it yet.
    jmp .2

; Reserve the blocks
    ;mov cx, [alloc_msg + proto_ALLOC.size]
    ;mov ax, 0xffff
    ;rep stosw

    dumpw di
    hang

    retf

realloc:
    ; TODO
    retf

free:
    ; TODO
    retf

services:
    dw start
    dw memalloc
    dw realloc
    dw free

alloc_msg: times proto_ALLOC_size db 0
; Organized like a primitive page table. Should give you a warm-fuzzy feeling
; 1 bit reserves 512 bytes, 512 * 8 * 253 = 1036288 bytes or just enough to map a little over 1mb
blocks_list:
length equ $ - start

