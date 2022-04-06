OBJS   = main.o
CFLAGS = -Wall -Wextra -O0 -g

.PHONY: all
all: uasm

uasm: $(OBJS)
	$(CC) -o $@ $^

.PHONY: clean
clean:
	rm -f $(OBJS)
