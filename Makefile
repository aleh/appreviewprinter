.SUFFIXES:
.SUFFIXES: .lua .d
	
DDIR=.deps
FILES=$(wildcard *.lua) ustream/uhttp.lua ustream/ujson.lua ustream/review_feed_parser.lua
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
	
	make $(DEPS)
	
	$(UPLOADER) upload -r init.lua
	
	touch $(DDIR)/all.d
	
upload: $(DDIR)/all.d
	
format:
	rm -rf $(DDIR)
	$(UPLOADER) file format

.PHONY: upload format prepare
