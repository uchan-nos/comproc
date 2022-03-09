OBJS = main.o

.PHONY: all
all: ucc

ucc: $(OBJS)
	$(CC) -o $@ $^

.PHONY: clean
clean:
	rm -f $(OBJS)
