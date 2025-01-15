# N/OS

The "Nanokernel OS." A 16-bit DOS analog with some very interesting IPC,
allocation and preemptive multitasking primitives built into the kernel.
Intended to be a research project for OS development and bootable off a 3.5"
floppy on anything resembling an 80286 or above.

# Requirements
- qemu
- nasm
- bochs (for debugging)

# Development
## Building
To produce an `OS.img` that can either be loaded into an x86 emulator or dumped
to a floppy:
```
make clean && \
  make all && \
  make OS.img
```

## Testing
To spawn a qemu instance that boots `OS.img`:
```
make test
```

## Debugging
To spawn a bochs that boots `OS.img`, useful for debugging the kernel (be sure
to have a list of memory pointers handy):
```
make debug
```

# Overview
It all starts with `image.s` as this NASM source is what defines the layout of
the floppy disk image, incuding the MBR, the FAT12 filesystem layout, the
"bootloader" configuration and all kernel + service code. Note that the padding
on each "file" following the bootloader configuration in `bconf_start` is
especially important, as we're using BIOS interrupts to read the disk which must
be done in 512-byte sectors addressed in CHS (cylinder-head-sector) form. When
the x86 system boots this floppy, it will immediately begin executing the `init`
method in `boot/floppy_boot.asm`.

The control flow from there is roughly that `floppy_boot.asm` will load all the
services from disk into memory as defined in `bconf_start`, starting with the
kernel (in order to call it's `init` method first so that we can make use of the
software interrupts it provides whilst loading additional services) and ending
with the `INIT` service (in `kernel/init.asm`). Once `INIT` is loaded, it will
immediately transfer control to the `PROMPT` service, at which point a very
minimal interpreter will be started whose functionality is described in the
"Usage" section.

# Usage
N/OS ships with an extremely buggy command line interpreter, and several
services such as DISKIO which rely on BIOS-managed software interrupts to do
things like read from the disk and print to the screen (at the moment). There is
also the basis of preemptive multitasking (i.e. enabling the PIT with a basic
debug print stub on IRQ 0) which you can play around with in `kernel.asm`.

At the moment, if you boot `OS.img` it will immediately drop you into a prompt
in which only two commands are recognized:
- `d(int)` dumps the first 2 bytes of a given sector from the floppy to the
  terminal. The command letter is "d" and it takes a base-10 integer indicating
  the sector to dump as the first argument, which is not separated by any
  spaces (no tokenization yet). Attempting to read sectors >65535 has undefined
  results due to a lack of bigint support.
- `c(int)` converts a base-10 `int` to base-16 (hexidecimal) and prints it.

```
N/OS PROMPT v1.0
> c255
\xFF
> d0
\3CEB
> d1
\FFF0
> d2
\0
> d100
\0
> d1000000
(sometimes crashes/hangs the OS, or repeats keypresses, and idk why)
```
