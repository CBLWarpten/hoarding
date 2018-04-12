#!/bin/sh
#To get the latest packagelists and to upgrade installs
echo Updating...
apt-get update
apt-get upgrade -y
 
#Installs needed programs
echo Installing programs...
apt-get -yqq update; apt-get -yqq upgrade; apt-get -yqq install git lsb-release
apt-get install git nano denyhosts screen apache2 unzip fuse unionfs-fuse man -y
 
#Make needed folders
echo Creating folders and settings permissions...
mkdir -p /home/plex /home/plex/tv-gd /home/plex/m-gd /home/plex/m-r /home/plex/tv-r /home/plex/fuse-tv /home/plex/fuse-m /home/scripts
echo "$(tput setaf 1)$(tput setab 7)What is your desired QuickBox username?$(tput sgr 0)"
read -p 'Username:' uservar
chown -R $uservar /home/plex/tv-r /home/plex/m-r /home/plex/fuse-tv /home/plex/fuse-m
 
#Installing rClone
echo Installing rClone...
curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip
unzip rclone-current-linux-amd64.zip
cd rclone-*-linux-amd64
sudo cp rclone /usr/bin/
sudo chown root:root /usr/bin/rclone
sudo chmod 755 /usr/bin/rclone
sudo mkdir -p /usr/local/share/man/man1
sudo cp rclone.1 /usr/local/share/man/man1/
sudo mandb
 
#Install Plexdrive
echo Installing PlexDrive...
wget https://github.com/dweidenfeld/plexdrive/releases/download/5.0.0/plexdrive-linux-amd64
mv plexdrive-linux-amd64 /usr/local/bin/plexdrive
chown root:root /usr/local/bin/plexdrive
chmod 755 /usr/local/bin/plexdrive
 
#Creating Mount for Plex drive
echo Making sure PlexDrive mounts...
cat <<EOF >/home/scripts/mount-plex.sh
#!/bin/bash
 
## GLOBAL VARS
LOGFILE="/home/scripts/logs/mount-plex.log"
MPOINT="/mnt/plexdrive/"
 
## UNMOUNT IF SCRIPT WAS RUN WITH unmount PARAMETER
if [[ $1 = "unmount" ]]; then
    echo "Unmounting $MPOINT"
    fusermount -uz $MPOINT
    exit
fi
 
## CHECK IF MOUNT ALREADY EXIST AND MOUNT IF NOT
if mountpoint -q $MPOINT ; then
    echo "$MPOINT already mounted"
else
    echo "Mounting $MPOINT"
    /usr/local/bin/plexdrive mount $MPOINT \
                       -o allow_other \
                       -v 2 &>>$LOGFILE &
fi
exit
 
## Default is with minimal options and if needed use aditional flags copy paste them above line: -v 2 &>>$LOGFILE &
##        Note: Only lines eg options with - or -- in front
##  --chunk-size 5M \
##        The size of each chunk that is downloaded (units: B, K, M, G) (default "5M")
##  --clear-chunk-age 30m0s \
##        The maximum age of a cached chunk file (default 30m0s)
##  --clear-chunk-interval 1m0s \
##        The time to wait till clearing the chunk directory (default 1m0s)
##  --clear-chunk-max-size 100G \
##        The maximum size of the temporary chunk directory (units: B, K, M, G)
##  -c, --config=/home/plex/.plexdrive \
##        The path to the configuration directory (default "/home/plex/.plexdrive")
##  -o allow_other \
##        Fuse mount options (e.g. -fuse-options allow_other,...)
##  --gid 1000 \
##        Set the mounts GID (-1 = default permissions) (default -1)
##  --refresh-interval 5m0s \
##        The time to wait till checking for changes (default 5m0s)
##  --speed-limit 1G \
##        This value limits the download speed, e.g. 5M = 5MB/s per chunk (units: B, K, M, G)
##  -t, --temp=/tmp \
##        Path to a temporary directory to store temporary data (default "/tmp")
##  --uid 1000 \
##        Set the mounts UID (-1 = default permissions) (default -1)
##  --umask value
##        Override the default file permissions
##  -v, --verbosity 2 \
##        Set the log level (0 = error, 1 = warn, 2 = info, 3 = debug, 4 = trace)
EOF
 
