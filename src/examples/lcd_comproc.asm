push 0x20
popfp
call main
st 0x1e
fin:
jmp fin

delay_ms:
enter
push 2
push 0
std
pop
L_0:
push 0
ldd
push 0
lt
jz L_1
jmp L_0
L_1:
leave
ret

lcd_out4:
enter
pushbp
push 0x2
add
std
pop
pushbp
push 0x4
add
std
pop
pushbp
push 0x6
add
popfp
push 4
pushbp
push 0x4
add
ldd
shl
pushbp
push 0x2
add
ldd
push 1
or
or
push 0x1d
std.1
pop
call delay_ms
push 0x1d
ldd.1
push 0xfe
and
push 0x1d
std.1
pop
call delay_ms
leave
ret

lcd_out8:
enter
pushbp
push 0x2
add
std
pop
pushbp
push 0x4
add
std
pop
pushbp
push 0x6
add
popfp
push 4
pushbp
push 0x4
add
ldd
sar
pushbp
push 0x2
add
ldd
call lcd_out4
pushbp
push 0x4
add
ldd
pushbp
push 0x2
add
ldd
call lcd_out4
push 0
leave
ret

main:
enter
pushbp
push 0x2
add
popfp
pushfp
push 0x2
add
popfp
push 128
push 0
call lcd_out8
pop
push 0
pushbp
push 0x2
add
std
pop
L_2:
push 15
pushbp
push 0x2
add
ldd
lt
jz L_3
push STR_0
pushbp
push 0x2
add
ldd
add
ldd.1
push 4
call lcd_out8
pop
L_4:
pushbp
push 0x2
add
ldd
push 1
dup 1
add
pushbp
push 0x2
add
sta.2
pop
pop
jmp L_2
L_3:
push 192
push 0
call lcd_out8
pop
push 0
pushbp
push 0x2
add
std
pop
L_5:
push 15
pushbp
push 0x2
add
ldd
lt
jz L_6
push STR_1
pushbp
push 0x2
add
ldd
add
ldd.1
push 4
call lcd_out8
pop
L_7:
pushbp
push 0x2
add
ldd
push 1
dup 1
add
pushbp
push 0x2
add
sta.2
pop
pop
jmp L_5
L_6:
push 1
leave
ret
STR_0: 
db 0x43,0x6f,0x6d,0x50,0x72,0x6f,0x63,0x20,0x50,0x72,0x6f,0x6a,0x65,0x63,0x74,0
STR_1: 
db 0x43,0x50,0x55,0x20,0xa6,0x20,0xbc,0xde,0xbb,0xb8,0x20,0xbc,0xd6,0xb3,0x21,0
