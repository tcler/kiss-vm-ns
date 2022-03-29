#export PATH:=${PATH}:/usr/local/bin:~/bin

_bin=/usr/bin
_repon=kiss-vm-ns
_confdir=/etc/$(_repon)
_oldconfdir=/etc/kiss-vm
completion_path=/usr/share/bash-completion/completions
ifeq ("$(wildcard $(completion_path))", "")
	completion_path=/usr/local/share/bash-completion/completions
endif
SUDO=sudo
ifeq (, $(shell which sudo))
	SUDO=
endif

i in ins inst install:
	$(SUDO) cp -af utils/* $(_bin)/.
	$(SUDO) cp -af kiss-vm $(_bin)/vm
	$(SUDO) cp -af kiss-ns $(_bin)/ns
	$(SUDO) cp -af kiss-netns $(_bin)/netns
	test -d $(_oldconfdir) && $(SUDO) mv $(_oldconfdir) $(_confdir) || true
	$(SUDO) mkdir -p $(_confdir)
	$(SUDO) cp -af distro-db.bash $(_confdir)/.
	@command -v yum >/dev/null && $(SUDO) yum install -y bash-completion 2>/dev/null || :
	@command -v apt >/dev/null && $(SUDO) apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y bash-completion 2>/dev/null || :
	@command -v zypper >/dev/null && $(SUDO) zypper in --no-recommends -y bash-completion 2>/dev/null || :
	$(SUDO) cp bash-completion/* $(completion_path)/.
	$(SUDO) wget -qO- http://api.github.com/repos/tcler/$(_repon)/commits/master -O $(_confdir)/version
	@$(SUDO) rm -rf /etc/kiss-vm
	$(SUDO) cp -r AnswerFileTemplates /usr/share/.

p pu pull u up update:
	git pull --rebase || :
	@echo

_isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }
