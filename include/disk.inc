%define DISKIO_INIT 1
%define DISKIO_READ_LBA 2
%define DISKIO_WRITE_LBA 3

%define FAT12_INIT 1
%define FAT12_READ 2
%define FAT12_WRITE 3
%define FAT12_SEARCH 4
%define FAT12_STAT 5

struc proto_FAT12
    .filename:
        .filename.seg resw 1
        .filename.offset resw 1
    .buffer:
        .buffer.seg resw 1
        .buffer.offset resw 1
    .time resb 1
    .date resb 1
    .size resd 1
endstruc

struc proto_DISK
    .status resb 1
    .lba resd 1 ; little endian of course, so 0x12345678 -> 0x78 0x56 0x34 0x12
    .sectors resw 1
    .buffer:
        .buffer.seg resw 1
        .buffer.offset resw 1
endstruc

; _______________
;|_______|___|___|
;| 0   1 | 2 | 3 |
;    C     H   S

struc tBCONFENTRY
    .chs resd 1 ; Location on disk in CHS format
    .size resb 1 ; Size in sectors
    ; Load address SEG:OFFSET
    .seg resw 1
    .offset resw 1
    .init resb 1; If 1, run service #0 at boot
endstruc

struc tBDRIVE
    .drive resb 1
    .nheads resb 1
    .ntracks resw 1
    .sptrack resb 1
    .bpsector resw 1
    .sectors resw 1

    .types resb 4
    .bindex resb 1

    .sc resw 4
    .sh resb 4
    .ss resb 4

    .ec resw 4
    .eh resb 4
    .es resb 4
endstruc

