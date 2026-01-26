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
	; --- ENABLE FPU ---
    mov eax, cr0
    and ax, 0xFFFB      ; Clear the TS (Task Switched) bit
    or ax, 0x2          ; Set the MP (Monitor Coprocessor) bit
    mov cr0, eax
    finit               ; Safely initialize it
	mov ax, 0x10
	mov ds, ax 
	mov ss, ax
	mov es, ax
	
	
	mov ebp, 0x90000   ; Set the Base of the stack
	mov esp, ebp       ; Set the Top (current pointer) to the same spot
	
	
	mov dword [playerData], 0
	mov dword [playerData+4], 0
	
	fild dword [playerData]
	;fiadd dword [constneg4]
	fstp dword [playerData]
	
	fild dword [playerData+4]
	fstp dword [playerData+4]
	
	mov dword [playerData+8], 160

mainLoop:
	
	call check_retrace ;check if monitor is "retracing",
	test al, 1			;tests if true. if true, result = 1 (checks bit 1)
	
	jnz .run ; if test is true (result is 1), runs the rendering sequence
	; if test is false, test again
	call blastBuffer
	jmp mainLoop ; 
	
.run:

	xor eax, eax
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
	
	; wall visualisers
	
	xor ecx, ecx
	xor edx, edx
	mov dword ecx, [Map]
	mov dword edx, [Map+4]
	imul ecx, 8
	add ecx, 160
	imul edx, -8
	add edx, 100
	
	call drawPixel
	xor ecx, ecx
	xor edx, edx
	mov dword ecx, [Map+8]
	mov dword edx, [Map+12]
	imul ecx, 8
	add ecx, 160
	imul edx, -8
	add edx, 100
	
	call drawPixel
	
	call line_draw_loop
	
	jmp mainLoop ; go back to mainLoop 

line_draw_loop:
	push ebp
	mov ebp, esp
	sub esp, 32
	xor ecx, ecx
	;sub ecx, 1
.loop:
	cmp ecx, 320
	jge .end
	
	mov dword ebx, [lines + ecx*4]
	mov [ebp-4], ecx
	fild dword [ebp-4]
	fisub dword [const160]
	fidiv dword [const320]
	fldpi
	fmulp
	fidiv dword [const2]
	fcos
	fmul dword [constpoint8]
	fmul dword [lines + ecx*4]
	
	fistp [ebp-8]
	
	mov ebx, 80
	sub dword ebx, [ebp-8]
	
	
	
	call drawColumn
	
	add ecx, 1
	jmp .loop
.end:
	mov esp, ebp
	pop ebp
	ret
	
drawColumn:
	push ebp
	mov ebp, esp
	sub esp, 32
	
	
	xor eax, eax
	add eax, ebx
	mov [ebp-4], eax
	xor eax, eax
	sub eax, ebx
	
.loop:
	cmp eax, [ebp-4]
	jg .end
	
	mov edx, 0
	add edx, eax
	add edx, 100
	
	mov ebx, 33
	
	call drawPixel
	
	add eax, 1
	jmp .loop
.end:
	mov esp, ebp
	pop ebp
	ret

ray_gen_loop:  ;  FOV  1280 units = 360 degrees, 512 units = 90 degrees
	push ebp
	mov ebp, esp
	sub esp, 32
	mov [ebp-4], 160   ; half of fov must be moved here
	mov [ebp-8], dword 0
	;mov ecx, [playerData]  	; eye pos (x)
	;mov edx, [playerData+4]  ; eye pos (y)
	
	
	mov eax, [ebp-8]
	add eax, 160
	add eax, [playerData+8]
	mov [ebp-8], eax
	
	mov eax, 0
	sub eax, 160  ; subtract half of fov
	add eax, [playerData+8]
	mov [esp-16], 0
	mov edx, 0
	
	
	
	
	
	
	
.loop:
	cmp eax, [ebp-8] ; end loop if our ray angle offset counter is
	jge .endLoop   ; greater than the max set at [esp + 0]
	
	call per_ray_loop
	
	add eax, 1 ; move next ray 1 angle units "right"
	add edx, 1
	
	
	jmp .loop
	
.endLoop:
	mov esp, ebp
	pop ebp
	finit
	ret
	
per_ray_loop:
	finit
	push ebp
	mov ebp, esp
	sub esp, 96
	mov [ebp-16], edx
	push ecx
	push edx
	push eax
	
	xor edx, edx
	
	
	
	
	; converts units (320 units = 90 degrees) to degrees
	mov [ebp-32], eax   ; puts ray number in eax
	fild dword [ebp-32] ; puts ray number (eax) in st0
	fidiv dword [const320] ; divides it by 320
	fldpi ; st0 --> st1, pi goes into st0
	fmulp ; multiplies st0 and st1, into st1, pops st0
	fidiv dword [const2] ; divides st0 by 2. now, the ray angle in radians, is in st0
	
	; puts cos(st0) into st0, puts sin(st0) into st1
	fsincos
	;fimul dword [const90]
	fstp dword [ebp-36]
	fstp dword [ebp-40]


	
	; [ebp-36] is for x component of ray vector 
	; [ebp-40] is for y component of ray vector

	
	; [ebp-44] is for x component of wall AB vector
	; [ebp-48] is for y component of wall AB vector
	; [ebp-52] is for x component of PA vector  (player to A)
	; [ebp-56] is for y component of PA vector  (player to A) 
	
	call wall_loop
	
	pop eax
	pop edx
	pop ecx
	
	mov esp, ebp
	pop ebp
	ret
	
