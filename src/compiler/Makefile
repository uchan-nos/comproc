OBJS   = main.o token.o
CFLAGS = -Wall -Wextra -O2

.PHONY: all
all: ucc

ucc: $(OBJS)
	$(CC) -o $@ $^

.PHONY: clean
clean:
	rm -f $(OBJS)
