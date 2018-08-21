#!/bin/sh
#script that will hopefully make installation and launching of OpenMW and TES3MP easier

# Thanks to:
# Grim Kriegor for his script
# whoever wrote Winetricks script
# OpenMW developers
# TES3MP developers

# TODO: delete this part before script release
#==============================================================================================================================================================

# URL to latest latest 64-bit OpenMW (openmw.org):
# echo https://downloads.openmw.org/linux/other/$(curl -s https://downloads.openmw.org/linux/other/ | grep 64Bit | tail -n 1 | cut -d \" -f 2)

# URL to latest latest 32-bit OpenMW (openmw.org):
# echo https://downloads.openmw.org/linux/other/$(curl -s https://downloads.openmw.org/linux/other/ | tail -n 3 | head -n 1 |  cut -d \" -f 2)

# URL to latest latest 64-bit TES3MP (github)
# curl -s https://api.github.com/repos/TES3MP/openmw-tes3mp/releases/latest | grep browser_download_url | grep Linux | cut -d '"' -f 4

# URL to latest 64-bit OpenMW nightly (redfortune.de/openmw):
#curl -s https://redfortune.de/openmw/nightly/ | grep 64Bit | tail -n 1 | cut -d \" -f 8

# URL to latest 32-bit OpenMW nightly (redfortune.de/openmw):
# curl -s https://redfortune.de/openmw/nightly/ | tail -n 4 | head -n 1 | cut -d \" -f 8

# TODO: find out how to do this for GitLab
# find latest OpenMW release on Github (just tag):
# curl -s https://api.github.com/repos/Openmw/openmw/releases/latest | grep -Po '"tag_name": "\K.*?(?=")'

# find latest TES3MP release on Github (just tag):
# curl -s https://api.github.com/repos/TES3MP/openmw-tes3mp/releases/latest | grep -Po '"tag_name": "\K.*?(?=")'

# OpenMW gitlab download page:
# https://gitlab.com/OpenMW/openmw/tags

# detect system architecture
# uname -m

# nice code from StackOverflow for reading sections from config file
# not used since now script uses "source" and section names are comments lol
#printSection()
#{
#  section="$1"
#  found=false
#  while read line
#  do
#    [[ $found == false && "$line" != "[$section]" ]] &&  continue
#    [[ $found == true && "${line:0:1}" = '[' ]] && break
#    found=true
#    echo "$line"
#  done
#}

# simple zenity checkbox example:
#zenity --list --checklist --title "OpenMW and TES3MP install sorcerer" --text "Yo yo yo, thank you for deciding to use free and open source software to play Morrowind." --column "" --column "Stuff" False 1st False 2nd False 3rd False 4th False 5th

#==============================================================================================================================================================

# TODO: make names at least a little bit consistent. Current system of "lul just make up a variable name" could use some improvements.
# TODO: check if all commands used in script are available



set -e

# read: somewhat working prototype
VERSION="0.0.4"

HEADERTEXT="\
OpenMW and TES3MP installer / launcher ($VERSION)
testman
Licensed under the GNU GPLv3 free license
"

HELPTEXT="\
Usage $0 [OPTIONS]

Options:
  -d, --DEBUG     Enable debug output

Please report bugs in the GitHub issue page or directly on the TES3MP Discord.
"

SCRIPT_DIR="$(dirname $(readlink -f $0))"
CONFIG_NAME=".openmw_tes3mp_script.cfg"

echo -e "$HEADERTEXT"

