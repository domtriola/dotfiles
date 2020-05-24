all: install update

install:
	install/install.sh

update:
	install/update.sh

tools:
	install/tools.sh

links:
	install/links.sh

.PHONY: all install update tools links