#MountChecks
echo Creating Mount Checks...
touch /home/plex/tv-r/mountcheck /home/plex/m-r/mountcheck
 
#mount-m.cron
echo Creating mount script for Movies
cat <<EOF >/home/scripts/mount-m.cron
#!/bin/bash

logfile="/home/scripts/logs/mount-m.cron.log"

if pidof -o %PPID -x "mount-m.cron"; then
echo "$(date "+%d.%m.%Y %T") EXIT: mount-m.cron already running."
exit 1
fi

if [[ -f "/home/plex/m-gd/mountcheck" ]]; then
echo "$(date "+%d.%m.%Y %T") INFO: Check successful, /home/plex/m-gd mounted." | tee -a "$logfile"
exit
else
echo "$(date "+%d.%m.%Y %T") ERROR: Drive not mounted, remount in progress." | tee -a "$logfile"
# Unmount before remounting
fusermount -uz /home/plex/m-gd | tee -a "$logfile"
rclone mount \
        --read-only \
        --allow-non-empty \
        --allow-other \
        --max-read-ahead 2G \
        --acd-templink-threshold 0 \
        --checkers 16 \
        --quiet \
        --stats 0 \
dec-m:/ /home/plex/m-gd/&

if [[ -f "/home/plex/m-gd/mountcheck" ]]; then
echo "$(date "+%d.%m.%Y %T") INFO: Remount successful." | tee -a "$logfile"
else
echo "$(date "+%d.%m.%Y %T") CRITICAL: Remount failed." | tee -a "$logfile"
fi
fi
exit
EOF
 
#mount-tv.cron
echo Creating TV mount script...
cat <<EOF >/home/scripts/mount-m.cron
#!/bin/bash

logfile="/home/scripts/logs/mount-tv.cron.log"

if pidof -o %PPID -x "mount-tv.cron"; then
echo "$(date "+%d.%m.%Y %T") EXIT: mount-tv.cron already running."
exit 1
fi

if [[ -f "/home/plex/tv-gd/mountcheck" ]]; then
echo "$(date "+%d.%m.%Y %T") INFO: Check successful, /home/plex/tv-gd mounted." | tee -a "$logfile"
exit
else
echo "$(date "+%d.%m.%Y %T") ERROR: Drive not mounted, remount in progress." | tee -a "$logfile"
# Unmount before remounting
fusermount -uz /home/plex/tv-gd | tee -a "$logfile"
rclone mount \
        --read-only \
        --allow-non-empty \
        --allow-other \
        --max-read-ahead 2G \
        --acd-templink-threshold 0 \
        --checkers 16 \
        --quiet \
        --stats 0 \
dec-tv:/ /home/plex/tv-gd/&

if [[ -f "/home/plex/tv-gd/mountcheck" ]]; then
echo "$(date "+%d.%m.%Y %T") INFO: Remount successful." | tee -a "$logfile"
else
echo "$(date "+%d.%m.%Y %T") CRITICAL: Remount failed." | tee -a "$logfile"
fi
fi
exit
EOF
 
#upload-m.cron
echo Creating upload script for Movies...
cat <<EOF >/home/scripts/mount-m.cron
#!/bin/bash

if pidof -o %PPID -x "upload-m.cron"; then
exit 1
fi

LOGFILE="/home/scripts/logs/upload-m.cron.log"
FROM="/home/plex/m-r/"
TO="m-gd:/"

# CHECK FOR FILES IN FROM FOLDER THAT ARE OLDER THEN 15 MINUTES
if find $FROM* -type f -mmin +5 | read
then
echo "$(date "+%d.%m.%Y %T") RCLONE UPLOAD STARTED" | tee -a $LOGFILE
# MOVE FILES OLDER THEN 5 MINUTES
rclone move $FROM $TO -c --no-traverse --transfers=300 --checkers=300 --delete-after --min-age 5m --log-file=$LOGFILE
echo "$(date "+%d.%m.%Y %T") RCLONE UPLOAD ENDED" | tee -a $LOGFILE
fi
exit
EOF
 
