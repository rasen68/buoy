.PHONY: all
all: exe daemon wrapper

.PHONY: exe
exe: src/buoy-server.janet src/buoy-client.janet 
	sudo jpm deps
	jpm build
	mkdir -p "${HOME}/.buoy/bin"
	sudo cp "build/buoy-client" "/usr/local/bin/"
	sudo cp "build/buoy-server" "/usr/local/bin/"

.PHONY: daemon
daemon: systemd/buoy-server.service
	mkdir -p "${HOME}/.config/systemd/user"
	cp "systemd/buoy-server.service" "${HOME}/.config/systemd/user"
	systemctl --user enable buoy-server #set to launch on boot
	systemctl --user start buoy-server #launch right now!

.PHONY: wrapper
wrapper: scripts/buoy-interface.sh scripts/bashrc-install.sh
	mkdir -p "${HOME}/.local/share/buoy/"	
	cp "scripts/buoy-interface.sh" "${HOME}/.local/share/buoy/"	
	#add line in bashrc sourcing this function
	bash "scripts/bashrc-install.sh"

.PHONY: update
update:
	git pull
	@$(MAKE) all


# will not remove anything from bashrc
.PHONY: clean
clean: clean-build clean-data clean-daemon

.PHONY: clean-save-data
clean-save-data: clean-build clean-daemon

.PHONY: clean-build
clean-build:
	rm -rf build
	sudo rm -f "/usr/local/bin/buoy-client"
	sudo rm -f "/usr/local/bin/buoy-server"

	#cleaning auto-deleted directories is a little too goody-two-shoes for me but I'm leaving this in anyway
	sudo rm -f "${XDG_RUNTIME_DIR}/buoy/buoy-maker.socket"
	sudo rm -f "${XDG_RUNTIME_DIR}/buoy/buoy-substitute.socket"

.PHONY: clean-data
clean-data: 
	#remove stored buoy table 
	rm -rf "${HOME}/.local/share/buoy"

.PHONY: clean-daemon
clean-daemon:
	#clean systemd of buoy
	systemctl --user stop buoy-server
	systemctl --user disable buoy-server
	rm "${HOME}/.config/systemd/user/buoy-server.service"
