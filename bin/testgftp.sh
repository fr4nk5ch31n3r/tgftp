#!/bin/bash

#  testgftp.sh - GridFTP test script

:<<COPYRIGHT

Copyright (C) 2010, 2011, 2014 Frank Scheiner, HLRS, Universitaet Stuttgart
Copyright (C) 2012 Frank Scheiner

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

VERSION="0.6.2"

#  The version numbering of tgftp tries to follow the "Semantic Versioning 
#+ 2.0.0-rc.1" specification avilable on <http://semver.org/>.

SUPPORTED_BATCHFILE_VERSIONS="$VERSION"

EXIT_VAL="0"

_sigintReceived=0

################################################################################
#  EXIT CODES
################################################################################

#  following "/usr/include/sysexits.h"
#  EX_OK
readonly _tgftp_exit_ok=0

#  EX_USAGE
#  e.g. wrong usage of program (wrong number of arguments, wrong flags, etc)
readonly _tgftp_exit_usage=64

#  EX_SOFTWARE
#  internal software error not related to OS
readonly _tgftp_exit_software=70

#  Own exit codes

#  guc timed out and was killed
readonly _tgftp_exit_timeout=79

################################################################################

#  use special path on AIX (this path contains the GNU versions of the binaries
#+ used by tgftp)
if [[ $(uname) == "AIX" ]]; then
	PATH=/opt/freeware/bin:$PATH
elif [[ $(uname) == "Linux" ]]; then
	#  use default path	
	:
else
	#  on different OS inform user about tgftp's needs
	cat <<- TGFTP_NEEDS
	NOTICE:
	This tool needs the GNU versions of "date", "sleep", "sed" and "(e)grep"
	and additionally the tool "globus-url-copy" from the Globus Toolkit data
	management client tools. If you can provide this, please write a patch
	for tgftp that extends the OS detection clause at the beginning to also
	support your OS. "globus-url-copy" is expected to be in the default
	path, the path for the GNU tools can be modified (please see the AIX
	example for more details!).
	If you want to have this patch included in future versions of "tgftp",
	please send the patch and a small comment about your target OS to
	"frank.scheiner@web.de".
	TGFTP_NEEDS
	
	#  stop execution
	exit 1
fi

DATE_BIN="$( which date )"
SLEEP_BIN="$( which sleep )"
SED_BIN="$( which sed )"
GREP_BIN="$( which grep )"
EGREP_BIN="$( which egrep )"

#  standard behaviour
GSIFTP_VERBOSE_PARAM=""

GSIFTP_DEBUG_PARAM=""

GSIFTP_PARALLEL_STREAMS_PARAM=""
GSIFTP_PARALLEL_STREAMS=""

GSIFTP_TCP_BLOCKSIZE_PARAM=""
GSIFTP_TCP_BLOCKSIZE=""

GSIFTP_BLOCKSIZE_PARAM=""
GSIFTP_BLOCKSIZE=""

GSIFTP_TRANSFER_LENGTH_PARAM=""
GSIFTP_TRANSFER_LENGTH=""

GSIFTP_SOURCE_URL=""

GSIFTP_TARGET_URL=""

GSIFTP_TIMEOUT="0"

#  additional variables
GSIFTP_TRANSFER_LOG_FILENAME=""
GSIFTP_TRANSFER_LOG_COMMENT=""

MULTIPLIER="1"

#  changed for thread safety
FIFO=".GSIFTP_TRANSFER_COMMAND_output.fifo.$$"
#FIFO="./$( mktemp .GSIFTP_TRANSFER_COMMAND_output.fifo_XXXXXX)"
GSIFTP_TRANSFER_COMMAND=".GSIFTP_TRANSFER_COMMAND.$$"
#GSIFTP_TRANSFER_COMMAND="./$( mktemp .GSIFTP_TRANSFER_COMMAND_XXXXXX )"

#  autotuning variables
#  parameter config permutation (as array)
#  2011-01-13 using a reduced parameter set
:<<COMMENT
gsiftpParamConfigs=(
"-vb"
"-vb -tcp-bs 4M"
"-vb -tcp-bs 8M"
"-vb -tcp-bs 16M"
"-vb -p 1"
"-vb -p 2"
"-vb -p 4"
"-vb -p 8"
"-vb -p 16"
"-vb -p 1 -tcp-bs 4M"
"-vb -p 1 -tcp-bs 8M"
"-vb -p 1 -tcp-bs 16M"
"-vb -p 2 -tcp-bs 4M"
"-vb -p 2 -tcp-bs 8M"
"-vb -p 2 -tcp-bs 16M"
"-vb -p 4 -tcp-bs 4M"
"-vb -p 4 -tcp-bs 8M"
"-vb -p 4 -tcp-bs 16M"
"-vb -p 8 -tcp-bs 4M"
"-vb -p 8 -tcp-bs 8M"
"-vb -p 8 -tcp-bs 16M"
"-vb -p 16 -tcp-bs 4M"
"-vb -p 16 -tcp-bs 8M"
"-vb -p 16 -tcp-bs 16M"
)
COMMENT
gsiftpParamConfigs=(
"-vb"
"-vb -p 1"
"-vb -p 2"
"-vb -p 4"
"-vb -p 8"
"-vb -p 16"
"-vb -p 32"
"-vb -p 1 -tcp-bs 1M"
"-vb -p 1 -tcp-bs 2M"
"-vb -p 1 -tcp-bs 4M"
"-vb -p 1 -tcp-bs 8M"
"-vb -p 1 -tcp-bs 16M"
"-vb -p 2 -tcp-bs 1M"
"-vb -p 2 -tcp-bs 2M"
"-vb -p 2 -tcp-bs 4M"
"-vb -p 2 -tcp-bs 8M"
"-vb -p 2 -tcp-bs 16M"
"-vb -p 4 -tcp-bs 1M"
"-vb -p 4 -tcp-bs 2M"
"-vb -p 4 -tcp-bs 4M"
"-vb -p 4 -tcp-bs 8M"
"-vb -p 4 -tcp-bs 16M"
"-vb -p 8 -tcp-bs 1M"
"-vb -p 8 -tcp-bs 2M"
"-vb -p 8 -tcp-bs 4M"
"-vb -p 8 -tcp-bs 8M"
"-vb -p 8 -tcp-bs 16M"
"-vb -p 16 -tcp-bs 1M"
"-vb -p 16 -tcp-bs 2M"
"-vb -p 16 -tcp-bs 4M"
"-vb -p 16 -tcp-bs 8M"
"-vb -p 16 -tcp-bs 16M"
"-vb -p 32 -tcp-bs 1M"
"-vb -p 32 -tcp-bs 2M"
"-vb -p 32 -tcp-bs 4M"
"-vb -p 32 -tcp-bs 8M"
"-vb -p 32 -tcp-bs 16M"
)
:<< COMMENT
gsiftpParamConfigs=(
"-vb -len 4G"
"-vb -len 4G -p 1"
"-vb -len 4G -p 2"
"-vb -len 4G -p 4"
"-vb -len 4G -p 8"
"-vb -len 4G -p 16"
"-vb -len 4G -p 32"
"-vb -len 4G -p 1 -tcp-bs 1M"
"-vb -len 4G -p 1 -tcp-bs 2M"
"-vb -len 4G -p 1 -tcp-bs 4M"
"-vb -len 4G -p 1 -tcp-bs 8M"
"-vb -len 4G -p 1 -tcp-bs 16M"
"-vb -len 4G -p 2 -tcp-bs 1M"
"-vb -len 4G -p 2 -tcp-bs 2M"
"-vb -len 4G -p 2 -tcp-bs 4M"
"-vb -len 4G -p 2 -tcp-bs 8M"
"-vb -len 4G -p 2 -tcp-bs 16M"
"-vb -len 4G -p 4 -tcp-bs 1M"
"-vb -len 4G -p 4 -tcp-bs 2M"
"-vb -len 4G -p 4 -tcp-bs 4M"
"-vb -len 4G -p 4 -tcp-bs 8M"
"-vb -len 4G -p 4 -tcp-bs 16M"
"-vb -len 4G -p 8 -tcp-bs 1M"
"-vb -len 4G -p 8 -tcp-bs 2M"
"-vb -len 4G -p 8 -tcp-bs 4M"
"-vb -len 4G -p 8 -tcp-bs 8M"
"-vb -len 4G -p 8 -tcp-bs 16M"
"-vb -len 4G -p 16 -tcp-bs 1M"
"-vb -len 4G -p 16 -tcp-bs 2M"
"-vb -len 4G -p 16 -tcp-bs 4M"
"-vb -len 4G -p 16 -tcp-bs 8M"
"-vb -len 4G -p 16 -tcp-bs 16M"
"-vb -len 4G -p 32 -tcp-bs 1M"
"-vb -len 4G -p 32 -tcp-bs 2M"
"-vb -len 4G -p 32 -tcp-bs 4M"
"-vb -len 4G -p 32 -tcp-bs 8M"
"-vb -len 4G -p 32 -tcp-bs 16M"
)
COMMENT
:<<COMMENT
gsiftpParamConfigs=(
"-vb -len 4G -p 16 -tcp-bs 1M"
"-vb -len 4G -p 16 -tcp-bs 2M"
"-vb -len 4G -p 16 -tcp-bs 4M"
"-vb -len 4G -p 16 -tcp-bs 8M"
"-vb -len 4G -p 16 -tcp-bs 16M"
)
COMMENT

defaultAutoTuningTimeout=30
defaultAutoTuningExecs=10

IFS_BAK=""

set_IFS()
{
        local IFS_NEW="$1"
        IFS_BAK="$IFS"
        IFS="$IFS_NEW"

        return
}

reset_IFS()
{
        IFS="$IFS_BAK"

        return
}

getMax()
{
	#  determines the maximum value of two values provided
	#
	#  usage:
	#+ getMax value1 value2

	local value1="$1"
	local value2="$2"

	#if [[ $value1 -ge $value2 ]]; then
	#	echo "$value1"
	#else
	#	echo "$value2"
	#fi

	echo -e "$value1\n$value2" | sort -n | tail -1
}

identifyMax()
{
	#  Identifies the maximum value of two values provided
	#
	#  usage:
	#+ identifyMax value1 value2

	local value1="$1"
	local value2="$2"

	if [[ "$( getMax $value1 $value2 )" == "$value1" ]]; then
		echo "1"
	else
		echo "2"
	fi
}

