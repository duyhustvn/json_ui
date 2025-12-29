program=JsonUI

test:
	flutter test

analyze:
	flutter analyze

build-linux:
	flutter build linux --release

run:
	flutter run lib/main.dart

install:
	cp -R build/linux/x64/release/bundle /opt/$(program)
	sudo mkdir -p /opt/$(program)/icons
	cp icons/json.png /opt/$(program)/icons/json.png
	cp json_ui.desktop /usr/share/applications/
