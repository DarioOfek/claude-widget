APP     = ClaudeWidget
BUNDLE  = $(APP).app
BINARY  = .build/release/$(APP)
PLIST   = Sources/ClaudeWidget/Info.plist

.PHONY: build bundle run clean install

build:
	swift build -c release 2>&1

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BINARY) $(BUNDLE)/Contents/MacOS/$(APP)
	cp $(PLIST)   $(BUNDLE)/Contents/Info.plist
	@echo "Bundle ready: $(BUNDLE)"

run: bundle
	open $(BUNDLE)

install: bundle
	cp -R $(BUNDLE) /Applications/$(BUNDLE)
	@echo "Installed to /Applications/$(BUNDLE)"

clean:
	rm -rf .build $(BUNDLE)
