poll_key:
	in al, 0x64  ; key status port
	test al, 1
	jz .no_key
	in al, 0x60
	ret
.no_key:
	xor al, al
	ret
	

key_cases:

	cmp al, 0x11 ; test for W make code
	jnz .skipMakeW_key_cases
	call key_W_press
.skipMakeW_key_cases:

	cmp al, 0x1F ; test for S make code
	jnz .skipMakeS_key_cases
	call key_S_press
.skipMakeS_key_cases:

	cmp al, 0x1E ; test for A make code
	jnz .skipMakeA_key_cases
	call key_A_press
.skipMakeA_key_cases:

	cmp al, 0x20 ; test for D make code
	jnz .skipMakeD_key_cases
	call key_D_press
.skipMakeD_key_cases:
	ret

key_W_press:
	mov ebx, [playerData+4]
	sub ebx, 5
	mov [playerData+4], ebx
	ret
key_S_press:
	mov ebx, [playerData+4]
	add ebx, 5
	mov [playerData+4], ebx
	ret
key_A_press:
	mov ebx, [playerData]
	sub ebx, 5
	mov [playerData], ebx
	ret
key_D_press:
	mov ebx, [playerData]
	add ebx, 5
	mov [playerData], ebx
	ret
