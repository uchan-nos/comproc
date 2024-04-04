	add fp,256
	call main
	st 6
fin:
	jmp fin
main:
	cpush fp
	st cstack+0
	add fp,2
	ld cstack+0
	push 3
	lt
	jz L_1
	push 42
	cpop fp
	ret
L_1:
	push 0
	cpop fp
	ret
