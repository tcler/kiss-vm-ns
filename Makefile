#export PATH:=${PATH}:/usr/local/bin:~/bin

_bin=/usr/local/bin
completion_path=/usr/share/bash-completion/completions

install: _isroot
	cp -af utils/* $(_bin)/.
	cp -af kiss-vm $(_bin)/vm
	cp -af kiss-ns $(_bin)/ns

_isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }
