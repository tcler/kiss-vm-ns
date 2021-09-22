#export PATH:=${PATH}:/usr/local/bin:~/bin

_bin=/usr/bin
completion_path=/usr/share/bash-completion/completions

i in ins inst install:
	sudo cp -af utils/* $(_bin)/.
	sudo cp -af kiss-vm $(_bin)/vm
	sudo cp -af kiss-ns $(_bin)/ns
	sudo cp -af kiss-netns $(_bin)/netns
	sudo mkdir -p /etc/kiss-vm
	sudo cp -af distro-db.bash /etc/kiss-vm/.
	@command -v yum >/dev/null && sudo yum install -y bash-completion 2>/dev/null || :
	@command -v apt >/dev/null && sudo apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y bash-completion 2>/dev/null || :
	@command -v zypper >/dev/null && sudo zypper in --no-recommends -y bash-completion 2>/dev/null || :
	sudo cp bash-completion/* ${completion_path}/.

p pu pull u up update:
	git pull --rebase || :
	@echo

_isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }
