[bits 16]
[org 0x7c3e] ; For FAT* boot

%include "kdef.inc"
%include "disk.inc"

; BCONF data starts at LBA 33 (= (512 + 4608*2 + 7168)/512)
BCONF_CYL equ 0
BCONF_HEAD equ 1
BCONF_SECT equ 16
BCONF_SIZE equ 2 ; Size in sectors

init:
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov sp, INIT_STACK
    mov bp, sp
    sti

    ; Boot drive should just be available in dl thanks to the BIOS
    mov byte [BOOT_DRIVE], dl

    mov si, strstart
    call printstr

    mov ax, BCONF_CYL
    mov dh, BCONF_HEAD
    mov dl, [BOOT_DRIVE]
    mov cl, BCONF_SECT
    mov ch, BCONF_SIZE
    mov bx, BCD_LOAD
    call read_disk

    ; This references the first word in image.s:bconf_start, used to determine
    ; the number of boot entries to load from disk.
    mov cx, [BCD_LOAD]
    mov si, BCD_LOAD + 2
.2:
    push cx
    mov ax, [si + tBCONFENTRY.chs]
    mov dh, [si + tBCONFENTRY.chs + 2]
    mov cl, [si + tBCONFENTRY.chs + 3]
    mov ch, [si + tBCONFENTRY.size]
    mov dl, [BOOT_DRIVE]
    push word [si + tBCONFENTRY.seg]
    pop es
    mov bx, [si + tBCONFENTRY.offset]
    call read_disk
    pop cx

    push word [si + tBCONFENTRY.seg]
    pop es
    mov bx, [si + tBCONFENTRY.offset]

    ; Is this the first entry in the list?
    cmp cx, [BCD_LOAD]
    jne .3
    ; If so call it to load the kernel. First entry is always the kernel.
    call bx
    jmp .5
.3:
    ; All subsequent entries are loaded by the software interrupt that the
    ; kernel's init method has just setup in the lines above.
    xor ax, ax
    int 0x2c
    test ax, ax
    jnz .4
    ; This means that we failed to load one of the services. It is treated as an
    ; unrecoverable error.
    mov si, strserverr
    call printstr
    hang
.4:
    ; Should we call this service's init method?
    mov dl, byte [si + tBCONFENTRY.init]
    test dl, dl
    jz .5
    xor dh, dh
    push cx
    doservice ax,dx,0,0,0
    pop cx
.5:
    ; Continue loading services until they are all loaded.
    add si, tBCONFENTRY_size
    loop .2

    ; Transfer control over to process INIT (always last)
    doexec ax

.1: ; If doexec fails then we print the str_init_error and hang
    push 0xB800
    pop es
    xor di, di
    mov si, str_init_error
    mov cx, 20
    rep movsw

    mov ah, 2
    xor bh, bh
    mov dx, 0x0013
    int 0x10

    hang

; simple read (just don't read past a cylinder boundary.. or more than 128 sectors)
; ax=cylinder dh=head dl=drive ch=sectors cl=sector es:bx=buffer
read_disk:
    push ax
    shr ax, 2
    and ax, 0xC0
    or cl, al
    pop ax
    xchg al, ch
    mov ah, 2
    int 0x13
    jc .1
    ret
.1:
    mov si, strdiskerr
    call printstr
    hang

printstr:
    lodsb
    test al, al
    jz .1
    mov ah, 0xE
    int 0x10 ; BIOS sets up a way for us to print one char at a time
    jmp printstr
.1:
    ret

; String Table
strstart db 'OS is starting',13,10,0
strdiskerr db 'Disk error',13,10,0
strserverr db 'Service error',13,10,0

; TODO: Make this part more maintainable
str_init_error: db 'F',4,'A',4,'I',4,'L',4,'E',4,'D',4,' ',4,'T',4,'O',4,' ',4,'L',4,'O',4,'A',4,'D',4,' ',4,'I',4,'N',4,'I',4,'T',4,'.',4