wall_loop: ;edx is wall counter
	cmp edx, [numWalls]
	jge .end_loop
	
	shl edx, 4
	
	
	fld dword [Map+edx]
	fld dword [Map+edx + 8]
	fsubp st1, st0
	fstp dword [ebp-44]        ;moves non-normalized vector A --> B into [ebp-44]  (x component)
	
	fld dword [Map+edx + 4]
	fld dword [Map+edx + 12]
	fsubp st1, st0
	fstp dword [ebp-48]        ;moves non-normalized vector A --> B into [ebp-48]  (y component)
	
	
	
	fld dword [playerData]     ;moves non-normalized vector Player --> A into [ebp-52]  (x component)
	fld dword [Map+edx]
	fsubp st1, st0
	fstp dword [ebp-52]
	
	fld dword [playerData+4]   ;moves non-normalized vector Player --> A into [ebp-56]  (y component)
	fld dword [Map+edx + 4]
	fsubp st1, st0
	fstp dword [ebp-56]
	
	
	call ray_per_wall_test
	
	shr edx, 4
	add edx, 1
	
	cmp ebx, 1

	jz .setColumn
	
	jmp wall_loop
.setColumn:
	mov ebx, [ebp-16]
	mov [ebp-8], ecx
	fld [ebp-8]
	fimul [const20]
	fstp [ebp-8]
	mov ecx, [ebp-8]
	mov dword [lines+ebx*4], ecx

	jmp wall_loop
.end_loop:
	ret

ray_per_wall_test: ; returns 0 in ebx if no intersect, returns 1 in ebx if yes intersect, returns distance in ecx
	fld dword [ebp-36]  ; Rx
	fld dword [ebp-48]  ; Wy
	fmulp
	fstp dword [ebp-60] ; Rx*Wy
	
	fld dword [ebp-40] ; Ry
	fld dword [ebp-44] ; Wx
	fmulp
	fstp dword [ebp-64] ; Ry*Wx
	
	fld dword [ebp-60] ; Rx*Wy
	fld dword [ebp-64] ; Ry*Wx
	fsubp
	fst dword [ebp-68] ; Rx*Wy-Ry*Wx  (denom)
	
	
	fldz
	fcomi st0, st1  ; compare Rx*Wy-Ry*Wx (denom) and 0, if equal, there is no intersection
	fstp st0
	fstp st0
	
	je .no_intersection
	
	fld dword [ebp-52]
	fld dword [ebp-48]
	fmulp
	fld dword [ebp-56]
	fld dword [ebp-44]
	fmulp
	fsubp
	fld dword [ebp-68]
	fdivp st1, st0
	fstp dword [ebp-72]   ; t = (Px*Wy - Py*Wx)/denom
	
	fld dword [ebp-52]
	fld dword [ebp-40]
	fmulp
	fld dword [ebp-56]
	fld dword [ebp-36]
	fmulp
	fsubp
	fld dword [ebp-68]
	fdivp st1, st0
	fstp dword [ebp-76]  ; u = (Px*Ry - Py*Rx)/denom
	
	; if t >= 0 and 0 <= u <= 1:
	fldz
	fld dword [ebp-72]
	fcomi st0, st1
	fstp st0
	fstp st0
	
	jae .TGZ
	
	jmp .no_intersection
	
	
.TGZ:
	fld dword [constMaxRayDistance]
	fld dword [ebp-72]  ; t at st0, maxray at st1
	fcomi st0, st1
	fstp st0
	fstp st0
	jb .TLM

	jmp .no_intersection
.TLM:  ; if t is less than max distance (50)
	fldz
	fld dword [ebp-76]
	fcomi st0, st1
	fstp st0
	fstp st0
	jae .UGZ

	jmp .no_intersection
.UGZ:
	fld1
	fld dword [ebp-76]
	fcomi st0, st1
	fstp st0
	fstp st0
	jbe .pass
	
	jmp .no_intersection
.pass:
	mov ebx, 1
	fld dword [ebp-72]
	
	mov dword ecx, [ebp-72]
	ret
	
	
.no_intersection:
	mov ebx, 0
	mov ecx, 0
	ret

	
	
	
sineTableScale dd -14.0

const2 dd 2
constneg4 dd -4
const90 dd 90
const320 dd 320
const20 dd 3
const160 dd 160
constpoint5 dd 0.5
const4 dd 4
constpoint8 dd 0.8

constMaxRayDistance dd 20.0

numWalls dd 6
Map:
dd -10.0, 10.0, -2.0, 10.0
dd 2.0, 10.0, 10.0, 10.0
dd -10.0, 10.0, -10.0, -10.0
dd -10.0, -10.0, 10.0, -10.0
dd 10.0, 10.0, 10.0, -10.0
dd -15.0, 20.0, 15.0, 12.0

lines: times 320 dd 0

%include "main_draw.asm"
	

%include "main_key.asm"






	
times 3072 - (($ - $$) % 512) db 0 ;ensures file is 6 sectors long
