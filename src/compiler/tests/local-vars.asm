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
	st cstack+2
	push 2
	st cstack+4
	push 1
	ld cstack+2
	sub
	cpop fp
	ret
