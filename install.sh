#!/bin/bash

#  install.sh / uninstall.sh - Install or uninstall software

prefixDir="$HOME/opt"
# nonUserInstall activated? 0 => no, 1 => yes
userInstall=1

if [[ "$1" != "" ]]; then
	prefixDir="$1"
	userInstall=0
fi

if [[ "$(basename $0)" == "install.sh" ]]; then

	#  first create bin dir in home, if not already existing
	if [[ $userInstall -eq 1 ]]; then	
		if [[ ! -e "$HOME/bin" ]]; then
			mkdir -p "$HOME/bin" &>/dev/null
		fi
	fi

	mkdir -p "$prefixDir/tgftp/bin" &>/dev/null
	mkdir -p "$prefixDir/tgftp/share/doc" &>/dev/null
	mkdir -p "$prefixDir/tgftp/share/man/man1" &>/dev/null

	#  copy scripts and...
	cp ./bin/testgftp.sh "$prefixDir/tgftp/bin"
	cp ./bin/testgftp_log.sh "$prefixDir/tgftp/bin"
	#  ...make links
	if [[ $userInstall -eq 1 ]]; then
		linkPath="$HOME"
	else
		linkPath="$prefixDir/tgftp"
	fi
	ln -s "$prefixDir/tgftp/bin/testgftp.sh" "$linkPath/bin/tgftp"
	ln -s "$prefixDir/tgftp/bin/testgftp_log.sh" "$linkPath/bin/tgftp_log"

	#  copy README and manpages
	cp ./share/doc/README "$prefixDir/tgftp/share/doc"
	cp ./share/doc/tgftp.1.pdf ./share/doc/tgftp_log.1.pdf "$prefixDir/tgftp/share/doc"
	cp ./COPYING "$prefixDir/tgftp/share/doc"
	cp ./share/man/man1/tgftp.1 "$prefixDir/tgftp/share/man/man1"
	cp ./share/man/man1/tgftp_log.1 "$prefixDir/tgftp/share/man/man1"

elif [[ "$(basename $0)" == "uninstall.sh" ]]; then

	#  remove a system installed tgftp
	if [[ "$1" != "" ]]; then
		rm -r "$prefixDir/tgftp"
	#  remove a user installed tgftp
	else
		#  remove scripts and links from "$HOME/bin"
		rm "$HOME/bin/tgftp"
		rm "$HOME/bin/tgftp_log"

		#  remove tgftp dir
		rm -r "$prefixDir/tgftp"
	fi

fi

