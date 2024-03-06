#!/bin/bash -x

#  NEED TO DO
###########--->  Fix menu duplication when enter is pressed with no string input ***whiptail as solution***
###########--->  Add Logging ***log_func***
###########--->  Add Error Handling

#######################################################
# Sets Menu colors by changing environmental variables for Newt
#######################################################
export NEWT_COLORS='
root=lightgray,black
window=white,gray
border=lightgray,gray
shadow=white,black
button=black,green
actbutton=black,red
compactbutton=lightgray,black
title=yellow,gray
roottext=red,black
textbox=lightgray,gray
acttextbox=gray,white
entry=black,lightgray
disentry=gray,black
checkbox=black,lightgray
actcheckbox=black,green
emptyscale=,lightgray
fullscale=,brown
listbox=black,lightgray
actlistbox=lightgray,black
actsellistbox=black,green'

############################################
# Global variabless
############################################
readonly mainmenu=(business_menu casual_menu adventure option_menu exit)
readonly business_menu=(log_menu backup_tools utilities mainmenu exit)
readonly log_menu=(auth.log search business_menu mainmenu exit)
readonly backup_tools=(Basic-Copy Bit-for-Bit business_menu mainmenu exit)
readonly utilities=(ping tracepath nslookup top ssh cron_menu business_menu mainmenu exit)
readonly cron_menu=(myself utilities mainmenu)
readonly option_menu=(start_at_login no_start_at_login mainmenu exit)
casual_menu=()
whichmenu=""
funclist=""

###################################################################
# When called with an array as argument, will duplicate each entry.
# ie: (1 2 3) becomes (1 1 2 2 3 3)
# Arguments:
#   $whichmenu
###################################################################
whiptail_array(){
  temparray=()
  local temp
  local etemp
  local menulength
  temp=$1[@]
  etemp=("${!temp}")
  menulength=${#etemp[@]}
  for ((i = 0; i < "$menulength"; i++)); do
    temparray+=("${etemp[i]}" "${etemp[i]}")
  done
}

######################################################################
# menu_end
# 
# When called, checks if last command or process run is still running,
# if it is not, the value provided by $whichmenu is called, returning 
# user to previous menu.
# Globals:
#   $whichmenu
# Arguments:
#   None
######################################################################
menu_end(){
  if [ ! -e /proc/$! ]; then
    continue
  else
    # clear
    $whichmenu
  fi
}

#####################################################################
# log_func
# 
# Creates system log when called in other functions.
# Logs username, menu they were in, and which menu option they chose.
#####################################################################
log_func() {
    local loguse
    loguse=$(whoami)
    logger -p user.notice -t "$0" "${loguse} accessed ${option} in ${whichmenu}"
}

#####################################################################
# mainmenu
# 
# The top menu in this script, all other menus are accessed from here.
# GLOBALS:
#   $whichmenu
#   $mainmenu
#####################################################################
mainmenu(){
  whichmenu="mainmenu"
  local option
  whiptail_array $whichmenu 
  option=$(whiptail --notags --title "SPAM" \
    --menu "Choose an option" 15 60 5 ${temparray[@]} 3>&1 1>&2 2>&3) 
  $option
  log_func
}

#####################################################################
# business_menu
#
# Contains categories pertaining to possible business functions
# leads to sub-menus with the various options
#####################################################################
business_menu(){
  whichmenu="business_menu"
  local option 
  whiptail_array $whichmenu 
  option=$(whiptail --notags --title "$whichmenu" \
    --menu "Choose an option" 15 60 5 ${temparray[@]} 3>&1 1>&2 2>&3)
  log_func
  "$option"
}

##############################################################################################################
# Displays /var/log/auth.log via less, or takes user input and applies it to journalctl to output desired logs.
# GLOBALS: 
#   $whichmenu
#   $log_menu
##############################################################################################################
log_menu(){
  whichmenu="log_menu"
  local option
  local target
  whiptail_array $whichmenu 
  option=$(whiptail --notags --title "$whichmenu" \
    --menu "Choose an option" 15 60 5 ${temparray[@]} 3>&1 1>&2 2>&3)
    log_func
    case "$option" in
      "$option")
        if [[ "$option" =~ ^(auth.log|search)$ ]]; then
          if [ -e /var/log/$option ]; then
            # clear
            less "/var/log/$option"
            menu_end
          else
            target=$(whiptail --inputbox "Enter Systemd unit name." \
              15 60 3>&1 1>&2 2>&3)
            journalctl -o json-pretty -u "$target"
            menu_end
          fi
        else
          case "$option" in
            "$option")
              "$option"
          esac
        fi
    esac
}

