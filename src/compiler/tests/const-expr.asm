	add fp,256
	push main
	call
	st 6
fin:
	jmp fin
main:
	cpush fp
	.push 2
	.push 3
	.push 4
	.mul
	.add
	push $top
	cpop fp
	ret