# Parse arguments
# Stolen from Grim's script, left that way for potential future arguments
SCRIPT_ARGS="$@"
while [[ $# -ne 0 ]]; do
    case $1 in
    # enable DEBUG output
    -d | --DEBUG )
      DEBUG=true
    ;;
    esac
    shift
done

# Sections written as comments instead of [section] because the "source" command tries to run them
# Making proper parser would be too much work
function write_config_file() {
    [[ $DEBUG ]] && echo -e "Updating config file"
    echo "\
#Meta
CONFIG_MADE_WITH_SCRIPT_VERSION=$VERSION

#Script
SHOW_ADVANCED=$SHOW_ADVANCED
LAUNCHER_LAST_CHOICE=$LAUNCHER_LAST_CHOICE

#OpenMW
OPENMW_INSTALLED=$OPENMW_INSTALLED
OPENMW_INSTALLED_VERSION=$OPENMW_INSTALLED_VERSION
OPENMW_NIGHTLY_INSTALLED=$OPENMW_NIGHTLY_INSTALLED
OPENMW_NIGHTLY_INSTALLED_BUILD_DATE=$OPENMW_NIGHTLY_INSTALLED_BUILD_DATE

#TES3MP
TES3MP_INSTALLED=$TES3MP_INSTALLED
TES3MP_INSTALLED_VERSION=$TES3MP_INSTALLED_VERSION
" > $CONFIG_NAME
}

# check if config file exists, otherwise load existing variables
function check_for_first_run() {
    if [[ ! -e $CONFIG_NAME ]]; then
        [[ $DEBUG ]] && echo "Script running for the first time."
        touch $CONFIG_NAME
        write_config_file
        FIRST_RUN=true
    else
        [[ $DEBUG ]] && echo "Reading data from existing config file."
        source "$SCRIPT_DIR/$CONFIG_NAME" 
    fi

}

# check if anything was installed, otherwise set wizard to run after frist installation happens
function check_for_existing_installations() {
    if [[ ! $OPENMW_INSTALLED ]] && [[ ! $TES3MP_INSTALLED ]]; then
        [[ $DEBUG ]] && echo "Nothing installed yet, will run import wizard"
        RUN_WIAZRD=true
    fi
}

function show_launcher_dialog() {
    OPENMW_SELECTED=False
    TES3MP_SELECTED=False
    SETTINGS_SELECTED=False
    case $LAUNCHER_LAST_CHOICE in
        openmw )
        OPENMW_SELECTED=True
       ;;
        tes3mp )
        TES3MP_SELECTED=True
       ;;
        settings )
        SETTINGS_SELECTED=True
       ;;
        manage_installed )
        OPENMW_SELECTED=True
       ;;
        "" )
        OPENMW_SELECTED=True
       ;;
    esac
    
    # this is some interesting bash wizardry because just concentrating strings together into one variable confuses the shit out of zenity
    [[ $OPENMW_INSTALLED ]] && LAUNCHER_LINE_OPENMW=( $OPENMW_SELECTED openmw "Launch OpenMW" "(single-player)" )
    [[ $TES3MP_INSTALLED ]] && LAUNCHER_LINE_TES3MP=( $TES3MP_SELECTED tes3mp "Launch TES3MP" "(multi-player)" )
    [[ $OPENMW_INSTALLED ]] || [[ $TES3MP_INSTALLED ]] && LAUNCHER_LINE_SETTINGS=( $SETTINGS_SELECTED settings "Configure game settings" "(run OpenMW launcher)" )
    LAUNCHER_LINE_MANAGE=( False manage_installed "Manage installed versions" "" )

    LAUNCHER_CHOSEN_OPTION=$(zenity --width=600 --height=200 \
    --list --radiolist --hide-header \
    --hide-column=2 \
    --title="OpenMW and TES3MP" \
    --text="Do the following:" \
    --column="" \
    --column="" \
    --column="" \
    --column="" \
    "${LAUNCHER_LINE_OPENMW[@]}" \
    "${LAUNCHER_LINE_TES3MP[@]}" \
    "${LAUNCHER_LINE_SETTINGS[@]}" \
    "${LAUNCHER_LINE_MANAGE[@]}" & )
    
    LAUNCHER_LAST_CHOICE=$LAUNCHER_CHOSEN_OPTION
    write_config_file
}

# TODO: should this dalogue also handle updating (once implemented) or would it be better to have separate dialog for that?
function show_install_dialog() {
    [[ $DEBUG ]] && echo "openmw_installed="$OPENMW_INSTALLED
    [[ $DEBUG ]] && echo "tes3mp_installed="$TES3MP_INSTALLED
    [[ ! $OPENMW_INSTALLED ]] && [[ ! $TES3MP_INSTALLED ]] && INSTALLER_LINE_OPENMW_AND_TES3MP=( True openmw_and_tes3mp "OpenMW and TES3MP" "(single-player and multi-player)" )
    [[ ! $OPENMW_INSTALLED ]] && INSTALLER_LINE_OPENMW=( False openmw "OpenMW" "(single-player)"  )
    [[ ! $TES3MP_INSTALLED ]] && INSTALLER_LINE_TES3MP=( False tes3mp "TES3MP" "(multi-player)" )
    # following two lines (show and hide advanced options) are designed to be mutually exclusive, menaing that only one of them is visible in the dialog
    [[ $SHOW_ADVANCED ]] || INSTALLER_LINE_SHOW_ADVANCED=( False show_advanced "Show advanced options" "" )
    [[ $SHOW_ADVANCED ]] && INSTALLER_LINE_HIDE_ADVANCED=( False hide_advanced "Hide advanced options" "" )
    [[ $SHOW_ADVANCED ]] && INSTALLER_LINE_OPENMW_NIGHTLY=( False openmw_nightly "Nightly build of OpenMW" "(latest single-player developer preview)" )
    #[[ $SHOW_ADVANCED ]] && INSTALLER_LINE_COMPILE_OPENMW=( False compile_openmw "Compile OpenMW" "(download latest OpenMW code and compile it)" )
    #[[ $SHOW_ADVANCED ]] && INSTALLER_LINE_COMPILE_TES3MP=( False compile_tes3mp "Compile TES3MP "(download latest TES3MP code and compile it)" )
    INSTALLER_CHOSEN_OPTION=$(zenity --width=600 --height=250 \
    --list --radiolist --hide-header \
    --hide-column=2 \
    --title="OpenMW and TES3MP"\
    --text="Install the following:"\
    --column="" \
    --column="" \
    --column="" \
    --column="" \
    "${INSTALLER_LINE_OPENMW_AND_TES3MP[@]}" \
    "${INSTALLER_LINE_OPENMW[@]}" \
    "${INSTALLER_LINE_TES3MP[@]}" \
    "${INSTALLER_LINE_SHOW_ADVANCED[@]}" \
    "${INSTALLER_LINE_HIDE_ADVANCED[@]}" \
    "${INSTALLER_LINE_OPENMW_NIGHTLY[@]}" & )
    # unset to prevent displaying options that are not viable any more
    unset INSTALLER_LINE_OPENMW_AND_TES3MP
    unset INSTALLER_LINE_OPENMW
    unset INSTALLER_LINE_TES3MP
    unset INSTALLER_LINE_SHOW_ADVANCED
    unset INSTALLER_LINE_HIDE_ADVANCED
    unset INSTALLER_LINE_OPENMW_NIGHTLY
}

function launcher_dialog_selection_handler() {
    case $LAUNCHER_CHOSEN_OPTION in
        openmw )
        [[ $DEBUG ]] && echo -e "Starting openmw"
        run_openmw
       ;;
        tes3mp )
        [[ $DEBUG ]] && echo -e "Starting TES3MP"
        run_tes3mp_browser
       ;;
        settings )
        [[ $DEBUG ]] && echo -e "Starting launcher"
        run_openmw_launcher
       ;;
        manage_installed )
        [[ $DEBUG ]] && echo -e "Showing installer"
        SHOW_INSTALLER=true
       ;;
        "" )
        # check if launcher was even displayed before deciding that there was nothing to handle
        [[ $DEBUG ]] && echo -e "launcher handler SHOW_LAUNCHER="$SHOW_LAUNCHER
        [[ $SHOW_LAUNCHER ]] && EXIT=true && unset SHOW_INSTALLER
        #[[ $SHOW_LAUNCHER ]] && [[ $DEBUG ]] && echo -e "Exiting launcher"
       ;;
    esac
    unset SHOW_LAUNCHER
}

