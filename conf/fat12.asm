[bits 16]
[org 0]

%include "kdef.inc"
%include "disk.inc"

db XMAGIC
db 'FAT12 '
dw 0
dw services
dw 4
dw ((end - start) / 512) + 1

servinf:
    .size dw 0
    .seg dw 0
    .msgptr dw 0

start:
init:
    ; alloc space
    ;allocate 1
    ;mov [disk_msg + proto_DISK.buffer.seg], es
    ;mov [disk_msg + proto_DISK.buffer.offset], bx
    ;dosearch 'DI','SK','IO'
    ;doservice ax,DISKIO_READ_LBA,proto_DISK_size,ds,disk_msg
    retf

check_proto:
    cmp word [servinf.size], proto_FAT12_size
    je .1
    mov word [servinf.size], 0
    mov word [servinf.seg], 0
    mov word [servinf.msgptr], 0
    mov bx, sp
    mov word [bx], 0
    add sp, 2
    retf
.1:
    mov word [servinf.seg], es
    mov bx, [servinf.msgptr]
    ret

; root directory table = reserved_sectors + 9*fat_copies
read_file:
    call check_proto

    allocate 1
    dumpw es
    dumpw bx

    ; Read FS information from boot drive
    hang

    retf

write_file:
    call check_proto
    retf

list_files:
    call check_proto
    retf

stat_file:
    call check_proto
    retf

services:
    dw init
    dw read_file
    dw write_file
    dw list_files
    dw stat_file

fat12_msg: times proto_FAT12_size db 0

disk_msg:
db 0 ; status
dd 0 ; lba
dw 1 ; sectors
dw 0 ; segment
dw 0 ; offset
times proto_DISK_size - ($ - disk_msg) db 0

alloc_msg:
times proto_ALLOC_size - ($ - alloc_msg) db 0

end:
