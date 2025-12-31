#!/bin/bash

#if we do not automatically source the eval script in bashrc, we will add a line to do so here

cmd="source \${HOME}/.local/share/buoy/buoy-interface.sh"
if cat "${HOME}/.bashrc" | grep -qe "^${cmd}$"; then 
	echo "bashrc already contains source call to buoy function"
else
	echo "Appending source call to buoy function in bashrc"
	echo "${cmd}" >> "${HOME}/.bashrc"
fi