function install_dialog_selection_handler() {
    [[ $DEBUG ]] && echo $INSTALLER_CHOSEN_OPTION
    case $INSTALLER_CHOSEN_OPTION in
        openmw_and_tes3mp )
        [[ $DEBUG ]] && echo -e "You chose to install both"
        install_openmw
        install_tes3mp
        SHOW_LAUNCHER=true
       ;;
        openmw )
        [[ $DEBUG ]] && echo -e "You chose to install single player"
        install_openmw
        SHOW_LAUNCHER=true
       ;;
        tes3mp )
        [[ $DEBUG ]] && echo -e "You chose to install multiplayer"
        install_tes3mp
        SHOW_LAUNCHER=true
       ;;
        show_advanced )
        [[ $DEBUG ]] && echo -e "Enabling advanced options"
        SHOW_ADVANCED=true
        write_config_file
        SHOW_INSTALLER=true
       ;;
        hide_advanced )
        [[ $DEBUG ]] && echo -e "Disabling advanced options"
        unset SHOW_ADVANCED
        write_config_file
        SHOW_INSTALLER=true
       ;;
       # openmw_nightly )
       # [[ $DEBUG ]] && echo -e "You chose to install multiplayer"
       # install_tes3mp
       #;;        
        "" )
        [[ $DEBUG ]] && echo -e "Nothing to handle"
        [[ $DEBUG ]] && [[ ! $FIRST_RUN ]] && echo -e "Not first run, making launcher show up again"
        [[ ! $FIRST_RUN ]] && SHOW_LAUNCHER=true
        #unset SHOW_INSTALLER
       ;;
    esac
}

