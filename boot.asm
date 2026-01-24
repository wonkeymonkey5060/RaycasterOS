[bits 16]           ; We start in 16-bit "Real Mode" (PC standard)
[org 0x7c00]        ; BIOS always loads bootloaders to this address

; The code here is the "Entry Point" for the "Operating System"
;
; It can only be 512 bytes and must start at 0x7c00 in memory,
; as that is where the BIOS looks for the entry point we
; immediately exit this and move to 0x8000 to have access
; to more memory.

jmp entry ; skip to entry: and not run anything in between as "code"

; variables
BOOT_DRIVE: db 0

entry:
	cli
	mov [BOOT_DRIVE], dl   ; Save drive id BIOS gives us
	
	mov bp, 0x9000 ; sets the stack base to 0x90000
	mov sp, bp
	
	; Call the BIOS to load Stage 2  (copied code)
    mov ah, 0x02            ; Read function
    mov al, 80               ; Number of sectors to read (512 bytes each)
    mov cl, 2               ; Start at Sector 2
    mov ch, 0               ; Cylinder 0
    mov dh, 0               ; Head 0
    mov dl, [BOOT_DRIVE]    ; From our boot drive
    mov bx, 0x8000          ; Put it at this address
    int 0x13                ; BIOS DISK INTERRUPT
	
	
	jmp 0x8000              ; JUMP TO STAGE 2!
	
	

; The Bootloader "Signature"
times 510-($-$$) db 0 ; Fill the rest of the 512 bytes with zeros
dw 0xaa55             ; The magic number that tells BIOS "this is bootable"
; it ensures that the code is exactly 512 bytes.

