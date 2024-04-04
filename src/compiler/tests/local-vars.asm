	add fp,256
	call main
	st 6
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
	ld cstack+2
	push 1
	sub
	cpop fp
	ret
