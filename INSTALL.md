# tgftp - The GridFTP test script - Installation instructions #

## Contents ##

1. Dependencies
2. Installation  
   2.1 Modulefile
3. Uninstallation

***

## (1) Dependencies ##

To run the tools in this distribution (namely `tgftp` and `tgftp_log`), some dependencies have to be met first. These tools need the following binaries in `$PATH` for operation:

* `uname`
* `cat`
* `cut` (GNU coreutils)
* `sleep` (GNU coreutils)
* `grep`/`egrep` (GNU versions)
* `sed` (GNU version)
* `globus-url-copy`

> **NOTICE:** On Linux systems (`uname` returns `Linux`) `tgftp` uses the default `$PATH` to search for the required tools. On AIX systems (`uname` returns `AIX`) the script uses `/opt/freeware/bin/` to search for the required tools. Other operating systems are currently not supported, but the script can be easily patched, if the required tools are available. Please follow the message that is printed out if you run this script on an operating system different from Linux or AIX.

## (2) Installation ##

For installation just run `./install.sh` (user install). This will create a directory named `bin` and a directory structure below `opt/tgftp/` in your home (if not already existing). The scripts of the tgftp distro are copied to `$HOME/opt/tgftp/bin/` and links will be created in `$HOME/bin/`, so one can run them directly.

If you add a path to `./install.sh` (system install) e.g. `./install /path`, the tgftp distribution will be installed in `path/tgftp/` instead.  For a system install, the links to the scripts will be created in `path/tgftp/bin/`.

## (2.1) Modulefile ##

To ease usage of this tool for users that have a [modules environment](http://en.wikipedia.org/wiki/Modules_Environment) available, a modulefile has been created. All related files are stored below
`./modulefiles`. After installing the modulefile please adapt the local configuration file to your needs.

## (3) Uninstallation ##

For uninstallation just run the link `./uninstall.sh`. This will remove the tgftp tools and its links from `$HOME/opt/` and `$HOME/bin` respectively. If you add a path to `./uninstall.sh`, the tgftp tools will be
removed from there instead.

