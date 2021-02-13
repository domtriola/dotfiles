all: install update

install:
	scripts/install.sh

update:
	scripts/update.sh

tools:
	scripts/tools.sh

links:
	scripts/links.sh

macos:
	scripts/macos_settings.sh

.PHONY: all install update tools links
