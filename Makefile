.SUFFIXES:
.SUFFIXES: .lua .d
	
# TODO: exclude config-example.lua and init.lua
SRC=$(wildcard src/*.lua) ustream/uhttp.lua ustream/ujson.lua ustream/review_feed_parser.lua
EXCLUDE=*example* *test* preupload.lua
FILES=$(filter-out $(EXCLUDE),$(SRC))

DDIR=.deps
DEPS=$(patsubst %.lua,%.d,$(patsubst %,$(DDIR)/%,$(FILES)))

UPLOADER=nodemcu-uploader --port /dev/tty.wchusbserial* 

$(DDIR)/%.d: %.lua
	luac -p $<
	$(UPLOADER) upload --compile $<:$(notdir $<)
	mkdir -p $(dir $@)
	touch $@
	
$(DDIR)/all.d: $(FILES)

	$(UPLOADER) file remove init.lua
	$(UPLOADER) node restart
	sleep 2	
	
	$(UPLOADER) upload preupload.lua
	$(UPLOADER) exec preupload.lua
	
	make $(DEPS)
	
	$(UPLOADER) upload -r init.lua
	
	touch $(DDIR)/all.d
	
upload: $(DDIR)/all.d
	
clean:
	rm -rf $(DDIR)
	
format: clean
	$(UPLOADER) file format
	
list:
	$(UPLOADER)	file list

.PHONY: upload format prepare list clean
