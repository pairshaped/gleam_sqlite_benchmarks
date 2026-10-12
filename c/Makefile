CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -Werror
SQLITE_CFLAGS := $(shell pkg-config --cflags sqlite3)
SQLITE_LIBS := $(shell pkg-config --libs sqlite3)

benchmark: benchmark.c
	$(CC) $(CFLAGS) $(SQLITE_CFLAGS) -o $@ $< $(SQLITE_LIBS)

clean:
	rm -f benchmark

.PHONY: clean
