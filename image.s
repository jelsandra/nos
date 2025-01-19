%include "kdef.inc"

%macro incwp 2
%%1:
incbin %1
%%2:
times %2*512 - (%%2 - %%1) db 0
%endmacro

; For a 1.44M Floppy...
; 512 bytes in a sector
; 18 sectors in a track(cylinder)
; 80 tracks in a head
; 2 heads in a disk
; 512 * 18 * 80 * 2 = 1474560 bytes in all

; 0
jmp boot
nop
db "MSDOS5.0"
dw 512          ; Bytes per sector
db 1            ; Sectors per cluster
dw 1            ; Reserved sectors
db 2            ; FAT copies
dw 224          ; Root directory entries (224 recommended)
dw 2880         ; Total sectors
db 0xf0         ; Media descriptor (1.44M floppy)
dw 9            ; Sectors per FAT
dw 18           ; Sectors per track
dw 2            ; Heads
dd 0            ; Hidden sectors

dd 0            ; Large number of sectors
db 0            ; Drive number
db 0            ; Reserved
db 0x29         ; Extended boot signature
dd 0xfedface    ; Volume serial
db "OS         "; Volume Label
db "FAT12   "   ; Volume type

boot:
incbin "obj/boot/floppy_boot.o"
times 510 - ($ - $$) db 0
dw 0xAA55

; Create two 12-bit FAT clusters in three bytes
%macro cluster 2 ; uv,wx,yz = xuv,yzw
db (%1 & 0xff), ((%1 >> 8) | ((%2 << 4) & 0xf0)), ((%2 >> 4) & 0xff)
%endmacro

; TODO: condense two FAT copies into one

; 1
fat_1:
cluster 0xff0,0xfff ; 0, 1
cluster 2,0xfff     ; 2, 3
cluster 0xfff,0xfff ; 4, 5
cluster 0xfff,0xfff ; 6, 7
cluster 0xfff,10    ; 8, 9
cluster 0xfff,0     ; 10,11
times 4608 - ($ - fat_1) db 0

; 10
fat_2:
cluster 0xff0,0xfff ; 0, 1
cluster 2,0xfff     ; 2, 3
cluster 0xfff,0xfff ; 4, 5
cluster 0xfff,0xfff ; 6, 7
cluster 0xfff,10    ; 8, 9
cluster 0xfff,0     ; 10,11
times 4608 - ($ - fat_2) db 0

; 32 byte directory entries
%macro direntry 10
db %1           ; 11 byte padded "NAME    EXT"
db %2           ; Attributes
times 10 db 0   ; Reserved

; time - hour,minute,second = (hour << 11) | (minute << 5) | second
; seconds are counted on two second intervals (e.g. 29 * 2 = 58)

dw (%3 << 11) | (%4 << 5) | (%5 / 2)          ; Timestamp

; date - day,month,year = (day << 11) | (month << 7) | year
; Year is actually an offset from 1980

dw (%6 << 11) | (%7 << 7) | (%8 - 1980) ; Date

dw %9           ; Starting cluster
dd %10          ; Filesize in bytes
%endmacro

; 19
root_table:

direntry "BOOT    CNF",1, 20,35,0, 2,8,2012, 2,BCONF_size
direntry "INIT    OS ",1, 15,21,0, 31,7,2012, 4,INIT_size
direntry "KERNEL  OS ",1, 15,21,0, 31,7,2012, 5,KERNEL_size
direntry "DISK    OS ",1, 15,21,0, 31,7,2012, 6,DISK_size
direntry "FAT12   OS ",1, 15,21,0, 31,7,2012, 7,FAT12_size
direntry "ALLOC   OS ",1, 15,21,0, 31,7,2012, 8,ALLOC_size
direntry "PROMPT  OS ",1, 15,21,0, 31,7,2012, 9,PROMPT_size

times 7168 - ($ - root_table) db 0 ; 224 * 32 = 7168

; 33
bconf_start:
; Boot configuration data

; Number of entries
dw 6

; Kernel is always first
dw 1
db 0,1,2 ; LBA 36
dw 0,KERNL_ADDR
db 0

; Then filesystem, network, whatever
; ALLOC
dw 1
db 0,5,1 ; LBA 40
dw 0,ALLOC_ADDR
db 1

; DISKIO
dw 1
db 0,3,1 ; LBA 38
dw 0,DISK_ADDR
db 1

; FAT12
dw 1
db 0,4,1 ; LBA 39
dw 0,FAT12_ADDR
db 1

; PROMPT
dw 1
db 0,6,2 ; LBA 41
dw 0,PROMPT_ADDR
db 0

; INIT must always be last
dw 0
db 1,18,1 ; LBA 35
dw 0,PINIT_ADDR
db 0


BCONF_size equ $ - bconf_start
times 1024 - BCONF_size db 0

; 35
incwp "obj/kernel/init.o",1
; 36
incwp "obj/kernel/kernel.o",2
; 37
incwp "obj/conf/disk.o",1
; 38
incwp "obj/conf/fat12.o",1
; 39
incwp "obj/kernel/alloc.o",1
; 40
incwp "obj/conf/prompt.o",2

times 1474560 - ($ - $$) db 0 ; Pad to 1474560 (1.44M) bytes

