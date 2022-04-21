OBJS   = main.o ast.o symbol.o token.o
CFLAGS = -Wall -Wextra -O0 -g

.PHONY: all
all: ucc

ucc: $(OBJS)
	$(CC) -o $@ $^

.PHONY: clean
clean:
	rm -f $(OBJS)
