install:
	cp -uR lib /usr/share/makepkg
	install -Cm 644 makepkg.conf /etc/makepkg.conf
	install -C makepkg debsearch /usr/bin

uninstall:
	rm -r /usr/share/makepkg /etc/makepkg.conf /usr/bin/debsearch /usr/bin/makepkg
