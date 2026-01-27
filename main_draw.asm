blastBuffer: ; draws backBuffer onto main vram buffer
	mov esi, backBuffer  ; source address
	mov edi, frontBuffer ; destination adress
	mov ecx, 16000       ; number of doublewords to copy
	
	cld
	
	rep movsd
	ret
	
drawPixel:
	push ebp
	mov ebp, esp
	sub esp, 32
	mov [ebp-4], ebx
	
	push edx
	imul edx, 320
	mov ebx, edx
	add ebx, ecx
	mov edx, [ebp-4]
	mov byte [backBuffer + ebx], dl
	pop edx
	
	mov esp, ebp
	pop ebp
	ret
	
drawPlayer:  ;   drawPlayer( player.x ECX,  player.y EDX ) 
	call .screenX
	call .screenY
	
	cmp eax, 0
	jl .offScreen
	
	cmp ebx, 0
	jl .offScreen
	
	cmp eax, 319
	jg .offScreen
	
	;cmp ebx, 199
	;jge .offScreen
	
	; if on screen:
	
	imul ebx, 320
	add eax, ebx
	
	mov byte [backBuffer + eax], 15
	add eax, 1
	mov byte [backBuffer + eax], 15
	add eax, 319
	mov byte [backBuffer + eax], 15
	add eax, 1
	mov byte [backBuffer + eax], 15
	ret
	
.screenX:  ;     puts screen x coordinate into eax
	mov eax, ecx
	add eax, 160
	ret
.screenY:  ;     puts screen y coordinate into ebx
	mov ebx, edx
	add ebx, 100
	ret
.offScreen:
	ret
	

clearScreen:
	mov edi, backBuffer
	mov ecx, 16000
	
	mov eax, 0x02020202
	
	cld
	
	rep stosd
	ret

check_retrace:
	mov dx, 0x03DA
	in al, dx
	test al, 8 ; Check bit 3
	jnz .retrace_true
	mov ax, 0
	ret
.retrace_true:
	mov ax, 1
	ret