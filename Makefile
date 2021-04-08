#export PATH:=${PATH}:/usr/local/bin:~/bin

_bin=/usr/bin
completion_path=/usr/share/bash-completion/completions

install: pull
	sudo cp -af utils/* $(_bin)/.
	sudo cp -af kiss-vm $(_bin)/vm
	sudo cp -af kiss-ns $(_bin)/ns
	sudo cp -af kiss-netns $(_bin)/netns
	sudo mkdir -p /etc/kiss-vm
	sudo cp -af distro-db.bash /etc/kiss-vm/.

pull:
	git pull --rebase || :
	@echo

_isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }
