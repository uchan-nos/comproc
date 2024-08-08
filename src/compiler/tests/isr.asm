	add fp,256
	push main
	call
	st 6
fin:
	jmp fin
_ISRfoo:
	cpush fp
	cpop fp
	iret
main:
	cpush fp
	push _ISRfoo
	isr

	push 0
	cpop fp
	ret
