%define XMAGIC 'NK'
%define PLIST_size 320 ; 0x500(kernel) + 0x500(plist) = 0x1000(init), 320 * 4 = 0x500
%define INIT_STACK 0xFEFF
%define OS_PTYPE 0xEA ; Partition type for boot configuration data, has yet to be used

%define BCD_LOAD 0x7E00
%define BOOT_DRIVE 0x7C00

; Memory addresses to load things into
%define KERNL_ADDR 0x500
%define KERNL_SEGM (KERNL_ADDR >> 4)
%define PINIT_ADDR 0x1000
%define PINIT_SEGM (PINIT_ADDR >> 4)
%define DISK_ADDR 0x1200
%define FAT12_ADDR 0x1400
%define PROMPT_ADDR 0x1600
%define ALLOC_ADDR 0x2000

%define ALLOC_FIRST_BLOCK 0x3200
%define ALLOC_BLOCK_SIZE 0x200 ; A kind of "superdense encoding" for the
                               ; allocation tables
%define ALLOC_MAX_BLOCKS 0xFD  ; 253 * 8 * 512 = 1036288 (or 0xFFFFF - 0x3000)

%define ALLOC_INIT 1
%define ALLOC_MEMALLOC 2
%define ALLOC_REALLOC 3

%define PIC_FREQ 100 ; Hz (must be >19) tick every 10ms

struc tPENTRY
    .cseg resw 1
    .pid resw 1
endstruc

struc tPRECORD
    .status resb 1
    .startchs resb 3
    .type resb 1
    .endchs resb 3
    .startlba resd 1
    .endlba resd 1
endstruc

struc tXHEADER
    .magic resw 1
    .pname resb 6
    .dseg resw 1
    .servlist resw 1
    .listlen resw 1
    .size resw 1

    .servinf.size resw 1
    .servinf.seg resw 1
    .servinf.msgptr resw 1
endstruc

struc proto_ALLOC
    .status resb 1
    .size resw 1
    .buffer:
        .seg resw 1
        .offset resw 1
endstruc

; If ax=1, allocation was a success
%macro allocate 1
    dosearch 'AL','LO','C '
    test ax, ax
    jz %%1
    sub sp, proto_ALLOC_size
    push bp
    mov bp, sp
    mov word [bp + proto_ALLOC.size], %1
    pop bp
    doservice ax,ALLOC_MEMALLOC,proto_ALLOC_size,ds,sp
    xor ax, ax
    test cx, cx
    jz %%1
    push word [es:bx + proto_ALLOC.seg]
    mov bx, [es:bx + proto_ALLOC.offset]
    pop es
    mov ax, 1
%%1:
%endmacro

; int 0x2a
; pid, sid, length, segment, offset
%macro doservice 5
    mov ax, %1
    mov dx, %2
    mov cx, %3
    push %4
    pop es
    mov bx, %5
    int 0x2a
%endmacro

; int 0x2b
; 'NA','ME',' '
%macro dosearch 3
    mov ax, %1
    mov dx, %2
    mov cx, %3
    int 0x2b
%endmacro

; int 0x2c
; pid, segment, offset
%macro doload 3
    mov ax, %1
    push %2
    pop es
    mov bx, %3
    int 0x2c
%endmacro

; int 0x2c
; pid
%macro doexec 1
    mov ax, %1
    int 0x2d
%endmacro

%macro zeromemw 2
    pushm ax,di,cx
    xor ax, ax
    mov di, %1
    mov cx, %2
    rep stosw
    popm ax,di,cx
%endmacro

%macro zeromemb 2
    pushm ax,di,cx
    xor al, al
    mov di, %1
    mov cx, %2
    rep stosb
    popm ax,di,cx
%endmacro

; Sets code pointer for interrupt number %1 to segment:offset %2:%3
%macro loadint 3
    push ds
    push 0
    pop ds
    push bx
    lea bx, [%1 * 4]
    mov word [bx+2], %2
    mov word [bx], %3
    pop bx
    pop ds
%endmacro

%macro dumpb 1
    pusha
    movzx ax, %1
    call PINIT_SEGM:tXHEADER_size + 2
    popa
%endmacro

%macro dumpw 1
    pusha
    mov ax, %1
    call PINIT_SEGM:tXHEADER_size + 2
    popa
%endmacro

%macro hang 0
    %%h: pause
    jmp %%h
%endmacro

%macro pushm 1-*
    %rep %0
        push %1
    %rotate 1
    %endrep
%endmacro

%macro popm 1-*
    %rep %0
    %rotate -1
        pop %1
    %endrep
%endmacro

