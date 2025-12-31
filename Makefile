.PHONY: all
all: exe daemon bashfunction

.PHONY: exe
exe: buoy-server.janet buoy-client.janet 
	sudo jpm deps
	jpm build
	mkdir -p "${HOME}/.buoy/bin"
	sudo cp "build/buoy-client" "/usr/local/bin/"
	sudo cp "build/buoy-server" "/usr/local/bin/"

.PHONY: daemon
daemon: buoy-server.service
	mkdir -p "${HOME}/.config/systemd/user"
	cp buoy-server.service "${HOME}/.config/systemd/user"
	systemctl --user enable buoy-server #set to launch on boot
	systemctl --user start buoy-server #launch right now!

.PHONY: bashfunction
bashfunction: buoy-interface.sh
	mkdir -p "${HOME}/.local/share/buoy/"	
	cp "buoy-interface.sh" "${HOME}/.local/share/buoy/"	
	#add line in bashrc sourcing this function
	bash bashrc-install.sh
	
# will not remove anything from bashrc
.PHONY: clean
clean:
	rm -rf build
	sudo rm -f "/usr/local/bin/buoy-client"
	sudo rm -f "/usr/local/bin/buoy-server"

	#cleaning /tmp is a little too goody-two-shoes for me but I'm leaving this in anyway
	sudo rm -f "${XDG_RUNTIME_DIR}/buoy/buoy-maker.socket"
	sudo rm -f "${XDG_RUNTIME_DIR}/buoy/buoy-substitute.socket"

	#remove stored buoy table 
	rm -rf "${HOME}/.local/share/buoy"

	#clean systemd of buoy
	systemctl --user stop buoy-server
	systemctl --user disable buoy-server
	rm "${HOME}/.config/systemd/user/buoy-server.service"

	
