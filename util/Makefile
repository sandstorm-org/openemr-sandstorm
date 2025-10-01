CFLAGS=-Wall --pedantic -Os
PREFIX=/usr/local/bin

SOURCES=$(wildcard src/*.c)
OBJECTS=$(patsubst %.c, %.o, $(SOURCES))

help:
	@echo "Targets:"
	@echo "    all        compile the utilities"
	@echo "    clean      start over"
	@echo "    install    install geteid as getegid and geteuid in /usr/local/bin"
	@echo "    uninstall  remove installed binaries"

$(OBJECTS): src/%.o : src/%.c
	$(CC) $(CFLAGS) -c $< -o $@

all: bin/geteid

bin:
	@mkdir -p bin

bin/geteid: bin src/geteid.o
	$(CC) $(CFLAGS) -o $@ $(OBJECTS)
	strip $@

.PHONY: clean
clean:
	rm -f $(OBJECTS)
	rm -rf bin

.PHONY: install
install:
	install -m 755 -o root -g staff bin/geteid $(PREFIX)/getegid
	ln -f $(PREFIX)/getegid $(PREFIX)/geteuid

.PHONY: uninstall
uninstall:
	rm -f $(PREFIX)/getegid
	rm -f $(PREFIX)/geteuid

