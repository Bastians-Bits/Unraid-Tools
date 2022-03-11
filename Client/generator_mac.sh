#!/bin/bash

#------
# Global Variables
# have to be customized
#The servers name or address 
export SSH_SERVER=alpha.local
#The servers user (usually root)
export SSH_USER=root
#The user to generate the script for
export SCRIPT_USER=uwe
#------

TEMPLATE=$(cat <<EOF

echo 'mount volume "smb://\$SCRIPT_USER\$SCRIPT_PASSWORD@\$SSH_SERVER/\$SHARE_NAME"' | osascript

EOF
)

echo -e $(cat <<'EOF'
A few things about this script (be sure to read!):
  * This script accesses your server via ssh. Be sure to be on an secure connection and to have ssh access
    * This will be done to read you share configuration in /boot/config/shares
  * This script will generate a second script in the same directory called unraid_mount.sh
    * This is the one you can execute to mount your shares
  * This script CAN add your user accounts password to the script. Be sure to store the script somewhere safe with no third person access
    * If you leave the input empty, you will only be authorized by username. In this case you have to authorize by password each time you execute the script

EOF
)

echo "Loading share configuration from server. This may require to enter your servers password"
CONFIG=$(ssh ${SSH_USER}${SCRIPT_PASSWORD}@${SSH_SERVER} "tail -n +1 /boot/config/shares/*")
echo "Enter your users password to the script (leave empty to skip)?"
read -sp "Password: " SCRIPT_PASSWORD 
export SCRIPT_PASSWORD="${SCRIPT_PASSWORD:+":$SCRIPT_PASSWORD"}"

i=1
s=1
declare -a arr
while read -r line; do 
  # If we find an empty line, then we increase the counter (i), 
  # set the flag (s) to one, and skip to the next line
  [[ $line == "" ]] && ((i++)) && s=1 && continue 

  # If the flag (s) is zero, then we are not in a new line of the block
  # so we set the value of the array to be the previous value concatenated
  # with the current line
  [[ $s == 0 ]] && arr[$i]="${arr[$i]}
$line" || { 
    # Otherwise we are in the first line of the block, so we set the value
    # of the array to the current line, and then we reset the flag (s) to zero 
    arr[$i]="$line"
    s=0; 
  }
done < <(echo "$CONFIG")

for file in "${arr[@]}"; do
  # Get the first line in the block (prepended by tail)
  # Remove the first 24 character (tail prepend + path and the last 4 character (tail append)
  # Return just the share name
  export SHARE_NAME=$(read -r temp_share_name< <(echo "$file"); echo ${temp_share_name:24:((${#temp_share_name}-24-8))})
  # Grab the shareExport line and extract the value
  export SHARE_EXPORT=$(temp_share_export=$(grep -e "shareExport=.*" <<< "$file"); [[ $temp_share_export =~ shareExport=\"(.*)\" ]]; echo ${BASH_REMATCH[1]})
  # Salvaged from an old version. Checks if the user is either in the read list or write list
  export SHARE_PERMISSION=$(if grep -q -e "shareReadList=\".*$SCRIPT_USER.*\"" <<< $file || grep -q -e "shareWriteList=\".*$SCRIPT_USER.*\"" <<< $file; then echo "1"; else echo "0"; fi)

  # DEBUG
  #echo "Share name: $SHARE_NAME"
  #echo "Export: $SHARE_EXPORT"
  #echo "Permission: $SHARE_PERMISSION"
  #echo ""

  if [[ "$SHARE_EXPORT" == *"e"* ]] && [[ "$SHARE_PERMISSION" == "1" ]]; then
    # Copied from SO. Expands the env vars in the string, don't ask me how and pray it won't break
    SCRIPT=$(echo -n "$SCRIPT$TEMPLATE" | perl -pe 's/\$(\{)?([a-zA-Z_]\w*)(?(1)\})/$ENV{$2}/g')
  fi
done 

echo "Script:"
echo -e "$SCRIPT"

if [ -f ./mount_mac.sh ]; then rm ./mount_mac.sh; fi
echo -e "$SCRIPT" >> ./mount_mac.sh
chmod +x ./mount_mac.sh

# Values for SHARE_EXPORT:
# YES ------------------------= e
# NO -------------------------= -
# YES (hidden) ---------------= eh
# Yes (Time-Machine) ---------= et
# Yes (Time-Machine (hidden)) = eth