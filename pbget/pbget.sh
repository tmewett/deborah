#!/bin/bash

# Copyright (C) 2009,2010,2011  Xyne
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# (version 2) as published by the Free Software Foundation.
#
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.



# METADATA
# Version: 4.5


##########################################################
#################### GLOBAL VARIABLES ####################
##########################################################

# URLs
ABS_HOST='rsync.archlinux.org'
AUR_BASE_URL='https://aur.archlinux.org/packages'
AUR_JSON='https://aur.archlinux.org/rpc.php?type=info&arg='
SVN_BASE_URL='https://repos.archlinux.org'
GIT_BASE='http://projects.archlinux.org/svntogit'
#http://projects.archlinux.org/svntogit/community.git/plain/powerpill/trunk/
#http://projects.archlinux.org/svntogit/packages.git/plain/pacman/trunk/

# paths
COMMON_FUNCTIONS_PATH="/usr/share/xyne/bash/common_functions"

# options
OUT_DIR=$(pwd)
ARCH=`uname -m`
USE_TESTING='false'
USE_AUR='false'
USE_ABS='false'
USE_GIT='true'
GET_HEAD='false'
UPGRADABLE='false'

# package array
PKGS=()

# colors for messages
RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BLUE="\e[1;34m"
MAGENTA="\e[1;35m"
CYAN="\e[1;36m"
RESET="\e[0;0m"


###################################################
#################### HELP TEXT ####################
###################################################

HELP_TEXT=$(cat <<HELP
USAGE
pbget [OPTIONS] [PACKAGES]

  --abs                 use the abs tree instead of svn (requires rsync)
  --arch=<architecture> override the target architecture when possible
  --aur                 download files from the AUR if available
  --aur-only            only download from the AUR
  --dir=<path>          use <path> as the base directory for saved files
  --head                retrieve the latest svn revision (core/extra)
  --help                display this message
  --upgradable          add all upgradable packages to the download queue
  --testing             use abs testing repo (with "--abs")

HELP
)

########################################################
#################### HANDLE OPTIONS ####################
########################################################

for ARG in $@
do
  case $ARG in
    --abs)
      USE_ABS='true'
      USE_GIT='false'
    ;;

    --arch=*)
      ARCH=${ARG:7}
    ;;

    --aur)
      USE_AUR='true'
    ;;

    --aur-only)
      USE_AUR='true'
      USE_GIT='false'
      USE_ABS='false'
    ;;

    --dir=*)
      OUT_DIR=${ARG:6}
      [ -d "$OUT_DIR" ] || mkdir -p "$OUT_DIR" || exit 1
      cd $OUT_DIR
    ;;

    --head)
      GET_HEAD='true'
    ;;

    --help)
      fmt -s <<HELP
