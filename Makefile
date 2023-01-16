#export PATH:=${PATH}:/usr/local/bin:~/bin

_bin=/usr/bin
_repon=kiss-vm-ns
_confdir=/etc/$(_repon)
_oldconfdir=/etc/kiss-vm
_libdir=/usr/lib/bash
completion_path=/usr/share/bash-completion/completions
ifeq ("$(wildcard $(completion_path))", "")
	completion_path=/usr/local/share/bash-completion/completions
endif
SUDO=sudo
ifeq (, $(shell which sudo))
	SUDO=
endif

i in ins inst install: _install_macos_kvm_utils
	$(SUDO) cp -af utils/* $(_bin)/.
	@$(SUDO) rm -f $(_bin)/install-sbopkg.sh /usr/local/bin/port-available.sh
	$(SUDO) cp -af kiss-vm $(_bin)/vm
	$(SUDO) cp -af kiss-ns $(_bin)/ns
	$(SUDO) cp -af kiss-netns $(_bin)/netns
	@test -d $(_oldconfdir) && $(SUDO) mv $(_oldconfdir) $(_confdir) || true
	$(SUDO) mkdir -p $(_confdir) $(_libdir)
	@$(SUDO) ln -s $(_confdir) $(_oldconfdir)
	$(SUDO) cp -af distro-db.bash $(_confdir)/.
	$(SUDO) cp -af lib/* $(_libdir)/.
	@command -v yum >/dev/null && $(SUDO) yum install -y bash-completion bind-utils 2>/dev/null || :
	@command -v apt >/dev/null && $(SUDO) apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y bash-completion bind-utils 2>/dev/null || :
	@command -v zypper >/dev/null && $(SUDO) zypper in --no-recommends -y bash-completion bind-utils 2>/dev/null || :
	$(SUDO) cp -r AnswerFileTemplates /usr/share/.
	$(SUDO) cp bash-completion/* $(completion_path)/.
	@$(SUDO) wget -qO- http://api.github.com/repos/tcler/$(_repon)/commits/master -O $(_confdir)/version

p pu pull u up update:
	git pull --rebase || :
	@echo

_install_macos_kvm_utils:
	$(SUDO) cp -r macOS-kvm-utils /usr/share/.

_isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }
