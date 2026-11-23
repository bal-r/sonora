CONFIG ?= release
APP = build/Sonora.app

.PHONY: all build app run icon dmg clean lint

all: app

build:
	swift build -c $(CONFIG)

app:
	CONFIG=$(CONFIG) ./scripts/bundle.sh

run: app
	open $(APP)

icon:
	swift scripts/make-icon.swift .

dmg: app
	rm -rf build/dmg
	mkdir -p build/dmg
	cp -R $(APP) build/dmg/
	ln -s /Applications build/dmg/Applications
	rm -f build/Sonora.dmg
	hdiutil create -volname Sonora -srcfolder build/dmg -ov -format UDZO build/Sonora.dmg
	@echo "✓ build/Sonora.dmg"

clean:
	rm -rf build .build

lint:
	swiftformat --lint Sources 2>/dev/null || true
	swiftlint lint --quiet 2>/dev/null || true