#upload-tv.cron
echo Creating upload for tv...
cat <<EOF >/home/scripts/mount-m.cron
#!/bin/bash

if pidof -o %PPID -x "upload-tv.cron"; then
exit 1
fi

LOGFILE="/home/scripts/logs/upload-tv.cron.log"
FROM="/home/plex/tv-r/"
TO="tv-gd:/"

# CHECK FOR FILES IN FROM FOLDER THAT ARE OLDER THEN 15 MINUTES
if find $FROM* -type f -mmin +15 | read
then
echo "$(date "+%d.%m.%Y %T") RCLONE UPLOAD STARTED" | tee -a $LOGFILE
# MOVE FILES OLDER THEN 15 MINUTES
rclone move $FROM $TO -c --no-traverse --transfers=300 --checkers=300 --delete-after --min-age 15m --log-file=$LOGFILE
echo "$(date "+%d.%m.%Y %T") RCLONE UPLOAD ENDED" | tee -a $LOGFILE
fi
exit
EOF

#Fusemount TV
echo Creating fuse mount for TV..
cat <<EOF >/home/scripts/fuse-mount-tv.cron
#!/bin/bash

logfile="/home/scripts/logs/fuse-mount-tv.cron.log"

if pidof -o %PPID -x "fuse-mount.cron"; then
echo "$(date "+%d.%m.%Y %T") EXIT: fuse-mount.cron already running."
exit 1
fi

if [[ -f "/home/plex/fuse-tv/mountcheck" ]]; then
echo "$(date "+%d.%m.%Y %T") INFO: Check successful, fuse mounted." | tee -a "$logfile"
exit
else
echo "$(date "+%d.%m.%Y %T") ERROR: Drive not mounted, remount in progress." | tee -a "$logfile"
# Unmount before remounting
fusermount -uz /home/plex/fuse-tv | tee -a "$logfile"
/usr/bin/unionfs-fuse -o cow,allow_other /home/plex/tv-r=RW:/home/plex/tv-gd=RO /home/plex/fuse-tv

if [[ -f "/home/plex/fuse-tv/mountcheck" ]]; then
echo "$(date "+%d.%m.%Y %T") INFO: Remount successful." | tee -a "$logfile"
else
echo "$(date "+%d.%m.%Y %T") CRITICAL: Remount failed." | tee -a "$logfile"
fi
fi
exit
EOF

#Fusemount Movies
echo Creating fuse mount for Movies..
cat <<EOF >/home/scripts/fuse-mount-m.cron
#!/bin/bash

logfile="/home/scripts/logs/fuse-mount-m.cron.log"

if pidof -o %PPID -x "fuse-mount-m.cron"; then
   echo "$(date "+%d.%m.%Y %T") EXIT: fuse-mount-m.cron already running."
   exit 1
fi

if [[ -f "/home/plex/fuse-m/mountcheck" ]]; then
   echo "$(date "+%d.%m.%Y %T") INFO: Check successful, /home/plex/fuse-m mounted." | tee -a "$logfile"
   exit
else
   echo "$(date "+%d.%m.%Y %T") ERROR: Drive not mounted, remount in progress." | tee -a "$logfile"
   # Unmount before remounting
   fusermount -uz /home/plex/fuse-m | tee -a "$logfile"
   /usr/bin/unionfs-fuse -o cow,allow_other /home/plex/m-r=RW:/home/plex/m-gd=RO /home/plex/fuse-m

   if [[ -f "/home/plex/fuse-m/mountcheck" ]]; then
      echo "$(date "+%d.%m.%Y %T") INFO: Remount successful." | tee -a "$logfile"
   else
      echo "$(date "+%d.%m.%Y %T") CRITICAL: Remount failed." | tee -a "$logfile"
   fi
fi
exit
EOF

#permissions
echo Settings permissions...
chmod a+x /home/scripts/fuse-mount-m.cron
chmod a+x /home/scripts/fuse-mount-tv.cron
#etc.