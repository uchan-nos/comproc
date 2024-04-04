	add fp,256
	call main
	st 6
fin:
	jmp fin
main:
	cpush fp
	push 14
	cpop fp
	ret
