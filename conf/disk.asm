[bits 16]
[org 0]

%include "kdef.inc"
%include "disk.inc"

xh_magic db XMAGIC
xh_pname db 'DISKIO'
xh_dseg dw 0
xh_servlist dw services
xh_listlen dw 3
xh_size dw ((end - init) / 512) + 1

; TODO it would be nice if we didn't rely on the BIOS int 0x13 for this.

servinf:
    .size dw 0
    .seg dw 0
    .msgptr dw 0

init:
    push 0
    pop es
    mov al, [es:BOOT_DRIVE]
    mov byte [bdrive + tBDRIVE.drive], al

    test al, 0x80
    jz .1
    xor di, di
    mov ah, 8
    int 0x13
    jmp .2
.1:
    ; Floppy disks
    ; They're all 3.5" 1.44M as far as we're concerned
    mov dh, 2
    mov cl, 18
    mov ch, 80
.2:
    push word [servinf.seg]
    pop es
    mov bx, [servinf.msgptr]

    mov byte [bdrive + tBDRIVE.nheads], dh

    movzx ax, ch
    push cx
    shr cl, 6
    or ah, cl
    pop cx
    mov word [bdrive + tBDRIVE.ntracks], ax

    and cx, 0x1F
    mov byte [bdrive + tBDRIVE.sptrack], cl

    ; LBA = nheads * ntracks * sptrack
    shr dx, 8
    mul dx
    mul cx
    mov word [bdrive + tBDRIVE.sectors], ax
    mov word [bdrive + tBDRIVE.sectors + 2], dx

    mov word [bdrive + tBDRIVE.bpsector], 512

    xor ah, ah
    mov dl, [bdrive + tBDRIVE.drive]
    int 0x13

    retf

; dx:ax + cx:bx
add_bigint:
    pushm cx,bx

    test bx, bx
    jz .3
.1:
    inc ax
    dec bx
    jnz .1

.3:
    test cx, cx
    jz .2

    inc dx
    dec cx
    jnz .1
.2:
    popm cx,bx
    ret

;sub_bigint:
;    pushm cx,bx
;.1:
;    dec dx
;    dec bx
;    jnz .1
;    dec ax
;    dec cx
;    jnz .1
;    popm cx,bx
;    ret

; Assumes two heads
; dx:ax = LBA
; ch = head, cl = sector, bx = track
lba_to_chs:
    pushm ax, dx, es, si
    mov si, [bdrive + tBDRIVE.sptrack]

; head = (lba / sptrack) & 1
    xor ch, ch
    pushm dx, ax
    div si
    shr ax, 1
    setc ch
    popm dx, ax

; track = (lba / (sptrack * 2))
    pushm dx, ax
    shl si, 1
    div si
    shr si, 1
    mov bx, ax
    popm dx, ax

; sector = (lba % sptrack) + 1
    div si
    mov cl, dl
    inc cl

    popm ax, dx, es, si
    ret

; proto_DISK.status = drive number
; proto_DISK.lba = lba
; proto_DISK.sectors = sectors to read
; proto_DISK.buffer.seg = segment
; proto_DISK.buffer.offset = offset
read_lba:
    cmp word [servinf.size], proto_DISK_size
    je .1
.3:
    mov word [servinf.size], 0
    mov word [servinf.seg], 0
    mov word [servinf.msgptr], 0
    retf
.1:
    push word [servinf.seg]
    pop es
    mov bx, word [servinf.msgptr]

    mov ax, word [es:bx + proto_DISK.buffer.seg]
    mov word [disk_msg + proto_DISK.buffer.seg], ax

    mov ax, word [es:bx + proto_DISK.buffer.offset]
    mov word [disk_msg + proto_DISK.buffer.offset], ax

    mov cx, word [es:bx + proto_DISK.sectors]
.4:
    push cx
    push bx

    mov dx, word [es:bx + proto_DISK.lba + 2]
    mov ax, word [es:bx + proto_DISK.lba]

    pushm ax, dx
    inc ax
    jnc .7
    inc dx
.7:
    mov word [es:bx + proto_DISK.lba + 2], dx
    mov word [es:bx + proto_DISK.lba], ax
    popm ax, dx

    call lba_to_chs

    mov dh, ch
    mov ch, bl
    pop bx

    call .read_sector

    ; TODO: implement proper carry for segment
    add word [es:bx + proto_DISK.buffer.offset], 512
    jnc .8
    dumpw 0xE005
    hang
.8:
    pop cx
    loop .4

    mov word [disk_msg + proto_DISK.status], 1
    mov word [servinf.size], proto_DISK_size
    mov word [servinf.seg], ds
    mov word [servinf.msgptr], disk_msg

    retf

.read_sector:
    pusha
    push 0
    mov bp, sp
    mov si, 3
.2:
    xor ah, ah
    mov dl, byte [es:bx + proto_DISK.status]
    int 0x13
    jc .9

    mov ah, 2
    mov al, 1
    pushm es, bx
    pushm word [es:bx + proto_DISK.buffer.seg], word [es:bx + proto_DISK.buffer.offset]
    popm es, bx
    int 0x13
    jnc .5
.9:
    inc word [bp]
    cmp word [bp], 3
    je .3 ; Return nothing on three successive failures
.5:
    popm es, bx
    dec si
    test si, si
    jnz .2
    add sp, 2
    popa
    ret

; TODO: Work on write_lba
write_lba:
    retf

get_boot_drive:
    mov al, [bdrive + tBDRIVE.drive]
    mov byte [servinf.size], al
    retf

services:
    dw init
    dw read_lba
    dw write_lba
    dw get_boot_drive

bdrive: times tBDRIVE_size db 0
disk_msg: times proto_DISK_size db 0

end:
