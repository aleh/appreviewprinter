.SUFFIXES:
.SUFFIXES: .lua .d
	
# TODO: exclude config-example.lua and init.lua
SRC=$(wildcard src/*.lua) $(wildcard ustream/*.lua)
EXCLUDE=src/preupload.lua $(wildcard src/test_*.lua) $(wildcard ustream/test_*.lua) $(wildcard src/*example*.lua)
FILES=$(filter-out $(EXCLUDE),$(SRC))

DDIR=.deps
DEPS=$(patsubst %.lua,%.d,$(patsubst %,$(DDIR)/%,$(FILES)))

# UPLOADER=nodemcu-uploader --timeout 10 --port /dev/tty.wchusbserial*
UPLOADER=nodemcu-uploader --timeout 10 --port /dev/tty.usbserial-*

$(DDIR)/%.d: %.lua
	luac-5.4 -p $<
	$(UPLOADER) upload --compile $<:$(notdir $<)
	mkdir -p $(dir $@)
	touch $@
	
$(DDIR)/all.d: $(FILES)

	$(UPLOADER) file remove init.lua
	$(UPLOADER) node restart
	sleep 2	
	
	$(UPLOADER) exec ./src/preupload.lua
	
	make $(DEPS)
	
	$(UPLOADER) upload -r src/init.lua:init.lua
	
	touch $(DDIR)/all.d
	
upload: $(DDIR)/all.d
	
clean:
	rm -rf $(DDIR)
	
format: clean
	$(UPLOADER) file format
	
list:
	$(UPLOADER)	file list

.PHONY: upload format prepare list clean
