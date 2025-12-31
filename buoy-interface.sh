#!/bin/bash

#Intended behavior is to source this file in ~/.bashrc, as this function uses eval to execute in the current terminal session

function buoy {
	eval $( buoy-client $@ )
}
