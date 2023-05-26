	add fp,256
	call main
	st 130
fin:
	jmp fin
main:
	cpush fp
	st cstack+0
	add fp,6
	push 42
	push cstack+2
	sta
	pop
	push 2
	push cstack+4
	sta
	pop
	push 0
	cpop fp
	ret
