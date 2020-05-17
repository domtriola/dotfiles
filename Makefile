all: install update

install:
	install/install.sh

update:
	install/update.sh

.PHONY: all install update
