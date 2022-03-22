#export PATH:=${PATH}:/usr/local/bin:~/bin

_bin=/usr/bin
completion_path=/usr/share/bash-completion/completions
ifeq ("$(wildcard $(completion_path))", "")
	completion_path=/usr/local/share/bash-completion/completions
endif
ifeq (, $(shell which sudo))
	SUDO=
endif

i in ins inst install:
	$(SUDO) cp -af utils/* $(_bin)/.
	$(SUDO) cp -af kiss-vm $(_bin)/vm
	$(SUDO) cp -af kiss-ns $(_bin)/ns
	$(SUDO) cp -af kiss-netns $(_bin)/netns
	$(SUDO) mkdir -p /etc/kiss-vm
	$(SUDO) cp -af distro-db.bash /etc/kiss-vm/.
	@command -v yum >/dev/null && $(SUDO) yum install -y bash-completion 2>/dev/null || :
	@command -v apt >/dev/null && $(SUDO) apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y bash-completion 2>/dev/null || :
	@command -v zypper >/dev/null && $(SUDO) zypper in --no-recommends -y bash-completion 2>/dev/null || :
	$(SUDO) cp bash-completion/* $(completion_path)/.

p pu pull u up update:
	git pull --rebase || :
	@echo

_isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }
