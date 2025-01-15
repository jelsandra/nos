[bits 16]
[org 0]

%include "kdef.inc"

init:
    pushm ax,es,ds
    mov ax, KERNL_SEGM
    mov es, ax
    mov ds, ax

    loadint 0x2A,KERNL_SEGM,int_2a
    loadint 0x2B,KERNL_SEGM,int_2b
    loadint 0x2C,KERNL_SEGM,int_2c
    loadint 0x2D,KERNL_SEGM,int_2d

    ; Setup preemptive multi-tasking

    cli
    ; Unmask IRQ0 (8253/4 PIT)
    in al, 0x21
    and al, 0xfe
    out 0x21, al

    ; Setup PIT
    mov al, 0x34 ; Ch 0, low/high byte, rate gen.
    out 0x43, al

    ; freq = 1193181 / rate Hz
    ;xor al, al
    mov ax, 1193181 / PIC_FREQ
    out 0x40, al
    mov al, ah
    out 0x40, al

    loadint 0x8,KERNL_SEGM,irq_0
    sti

    zeromemw proclist, PLIST_size * (tPENTRY_size / 2)

    popm ax,es,ds
    ret

ticks db 0
counter dw 0

irq_0:
    pushm ax,es,ds
    mov ax, KERNL_SEGM
    mov es, ax
    mov ds, ax

    inc byte [ticks]
    cmp byte [ticks] , 0x64
    jne .over
    ; Uncomment to prove that the interrupt handler works
    ;dumpw word [counter]
    inc word [counter]
    mov byte [ticks], 0

.over:
    popm ax,es,ds

    ; Issue EOI (Master PIC)
    mov al, 0x20
    out 0x20, al
    iret

; ax = pid
; di = tPENTRY ptr
search_plist:
    pushm ax,cx
    mov di, proclist
    mov cx, PLIST_size
.1:
    cmp word [di + tPENTRY.pid], ax
    je .2
    add di, tPENTRY_size
    loop .1
    xor di, di
.2:
    popm ax,cx
    ret

; ax = pid, dx = sid, cx = len, es:bx = msg ptr
; ax = 1 or 0, cx = len, es:bx = msg ptr
int_2a:
    pushm ds,dx,si

    push KERNL_SEGM
    pop ds

    call search_plist
    test di, di
    jz .1
    mov ax, es
    mov si, bx
    push word [di + tPENTRY.cseg]
    pop es
    cmp word [es:tXHEADER.listlen], dx
    jb .1
    mov bx, word [es:tXHEADER.servlist]
    test bx, bx
    jz .1
    mov word [es:tXHEADER.servinf.size], cx
    mov word [es:tXHEADER.servinf.seg], ax
    mov word [es:tXHEADER.servinf.msgptr], si
    mov si, dx
    dec si
    shl si, 1
    mov ax, [es:bx + si]
    push word [es:tXHEADER.dseg]
    pop ds

    push es
    ; call far es:ax
    push KERNL_SEGM
    push $ + 6
    push es
    push ax
    retf
    pop es

    mov ax, 1
    mov cx, [es:tXHEADER.servinf.size]
    mov bx, [es:tXHEADER.servinf.msgptr]
    push word [es:tXHEADER.servinf.seg]
    pop es
    jmp .2
.1:
    xor ax, ax
    xor cx, cx
    xor bx, bx
    push 0
    pop es
.2:
    popm ds,dx,si
    iret

; ax:dx:cx = 'PR':'OC':'NA' (Process name)
; ax = pid or 0
int_2b:
    pushm dx,cx,di,si,ds,es
    push KERNL_SEGM
    pop ds

    mov di, proclist
    mov si, cx
    mov cx, PLIST_size
    cld
.1:
    cmp word [di + tPENTRY.pid], 0
    jz .2
    push word [di + tPENTRY.cseg]
    pop es
    cmp word [es:tXHEADER.magic], XMAGIC
    jne .2
    cmp word [es:tXHEADER.pname], ax
    jne .2
    cmp word [es:tXHEADER.pname + 2], dx
    jne .2
    cmp word [es:tXHEADER.pname + 4], si
    jne .2
    jmp .3
.2:
    add di, tPENTRY_size
    loop .1
    xor ax, ax
    jmp .4
.3:
    mov ax, word [di + tPENTRY.pid]
.4:
    popm dx,cx,di,si,ds,es
    iret

; TODO: either add a new interrupt or modify this one to "update" service images in memory
;       or exchange one service with another

; ax = pid or 0, es:bx = buffer
; ax = new pid or 0
int_2c:
    pushm cx,dx,si,di,ds
    push KERNL_SEGM
    pop ds

    cmp word [es:bx + tXHEADER.magic], XMAGIC
    jne .bad
    test bx, 0xf
    jnz .bad
    xor cx, cx
    test ax, ax
    setnz ch
    push cx
    call search_plist
    pop cx
    test di, di
    setnz cl
    mov dx, cx
    xor dh, dl
    test dh, dh
    jnz .1
.bad:
    xor ax, ax
    jmp .4
.1:
    cmp cx, 0x0100
    jnz .2
    push ax
    xor ax, ax
    call search_plist
    pop ax
    jmp .3
.2:
    mov ax, di
    shr ax, 2

    ; TODO: I WOULD replace with "sub ax, (proclist / 4) + 1" if nasm would let me
    mov dx, proclist
    shr dx, 2
    dec dx
    sub ax, dx
.3:
    mov word [di + tPENTRY.pid], ax
    mov si, es
    shr bx, 4
    add si, bx
    shl bx, 4
    mov word [di + tPENTRY.cseg], si
    mov di, word [es:bx + tXHEADER.dseg]
    test di, 0xf
    jnz .4
    shr di, 4
    add si, di
    mov word [es:bx + tXHEADER.dseg], si
.4:
    popm cx,dx,si,di,ds
    iret

; ax = pid (arguments on stack)
; If it returns, there was an error (DEAL WITH IT)
int_2d:
    push KERNL_SEGM
    pop ds

    call search_plist
    test di, di
    jnz .1
    iret
.1:
    push word [di + tPENTRY.cseg]
    pop es
    push word [es:tXHEADER.dseg]
    pop ds
    add sp, 6
    push es
    push tXHEADER_size
    sti
    retf

proclist:

