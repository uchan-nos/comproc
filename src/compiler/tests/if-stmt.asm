	add fp,256
	push main
	call
	st 6
fin:
	jmp fin
main:
	cpush fp
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
