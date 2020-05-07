LUA := $(shell echo `which lua`)
LUA_BINDIR := $(shell echo `dirname $(LUA)`)
LUA_PREFIX := $(shell echo `dirname $(LUA_BINDIR)`)
LUA_VER := $(shell lua -v | sed 's/Lua \([0-9]\{1,\}\.[0-9]\{1,\}\)\..*/\1/')
LUA_SHAREDIR := $(LUA_PREFIX)/share/lua/$(LUA_VER)

ldoc:

install: install_parts
	echo "lua $(LUA_SHAREDIR)/ldoc/ldoc.lua \$$*" > $(LUA_BINDIR)/ldoc
	chmod +x $(LUA_BINDIR)/ldoc

install_luajit: install_parts
	echo "luajit $(LUA_SHAREDIR)/ldoc/ldoc.lua \$$*" > $(LUA_BINDIR)/ldoc
	chmod +x $(LUA_BINDIR)/ldoc

install_parts:
	cp -r ldoc $(LUA_SHAREDIR)
	cp ldoc.lua $(LUA_SHAREDIR)/ldoc

uninstall:
	-rm -r $(LUA_SHAREDIR)/ldoc
	-rm $(LUA_BINDIR)/ldoc

test: test-basic test-example test-md test-tables

RUN=&&  ldoc . && diff -r docs cdocs && echo ok

test-basic:
	cd tests $(RUN)

test-example:
	cd tests && cd example $(RUN)

test-md:
	cd tests && cd md-test $(RUN)

test-tables:
	cd tests && cd simple $(RUN)

test-clean: clean-basic clean-example clean-md clean-tables

CLEAN=&& ldoc . && rd /S /Q cdocs && cp -rf docs cdocs

clean-basic:
	cd tests $(CLEAN)

clean-example:
	cd tests && cd example $(CLEAN)

clean-md:
	cd tests && cd md-test $(CLEAN)

clean-tables:
	cd tests && cd simple $(CLEAN)