isGreater()
{
	#  determines if the first value provided is greater than the second
	#+ value provided
	#
	#  usage:
	#+ isGreater value1 value2

	local value1="$1"
	local value2="$2"

	if [[ "$value1" == "$value2" ]]; then
		return 1
	elif [[ "$( getMax $value1 $value2 )" == "$value1" ]]; then
		return 0
	else
		return 1
	fi
}

getMedian()
{
	#  derived from a function provided at:
	#  <http://panoskrt.wordpress.com/2009/03/10/shell-script-for-standard-deviation-arithmetic-mean-and-median/>

	#  determines the median of the provided values
	#
	#  usage:
	#+ getMedian < valuesFile
	#+ echo -e "value1\nvalue2[\nvalue3[\n...]]" | getMedian

	local values=""

	local field=0
	
	while read value; do
		values[$field]=$value
		field=$(( $field + 1 ))
	done

	local totalNumberOfValues=${#values[*]}
	
	local arrayMiddle=""

	local median=""

	#  determine number of decimals to be used by "bc"
	local scale=2

	#  even number of values?
	if [[ $(( $totalNumberOfValues % 2 )) -eq 0 ]]; then
		arrayMiddle=$( echo "($totalNumberOfValues / 2)-1" | bc )
		arrayNextMiddle=$(( $arrayMiddle + 1 ))
		median=$( echo "scale=$scale; ((${values[$arrayMiddle]})+(${values[$arrayNextMiddle]})) / 2" | bc )
	#  odd number of elements
	else
		arrayMiddle=$( echo "($totalNumberOfValues / 2)" | bc )
		median=${values[$arrayMiddle]}
	fi
	
	echo $median
}

getArithmeticMean()
{
	#  determines the arithmetic mean of the provided values
	#
	#  usage:
	#+ getArithmeticMean < valuesFile
	#+ echo -e "value1\nvalue2[\nvalue3[\n...]]" | getArithmeticMean

	local values=""

	local field=0
	
	local value=""

	local totalValue=0

	#  determine number of decimals to be used by "bc"
	local scale=2

	while read value; do
		values[$field]=$value
	
		totalValue=$(( $totalValue + $value ))

		field=$(( $field + 1 ))
	done

	local totalNumberOfValues=${#values[*]}

	local arithmeticMean=$( echo "scale=$scale; $totalValue/$totalNumberOfValues" | bc )

	echo $arithmeticMean
}

usage_msg()
{
#USAGE##########################################################################
        cat <<USAGE

usage: tgftp [--help] ||

       tgftp --source|-s <GSIFTP_SOURCE_URL> \\
 		--target|-t <GSIFTP_TARGET_URL> \\
 		[optional params] \\
 		[-- <GLOBUS_URL_COPY_PARAMS>] ||

       tgftp -f|--batchfile <GSIFTP_BATCHFILE>

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

tgftp [--source|-s gsiftpSourceUrl] \\
      [--target|-t gsiftpTargetUrl] \\
      [--timeout gsiftpTimeout] \\
      [--log-filename "gsiftpTransferLogFilename"] \\
      [--log-comment "gsiftpTransferLogComment"] \\
      [--pre-command "gsiftpTransferPreCommand"] \\
      [--post-command "gsiftpTransferPostCommand"] \\
      [-- gsiftpParameters]

tgftp --source|-s gsiftpSourceUrl \\
      --target|-t gsiftpTargetUrl \\
      --connection-test|-c

tgftp --source|-s gsiftpSourceUrl \\
      --target|-t gsiftpTargetUrl \\
      --autotune|-a

tgftp --batchfile|-f gsiftpBatchfile


DESCRIPTION:

tgftp is a wrapper script for globus-url-copy (guc) to ease testing and
documentation of GridFTP performance for specific connections. The generated
guc command, it's output and the reached performance are logged to a file named
like the following:

"yyyymmdd_H:Mh_\$\$_testgftp.sh.log"

Additionally the output of the guc command and the performance (transfer rate)
is printed out to screen.


NOTES:

Because this tool includes the time needed for establishing the connection
(total time needed for the transfer), the transfer rates may vary from the rates
that the guc command prints out - especially for short transfers. Additionally
this tool can only calculate the transfer rate if a "-len|-partial-length
length" guc param is present.

The options are as follows:

General Options:

[--source|-s gsiftpSourceUrl]
                        Determine the source URL for the transfer to test. If
                        the gsiftpParameters contain a "-f"  and provide a file
                        with guc source and destination URLs, this option can be
                        omitted.

[--target|-t gsiftpTargetUrl]
                        Determine the target URL for the transfer to test. If
                        the gsiftpParameters contain a "-f"  and provide a file
                        with guc source and destination URLs, this option can be
                        omitted.

[--force-log-overwrite] By default tgftp refuses to overwrite existing tgftp
                        logfiles. This option forces overwriting of existing
                        tgtfp logfiles.

[--help]                Prints out this help message.

[--help-batchfile]      Prints out the help about batchfiles.

[--version|-V]          Prints out version information

SINGLE TEST Mode:

[--timeout gsiftpTimeout]
                        Determine the time in seconds, "$(basename $0)" waits
                        before it kills the "globus-url-copy" command. By
                        default no timeout is set. Also true if set to "0".

[--log-filename "gsiftpTransferLogFilename"]
                        Determine the filename (including extension) of the
                        logfile. The filename has to be enclosed by double
                        quotes. If not specified the default naming is used.

[--log-comment "gsiftpTransferLogComment"]
                        Add a comment to the log. The comment has to be enclosed
                        by double quotes. This can also be a command like
                        "cat PRE_COMMAND_OUTPUT.txt", which enables to include
                        output of the pre-command in the logfile (for example
                        network params of the target system or traceroute
                        output, etc.). If not specified no comment is added. 
                        Text only comments, meaning no command should be called,
                        have to be preceded by "#"!

[--pre-command "gsiftpTransferPreCommand"]
                        Determine the filename of the command that should be
                        executed before the test (command must be executable and
                        path must be included). Must be enclosed by double
                        quotes.A pre-command may consist of multiple commands
                        included in one script. If not specified no additional
                        command will be excuted before the test.

[--post-command "gsiftpTransferPostCommand"]
                        Determine the filename of the command that should be
                        executed after the test (command must be executable and
                        path must be included). Must be enclosed by double
                        quotes. A post-command may consist of multiple commands
                        included in one script. If not specified no additional
                        command will be excuted after the test.
	
[-- gsiftpParameters]	Determine the "globus-url-copy" parameters that should
                        be used for the test. Notice the space between "--" and
                        the actual parameters. To calculate the transfer rate at
                        least "-len|-partial-length <LENGTH>" should be
                        specified. If this is not needed, the 
                        "-len|-partial-length <LENGTH>" parameter can be omitted
                        completely.

CONNECTION TEST Mode:

--connection-test|-c    Just do a connection test. This test does only transfer
                        1 Byte and logs the full connection process. This
                        implies "-dbg" and "-vb" for the resulting guc command.
                        Additionally the timeout is set to 30 seconds. If this
                        parameter is used, all other parameters except
                        "--source" and "--target" are ignored.

AUTO-TUNING Mode:

--auto-tune|-a          Determine the best performing guc parameter
                        configuration for the current source and target URLs.

BATCH Mode:

--batchfile|-f gsiftpBatchfile
                        Determine the batchfile containing the parameter values
                        for the tests to be batch processed. If this parameter
                        is used, all other parameters are ignored.

--------------------------------------------------------------------------------

EXAMPLES:

$ tgftp -s file:///dev/zero -t gsiftp://localhost:2811/dev/null

This command results in the following "globus-url-copy" command:

globus-url-copy \\
file:///dev/zero \\
gsiftp://localhost:2811/dev/null

................................................................................

$ tgftp \\
-s file:///dev/zero \\
-t gsiftp://gridftp-host.domain:2811/dev/null \\
--log-comment 'cat PRE_COMMAND_OUTPUT.txt' \\
--pre-command 'sysctl -n net.ipv4.tcp_congestion_control > PRE_COMMAND_OUTPUT.txt'
-- \\
-len 1M

This command will determine the congestion protocol that is used locally before
starting the test and include the output of the pre-command in the comment of
the logfile.

................................................................................

$ tgftp -f tgftp_tests.csv

This command will initiate multiple tests (one after another) with the parameter
values included in "tgftp_tests.csv".

HELP
#END_HELP#######################################################################
        return
}

help_batchfile_msg()
{
#HELP_BATCHFILE#################################################################
	cat <<HELP_BATCHFILE
A batchfile is a table containing multiple lines with "tgftp" parameters. Each
non empty line not starting with a "#" is evaluated as the following:

source:             Enter a valid source address for GridFTP.

target:             Enter a valid target address for GridFTP.

gsiftp-params:      Determine the "globus-url-copy" parameters to be used
                    for the test.

connection-test:    Enter "yes" to activate and "no" to deactivate. This
                    overwrites all other parameters (except "source" and
                    "target" with the default values for a connection
                    test).

timeout:            Enter the time in seconds after "testgftp.sh" kills the
                    "globus-url-copy" command.

log-filename:       Enter the filename for the logfile.

log-comment:        Enter a comment to the logfile. This can also be a
                    command like "cat PRE_COMMAND_OUTPUT.txt", which enables
                    to include output of the pre-command in the logfile (for
                    example network params of the target system or
                    traceroute output, etc.). Text only comments have to be
                    preceded by "#"!

pre-command:        Enter the filename of the command to be executed before
                    the test (command must be executable and path must be
                    included).	

post-command:       Enter the filename of the command to be executed after
                    the test (command must be executable and path must be
                    included).

execs:              Determine how often the test should be executed.

--------------------------------------------------------------------------------

notice:

"gsiftp-params", "log-filename", "log-comment", "pre-command", "post-command"
and "execs" can be  empty, in which case the default values are used:

gsiftp-params: -tcp-bs 4M -len 4G

timeout: 0 (no timeout!)

log-filename: "" (file is named like: "<BATCHFILENAME>_#<NUMBER_OF_TEST>.log")

log-comment: "" (no comment is addded to the log)

pre-command: "" (no command is executed before the test)

post-command: "" (no command is executed after the test)

execs: 1 (test executed one times only)


A pre-/post-command may consist of multiple commands included in one script.

--------------------------------------------------------------------------------

example:

#%tgftp%v$VERSION
#  source;target;gsiftp-params;connection-test;timeout;log-filename;log-comment;pre-command;post-command;execs
#  GridFTP tests on GridFTP example sites
#  GridFTP from Domain1 to Domain2
gsiftp://gridftp.domain1/dev/zero;gsiftp://gridftp.domain2/dev/null;-vb -p 16 -tcp-bs 4M -len 4G;no;30;;"#Domain1 to Domain2";;;

#  GridFTP from Domain1 to Domain3
gsiftp://gridftp.domain1/dev/zero;gsiftp://gridftp.domain3/dev/null;-vb -p 16 -tcp-bs 4M -len 4G;no;30;;"#Domain1 to Domain3";;;

#  GridFTP from Domain1 to Domain4
gsiftp://gridftp.domain1/dev/zero;gsiftp://gridftp.domain4/dev/null;-vb -p 16 -tcp-bs 4M -len 4G;no;30;;"#Domain1 to Domain4";;;

#  GridFTP from Domain1 to Domain5
gsiftp://gridftp.domain1/dev/zero;gsiftp://gridftp.domain5/dev/null;-vb -p 16 -tcp-bs 4M -len 4G;no;30;;"#Domain1 to Domain5";;;

#  GridFTP from Domain1 to Domain6
gsiftp://gridftp.domain1/dev/zero;gsiftp://gridftp.domain6/dev/null;-vb -p 16 -tcp-bs 4M -len 4G;no;30;;"#Domain1 to Domain6";;;

#  GridFTP from Domain1 to Domain7
gsiftp://gridftp.domain1/dev/zero;gsiftp://gridftp.domain7/dev/null;-vb -p 16 -tcp-bs 4M -len 4G;no;30;;"#Domain1 to Domain7";;;

#  GridFTP from Domain1 to Domain8
gsiftp://gridftp.domain1/dev/zero;gsiftp://gridftp.domain8/dev/null;-vb -p 16 -tcp-bs 4M -len 4G;no;30;;"#Domain1 to Domain8";;;

#  GridFTP from Domain1 to Domain9
gsiftp://gridftp.domain1/dev/zero;gsiftp://gridftp.domain9/dev/null;-vb -p 16 -tcp-bs 4M -len 4G;no;30;;"#Domain1 to Domain9";;;

HELP_BATCHFILE
#END_HELP_BATCHFILE#############################################################
	return
}

version_msg()
{
	if [[ "$($DATE_BIN +%m%d)" == "0414" ]]; then
		cat <<ASCII_BANNER
   __                 ______    __               
  /  |               /      \  /  |              
 _## |_     ______  /######  |_## |_     ______  
/ ##   |   /      \ ## |_ ##// ##   |   /      \ 
######/   /######  |##   |   ######/   /######  |
  ## | __ ## |  ## |####/      ## | __ ## |  ## |
  ## |/  |## \__## |## |       ## |/  |## |__## |
  ##  ##/ ##    ## |## |       ##  ##/ ##    ##/ 
   ####/   ####### |##/         ####/  #######/  
          /  \__## |                   ## |      
          ##    ##/                    ## |      
           ######/                     ##/       B I R T H D A Y ! ! !

ASCII_BANNER
	fi

        echo "$(basename $0) - The GridFTP benchmark, test and transfer script v$VERSION"

        return
}

get_unit()
{
        local SIZE="$1"

        if echo "$SIZE" | $GREP_BIN -e 'G$' &>/dev/null; then
                UNIT="GB"
        elif echo "$SIZE" | $GREP_BIN -e 'M$' &>/dev/null; then
                UNIT="MB"
        elif echo "$SIZE" | $GREP_BIN -e 'K$' &>/dev/null; then
                UNIT="KB"
        elif ! echo "$SIZE" | $GREP_BIN -e '[GMK]$' &>/dev/null; then
                UNIT="B"
        fi

        echo "$UNIT"

        return
}

get_multiplier()
{
        local UNIT="$1"
        local MULTIPLIER="1"

        #  set multiplier to get MB/s
        if [[ "$UNIT" == "GB" ]]; then
                MULTIPLIER="1024"
        elif [[ "$UNIT" == "MB" ]]; then
                MULTIPLIER="1"
        elif [[ "$UNIT" == "KB" ]]; then
                MULTIPLIER="$(( 1 / 1024 ))"
        elif [[ "$UNIT" == "B" ]]; then
                MULTIPLIER="$(( 1 / $(( 1024 * 1024 )) ))"
        fi

        echo "$MULTIPLIER"

        return
}

create_fifo()
{
        local FIFO="$1"

        mkfifo $FIFO &>/dev/null

        return
}

rm_fifo()
{
        local FIFO="$1"
        
        rm -f $FIFO &>/dev/null

        return
}

getURLWithoutPath()
{
	#  determines the URL portion that consists of the protocol id, the
	#+ domain name and the port, or "file://":
	#
	#  (gsiftp://venus.milkyway.universe:2811)/path/to/file
	#  (file://)/path/to/local/file
	#
	#  usage:
	#+ getURLWithoutPath "URL"

	local URL="$1"
	
	#  TODO:
	#+ support URLs not containing any port descriptions:
	#
	#  done!
	
	:<<-COMMENT
	from: <http://wiki.linuxquestions.org/wiki/Regular_expression>
	"
	echo gsiftp://venus.milkyway.universe/path/to/file | sed "s;\(gsiftp://[^/]*\)/.*;\1;"
	"

	or

	"
	echo gsiftp://venus.milkyway.universe/path/to/file | cut -d '/' -f "1-3"
	"

	returns:
	"
	gsiftp://venus.milkyway.universe
	"
	COMMENT

	#local tmp=$(echo "$URL" | grep -o "gsiftp://.*:[[:digit:]]*")
	local tmp=""
	#  URL starting with "/", then this is a local path (equal to
	#+  "file://$URL".
	if [[ ${URL:0:1} == "/" ]]; then
		#echo "DEBUG: 1"
		tmp="file://"
	#  valid URL
	else
		#echo "DEBUG: 3"
		tmp=$( echo $URL | cut -d '/' -f "1-3" )
	fi
	#if [[ "$tmp" == "" ]]; then
	#	tmp=$( echo "$URL" | grep -o "file://" )
	#fi

	#  does $tmp start with 'gsiftp://'?
	if echo $tmp | grep '^gsiftp://' &>/dev/null; then
		#  if yes, check if port is provided
		if echo $tmp | grep -o ':[[:digit:]].*' &>/dev/null; then
			#  port provided by user, don't modify string
			:
		else
			#  no port provided, add default gsiftp port
			tmp="${tmp}:2811"
		fi
	#  does $tmp start with 'ftp://'?
	elif echo $tmp | grep '^ftp://' &>/dev/null; then
		#  if yes, check if port is provided
		if echo $tmp | grep -o ':[[:digit:]].*' &>/dev/null; then
			#  port provided by user, don't modify string
			:
		else
			#  no port provided, add default ftp port
			tmp="${tmp}:21"
		fi
	#  does $tmp start with 'http://'?
	elif echo $tmp | grep '^http://' &>/dev/null; then
		#  if yes, check if port is provided
		if echo $tmp | grep -o ':[[:digit:]].*' &>/dev/null; then
			#  port provided by user, don't modify string
			:
		else
			#  no port provided, add default ftp port
			tmp="${tmp}:80"
		fi
	#  does $tmp start with 'https://'?
	elif echo $tmp | grep '^https://' &>/dev/null; then
		#  if yes, check if port is provided
		if echo $tmp | grep -o ':[[:digit:]].*' &>/dev/null; then
			#  port provided by user, don't modify string
			:
		else
			#  no port provided, add default ftp port
			tmp="${tmp}:443"
		fi
	fi

	local URLWithoutPath=$tmp

	echo "$URLWithoutPath"
}

createAutoTuningBatchJob()
{
	#  Creates an autotuning batchjob for the provided source and target
	#+ combination. This batchjob contains different parameter configs to
	#+ determine the best performing parameter set.
	#
	#  usage:
	#+ createAutoTuningBatchJob source target

	local source="$1"
	local target="$2"

	local sourceWithoutPath=$( getURLWithoutPath $source )
	local targetWithoutPath=$( getURLWithoutPath $target )

	local timeout=$defaultAutoTuningTimeout
	local execs=$defaultAutoTuningExecs

	cat <<-AutoTuningBatchJobHeader
		#%tgftp%v$VERSION
		#%tgftp_autotuning_batchfile
		#  source;target;gsiftp-params;connection-test;timeout;log-filename;log-comment;pre-command;post-command;execs
	AutoTuningBatchJobHeader

	field=0
	while [[ $field -le ${#gsiftpParamConfigs[@]} ]]; do
		if [[ ${gsiftpParamConfigs[$field]} != "" ]]; then
			cat <<-AutoTuningBatchJobLine
				$sourceWithoutPath/dev/zero;$targetWithoutPath/dev/null;${gsiftpParamConfigs[$field]} -len 4G;no;$timeout;;;;;$execs
			AutoTuningBatchJobLine
		fi
		field=$(( $field + 1 ))
	done

	return 0
}

#  this function handles batchfiles
process_batchfile()
{
	#return 0

	#  this function enables file numbering with leading zeroes for up to 1000 files
	get_file_number()
	{
		local counter="$1"

		if [[ "$counter" -lt 10 ]]; then
		        file_number="00$counter"
		elif [[ "$counter" -lt 100 ]]; then
		        file_number="0$counter"
		else
		        file_number="$counter"
		fi

		echo "$file_number"

		return
	}

        local FILE="$1"

        #  check if this is a "testgftp.sh" batch file and determine version
        local FILE_VERSION=$($GREP_BIN "#%tgftp" <$FILE | $SED_BIN -e 's/^#%tgftp%v//')

        if ! echo "$SUPPORTED_BATCHFILE_VERSIONS" | $GREP_BIN "$FILE_VERSION" &>/dev/null; then
                echo "ERROR: $(basename $0) batch file version \"v$FILE_VERSION\" not supported!" 1>&2
                exit "$_tgftp_exit_usage"
        fi
	
	#autotuning#############################################################
	#  autotuning variables
	local autoTuning=1
	#local maxMedianPerformance=0
	local maxAveragePerformance=0
	#local maxMedianPerfConfig=""
	local maxAveragePerfConfig=""
	#autotuning#############################################################

	#  check if this is a autotuning batch file
	if [[ "$( $GREP_BIN -o "#%tgftp_autotuning_batchfile" <$FILE )" == "#%tgftp_autotuning_batchfile" ]]; then
		#  enable autotuning
		autoTuning=0
	fi

	#  variables
        local TGFTP_COMMAND="./$( mktemp .TGFTP_COMMAND_XXXXXX )"
	local TGFTP_COMMAND_EXIT_VALUE="0"
	local EXEC_COUNTER="0"
	local DATA_LINE_NUMBER=0
	local LINE_NUMBER=1

	local GSIFTP_VERBOSE_PARAM=""

	local GSIFTP_DEBUG_PARAM=""

	local GSIFTP_PARALLEL_STREAMS_PARAM=""
	local GSIFTP_PARALLEL_STREAMS=""

	local GSIFTP_TCP_BLOCKSIZE_PARAM=""
	local GSIFTP_TCP_BLOCKSIZE=""

	local GSIFTP_TRANSFER_LENGTH_PARAM=""
	local GSIFTP_TRANSFER_LENGTH=""

	local GSIFTP_SOURCE_URL=""

	local GSIFTP_TARGET_URL=""

	local GSIFTP_TIMEOUT=""

	local CONNECTION_TEST=""

	local GSIFTP_TRANSFER_LOG_FILENAME=""

	local GSIFTP_TRANSFER_LOG_COMMENT=""

	local GSIFTP_TRANSFER_PRE_COMMAND_PARAM=""
	local GSIFTP_TRANSFER_PRE_COMMAND=""

	local GSIFTP_TRANSFER_POST_COMMAND_PARAM=""
	local GSIFTP_TRANSFER_POST_COMMAND=""

	local GSIFTP_TRANSFER_EXECS=""

	# prepare IFS for CSV input
	IFS_BAK="$IFS"
	IFS=";"

	#  open file
	exec 3<$FILE

	#  read it line after line
	while read -r -u 3 -a CSV_LINE; do

		#  set the defaults
		GSIFTP_SOURCE_URL=""

		GSIFTP_TARGET_URL=""

		GSIFTP_PARAMS=""

		CONNECTION_TEST=""

		GSIFTP_TIMEOUT="0"

		GSIFTP_TRANSFER_LOG_FILENAME=""

		GSIFTP_TRANSFER_LOG_COMMENT=""
	
		GSIFTP_TRANSFER_PRE_COMMAND_PARAM=""
		GSIFTP_TRANSFER_PRE_COMMAND=""

		GSIFTP_TRANSFER_POST_COMMAND_PARAM=""
		GSIFTP_TRANSFER_POST_COMMAND=""
	
		GSIFTP_TRANSFER_EXECS="1"
	
		#autotuning#####################################################
		#  autotuning variables
		#medianPerfPerTestConfig=0
		local averagePerfPerTestConfig=0
		#autotuning#####################################################

		#  skip empty lines
		if [[ "${CSV_LINE[0]}" == "" ]]; then
			LINE_NUMBER=$(( $LINE_NUMBER + 1 ))
			continue
		#  omit commented lines
		elif [[ $( echo "${CSV_LINE[0]}" | $GREP_BIN '^#' ) != "" ]]; then
			LINE_NUMBER=$(( $LINE_NUMBER + 1 ))
		        continue
		#  omit garbage
		#  The test tests for only 9 fields, as the last field is not
		#+ limited by a ";" and therefore the ${#[...]} function returns
		#+ only 9 fields.
		elif [[ `echo "${#CSV_LINE[@]}"` -lt "9" ]]; then
			echo "Fields: ${#CSV_LINE[@]}"
			echo "WARNING: Line $LINE_NUMBER: Less than 10 fields! Skipping line!" 1>&2
			LINE_NUMBER=$(( $LINE_NUMBER + 1 ))
		        continue
		fi

		#  v0.3.0 batch files have the following fields:
		#
		#  CSV_LINE[0] => source
		#  CSV_LINE[1] => target
		#  CSV_LINE[2] => gsiftp-params
		#  CSV_LINE[3] => connection-test
		#  CSV_LINE[4] => timeout
		#  CSV_LINE[5] => log-filename
		#  CSV_LINE[6] => log-comment
		#  CSV_LINE[7] => pre-command
		#  CSV_LINE[8] => post-command
		#  CSV_LINE[9] => execs
		#
		
		#  debug
		# echo "CSV_LINE[0]=\"${CSV_LINE[0]}\""
		# echo "CSV_LINE[1]=\"${CSV_LINE[1]}\""
		# echo "CSV_LINE[2]=\"${CSV_LINE[2]}\""
		# echo "CSV_LINE[3]=\"${CSV_LINE[3]}\""
		# echo "CSV_LINE[4]=\"${CSV_LINE[4]}\""
		# echo "CSV_LINE[5]=\"${CSV_LINE[5]}\""
		# echo "CSV_LINE[6]=\"${CSV_LINE[6]}\""
		# echo "CSV_LINE[7]=\"${CSV_LINE[7]}\""
		# echo "CSV_LINE[8]=\"${CSV_LINE[8]}\""
		# echo "CSV_LINE[9]=\"${CSV_LINE[9]}\""
		
		#  get params for current test:
		#
		#  source
		if [[ "${CSV_LINE[0]}" != "" ]]; then
		        GSIFTP_SOURCE_URL="${CSV_LINE[0]}"
		else
		        #  if empty, print out warning and skip line
		        echo "WARNING: Line $LINE_NUMBER: \"source\" field is empty! Skipping line!" 1>&2
			continue
		fi
		
		#  target
		if [[ "${CSV_LINE[1]}" != "" ]]; then
		        GSIFTP_TARGET_URL="${CSV_LINE[1]}"
		else
		        #  if empty, print out warning and skip line
		        echo "WARNING: Line $LINE_NUMBER: \"target\" field is empty! Skipping line!" 1>&2
			continue
		fi
		
		#  gsiftp-params
		if [[ "${CSV_LINE[2]}" != "" ]]; then
		        GSIFTP_PARAMS="${CSV_LINE[2]}"
		fi

		#  connection-test
		if [[ "${CSV_LINE[3]}" == "yes" ]]; then
		        CONNECTION_TEST_PARAM="--connection-test"
		elif [[ "${CSV_LINE[3]}" == "no" ]]; then
		        #  use the default
		        :
		else
		        #  print out warning and skip line
		        echo "WARNING: Line $LINE_NUMBER: \"connection-test\" field is empty! Skipping line!" 1>&2
		        continue
		fi
		
		#  timeout
		if [[ "${CSV_LINE[4]}" != "" ]]; then
			GSIFTP_TIMEOUT_PARAM="--timeout"
		        GSIFTP_TIMEOUT="${CSV_LINE[4]}"
		fi
		
		#  log-filename
		if [[ "${CSV_LINE[5]}" == "" ]]; then
			GSIFTP_TRANSFER_LOG_FILENAME_PARAM="--log-filename"
		        GSIFTP_TRANSFER_LOG_FILENAME="$(basename ${FILE})_#$(get_file_number $DATA_LINE_NUMBER).log"
		else
			GSIFTP_TRANSFER_LOG_FILENAME_PARAM="--log-filename"
		        GSIFTP_TRANSFER_LOG_FILENAME="${CSV_LINE[5]}"
		fi

		#  log-comment
		if [[ "${CSV_LINE[6]}" != "" ]]; then
			GSIFTP_TRANSFER_LOG_COMMENT_PARAM="--log-comment"
		        GSIFTP_TRANSFER_LOG_COMMENT="${CSV_LINE[6]}"
		fi

		#  pre-command
		if [[ "${CSV_LINE[7]}" != "" ]]; then
			GSIFTP_TRANSFER_PRE_COMMAND_PARAM="--pre-command"
			GSIFTP_TRANSFER_PRE_COMMAND="${CSV_LINE[7]}"
		fi

		#  post-command
		if [[ "${CSV_LINE[8]}" != "" ]]; then
			GSIFTP_TRANSFER_POST_COMMAND_PARAM="--post-command"
			GSIFTP_TRANSFER_POST_COMMAND="${CSV_LINE[8]}"
		fi

		#  execs
		if [[ "${CSV_LINE[9]}" != "" ]]; then
			GSIFTP_TRANSFER_EXECS="${CSV_LINE[9]}"
		fi

		#  reset execution counter
		EXEC_COUNTER="0"

		while [[ $EXEC_COUNTER -lt $GSIFTP_TRANSFER_EXECS ]]; do
			#  suppress output if in auto tuning mode
			if [[ ! $autoTuning -eq 0 ]]; then			
				eval echo $0 	--source "$GSIFTP_SOURCE_URL" \
						--target "$GSIFTP_TARGET_URL" \
						"$CONNECTION_TEST_PARAM" \
						"$GSIFTP_TIMEOUT_PARAM" "$GSIFTP_TIMEOUT" \
						"$GSIFTP_TRANSFER_LOG_FILENAME_PARAM" "${GSIFTP_TRANSFER_LOG_FILENAME/%.log/_$(get_file_number $EXEC_COUNTER).log}" \
						"$GSIFTP_TRANSFER_LOG_COMMENT_PARAM" '"$GSIFTP_TRANSFER_LOG_COMMENT"' \
						"$GSIFTP_TRANSFER_PRE_COMMAND_PARAM" '"$GSIFTP_TRANSFER_PRE_COMMAND"' \
						"$GSIFTP_TRANSFER_POST_COMMAND_PARAM" '"$GSIFTP_TRANSFER_POST_COMMAND"' \
						"--" "$GSIFTP_PARAMS" | tee "$TGFTP_COMMAND"
			else
				eval echo $0 	--source "$GSIFTP_SOURCE_URL" \
						--target "$GSIFTP_TARGET_URL" \
						"$CONNECTION_TEST_PARAM" \
						"$GSIFTP_TIMEOUT_PARAM" "$GSIFTP_TIMEOUT" \
						"$GSIFTP_TRANSFER_LOG_FILENAME_PARAM" "${GSIFTP_TRANSFER_LOG_FILENAME/%.log/_$(get_file_number $EXEC_COUNTER).log}" \
						"$GSIFTP_TRANSFER_LOG_COMMENT_PARAM" '"$GSIFTP_TRANSFER_LOG_COMMENT"' \
						"$GSIFTP_TRANSFER_PRE_COMMAND_PARAM" '"$GSIFTP_TRANSFER_PRE_COMMAND"' \
						"$GSIFTP_TRANSFER_POST_COMMAND_PARAM" '"$GSIFTP_TRANSFER_POST_COMMAND"' \
						"--" "$GSIFTP_PARAMS" > "$TGFTP_COMMAND"
			fi

			bash "$TGFTP_COMMAND" &>/dev/null &

			TGFTP_COMMAND_PID="$!"

			#  indicate progress (but only if not in auto tuning
			#+ mode)
			if [[ ! $autoTuning -eq 0 ]]; then
				while ps -p$TGFTP_COMMAND_PID &>/dev/null; do
					echo -n "."
					$SLEEP_BIN 0.5
				done
			fi

			wait $TGFTP_COMMAND_PID

			TGFTP_COMMAND_EXIT_VALUE_TMP="$?"
	
			#  save the tgftp command exit value, but don't
			#+ overwrite possible errors
			if [[ "$TGFTP_COMMAND_EXIT_VALUE" == "0" ]]; then
				TGFTP_COMMAND_EXIT_VALUE="$TGFTP_COMMAND_EXIT_VALUE_TMP"
			fi

			if [[ "$TGFTP_COMMAND_EXIT_VALUE_TMP" == "0" ]]; then
				if [[ ! $autoTuning -eq 0 ]]; then
					echo " Test #${DATA_LINE_NUMBER}_${EXEC_COUNTER} was successful!"
				fi

				#autotuning#####################################
				if [[ $autoTuning -eq 0 ]]; then
					#  save the performance value
					tgftp_log \
                                         -a GSIFTP_TRANSFER_RATE \
                                         -f "${GSIFTP_TRANSFER_LOG_FILENAME/%.log/_$(get_file_number $EXEC_COUNTER).log}" | \
                                        cut -d ' ' -f 1 >> .perfValues
				fi
				#autotuning#####################################

				rm -f "$TGFTP_COMMAND"
			else
				if [[ ! $autoTuning -eq 0 ]]; then
					echo " Test #${DATA_LINE_NUMBER}_${EXEC_COUNTER} failed!"
				fi
				mv "$TGFTP_COMMAND" "${TGFTP_COMMAND}_#$DATA_LINE_NUMBER"
			fi

			EXEC_COUNTER=$(($EXEC_COUNTER + 1))
		done
		#autotuning#####################################################
		if [[ $autoTuning -eq 0 ]]; then
			#  determine the median of all values
			#medianPerfPerTestConfig=$( getMedian < .perfValues )
			#  try with arithmetic mean to see, if this is more
			#+ stable
			if [[ -e .perfValues ]]; then
				#medianPerfPerTestConfig=$( getArithmeticMean < .perfValues )
				averagePerfPerTestConfig=$( getArithmeticMean < .perfValues )
				rm -f .perfValues &>/dev/null
			fi

			#echo "DEBUG1: current average performance=\"$medianPerfPerTestConfig\""
			#echo "DEBUG1: current average performance=\"$averagePerfPerTestConfig\""

			#echo "DEBUG: current config=\"$GSIFTP_PARAMS\""

			#  only overwrite max median performance value and save
			#+ parameter configuration, if new median value is
			#+ bigger
			#if [[ $( identifyMax $maxMedianPerformance $medianPerfPerTestConfig ) -eq 2 ]]; then
			#  Try the following:
			#+ The maxMedianPerfPerformance and [...]Config is only
			#+ exchanged, if the new value is bigger than the old
			#+ value plus 20(MB/s).
			local scale=2
			#tmpMax=$( echo "scale=$scale; ($maxMedianPerformance * 1.1)" | bc )
			#tmpMax=$(( $maxMedianPerformance + 20 ))
			tmpMax=$( echo "scale=$scale; ($maxAveragePerformance + 10)" | bc )						
			#if ! isGreater $tmpMax $medianPerfPerTestConfig; then
			if ! isGreater $tmpMax $averagePerfPerTestConfig; then
				#maxMedianPerfConfig="$GSIFTP_PARAMS"
				maxAveragePerfConfig="$GSIFTP_PARAMS"
				#maxMedianPerformance=$medianPerfPerTestConfig
				maxAveragePerformance=$averagePerfPerTestConfig
			fi
			
			#echo "DEBUG1: current max median performance=\"$maxMedianPerformance\""
			#echo "DEBUG1: current max average performance=\"$maxAveragePerformance\""
			#echo "DEBUG1: current max median performance config=\"$maxMedianPerfConfig\""
			#echo "DEBUG1: current max average performance config=\"$maxAveragePerfConfig\""
		fi
		#autotuning#####################################################

		if [[ "$TGFTP_COMMAND_EXIT_VALUE" == "0" ]]; then
			if [[ ! $autoTuning -eq 0 ]]; then
				echo -e "Test #$DATA_LINE_NUMBER was successful!"
			fi
		else
			if [[ ! $autoTuning -eq 0 ]]; then
				echo -e "Test #$DATA_LINE_NUMBER failed (for at least one run)!"
			fi
		fi

		#  data lines (and therefore tests) start with 0!
		DATA_LINE_NUMBER=$(($DATA_LINE_NUMBER + 1))
		
		#  increment line number
		LINE_NUMBER=$(( $LINE_NUMBER + 1 ))

		#  Reset TGFTP_COMMAND_EXIT_VALUE
		TGFTP_COMMAND_EXIT_VALUE="0"

	done

	#  close file
	3<&-

	#echo "DEBUG2: final max median performance=\"$maxMedianPerformance\""
	#echo "DEBUG2: final max average performance=\"$maxAveragePerformance\""
	#echo "DEBUG2: final max median performance config=\"$maxMedianPerfConfig\""
	#echo "DEBUG2: final max average performance config=\"$maxAveragePerfConfig\""

	#reset_IFS
	IFS="$IFS_BAK"

	#autotuning#############################################################
	if [[ $autoTuning -eq 0 ]]; then
		#echo "$maxMedianPerfConfig"
		#  remove "-len" param from output
		echo "$maxAveragePerfConfig" | sed -e 's/ -len 4G//'
	fi
	#autotuning#############################################################

        return
}

################################################################################
#  from gtransfer v0.0.7d-dev07
################################################################################
getProtocolSpecifier()
{
	#  determine the protocol specifier for a URL
	#
	#  usage:
	#+ getProtocolSpecifier url

	local url="$1"

	local protocolSpecifier=""

	#  if the URL starts with an absolute path it's equal to "file://$URL"
	if  [[ ${url:0:1} == "/" ]]; then
		echo "file://"
		return 0
	#  return the protocol specifier
	else
		protocolSpecifier=$( echo $url | grep -o ".*://" )
		echo "$protocolSpecifier"
		return 0
	fi
}


isValidUrl()
{
	#  determines if a valid URL was used
	#
	#  usage:
	#+ isValidUrl url

	local url="$1"

	#  if the URL starts with an absolute path it's equal to "file://$URL"
	#+ and therefore valid.
	if  [[ ${url:0:1} == "/" ]]; then
		return 0
	#  protocol specifier missing?
	elif ! echo $url | grep ".*://" &>/dev/null; then
		#echo "ERROR: Protocol specifier missing in \"$URL\" and no local path specified!"
		return 1
	fi

}


listTransfer/createTransferList() {
	#  create transfer list from source and destination URLs
	#
	#  usage:
	#+ listTransfer/createTransferList gsiftpSourceUrl gsiftpDestinationUrl
	#
	#  prints the transfer list filename to stdout
	#
	#  returns:
	#+ 0 if everything is allright
	#+ 1 otherwise

	local _source="$1"
	local _destination="$2"

	#  Check if valid URLs are provided
	if ! isValidUrl $_source; then
		echo "ERROR: Protocol specifier missing in \"$_source\" and no local path specified!"
		return 1
	elif ! isValidUrl $_destination; then
		echo "ERROR: Protocol specifier missing in \"$_destination\" and no local path specified!"
		return 1
	#  check if target URL is a "http://" URL
	elif [[ "$( getProtocolSpecifier $_destination )" == "http://" || \
		"$( getProtocolSpecifier $_destination )" == "https://" \
	]]; then
		echo "ERROR: Target URL cannot be a \"http[s]://\" URL!"
		return 1
	fi
	
	#  perform recursive transfer
	if [[ $recursiveTransferSet -eq 0 ]]; then
		local _recursive="-r"
	else
		local _recursive=""
	fi

	#  to get the transfer list we use guc with "-do" option
	globus-url-copy -do "$$_transferList" $_recursive "$_source" "$_destination"

	if [[ "$?" == "0" && -e "$$_transferList" ]]; then
		#  strip comment lines
		sed -i -e '/^#.*$/d' "$$_transferList"
		echo "$$_transferList"
		return 0
	else
		return 1
	fi
}


listTransfer/getTransferSizeFromTransferList() {
	#  gets the complete size of all data transferred with the provided
	#+ transfer list
	#
	#  usage:
	#+ listTransfer/getTransferSizeFromTransferList transferList
	
	local _transferList="$1"

	#  format of transfer list (guc v8.2):
	#													offset
	#  source					     destination					|    size, modify timestamp and permissions
	#  |						  |						  |    |
	#  "ftp://vserver1.asc:2811/~/files/test4/file.00355" "ftp://vserver2.asc:2811/~/files/test4/file.00355" 0,-1 size=0;modify=1328981550;mode=0644;

	#  get all file sizes of the transfer list, one each line and strip
	#+ comment lines
	local _fileSizes=$( grep -v '^#' "$_transferList" | cut -d ' ' -f 4 | cut -d ';' -f 1 | cut -d '=' -f 2 )

	#  now sum up all file sizes
	for _size in $( echo $_fileSizes ); do
		_sum=$(( $_sum + $_size ))
		if [[ "$?" != "0" ]]; then
			break
		fi
	done

	if [[ "$?" == "0" ]]; then
		echo "$_sum"
		return 0
	else
		return 1
	fi
}


################################################################################

################################################################################
#  NEW FUNCTIONS
################################################################################
tgftp/getMultiplier()
{
        local _unit="$1"
        
        local _multiplier="1"

        #  set multiplier to get MB/s
        if [[ "$_unit" == "GB" ]]; then
                _multiplier="1024"
        elif [[ "$_unit" == "MB" ]]; then
                _multiplier="1"
        #  PLEASE NOTICE:
        #+ When the unit is detected as "KB" or "B", then the multiplier result
        #+ is actually a divisior and has to be used that way. This is because
        #+ bash can only do integer division and hence 1 divided by a number
        #+ greater than 1 is 0, which would make any further calculations with
        #+ this multiplier result wrong.
        elif [[ "$_unit" == "KB" ]]; then
                _multiplier="1024"
        elif [[ "$_unit" == "B" ]]; then
                _multiplier="$(( 1024 * 1024 ))"
        fi

        echo "$_multiplier"

        return
}


tgftp/calcTransferRate()
{
	local _transferStartDate="$1" # in seconds since epoch
	local _transferEndDate="$2"   # in seconds since epoch
	local _size="$3"              # can be x, xK, xM, xG
	
	#  prevent situations where the divisor could be "0".
	local _divisor=$(( $_transferEndDate - $_transferStartDate ))
	if [[ $_divisor -eq 0 ]]; then
		_divisor=1
	fi
	
	local _unit=$( get_unit $_size )
	
	local _multiplier=$( tgftp/getMultiplier "$_unit")

	#  Take into account, that the mulitplier is actually a divisor when
	#+ the size unit is detected as "KB" or "B".
	if [[ "$_unit" == "KB" || "$_unit" == "B" ]]; then
		_divisor=$(( $_divisor * $_multiplier ))
		_multiplier=1
	fi	
	
	local _transferRate=$(( $(( $( echo "$_size" | $SED_BIN -e 's/[KMG]$//' ) * $_multiplier )) / $_divisor ))
	
	echo "$_transferRate"
	
	return
}


################################################################################

kill_after_timeout()
{
        local KPID="$1"

        local TIMEOUT="$2"

        #  if $TIMEOUT is "0" just return and don't kill the process
        if [[ "$TIMEOUT" == "0" ]]; then
                return
        fi

        $SLEEP_BIN "$TIMEOUT"

	#  process still running?
        if kill -0 "$KPID" &>/dev/null ; then
                kill "$KPID" &>/dev/null
                _programReturnVal="$?"

		if [[ $_programReturnVal -eq 0 ]]; then
	                #  indicate that the pid was killed
	                touch "${GSIFTP_TRANSFER_COMMAND}_KILLED"
	                RETURN_VAL="0"
	        else
	        	RETURN_VAL=$_programReturnVal
		fi
        else
                RETURN_VAL="1"
        fi

        return $RETURN_VAL
}

#  remove indicator
if [[ -e "${GSIFTP_TRANSFER_COMMAND}_KILLED" ]]; then
        rm - f "${GSIFTP_TRANSFER_COMMAND}_KILLED" &>/dev/null
fi

#  save commandline
commandLine="$0 $@"

#  correct number of params?
#if [[ "$#" -lt "1" || "$#" == "3" ]]; then
#   # no, so output a usage message
#   usage_msg
#   exit 1
#fi

# read in all parameters
while [[ "$1" != "" ]]; do

	#  only valid params used?
	#
	#  NOTICE:
	#  This was added to prevent high speed loops
	#+ if parameters are mispositioned.
	if [[   "$1" != "--help" && \
		"$1" != "--help-batchfile" && \
                "$1" != "--force-log-overwrite" && \
		"$1" != "--source" && "$1" != "-s" && \
		"$1" != "--target" && "$1" != "-t" && \
		"$1" != "--connection-test" && "$1" != "-c" && \
		"$1" != "--version" && "$1" != "-V" && \
		"$1" != "--timeout" && "$1" != "-k" && \
		"$1" != "--batchfile" && "$1" != "-f" && \
		"$1" != "--help-batchfile" && \
		"$1" != "--log-filename" && \
		"$1" != "--log-comment" && \
		"$1" != "--pre-command" && \
		"$1" != "--post-command" && \
		"$1" != "--auto-tune" && "$1" != "-a" && \
		"$1" != "--" \
	]]; then
		#  no, so output a usage message
		usage_msg
		exit "$_tgftp_exit_usage"   
	fi

	#  "--"
	if [[ "$1" == "--" ]]; then
		#  remove "--" from "$@"
		shift 1
		#  params forwarded to "globus-url-copy"
		GSIFTP_PARAMS="$@"
		
		#  exit the loop (this assumes that everything left in "$@" is
		#+ a "globus-url-copy" param).		
		break

	#  "--help"
	elif [[ "$1" == "--help" ]]; then
		help_msg
		exit 0

	#  "--help-batchfile"
	elif [[ "$1" == "--help-batchfile" ]]; then
		help_batchfile_msg
		exit 0

	#  "--version|-V"
	elif [[ "$1" == "--version" || "$1" == "-V" ]]; then
		version_msg
		exit 0

	#  "--force-log-overwrite"
	elif [[ "$1" == "--force-log-overwrite" ]]; then
		if [[ "$FORCE_LOG_OVERWRITE_SET" != "0" ]]; then
                        shift 1
			FORCE_LOG_OVERWRITE_SET="0"
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--force-log-overwrite\" cannot be used multiple times!"
			exit "$_tgftp_exit_usage"
		fi

	#  "--source|-s <GSIFTP_SOURCE_URL>"
	elif [[ "$1" == "--source" || "$1" == "-s" ]]; then
		if [[ "$GSIFTP_SOURCE_URL_SET" != "0" ]]; then
			shift 1
			GSIFTP_SOURCE_URL="$1"
			GSIFTP_SOURCE_URL_SET="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--source|-s\" cannot be used multiple times!"
			exit "$_tgftp_exit_usage"
		fi

	#  "--target|-t <GSIFTP_TARGET_URL>"
	elif [[ "$1" == "--target" || "$1" == "-t" ]]; then
		if [[ "$GSIFTP_TARGET_URL_SET" != "0" ]]; then
			shift 1
			GSIFTP_TARGET_URL="$1"
			GSIFTP_TARGET_URL_SET="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--target|-t\" cannot be used multiple times!"
			exit "$_tgftp_exit_usage"
		fi

	#  "--connection-test|-c"
	elif [[ "$1" == "--connection-test" || "$1" == "-c" ]]; then
		if [[ "$CONNECTION_TEST_SET" != "0" ]]; then
			shift 1
			CONNECTION_TEST_SET="0"         
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--connection-test|-c\" cannot be used multiple times!"
			exit "$_tgftp_exit_usage"
		fi

	#  "--auto-tune|-a"
	elif [[ "$1" == "--auto-tune" || "$1" == "-a" ]]; then
		if [[ "$AUTO_TUNING_SET" != "0" ]]; then
			shift 1
			AUTO_TUNING_SET="0"         
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--auto-tune|-a\" cannot be used multiple times!"
			exit "$_tgftp_exit_usage"
		fi

	#  "--timeout|-k"
	elif [[ "$1" == "--timeout" || "$1" == "-k" ]]; then
		if [[ "$GSIFTP_TIMEOUT_SET" != "0" ]]; then
			shift 1
			GSIFTP_TIMEOUT="$1"
			GSIFTP_TIMEOUT_SET="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--timeout|-k\" cannot be used multiple times!"
			exit "$_tgftp_exit_usage"
		fi

	#  "--batchfile|-f <GSIFTP_BATCHFILE>"
	elif [[ "$1" == "--batchfile" || "$1" == "-f" ]]; then
		if [[ "$GSIFTP_BATCHFILE_SET" != "0" ]]; then
			shift 1
			GSIFTP_BATCHFILE="$1"
			GSIFTP_BATCHFILE_SET="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--batchfile|-f\" cannot be used multiple times!"
			exit "$_tgftp_exit_usage"
		fi

	#  "--log-filename "<GSIFTP_TRANSFER_LOG_FILENAME>""
	elif [[ "$1" == "--log-filename" ]]; then
		if [[ "$GSIFTP_TRANSFER_LOG_FILENAME_SET" != "0" ]]; then
			shift 1
			GSIFTP_TRANSFER_LOG_FILENAME="$1"
			GSIFTP_TRANSFER_LOG_FILENAME_SET="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--log-filename\" cannot be used multiple times!"
			exit "$_tgftp_exit_usage"
		fi

	#  "--log-comment "<GSIFTP_TRANSFER_LOG_COMMENT>""
	elif [[ "$1" == "--log-comment" ]]; then
		if [[ "$GSIFTP_TRANSFER_LOG_COMMENT_SET" != "0" ]]; then
			shift 1
			GSIFTP_TRANSFER_LOG_COMMENT="$1"
			GSIFTP_TRANSFER_LOG_COMMENT_SET="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--log-comment\" cannot be used multiple times!"
			exit "$_tgftp_exit_usage"
		fi

	#  "--pre-command "<GSIFTP_TRANSFER_PRE_COMMAND>""
	elif [[ "$1" == "--pre-command" ]]; then
		if [[ "$GSIFTP_TRANSFER_PRE_COMMAND_SET" != "0" ]]; then
			shift 1
			GSIFTP_TRANSFER_PRE_COMMAND="$1"
			GSIFTP_TRANSFER_PRE_COMMAND_SET="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--pre-command\" cannot be used multiple times!"
			exit "$_tgftp_exit_usage"
		fi

	#  "--post-command "<GSIFTP_TRANSFER_POST_COMMAND>""
	elif [[ "$1" == "--post-command" ]]; then
		if [[ "$GSIFTP_TRANSFER_POST_COMMAND_SET" != "0" ]]; then
			shift 1
			GSIFTP_TRANSFER_POST_COMMAND="$1"
			GSIFTP_TRANSFER_POST_COMMAND_SET="0"
			shift 1
		else
			#  duplicate usage of this parameter
			echo "ERROR: The parameter \"--post-command\" cannot be used multiple times!"
			exit "$_tgftp_exit_usage"
		fi

	fi
done

################################################################################
#  check that all mandatory parameters are present
################################################################################
if [[ "$GSIFTP_BATCHFILE_SET" == "0" ]]; then
        #  start batch processing
        if [[ -e "$GSIFTP_BATCHFILE" ]]; then
                process_batchfile "$GSIFTP_BATCHFILE"
                exit "$?"
        else
                echo "ERROR: batchfile \"$GSIFTP_BATCHFILE\" not existing!" 1>&2
                exit "$_tgftp_exit_usage"
        fi

elif [[ "$GSIFTP_SOURCE_URL" == "" || \
	"$GSIFTP_TARGET_URL" == "" \
]]; then
    #  if there's a "-f" in the guc params, then source and destination URLs are
    #+ not needed.
    GREP=$( echo "$GSIFTP_PARAMS" | grep -o '\-f [^\ ]*' )
    if [[ $GREP != "" ]]; then
	#  Also set variable for transfer list, so that there is no additional
	#+ transfer list created.
	_transferList=$( echo "$GREP" | cut -d ' ' -f 2 )
    else
        #  no, so output a usage message
        usage_msg
        exit "$_tgftp_exit_usage"
    fi

#  Auto tuning needed?
elif [[ "$AUTO_TUNING_SET" == "0" ]]; then
	#  create auto tuning batch job
	createAutoTuningBatchJob "$GSIFTP_SOURCE_URL" "$GSIFTP_TARGET_URL" > .autoTuneBatchJob.csv

	#echo "DEBUG0: $( cat .autoTuneBatchJob.csv )"

	#  run auto tuning batch job
	tgftp -f .autoTuneBatchJob.csv
	exit "$?"
fi

#  logfile already existing?
if [[ "$GSIFTP_TRANSFER_LOG_FILENAME" != "" && -e "$GSIFTP_TRANSFER_LOG_FILENAME" ]]; then
        if [[ "$FORCE_LOG_OVERWRITE_SET" == "0" ]]; then
            : # do nothing, just continue
        else
            echo "ERROR: the logfile named \"$GSIFTP_TRANSFER_LOG_FILENAME\" already exists! Refusing to overwrite!" 1>&2
            exit "$_tgftp_exit_usage"
        fi
fi

#  is this a connection test?
if [[ "$CONNECTION_TEST_SET" == "0" ]]; then
	#  if yes, overwrite possible other params	
	GSIFTP_DEBUG_PARAM="-dbg"

	GSIFTP_VERBOSE_PARAM="-vb"

	GSIFTP_TRANSFER_LENGTH_PARAM="-len"

	GSIFTP_TRANSFER_LENGTH="1"
	
	GSIFTP_TIMEOUT="30"

	#  preset default params
	GSIFTP_DEFAULT_PARAMS="$GSIFTP_DEBUG_PARAM $GSIFTP_VERBOSE_PARAM"

	#  ignore any additional non default "globus-url-copy" params
	GSIFTP_PARAMS=""
else
	################################################################################
	#  default params will be overwritten by forwarded params
	################################################################################

	#  -len|-partial-length
	GREP=$( echo $GSIFTP_PARAMS | $EGREP_BIN -o "\-len [[:alnum:]]*|\-partial-length [[:alnum:]]*" | $GREP_BIN -o " [[:alnum:]]*" )
	if [[ "$GREP" != "" ]]; then
		GSIFTP_TRANSFER_LENGTH="$GREP"
	else		
		#  use default values
		GSIFTP_DEFAULT_PARAMS="$GSIFTP_DEFAULT_PARAMS $GSIFTP_TRANSFER_LENGTH_PARAM $GSIFTP_TRANSFER_LENGTH"
	fi

	#  -tcp-bs|-tcp-buffer-size
	GREP=$( echo $GSIFTP_PARAMS | $EGREP_BIN -o "\-tcp-bs [[:alnum:]]*|\-tcp-buffer-size [[:alnum:]]*" | $GREP_BIN -o " [[:alnum:]]*" )
	if [[ "$GREP" != "" ]]; then
		GSIFTP_TCP_BLOCKSIZE="$GREP"
	else
		#  use default values
		GSIFTP_DEFAULT_PARAMS="$GSIFTP_DEFAULT_PARAMS $GSIFTP_TCP_BLOCKSIZE_PARAM $GSIFTP_TCP_BLOCKSIZE"
	fi

	#  -r|-recurse
	recursiveTransferSet=1
	GREP=$( echo $GSIFTP_PARAMS | $EGREP_BIN -o "\-r|\-recurse" )
	if [[ "$GREP" != "" ]]; then
		#  perform recursive transfer (=> when creating transfer list
		#+ for transfer size and performance calculation also use "-r")
		recursiveTransferSet=0
	fi
fi

################################################################################
#  traps
################################################################################
trap 'rm_fifo $FIFO; rm -f "${GSIFTP_TRANSFER_COMMAND}_KILLED" "$GSIFTP_TRANSFER_COMMAND" "$$_testgftp.sh.log"' EXIT
#  trap SIGINT but wait until "#  MARK X" before killing yourself with SIGINT.
trap '_sigintReceived=1; trap - SIGINT' SIGINT

################################################################################
#  execute pre-command if needed
################################################################################
if [[ "$GSIFTP_TRANSFER_PRE_COMMAND" != "" ]]; then
	eval $GSIFTP_TRANSFER_PRE_COMMAND &
	wait $!
fi

################################################################################
#  do performance test
################################################################################

#  create FIFO
if ! create_fifo $FIFO; then
	echo "ERROR: FIFO \"$FIFO\" couldn't be created." 1>&2
	exit "$_tgftp_exit_software"
fi

#  let tee listen to it
#  TODO:
#+ Check if this is thread safe!
tee $$_testgftp.sh.log < $FIFO &


#  [1] get current time in seconds since epoch
################################################################################
#GSIFTP_START_DATE=$($DATE_BIN +%s)


#  [2] perform transfer
################################################################################
#globus-url-copy $GSIFTP_DEBUG_PARAM \
#                $GSIFTP_VERBOSE_PARAM \
#                $GSIFTP_PARALLEL_STREAMS_PARAM $GSIFTP_PARALLEL_STREAMS \
#                $GSIFTP_TCP_BLOCKSIZE_PARAM $GSIFTP_TCP_BLOCKSIZE \
#		 $GSIFTP_BLOCKSIZE_PARAM $GSIFTP_BLOCKSIZE \
#                $GSIFTP_TRANSFER_LENGTH_PARAM $GSIFTP_TRANSFER_LENGTH \
#                $GSIFTP_SOURCE_URL \
#                $GSIFTP_TARGET_URL &> $FIFO &
#
echo 	"exec globus-url-copy" \
	"$GSIFTP_DEFAULT_PARAMS" \
	"$GSIFTP_PARAMS" \
	"$GSIFTP_SOURCE_URL" \
	"$GSIFTP_TARGET_URL" \
	"&>$FIFO" > "$GSIFTP_TRANSFER_COMMAND"

#  Just in case the file creation takes longer, we get the timestamp directly
#+ prior to the execution of the guc command.
GSIFTP_START_DATE=$($DATE_BIN +%s)

bash "$GSIFTP_TRANSFER_COMMAND" &

#globus-url-copy \
#$GSIFTP_DEFAULT_PARAMS \
#$GSIFTP_PARAMS \
#"$GSIFTP_SOURCE_URL" \
#"$GSIFTP_TARGET_URL" &>$FIFO &

GSIFTP_TRANSFER_COMMAND_PID="$!"

#  kill command after timeout
if [[ ! $GSIFTP_TIMEOUT -eq 0 ]]; then
	kill_after_timeout "$GSIFTP_TRANSFER_COMMAND_PID" "$GSIFTP_TIMEOUT" &
fi

#  wait for pid and discard "lengthy" output
wait "$GSIFTP_TRANSFER_COMMAND_PID" &>/dev/null

#  NOTICE:
#+ If tgftp is used interactively, when hitting "Ctrl+C" and tgftp is already
#+ executing the above "wait", the "wait" is interrupted, will exit with 128 +
#+ signal number and the trap is executed.
#
#  From <http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_12_02.html>
#+ "[...]
#+ 12.2.2. How Bash interprets traps
#+
#+ When Bash receives a signal for which a trap has been set while waiting for a
#+ command to complete, the trap will not be executed until the command
#+ completes. When Bash is waiting for an asynchronous command via the wait
#+ built-in, the reception of a signal for which a trap has been set will cause
#+ the wait built-in to return immediately with an exit status greater than 128,
#+ immediately after which the trap is executed.
#+ [...]"
#+
#+ [1] states that "Ctrl+C" sends SIGINT "to all the processes of the foreground
#+ process group", but during testing tgftp I recognized the following
#+ behaviour:
#+
#+ When tgftp was interrupted by "Ctrl+C" also the background process (guc) was
#+ interrupted. But if another process was used, that process continued to run
#+ after tgftp exited. It is unclear why guc - being in the background -
#+ receives a SIGINT. Although the current behaviour is desirable.
#+ _____________
#+ [1] <http://stackoverflow.com/a/8406413>

#  save exit value
#
#  NOTICE:
#+ When a user hits "Ctrl+C" during execution of tgftp at a point in time when
#+ guc has already started and is not yet finished, the exit value stored will
#+ be the exit value of the "wait" command above, which then will be 130 = 128 +
#+ 2. If guc would exit immediately on SIGINT and the "wait" wouldn't be
#+ interrupted, the effect would be the same, an exit value of 130 stored.
GSIFTP_EXIT_VALUE="$?"

#  [3] get current time in seconds since epoch
################################################################################
GSIFTP_END_DATE=$($DATE_BIN +%s)

#  remove FIFO
rm_fifo $FIFO
################################################################################

#  [4] save command and log to one file
################################################################################

#  filename set by user?
if [[ "$GSIFTP_TRANSFER_LOG_FILENAME" == "" ]]; then
        GSIFTP_TRANSFER_LOG_FILENAME="$($DATE_BIN -d "1970-01-01 UTC + $GSIFTP_START_DATE seconds" +%Y%m%d_%H:%Mh)_$$_testgftp.sh.log"
fi

#  file already existing?
if [[ -e "$GSIFTP_TRANSFER_LOG_FILENAME" ]]; then
        if [[ "$FORCE_LOG_OVERWRITE_SET" == "0" ]]; then
            #  truncate file
            > "$GSIFTP_TRANSFER_LOG_FILENAME"
        else
            echo "ERROR: the logfile named \"$GSIFTP_TRANSFER_LOG_FILENAME\" already exists! Refusing to overwrite!" 1>&2
            exit "$_tgftp_exit_usage"
        fi
fi
################################################################################


#  comment set by user?
if  echo "$GSIFTP_TRANSFER_LOG_COMMENT" | $GREP_BIN '^#'; then
	#  text-only comment, don't evaluate the string	
	echo -en \
"<GSIFTP_TRANSFER_LOG_COMMENT>\n"\
"$GSIFTP_TRANSFER_LOG_COMMENT"\
"\n</GSIFTP_TRANSFER_LOG_COMMENT>\n"\
	>> "$GSIFTP_TRANSFER_LOG_FILENAME"
else
	#  seems to be a command, do evaluate the string
	echo -en \
"<GSIFTP_TRANSFER_LOG_COMMENT>\n"\
"$(eval $GSIFTP_TRANSFER_LOG_COMMENT)"\
"\n</GSIFTP_TRANSFER_LOG_COMMENT>\n"\
	>> "$GSIFTP_TRANSFER_LOG_FILENAME"
fi
################################################################################


#  save "globus-url-copy" command
echo -en \
"<GSIFTP_TRANSFER_COMMAND>\n"\
$(cat "$GSIFTP_TRANSFER_COMMAND" | $SED_BIN -e 's/^exec //' -e 's/\ &>.*//')\
"\n</GSIFTP_TRANSFER_COMMAND>\n"\
>> "$GSIFTP_TRANSFER_LOG_FILENAME"

#  remove temp file
rm -f "$GSIFTP_TRANSFER_COMMAND"
################################################################################


#  guc (<= v8.2) does exit on SIGINT unconventionally, meaning it catches a
#+ SIGINT, but after doing its internal cleanup and writing out a possible
#+ dumpfile, it does not reset the SIGINT handler to the default SIGINT handler
#+ and kills itself with SIGINT, but simply exits normally (leading to "0" as
#+ exit value in the bash shell). "Correct" would be an exit value of "130"
#+ (which is 128 + <SIGNAL>, with <SIGNAL> being SIGINT, which is "2").
#
#  See <http://www.cons.org/cracauer/sigint.html> for an elaborate discussion.

#  To also support these specific versions of guc we will try to detect if guc
#+ was SIGINTed by grepping for the string "^Cancelling copy...$", which is
#+ written out by guc if it was interrupted.
_gucSIGINTed=0
if grep '^Cancelling copy...$' < $$_testgftp.sh.log &>/dev/null || \
   [[ $GSIFTP_EXIT_VALUE -eq 130 ]]; then
        _gucSIGINTed=1
fi

#  save output of "globus-url-copy" command
echo -en \
"<GSIFTP_TRANSFER_COMMAND_OUTPUT>\n"\
>> "$GSIFTP_TRANSFER_LOG_FILENAME"

cat $$_testgftp.sh.log >> "$GSIFTP_TRANSFER_LOG_FILENAME"

echo -en \
"\n</GSIFTP_TRANSFER_COMMAND_OUTPUT>\n"\
>> "$GSIFTP_TRANSFER_LOG_FILENAME"

rm $$_testgftp.sh.log
################################################################################


#  add start and end timestamps:
echo -en \
"<GSIFTP_TRANSFER_START>\n"\
"$($DATE_BIN -d "1970-01-01 UTC + $GSIFTP_START_DATE seconds" +%Y-%m-%d_%H:%M:%S)"\
"\n</GSIFTP_TRANSFER_START>\n"\
>> "$GSIFTP_TRANSFER_LOG_FILENAME"

echo -en \
"<GSIFTP_TRANSFER_END>\n"\
"$($DATE_BIN -d "1970-01-01 UTC + $GSIFTP_END_DATE seconds" +%Y-%m-%d_%H:%M:%S)"\
"\n</GSIFTP_TRANSFER_END>\n"\
>> "$GSIFTP_TRANSFER_LOG_FILENAME"
################################################################################

#  Did the globus-url-copy command time out and was killed?
if [[ -e "${GSIFTP_TRANSFER_COMMAND}_KILLED" ]]; then
        rm - f "${GSIFTP_TRANSFER_COMMAND}_KILLED" &>/dev/null
        echo -en \
"<GSIFTP_TRANSFER_ERROR>\n"\
"ERROR: \"globus-url-copy\" timed out."\
"\n</GSIFTP_TRANSFER_ERROR>\n"\
	>> "$GSIFTP_TRANSFER_LOG_FILENAME"
        echo -e "\nERROR: \"globus-url-copy\" timed out. Please see \""$GSIFTP_TRANSFER_LOG_FILENAME"\" for details." 1>&2
        exit "$_tgftp_exit_timeout"

#  Was guc interrupted?
elif [[ $_gucSIGINTed -eq 1 ]]; then
	echo -en \
"<GSIFTP_TRANSFER_ERROR>\n"\
"ERROR: \"globus-url-copy\" was interrupted.\n"\
"</GSIFTP_TRANSFER_ERROR>\n"\
	>> "$GSIFTP_TRANSFER_LOG_FILENAME"
        echo -e "\nERROR: \"globus-url-copy\" was interrupted." 1>&2

	if [[ $_sigintReceived -eq 0 ]]; then
		#echo "($$) DEBUG: SIGINT received." 1>&2
		
		#  NOTICE:
		#+ If using "/bin/kill" instead of the bash builtin "kill"
		#+ below, the SIGINT sent after "#  MARK X" is ignored by tgftp.
		#+ It continues execution then. With "kill", it works as
		#+ intended.
		
		#  MARK X
		kill -SIGINT $$		
	fi
	kill -SIGINT $$

#  Did the transfer work?
elif [[ "$GSIFTP_EXIT_VALUE" != "0" ]]; then
        echo -en \
"<GSIFTP_TRANSFER_ERROR>\n"\
"ERROR: \"globus-url-copy\" failed."\
"\n</GSIFTP_TRANSFER_ERROR>\n"\
	>> "$GSIFTP_TRANSFER_LOG_FILENAME"
        echo -e "\nERROR: \"globus-url-copy\" failed. Please see \""$GSIFTP_TRANSFER_LOG_FILENAME"\" for details." 1>&2
        exit 1        
        
fi
################################################################################


#  [5] calculate transfer rate in MB/s
################################################################################
if [[ "$CONNECTION_TEST_SET" != "0" && \
      "$GSIFTP_TRANSFER_LENGTH" != "" && \
      ! $_gucSIGINTed -eq 1 \
]]; then

	GSIFTP_TRANSFER_RATE=$( tgftp/calcTransferRate "$GSIFTP_START_DATE" "$GSIFTP_END_DATE" "$GSIFTP_TRANSFER_LENGTH" )

	#  output transfer rate (including time needed for connection) to screen
        echo -e "\n$GSIFTP_TRANSFER_RATE MB/s"
	#  ...and append it to the log
        echo -en \
"<GSIFTP_TRANSFER_RATE>\n"\
"$GSIFTP_TRANSFER_RATE MB/s\n"\
"</GSIFTP_TRANSFER_RATE>\n"\
	>> "$GSIFTP_TRANSFER_LOG_FILENAME"
	
elif [[ "$GSIFTP_TRANSFER_LENGTH" == "" && \
      ! $_gucSIGINTed -eq 1 \
]]; then

	#echo "($$) DEBUG: transfer length not given via commandline!" 1>&2

	#  guc understandably cannot get the transfer size when transferring
	#+ from /dev/zero to /dev/null
	if ! echo "$GSIFTP_SOURCE_URL" | grep '/dev/zero' &>/dev/null && \
	   ! echo "$GSIFTP_TARGET_URL" | grep '/dev/null' &>/dev/null; then
		
		#  NOTICE:
		#+ The time needed for transfer size/length auto-detection is quite
		#+ short (about a second during tests). If you want to check this,
		#+ please uncomment the following two TIMING echo commands.

		#echo "TIMING: Before transfer length auto-detection: $( date )" 1>&2

		#  calculate size from transfer list
		#  create transfer list (the name will contain the current PID)
		if [[ ! "$_transferList" ]]; then
			_tmpTransferList=$( listTransfer/createTransferList "$GSIFTP_SOURCE_URL" "$GSIFTP_TARGET_URL" )
			_transferSize=$( listTransfer/getTransferSizeFromTransferList "$_tmpTransferList" )
			rm -f "$_tmpTransferList"
		else
			_transferSize=$( listTransfer/getTransferSizeFromTransferList "$_transferList" )
		fi
		#echo "TIMING: After transfer length auto-detection: $( date )" 1>&2
	
		GSIFTP_TRANSFER_RATE=$( tgftp/calcTransferRate "$GSIFTP_START_DATE" "$GSIFTP_END_DATE" "$_transferSize" )

		#  output transfer rate (including time needed for connection) to screen
		echo -e "\n$GSIFTP_TRANSFER_RATE MB/s"
		#   and append it to the log
		echo -en \
"<GSIFTP_TRANSFER_RATE>\n"\
"$GSIFTP_TRANSFER_RATE MB/s\n"\
"</GSIFTP_TRANSFER_RATE>\n"\
		>> "$GSIFTP_TRANSFER_LOG_FILENAME"
	fi
	
elif [[ "$CONNECTION_TEST_SET" == "0" ]]; then
	#  connection test, no calculation done
	echo -e "\nINFO: Connection test => no performance calculation done!"
fi
################################################################################


################################################################################
#  execute post-command if needed
################################################################################

#  post command is only executed if guc returned 0 and was *not* interrupted.
if [[ "$GSIFTP_TRANSFER_POST_COMMAND" != "" && \
      "$GSIFTP_EXIT_VALUE" == "0" && \
      $_gucSIGINTed -eq 0 ]]; then
	eval $GSIFTP_TRANSFER_POST_COMMAND &
	wait $!
fi

echo -e "\nPlease see \""$GSIFTP_TRANSFER_LOG_FILENAME"\" for details."

exit "$GSIFTP_EXIT_VALUE"