function install_openmw() {
    # TODO: properly check if already installed
    [[ -d openmw ]] && [[ $DEBUG ]] && echo "directory openmw already exists"
    [[ -d openmw ]] && exit 1
    mkdir openmw
    cd openmw
    if [[  $(uname -m) == "x86_64"  ]]; then
       #provided that structure of the site stays the same
       OPENMW_DOWNLOAD_FILENAME=$(curl -s https://downloads.openmw.org/linux/other/ | grep 64Bit | tail -n 1 | cut -d \" -f 2)
    else
       #provided that structure of the site stays the same
       OPENMW_DOWNLOAD_FILENAME=$(curl -s https://downloads.openmw.org/linux/other/ | tail -n 3 | head -n 1 |  cut -d \" -f 2)
    fi
    # some of most insane spaghetti magic I have seen lately. So you wget the URL, you make wget write to stdout, you do some parsing, send everything to awk which doesn't stdout by default,
    # so you have to fflush() so that awk tells zenity what to display
    # TODO: allow user to actually cancel the download. This is a bit difficult at zenity won't cooperate at all. If cancel button is enabled, it seems to only work before download starts.
    # after that it won't do anything untill download finishes and window closes automatically. There are many suggestions on the internet about how this should be handled. Sadly, I couldn't
    # get any of them to actually work in this case. 
    wget -q --show-progress --progress=dot https://downloads.openmw.org/linux/other/$OPENMW_DOWNLOAD_FILENAME 2>&1 | grep --line-buffered "%" | sed -u -e "s,[\.|\%],,g" | \
    awk '{printf("\n%i\n# Downloading '$OPENMW_DOWNLOAD_FILENAME'", $2); fflush()}'| zenity --progress --title="Downloading OpenMW" \
    --text="Downloading $OPENMW_DOWNLOAD_FILENAME" --percentage=0 --auto-close --no-cancel
    tar -xzf $OPENMW_DOWNLOAD_FILENAME
    cd ..
    OPENMW_INSTALLED=true
    # adding "openmw-" in frot of version for comparing with GitLab tag for when updating gets implemented.
    # Provided filename structure stays the same. It did so far, so it's nothing to worry about.
    OPENMW_INSTALLED_VERSION="openmw-"$(echo $OPENMW_DOWNLOAD_FILENAME | cut -d \- -f 2)
    write_config_file
    [[ $RUN_WIAZRD ]] && run_openmw_wizard
    unset RUN_WIAZRD
}

function install_tes3mp() {
    # TODO: properly check if already installed
    [[ -d tes3mp ]] && [[ $DEBUG ]] && echo "directory tes3mp already exists"
    [[ -d tes3mp ]] && exit 1
    mkdir tes3mp
    cd tes3mp
    TES3MP_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/TES3MP/openmw-tes3mp/releases/latest | grep browser_download_url | grep Linux | cut -d '"' -f 4)
    TES3MP_DOWNLOAD_FILENAME=$(echo $TES3MP_DOWNLOAD_URL | rev | cut -d\/ -f1 | rev)
    wget -q --show-progress --progress=dot $TES3MP_DOWNLOAD_URL 2>&1 | grep --line-buffered "%" | sed -u -e "s,[\.|\%],,g" | \
    awk '{printf("\n%i\n# Downloading '$TES3MP_DOWNLOAD_FILENAME'", $2); fflush()}' |  zenity --progress --title="Downloading TES3MP" \
    --text="Downloading $TES3MP_DOWNLOAD_FILENAME" --percentage=0 --auto-close --no-cancel
    tar -xzf *
    cd ..
    TES3MP_INSTALLED=true
    # adding "tes3mp-" in frot of version for comparing with Github tag for when updating gets implemented.
    # Provided filename structure stays the same. It did so far, so it's nothing to worry about.
    # URL is easier to parse than the filename
    TES3MP_INSTALLED_VERSION="tes3mp-"$(echo $TES3MP_DOWNLOAD_URL | cut -d \- -f 3 | cut -d \/ -f 1)
    write_config_file
    [[ $RUN_WIAZRD ]] && run_openmw_wizard
    unset RUN_WIAZRD
}

function install_openmw_nightly() {
    mkdir openmw_nightly
}

# TODO: implement this function in the most user-friendly way possible. Use words and phrases that normalfriends understand.
# Have it handle the possible data sources (for example already extracted game data / installed instance of game, game data from Steam, game data still inside GOG installer, etc. )
#function locate_game_data() {
#}

# # can be one or two results, so filtering is required for command to run successfully
# TODO: would it be better if it got paths for both launchers into variables and then do ./$openmw_wizard || ./$tes3mp_openmw_wizard ?
function run_openmw_wizard() {
    ./$(find . -type f -name openmw-wizard | head -n 1 )
    # It's actually even better to show launcher after this
    unset FIRST_RUN
    #EXIT=true
}

# can be one or two results, so filtering is required for command to run successfully
# TODO: would it be better if it got paths for both launchers into variables and then do ./$openmw_launcher || ./$tes3mp_openmw_launcher ?
function run_openmw_launcher() {
    ./$(find . -type f -name openmw-launcher | head -n 1 )
    EXIT=true
}

# should be just one result. Could add " | head -n 1" to filter if something goes wrong
function run_openmw() {
    ./$(find openmw -type f -name *openmw)
    EXIT=true
}

# should be just one result. Could add " | head -n 1" to filter if something goes wrong
function run_tes3mp_browser() {
    ./$(find tes3mp -type f -name tes3mp-browser)
    EXIT=true
}

#function run_openmw_nightly() {
#}

#function check_for_updates() {
#}

#function update_openmw() {
#}

#function update_tes3mp() {
#}

#function update_openmw_nightly() {
#}


# Main part of the script 
check_for_first_run
check_for_existing_installations
if [[ $FIRST_RUN ]]; then
    show_install_dialog
    install_dialog_selection_handler
fi

# Main loop is now actually loop because recursion was getting way too funky to handle
# Unset variables after each successful cycle to prevent incorrect dialog appearances
[[ $OPENMW_INSTALLED ]] || [[ $TES3MP_INSTALLED ]] && SHOW_LAUNCHER=true || SHOW_INSTALLER=true
#SHOW_LAUNCHER=true
while [[ ! $EXIT ]]; do
    #echo "before dialog, EXIT=$EXIT SHOW_LAUNCHER=$SHOW_LAUNCHER SHOW_INSTALLER=$SHOW_INSTALLER"
    [[ $SHOW_LAUNCHER ]] && show_launcher_dialog
    launcher_dialog_selection_handler
    [[ $SHOW_INSTALLER ]] && show_install_dialog
    install_dialog_selection_handler
    echo "after dialog, EXIT=$EXIT SHOW_LAUNCHER=$SHOW_LAUNCHER SHOW_INSTALLER=$SHOW_INSTALLER"
done
exit 0

