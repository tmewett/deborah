install:
	cp -uTR lib $(DESTDIR)/usr/share/makepkg
	install -Cm 644 makepkg.conf $(DESTDIR)/etc
	install -C makepkg debsearch pbget/pbget.sh $(DESTDIR)/usr/bin

uninstall:
	rm -r \
		$(DESTDIR)/usr/share/makepkg \
		$(DESTDIR)/etc/makepkg.conf \
		$(DESTDIR)/usr/bin/debsearch \
		$(DESTDIR)/usr/bin/makepkg \
		$(DESTDIR)/usr/bin/pbget
