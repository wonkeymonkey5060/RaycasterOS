[org 0x8000] ;load all code in this file, into memory, on from 0x8000

jmp start ;  THIS CODE WILL BE AT 0x8000, JUMPED TO BY ENTRY POINT

gdt_start:
    ; 1. The Null Descriptor (8 bytes of 0)
    dd 0x0
    dd 0x0

    ; 2. The Code Segment
    ; Base=0, Limit=0xFFFFF, Flags=0x9A (Execute/Read), Granularity=0xCF (4KB blocks)
    dw 0xffff    ; Limit (bits 0-15)
    dw 0x0       ; Base (bits 0-15)
    db 0x0       ; Base (bits 16-23)
    db 10011010b ; Access byte
    db 11001111b ; Flags + Limit (bits 16-19)
    db 0x0       ; Base (bits 24-31)

    ; 3. The Data Segment
    ; Identical to Code, but Access=0x92 (Read/Write)
    dw 0xffff
    dw 0x0
    db 0x0
    db 10010010b ; Access byte
    db 11001111b
    db 0x0
gdt_end:

; This is the actual "gdt_descriptor"
gdt_descriptor:
    dw gdt_end - gdt_start - 1 ; Size of the GDT (16-bit)
    dd gdt_start               ; Address of the GDT (32-bit)
	
start:
    cli             ; 1. KILL INTERRUPTS. This is non-negotiable for PM switch.
    
    xor ax, ax      ; 2. Ensure DS is 0 so the GDT address is absolute
    mov ds, ax
    mov es, ax      ; ES was used for VRAM, but we need it for STOSB below

    ; --- Video Mode Code ---
    mov ax, 0x0013 
    int 0x10 

    ; --- Screen Clear Code ---
    mov ax, 0xA000  
    mov es, ax      
    xor di, di      
    mov al, 2       
    mov cx, 64000   
    rep stosb       

    ; --- Switch to Protected Mode ---
    lgdt [gdt_descriptor] 
    
    mov eax, cr0
    or eax, 3
    mov cr0, eax
    
    jmp 0x08:start_32 ; The "Far Jump" to flush the pipeline

[bits 32]
%define backBuffer 0x20000  ; back buffer, directly edited

%define frontBuffer 0xA0000  ; actual vram that the screen displays. backBuffer
;                             data is copied directly to here in order to update
;                             the screen

%define playerData 0x30000  ; dd player.x dd player.y
start_32:
	mov ax, 0x10
	mov ds, ax 
	mov ss, ax
	mov es, ax
	
	
	mov ebp, 0x90000   ; Set the Base of the stack
	mov esp, ebp       ; Set the Top (current pointer) to the same spot
	
	mov dword [playerData], 10
	mov dword [playerData+4], 2

mainLoop:
	
	call check_retrace ;check if monitor is "retracing",
	test al, 1			;tests if true. if true, result = 1 (checks bit 1)
	
	jnz .run ; if test is true (result is 1), runs the rendering sequence
	; if test is false, test again
	call blastBuffer
	jmp mainLoop ; 
	
.run:
	call poll_key  ; gets keyboard input code (if any)
	cmp al, 0
	jz .skip_key_cases
	call key_cases
.skip_key_cases:
	
	call clearScreen ; fills back buffer with a color
	
	mov ecx, 8
	mov edx, 8
	call drawPixel ; drawPixel(ecx, edx)  sets color of a pixel at coordinates
	
	
	mov ecx, [playerData]
	mov edx, [playerData+4]
	call drawPlayer ; draws a 2x2 square at (ecx,edx) assuming (0, 0) is center of the screen
	
	call ray_gen_loop
	
	jmp mainLoop ; go back to mainLoop 
	

ray_gen_loop:
	push ebp
	mov ebp, esp
	sub esp, 32
	mov [esp], dword 512 ; FOV  2048 units = 360 degrees, 512 units = 90 degrees
	mov ecx, 20  ; eye pos (x)
	mov edx, 50  ; eye pos (y)
	mov eax, 0  ; angle offset counter
	
	; [sineTableScale] just holds the scaling of all the fixed point integers
	; we divide by it in the fpu to turn integer into floats
	
	fld dword [sineTableScale] ; st0, will be pushed to st1 by next line
	fild dword [ecx]  ; loads player x (ecx) into fpu register st0 as an integer
	fscale          ; "un-scales" the players x coordinate
	
	fld dword [sineTableScale] ; st0, will be pushed to st1 by next line
	fild dword [ecx]  ;loads player y (edx) into fpu register st0 as an integer
	fscale          ;"un-scales" the players y coordinate
	
	; players x float in st2, y is in st0
	
	
	
.loop:
	cmp eax, [esp] ; end loop if our ray angle offset counter is
	jge .endLoop   ; greater than the max set at [esp + 0]
	
	
	
	fxch st2
	fst dword [ebp-8] ;stores ray start y 8 bytes from stack frame base
	fxch st2 
	fst dword [ebp-12] ;stores ray start x 12 bytes from stack frame base
	
	fld dword [sineTableScale]
	fld dword [sine_table + 50]
	fscale  ; sine of 50 angle units in st0
	
	fst dword [ebp-16] ; stores sine of the ray angle 16 bytes from stack frame base
	
	call per_ray_loop
	
	add eax, 2 ; move next ray 2 angle units "right"
	
.endLoop:
	mov esp, ebp
	pop ebp
	finit
	ret
	
per_ray_loop:
	fld dword [ebp-8]
	fld dword [ebp-12]
	push ebp
	mov ebp, esp
	sub esp, 32
	
	push eax
	fistp dword [ebp-8]
	fistp dword [ebp-16]
	
	mov ecx, [ebp-8]
	mov edx, [ebp-16]
	call drawPixel
	
	pop eax
	mov esp, ebp
	pop ebp
	ret
	
	
	
sineTableScale dd -14.0


%include "main_draw.asm"
	

%include "main_key.asm"



%include "sine_table.asm"
	

	
times 512 - (($ - $$) % 512) db 0
