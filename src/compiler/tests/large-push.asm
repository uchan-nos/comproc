	add fp,256
	push main
	call
	st 6
fin:
	jmp fin
main:
	cpush fp
	add fp,2
	push 24237
	sign
	st cstack+0
	ld cstack+0
	push 15
	sar
	cpop fp
	ret
