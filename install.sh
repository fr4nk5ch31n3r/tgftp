#!/bin/bash

#  install.sh / uninstall.sh - Install or uninstall software

prefixDir="$HOME/opt"
# nonUserInstall activated? 0 => yes, 1 => no
nonUserInstall=1

if [[ "$1" != "" ]]; then
	prefixDir="$1"
	nonUserInstall=0
fi

if [[ "$(basename $0)" == "install.sh" ]]; then

	#  first create bin dir in home, if not already existing
	if [[ $nonUserInstall -eq 1 ]]; then	
		if [[ ! -e "$HOME/bin" ]]; then
			mkdir -p "$HOME/bin" &>/dev/null
		fi
	fi

	mkdir -p "$prefixDir/tgftp/bin" &>/dev/null
	mkdir -p "$prefixDir/tgftp/doc" &>/dev/null
	mkdir -p "$prefixDir/tgftp/man/man1" &>/dev/null

	#  copy scripts and...
	cp ./testgftp.sh "$prefixDir/tgftp/bin"
	cp ./testgftp_log.sh "$prefixDir/tgftp/bin"
	#  ...make links
	if [[ $nonUserInstall -eq 1 ]]; then
		linkPath="$HOME"
	else
		linkPath="$prefixDir/tgftp"
	fi
	ln -s "$prefixDir/tgftp/bin/testgftp.sh" "$linkPath/bin/tgftp"
	ln -s "$prefixDir/tgftp/bin/testgftp_log.sh" "$linkPath/bin/tgftp_log"

	#  copy README and manpages
	cp ./README "$prefixDir/tgftp/doc"
	cp ./tgftp.1.pdf ./tgftp_log.1.pdf "$prefixDir/tgftp/doc"
	cp ./COPYING "$prefixDir/tgftp/doc"
	cp ./tgftp.1 "$prefixDir/tgftp/man/man1"
	cp ./tgftp_log.1 "$prefixDir/tgftp/man/man1"

elif [[ "$(basename $0)" == "uninstall.sh" ]]; then

	if [[ "$1" != "" ]]; then
		rm -r "$prefixDir/tgftp"
	else
		#  remove scripts and links from "$HOME/bin"
		rm "$HOME/bin/tgftp"
		rm "$HOME/bin/tgftp_log"

		#  remove tgftp dir
		rm -r "$prefixDir/tgftp"
	fi

fi

