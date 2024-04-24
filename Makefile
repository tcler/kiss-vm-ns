#export PATH:=${PATH}:/usr/local/bin:~/bin

_bin=/usr/bin
_repon=kiss-vm-ns
_confdir=/etc/$(_repon)
_oldconfdir=/etc/kiss-vm
_varlibdir=/var/lib/kiss-vm
_sharedir=/usr/share/kiss-vm
_libdir=/usr/lib/bash
_dnfconf=$(shell test -f /etc/yum.conf && echo /etc/yum.conf || echo /etc/dnf/dnf.conf)
completion_path=/usr/share/bash-completion/completions
required_pkgs=curl iproute tmux expect bind-utils bash-completion nmap ipcalc
required_pkgs_debian=curl iproute2 tmux expect bind9-utils bash-completion nmap ipcalc-ng
required_pkgs_arch=curl iproute2 tmux expect bind bash-completion nmap ipcalc
ifeq ("$(wildcard $(completion_path))", "")
	completion_path=/usr/local/share/bash-completion/completions
endif
SUDO=sudo
ifeq (, $(shell which sudo))
	SUDO=
endif

HTTP_PROXY := $(shell grep -q redhat.com /etc/resolv.conf && echo "squid.redhat.com:8080")

i in ins inst install: _isroot
	@-test -f $(_dnfconf) && { grep -q ^metadata_expire= $(_dnfconf) 2>/dev/null || echo metadata_expire=7d >>$(_dnfconf); }
	$(SUDO) cp -af utils/* $(_bin)/.
	@$(SUDO) rm -f $(_bin)/install-sbopkg.sh /usr/local/bin/port-available.sh
	$(SUDO) cp -af kiss-vm $(_bin)/vm
	$(SUDO) cp -af kiss-ns $(_bin)/ns
	$(SUDO) cp -af kiss-netns $(_bin)/netns
	@test ! -L $(_oldconfdir) -a -d $(_oldconfdir) && $(SUDO) mv $(_oldconfdir) $(_confdir) || true
	$(SUDO) mkdir -p $(_confdir) $(_libdir) $(_varlibdir) $(_sharedir)
	@-if getent group libvirt &>/dev/null; then \
	  $(SUDO) chown root:libvirt -R $(_varlibdir) && $(SUDO) chmod g+ws $(_varlibdir); fi
	@$(SUDO) ln -s $(_confdir) $(_oldconfdir)
	$(SUDO) cp -af distro-db.bash $(_confdir)/.
	$(SUDO) cp -af lib/* $(_libdir)/.
	$(SUDO) cp -af share/* $(_sharedir)/.
	@command -v yum >/dev/null && $(SUDO) yum install -y $(required_pkgs) 2>/dev/null || :
	@command -v apt >/dev/null && $(SUDO) apt-get install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y $(required_pkgs_debian) 2>/dev/null || :
	@command -v zypper >/dev/null && $(SUDO) zypper in --no-recommends -y $(required_pkgs) 2>/dev/null || :
	@command -v pacman >/dev/null && $(SUDO) pacman -Sy --noconfirm $(required_pkgs_arch) 2>/dev/null || :
	$(SUDO) cp -r AnswerFileTemplates /usr/share/.
	$(SUDO) cp bash-completion/* $(completion_path)/.
	test -f /usr/bin/egrep && sed -ri '/^cmd=|^echo/d' /usr/bin/egrep || { echo 'exec grep -E "$$@"' >/usr/bin/egrep; chmod +x /usr/bin/egrep; }
	@$(SUDO) cp -f /etc/os-release $(_confdir)/os-release
	@$(SUDO) curl -Ls http://api.github.com/repos/tcler/$(_repon)/commits/master -o $(_confdir)/version
	@rm -f /etc/profile.d/nano-default-editor.*

u up update:
	https_proxy=$(HTTP_PROXY) git pull --rebase || :
	@echo
p pu push:
	https_proxy=$(HTTP_PROXY) git push origin master || :
	@echo

install_macos_kvm_utils:
	echo "{JFYI} macOS-kvm-utils has been moved to https://github.com/tcler/macOS-kvm-utils"

_isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }
