	add fp,0x100
	call main
	st 0x82
fin:
	jmp fin
main:
	cpush fp
	st cstack+0x0
	add fp,0x2
	add fp,0x2
	push 42
	push cstack+0x2
	sta
	pop
	add fp,0x2
	push 2
	push cstack+0x4
	sta
	pop
	push 0
	cpop fp
	ret
