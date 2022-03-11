#!/bin/bash
###############################################################################
# gen-mount-win.sh
#
# Reads the unraid config and create a Windows Batch Script to mount all
# user shares
#
# Before the first usage:
# - Read the script and make sure you understand what id does.
#   Never execute code you don't fully understand on your machine!
# - After that, replace the server and username variables with the server name
#   or IP and the user to create the script for
#
###############################################################################

server=
username=

##
## Template for the header
##
header=$(cat <<EOF
###################
### COPY FROM HERE:
###################
@echo off
set /p password="Password: "

EOF
)

##
## Template for the body
##
template=$(cat <<EOF


REM \$share \$letter:
if exist \$letter:\ (
   @echo on
   echo "\$letter: already in use"
   @echo off
) else (
   net use \$letter: \\\\$server\\\$share /user:$username %password%
)

EOF
)

##
## Template for the footer
##
footer=$(cat <<EOF

pause
@echo on
###################
### TO HERE
###################
EOF
)

# Iterate each share config
for file in /boot/config/shares/*.cfg; do
   # Get the share name from the filename
   share=${file%.cfg}; share=${share##*/}; export share=${share,,};

   # Check if the share is exported
   is_export=$(grep -e "shareExport=.*" $file)
   [[ $is_export =~ shareExport=\"(.*{1})\" ]]
   is_export=${BASH_REMATCH[1]}
   if [ "$is_export" != "e" ]; then continue; fi

   # Check if the user is either in the read or write list
   if grep -q -e "shareReadList=\".*$username.*\"" $file || grep -q -e "shareWriteList=\".*$username.*\"" $file; then
      # Get the letter from the share description
      letter=$(grep -e "shareComment=.*mountpoint.*" $file)
      [[ $letter =~ \(mountpoint\ (.*{1})\) ]]
      export letter=${BASH_REMATCH[1]}

      # Check if the letter is set
      if [[ -z "${letter+x}" ]]; then continue; fi

      # Build the body from the template
      main=$(echo -n "$main$template" | perl -pe 's/\$(\{)?([a-zA-Z_]\w*)(?(1)\})/$ENV{$2}/g')
   fi
done

# Echo the script
echo "$header"
echo "$main"
echo "$footer"
