PREFIX ?= /usr/local
DESTDIR ?=

BINDIR = $(DESTDIR)$(PREFIX)/bin
SHAREDIR = $(DESTDIR)$(PREFIX)/share/nowspinning
APPDIR = $(DESTDIR)$(PREFIX)/share/applications
DOCDIR = $(DESTDIR)$(PREFIX)/share/doc/nowspinning
LICENSEDIR = $(DESTDIR)$(PREFIX)/share/licenses/nowspinning

.PHONY: install uninstall

install:
	install -d $(SHAREDIR)
	cp -r nowspinning/. $(SHAREDIR)/
	install -Dm755 bin/nowspinning $(BINDIR)/nowspinning
	install -Dm644 desktop/nowspinning.desktop $(APPDIR)/nowspinning.desktop
	install -Dm644 config.example.json $(DOCDIR)/config.example.json
	install -Dm644 LICENSE $(LICENSEDIR)/LICENSE
	install -Dm644 nowspinning/fonts/PermanentMarker-LICENSE.txt $(LICENSEDIR)/PermanentMarker-LICENSE.txt

uninstall:
	rm -rf $(SHAREDIR) $(DOCDIR) $(LICENSEDIR)
	rm -f $(BINDIR)/nowspinning $(APPDIR)/nowspinning.desktop