###################################################################
# backup_tools
# 
# Contains two options for "backing up" files, cp and dd.
# Asks user for source path/file and destination path/file, then sets them each 
# to a local variable.
# Runs respective command followed by variables
# GLOBALS:
#   $whichmenu
#   $backup_tools
###################################################################
backup_tools(){
  whichmenu="backup_tools"
  local option
  local sourcefile
  local destfile
  whiptail_array $whichmenu
  option=$(whiptail --notags --title "$whichmenu" --menu \
    "Choose an option" 15 60 7 ${temparray[@]} 3>&1 1>&2 2>&3)
  log_func
  if ! [[ $funclist =~ $option ]] ; then
    case "$option" in
      Basic-Copy)
        log_func
        sourcefile=$(whiptail --inputbox \
          "Enter absolute path of target file." 15 60 3>&1 1>&2 2>&3)
        if [ "$?" -eq 1 ]; then
          "$whichmenu"
        else        
        destfile=$(whiptail --inputbox "Enter absolute path of destination file." \
          15 60 3>&1 1>&2 2>&3)
          if [ "$?" -eq 1 ]; then
            "$whichmenu"
          elif (whiptail --title "CONFIRMATION" --yesno "Copy "$sourcefile" to "$destfile"?" 8 60); then
            cp "$sourcefile" "$destfile"
          fi
        fi
        ;;
      Bit-for-Bit)
        log_func
        sourcefile=$(whiptail --inputbox \
          "Enter absolute path of target file." 15 60 3>&1 1>&2 2>&3)
        destfile=$(whiptail --inputbox \
          "Enter absolute path of destination file." 15 60 3>&1 1>&2 2>&3)
        if (whiptail --title "CONFIRMATION" --yesno "Copy "$sourcefile" to "$destfile"?" 8 60); then
          dd "$sourcefile" "$destfile"
        else
          backup_tools
        fi
    esac
  else
    "$option"
  fi   
}

###################################################################
# utilities
#
# Largely contains networking utilites.  
# Also includes top and a guided menu for adding cronjobs
# GLOBALS:
#   $whichmenu
#   $utilites
###################################################################
utilities(){
  whichmenu="utilities"
  local target
  local remoteuser
  whiptail_array $whichmenu 
  if option=$(whiptail --notags --title "$whichmenu" --menu "Choose an option" 15 60 9 ${temparray[@]} 3>&1 1>&2 2>&3); then
    log_func
    if [[ "$option" =~ ^(ping|tracepath|nslookup)$ ]] && target=$(whiptail --inputbox "Enter target FQDN, or IP address if applicable." 15 60 3>&1 1>&2 2>&3); then
      echo "2222222222222222222222222222222222222"
      "$option" "$target"
      read -s -n 1
      echo '******Press any key to return to menu*******'
    elif [[ "$option" =~ ^(ssh)$ ]] && target=$(whiptail --inputbox "Enter target FQDN, or IP address." 15 60 3>&1 1>&2 2>&3) && remoteuser=$(whiptail --inputbox "Enter username for remote host." 15 60 3>&1 1>&2 2>&3); then
      ssh -l "$remoteuser" "$target"
      "$whichmenu"
    else
      "$option"
    fi
  else
    echo "Why you leave so soon?"
  fi
}

######################################################################
# cron_menu
# 
# Asks user to make selection from (hourly, daily, weekly, monthly),
# then asks to input name of task, then
# GLOBALS:
#   $whichmenu
#   $cron_menu
#   $funclist
######################################################################

cron_menu(){
  whichmenu="cron_menu"
  local crontask
  whiptail_array $whichmenu 
  if option=$(whiptail --notags --title "$whichmenu" --menu "Choose an option" 15 60 7 ${temparray[@]} 3>&1 1>&2 2>&3); then
    log_func
    if [[ "$option" == "myself" ]] && crontask=$(whiptail --inputbox "Enter Schedule and path to script to be executed.\nFormat: 0 0 0 0 0 <command>" 15 60 3>&1 1>&2 2>&3); then
        (crontab -l 2>/dev/null; echo "$crontask") | crontab -
        $whichmenu
    else
      $option
    fi
  else
    echo "Why you leave so soon?"
  fi
}

