all: install update

install:
	install/install.sh

update:
	install/update.sh

tools:
	install/tools.sh

.PHONY: all install update tools
