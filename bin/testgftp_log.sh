#!/bin/bash

#  testgftp_log.sh - tgftp log attribute extractor

:<<COPYRIGHT

Copyright (C) 2010, 2014 Frank Scheiner, HLRS, Universitaet Stuttgart

The program is distributed under the terms of the GNU General Public License

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

This product includes software developed by members of the DEISA project
www.deisa.org. DEISA is an EU FP7 integrated infrastructure initiative under
contract number RI-222919. 

COPYRIGHT

#  List of supported attributes. To add support for future attributes, just add
#+ the attribute's tag to the list.
SUPPORTED_ATTS="
GSIFTP_TRANSFER_LOG_COMMENT
GSIFTP_TRANSFER_COMMAND
GSIFTP_TRANSFER_COMMAND_OUTPUT
GSIFTP_TRANSFER_START
GSIFTP_TRANSFER_END
GSIFTP_TRANSFER_ERROR
GSIFTP_TRANSFER_RATE
GSIFTP_TRANSFER_SIZE
GSIFTP_TRANSFER_LIST
TGFTP_COMMAND"

VERSION="0.1.0"

SELF_NAME=$( basename $0 )

version_msg()
{
        echo "$SELF_NAME - v$VERSION"

        return
}

usage_msg()
{
#USAGE##########################################################################
        cat <<USAGE

usage: $(basename $0) [--help] ||
       $(basename $0) \\
        --get-attribute|-a <TGFTP_LOGFILE_ATTRIBUTE> \\
        --file|-f <TGFTP_LOGFILE>

--help gives more information

USAGE
#END_USAGE######################################################################
        return
}

help_msg()
{
#HELP###########################################################################
        cat <<HELP

$(version_msg)

SYNOPSIS:

tgftp_log --get-attribute|-a tgftpLogfileAttribute \\
          --file|-f tgftpLogfile


DESCRIPTION:

Script to extract single attribute values from tgftp logfiles.

The options are as follows:

--get-attribute|-a tgftpLogfileAttribute
                        Determine the tgftp logfile attribute to extract.
			Possible attributes are:

$(for line in $SUPPORTED_ATTS; do
	echo -e "\t\t\t$line"
 done)

--file|-f tgftpLogfile
                        Determine the tgftp logfile to extract data from.

--------------------------------------------------------------------------------

[--help]                Prints out this help message.

[--version|-V]          Prints out version information

HELP
#END_HELP#######################################################################
        return
}

#  correct number of params?
if [[ $# -lt 1 || $# -gt 1 && $# -lt 4 ]]; then
   # no, so output a usage message
   usage_msg
   exit 1
fi

while [[ "$1" != "" ]]; do

#  only valid params used?
	#
	#  NOTICE:
	#  This was added to prevent high speed loops
	#+ if parameters are mispositioned.
	if [[   "$1" != "--help" && \
		"$1" != "--version" && "$1" != "-V" && \
		"$1" != "--file" && "$1" != "-f" && \
		"$1" != "--get-attribute" && "$1" != "-a" \
	]]; then
		usage_msg
		exit 1

	#  "--help"
	elif [[ "$1" == "--help" ]]; then
		help_msg
		exit 0

	#  "--version|-V"
	elif [[ "$1" == "--version" || "$1" == "-V" ]]; then
		version_msg
		exit 0

	#  "--file|-f"
	elif [[ "$1" == "--file" || "$1" == "-f" ]]; then
		if [[ "$LOGFILE_SET" != "0" ]]; then
			shift 1
			LOGFILE="$1"
			LOGFILE_SET="0"
			shift 1
		else
			echo "$SELF_NAME: the parameter \"--file|-f\" can not be used multiple times." 1>&2
			exit 1
		fi

	#  "--get-attribute|-a"
	elif [[ "$1" == "--get-attribute" || "$1" == "-a" ]]; then
		if [[ "$ATTRIBUTE_SET" != "0" ]]; then
			shift 1
			ATTRIBUTE="$1"
			ATTRIBUTE_SET="0"
			shift 1
		else
			echo "$SELF_NAME: the parameter \"--get-attribute|-a\" can not be used multiple times." 1>&2
        	        exit 1
		fi	

	fi

done

if [[ $(echo $SUPPORTED_ATTS | grep -o $ATTRIBUTE) == "" ]]; then
	echo "$SELF_NAME: the attribute \"$ATTRIBUTE\" is not supported!" 1>&2
	exit 1
fi

if [[ ! -e "$LOGFILE" ]]; then
	echo "$SELF_NAME: the logfile \"$LOGFILE\" does not exist!" 1>&2
	exit 1
fi

ATTRIBUTE_VALUE=$( sed -n -e "/<$ATTRIBUTE>/,/<\/$ATTRIBUTE>/p" <"$LOGFILE" | sed -e "/^<.*$ATTRIBUTE>$/d" )

if [[ "$ATTRIBUTE_VALUE" == "" ]]; then

	echo "$SELF_NAME: attribute \"$ATTRIBUTE\" not found in \"$LOGFILE\" or empty." 1>&2
else
	echo "$ATTRIBUTE_VALUE"
fi