$HELP_TEXT
HELP
      exit 0
    ;;

    --testing)
      USE_TESTING='true'
    ;;

    --upgradable)
      UPGRADABLE='true'
      if [ -e "$COMMON_FUNCTIONS_PATH" ]; then
        source "$COMMON_FUNCTIONS_PATH"
      else
        echo "bash-xyne-common_functions is required to detect upgradable packages"
        exit 1
      fi
    ;;

    *)
      PKGS[${#PKGS[@]}]=$ARG
    ;;
  esac
done




###########################################################
#################### MESSAGE FUNCTIONS ####################
###########################################################

function header
{
  # Yeah, this is unnecessary, but I thought it looked nice
  # I would have used the screen width, but $COLUMNS isn't
  # exported by default and the workarounds that I've found
  # are unacceptable
  echo
  HEADER=$1
  shift
  COLOR=$1
  shift
  _DW=80
  _N=${#HEADER}
  if [ -x $(which tput) ]; then
    _W=$(tput cols)
  else
    if [ ${#MSG} > $_N ]; then
      _W=${#MSG}
    else
      _W=$_N
    fi
    _W=$(($_W+4))
    if [ $_DW > $_W ]; then
      _W=$_DW
    fi
  fi
  _R=$(($_W-$_N-4))
  echo -en "${COLOR}--[${RESET}"
  echo -n "$HEADER"
  echo -en "${COLOR}]"
  for ((i=0;i<$_R;i+=1)); do echo -n "-"; done
  echo -e "$RESET"
  for ARG in "$@"; do
    echo "  $ARG"
  done
  echo -en "$COLOR"
  for ((i=0;i<$_W;i+=1)); do echo -n "-"; done
  echo -e "$RESET"
}

function err
{
  echo -e "${RED}==> ERROR${RESET} $1"
  exit 1
}

function warn
{
  echo -e "${RED}==> WARNING${RESET} $1"
}

function notify
{
  echo -e "${BLUE}-->${RESET} $1"
}


##############################################
#################### MAIN ####################
##############################################

# check if wget is required and enabled
WGET=$(which "wget" 2>/dev/null)
if [ ! -x "$WGET" ] && ([ "$USE_GIT" == "true" ] || [ "$USE_AUR" == "true" ]) ; then
  warn "you must install wget in order to search the SVN, CVS and AUR web interfaces"
  USE_GIT="false"
  USE_AUR="false"
fi

# do this here to catch all potential official repo pkgs
# AUR is done in the aur section to avoid unnecessary searches
# in the official repos
if [ "$UPGRADABLE" == 'true' ] && ([ "$USE_GIT" == "true" ] || [ "$USE_ABS" == "true" ]); then
  notify "checking for upgradable packages"
  REPO_PKGS=($(get_upgradable_repo_pkgs))
  for PKG in ${REPO_PKGS[@]}; do
    NAME=$(get_package_name $PKG)
    notify "  $NAME"
    PKGS[${#PKGS[@]}]=$NAME
  done
fi

###########################################################
#################### GIT WEB INTERFACE ####################
###########################################################

if [ "$USE_GIT" == "true" ]; then
  notify "searching GIT"
  REMAINING_PKGS=()
  for PKG in ${PKGS[@]}; do
    for REPO in "packages.git/plain" "community.git/plain"; do
      URL="$GIT_BASE/$REPO/$PKG/trunk/"
      if wget -m -e robots=off -R index.html -q -nH -np -nd -P "$PKG" "$URL"; then
        header "$PKG" "$GREEN" "found in GIT:" " $URL"
        continue 2
      fi
    done
    warn "$PKG not found in the official GIT repository"
    REMAINING_PKGS[${#REMAINING_PKGS[@]}]=$PKG
  done
  PKGS=(${REMAINING_PKGS[@]})
fi


#############################################
#################### AUR ####################
#############################################

if [ "$USE_AUR" == "true" ]; then
  if [ "$UPGRADABLE" == 'true' ]; then
    notify "searching for foreign packages in the AUR"
    notify "this may take a while if you have many foreign packages"
    AUR_PKGS=($(get_upgradable_aur_pkgs))
    for PKG in ${AUR_PKGS[@]}; do
      NAME=$(get_package_name $PKG)
      notify "  $NAME"
      PKGS[${#PKGS[@]}]=$NAME
    done
  fi
  REMAINING_PKGS=()
  notify "searching AUR"
  for PKG in ${PKGS[@]}; do
    # Ugly trick to test
    OUTPUT=$(wget -q -O - "$AUR_BASE_URL/$PKG/$PKG.tar.gz" | \
    bsdtar -x -f - -v 2>&1)
    if [[ $OUTPUT ]]; then
      header "$PKG" "$MAGENTA" "found in AUR:" "  $AUR_BASE_URL/$PKG"
    else
      warn "$PKG was not found in the AUR"
      REMAINING_PKGS[${#REMAINING_PKGS[@]}]=$PKG
    fi
  done
  PKGS=(${REMAINING_PKGS[@]})
fi



#############################################
#################### ABS ####################
#############################################

if [ "$USE_ABS" == "true" ]; then
  RSYNC=$(which "rsync" 2>/dev/null)
  if [ ! -x "$RSYNC" ]; then
    warn "you must install rsync in order to search the ABS tree"
    exit
  fi
  #warn "no notifications are given for ABS search results"
  ABS_PATHS="::abs/any/core/ ::abs/any/extra/ ::abs/any/community/"
  if [ "$USE_TESTING" == "true" ]; then
    ABS_PATHS="::abs/any/testing/ ::abs/any/community-testing/ $ABS_PATHS"
  fi

  INCLUDES=''
  for PKG in ${PKGS[@]}; do
    notify "adding $PKG to ABS queue"
    INCLUDES="$INCLUDES --include=/$PKG/***"
  done

  ABS_PATHS="${ABS_PATHS//abs\/any/abs/$ARCH} $ABS_PATHS"

  if [ "$ARCH" == "x86_64" ]; then
    ABS_PATHS="$ABS_PATHS ::abs/$ARCH/multilib/"
  fi

  notify "starting rsync..."
  rsync -r -t --progress $INCLUDES --exclude=/* ${ABS_HOST}${ABS_PATHS} $OUT_DIR
fi