################################################################
# casual_menu
#
#
# Performs dpkg query for installed packages, 
# filtering by section:games, strips the word
# "games" from output, removes blank spaces, then prints to a text file.
# Adds two new entries to the file, exit and menu.
# Removes duplicates from the file.
# Creates array from text file called "casual_menu"
# Uses the array for a whiptail menu listing the installed games, mainmenu, and exit.
# GLOBALS:
#   $whichmenu
#   $casual_menu
#   $funclist
################################################################
casual_menu(){
  whichmenu="casual_menu"
  dpkg-query -W -f '${Package} ${Section}\n' | grep "games" | sed 's/ games//' \
    | tr -d "[:blank:]" > test.txt
  echo -e "mainmenu" >> test.txt
  echo -e "exit" >> test.txt
  sort -u -m test.txt -o test.txt
  readarray -t casual_menu < test.txt
  whiptail_array $whichmenu
  option=$(whiptail --notags --title "$whichmenu" \
    --menu "Choose an option" 15 60 7 ${temparray[@]} 3>&1 1>&2 2>&3)
  log_func 
    if ! [[ $funclist =~ $option ]] && [[ "$option" != "exit" ]]; then
      if [ $(dpkg-query -W -f='${Status}' $option 2>/dev/null | grep -c "ok installed") ]; then
        "$option"
        "$whichmenu"
      elif (whiptail --title "CONFIRMATION" --yesno ""$option" is not installed, do you wish to install "$option"?" 8 60); then
        sudo apt install "$option" && "$option"
        "$whichmenu"
      fi
    elif [[ $funclist =~ "$option" ]] || [[ "$option" == "exit" ]]; then
      "$option"
    elif (whiptail --msgbox "Apologies, due to my ineptitude, this is not a game...just a related entry." 12 30); then
      echo "sorry"
    fi
}

################################################################
# adventure
#
# Just reads a few paragrahs of "The Hobbit" to the screen.
# ctrl^c to exit or wait for it to finish and press any key.
# GLOBALS:
#   $whichmenu
################################################################
adventure(){
  whichmenu="adventure"
  log_func
  local story="  THE HOBBIT
  OR
  THERE AND BACK AGAIN
  BY
  J.R.R. TOLKIEN

  In a hole in the ground there lived a hobbit. Not a nasty,
  dirty, wet hole, filled with the ends of worms and an oozy
  smell, nor yet a dry, bare, sandy hole with nothing in it to
  sit down on or to eat: it was a hobbit-hole, and that means
  comfort.
  It had a perfectly round door like a porthole, painted
  green, with a shiny yellow brass knob in the exact middle.
  The door opened on to a tube-shaped hall like a tunnel: a
  very comfortable tunnel without smoke, with panelled
  walls, and floors tiled and carpeted, provided with
  polished chairs, and lots and lots of pegs for hats and
  coats—the hobbit was fond of visitors. The tunnel wound
  on and on, going fairly but not quite straight into the side
  of the hill—The Hill, as all the people for many miles
  round called it—and many little round doors opened out
  of it, first on one side and then on another. No going
  upstairs for the hobbit: bedrooms, bathrooms, cellars,
  pantries (lots of these), wardrobes (he had whole rooms
  devoted to clothes), kitchens, dining-rooms, all were on
  the same floor, and indeed on the same passage. The best
  rooms were all on the left-hand side (going in), for these
  were the only ones to have windows, deep-set round
  windows looking over his garden, and meadows beyond,
  sloping down the river."
  trap break INT
  for ((i=0; i<=${#story}; i++)); do
    printf '%s' "${story:$i:1}"
    sleep 0.1  #$(( (RANDOM % 2) + 1 ))    
  done
  trap - INT
  printf "\n\n Press any key to return to menu"
  read -s -n 1
  # clear
  mainmenu
}

################################################################
# option_menu
#
# Includes options to add or remove this script from the user's bashrc.
# GLOBALS:
#   $whichmenu
################################################################
option_menu(){
  whichmenu="option_menu"
  local scriptvar
  whiptail_array "$whichmenu" 
  option=$(whiptail --notags --title "$whichmenu" --menu "Choose an option" 15 60 5 ${temparray[@]} \
    3>&1 1>&2 2>&3)
  log_func
  if ! [[ $funclist =~ $option ]] && [[ "$option" != "exit" ]]; then
    case "$option" in 
      start_at_login)
        realpath $0 >> ~/.bashrc
        whiptail --msgbox "Added this script from .bashrc" 12 30
        $whichmenu;;
      no_start_at_login)
        scriptvar="$0"
        scriptvar="${scriptvar:2}"
        # sed -i "/$scriptvar/d" ~/.bashrc ### Wanted to do this but it doesn't work###
        sed -i '/bashfinal/d' ~/.bashrc
        echo "$scriptvar"
        whiptail --msgbox "Removed this script from .bashrc" 12 30
        $whichmenu
    esac
  else
    "$option"
  fi  
}

################################################################
# funccheck
# 
# Defines $funclist with a list of the functions in this script.
# This is required by a couple of other functions for if statments.
# Must be at end of script
# GLOBALS:
#   $funclist
###############################################################
funccheck(){
  funclist=$(declare -F | cut --complement -d' ' -f1,2)
}

funccheck
mainmenu

