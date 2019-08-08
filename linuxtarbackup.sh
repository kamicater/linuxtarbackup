#!/bin/bash

function resolve_symlink_silent () 
{
  SOURCE="${BASH_SOURCE[0]}"
  while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    TARGET="$(readlink "$SOURCE")"
    if [[ $TARGET == /* ]]; then
      #echo "SOURCE '$SOURCE' is an absolute symlink to '$TARGET'"
      SOURCE="$TARGET"
    else
      DIRE="$( dirname "$SOURCE" )"
      #echo "SOURCE '$SOURCE' is a relative symlink to '$TARGET' (relative to '$DIRE')"
      SOURCE="$DIRE/$TARGET" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    fi
  done
  #echo "SOURCE is '$SOURCE'"
  RDIR="$( dirname "$SOURCE" )"
  DIRE="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  #if [ "$DIRE" != "$RDIR" ]; then
    #echo "DIRE '$RDIR' resolves to '$DIRE'"
  #fi
  #echo "DIRE is '$DIRE'"
  ## http://stackoverflow.com/a/246128/4976191
}

function byte_format () 
{

  # 1. parameter is number
  num=$1
  # set unit and factor
  if [ $num -gt 999999999999 ] ; then
    t=1099511627776
    e=TB
  else
    if [ $num -gt 999999999 ] ; then
      t=1073741824
      e=GB
    else
      if [ $num -gt 999999 ] ; then
        t=1048576
        e=MB
      else
        if [ $num -gt 999 ] ; then
          t=1024
          e=KB
        else    
          # no formating needed
          printf "%5d Byte" $num
          return
        fi
      fi
    fi
  fi
  # round and get integer part
  n1=$((($num+($t/20))/$t))
  # get 1 decimal place of remainder
  n2=$(((($num+($t/20))%$t)/($t/10)))
  # and print
  printf "%3d.%1d%s" $n1 $n2 " $e"
  return
}

function run_backup () 
{

  # Get full size of folders
  backupfoldersizeint=$(cat $filelist | while read line; do du -s "/$line"; done | cut -f1 | paste -sd+ | bc)
  # Format to KB/MB/GB/TB
  backupfoldersize=$(byte_format $(( $backupfoldersizeint * 1024 )))

  echo -e "\n===== TAR-Filebackup ====="
  echo "time:            " $time
  echo "backupname:      " $backupname
  echo "backupdir:       " $backupdir
  echo "filelist:        " $filelist
  echo "filelistexclude: " $filelistexclude
  echo "logfile:         " $logfile
  echo "backupfile:      " $backupfile
  
  echo -e "\nAbout $backupfoldersize will be saved from these files and folders:"
  cat $filelist
  echo -e "\nWith these exceptions:"
  cat $filelistexclude
  echo -e "\n"

  read -p "Please close all programs. Do you want to start backup now (y)? " startbackup

  if [ $startbackup == 'y' ]
    then
      echo -e "\nFilebackup $backupname started at $time"
      # measure duration
      date1=$(date -u +"%s")
      # Create backup folder if doesn't exist
      mkdir -p $backupdir/$backupname
      # start tar
      sudo tar -cp -C / --index-file=$logfile --files-from=$filelist --exclude-from=$filelistexclude -f - | pv -pterabs ${backupfoldersizeint}k | gzip > $backupfile
      # without pv:  echo sudo tar -czp -C / --index-file=$logfile --files-from=$filelist --exclude-from=$filelistexclude -f $backupfile

      date2=$(date -u +"%s")
      diff=$(($date2-$date1))
      duration=$(date -u -d @"$diff" +'%-Mm %-Ss')

      # print archive size
      backupfilesize=$(wc -c < $backupfile)

      echo -e "\nBackup completed."
      echo -e "Backupfile:    $backupfile"
      echo -e "Backupsize:    $(byte_format $backupfilesize)"
      echo -e "Time needed: $duration"
      echo -e "\a" # Beep, Bell

    else
      echo -e "\nAbort. Nothing done."
      exit 0
  fi

}

# Start

# check sudo
if [ $UID != 0 ] ; then
  echo "Please run as root!"
  echo "sudo $0 [BACKUPNAME]"
  exit 4
fi

# Global variables
time=$(date "+%Y-%m-%d_%H-%M-%S")
backupname=$1
resolve_symlink_silent # Get directory of this script despite possible symlinks
backupdir=$DIRE
filelist="$backupdir/filelist_$backupname.txt"
filelistexclude="$backupdir/filelistexclude_$backupname.txt"
logfile="$backupdir/$backupname/$time.log"
backupfile="$backupdir/$backupname/$time.tar.gz"

# check parameters
if [ $# -ne 1 ] ; then
  echo "Please provide exactly 1 parameter!"
  echo "sudo $backupdir/linuxtarbackup.sh [BACKUPNAME]"
  echo "These backups are available:"
  for entry in $backupdir/*
    do
      echo "$entry" | grep -Po "(?<=$DIRunknown/filelist_).*?(?=\.txt)" | tr "\n" " "
    done
  echo ""
  exit 1
else
  # parameter correct. Check if files exists, which control backup
  if [ -f $filelist ] ; then
    if [ -f $filelistexclude ] ; then
      # Parameter ok, start backup."
      run_backup
      exit 0
    else
      # Exclude not fond
      echo "Can't find exclude file $filelistexclude. Backup aborted."
      exit 3
    fi
  else
    echo "Can't find include file $filelist. Backup aborted."
    exit 2
  fi
fi
