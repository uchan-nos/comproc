	add fp,256
	push main
	call
	st 6
fin:
	jmp fin
_ISRfoo:
	iret
main:
	push _ISRfoo
	isr

	push 0
	ret
