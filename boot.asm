[bits 16]
[org 0x7c00]


; Some BIOSes overwrite bytes 3-60 with drive geometry. 
; If your code is there, the BIOS will corrupt it.
jmp start
nop
times 33 db 0      ; fills space so BIOS doesnt set it to junk

BOOT_DRIVE: db 0

start:
    ; Explicitly zero out segments

    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00  ; Standard safe stack location
    
    mov [BOOT_DRIVE], dl

    ; Reset Disk Controller
    xor ah, ah
    int 0x13

    ; Load Stage 2
    mov ah, 0x02
    mov al, 4    ; Number of sectors to load
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [BOOT_DRIVE]
    mov bx, 0x8000
    int 0x13
    jc disk_error

    ; Enable A20
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Far jump to Stage 2
    jmp 0x0000:0x8000

disk_error:
    ; Visual feedback: Makes the screen red if jump to stage 2 fails
    mov ax, 0x0013
    int 0x10
    mov ax, 0xa000
    mov es, ax
    mov byte [es:0], 4 ; Red pixel
    jmp $

; 5. Fix: Dummy Partition Table
; This is the #1 reason for "Insert boot media" on laptops.
; We must place this starting at offset 446 (0x1BE).
times 446-($-$$) db 0

db 0x80 ; Partition 1: Active/Bootable
db 0, 1, 0 ; Start CHS
db 0x01 ; Type
db 0, 1, 0 ; End CHS
dd 0 ; Start LBA
dd 2880 ; Total sectors

; Pad the rest of the MBR
times 510-($-$$) db 0
dw 0xAA55