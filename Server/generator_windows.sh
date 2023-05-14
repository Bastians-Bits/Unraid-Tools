#name=Mount Script Windows
#description=Create a batch script to mount all shares in Windows
#arrayStarted=true
#argumentDescription=Server Address? Username?

args=( $1 )
echo "Test ${#args[@]}"
if [ "${#args[@]}" -ne "2" ]; then
   echo "Wrong amount of arguments, exit"
   exit 1
fi

server=${1}
username=${2}

header=$(cat <<EOF

--- COPY FROM HERE:
-------------------------------------------------------------------------------

@echo off
set /p password="Password: "

EOF
)

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

footer=$(cat <<EOF

pause
@echo on

-------------------------------------------------------------------------------
--- TO HERE
EOF
)

for file in /boot/config/shares/*.cfg; do
   # Check if user in write list
   share=${file%.cfg}; share=${share##*/}; export share=${share,,};

   is_export=$(grep -e "shareExport=.*" $file)
   [[ $is_export =~ shareExport=\"(.*{1})\" ]]
   is_export=${BASH_REMATCH[1]}

   if [ "$is_export" != "e" ]; then continue; fi

   if grep -q -e "shareReadList=\".*$username.*\"" $file || grep -q -e "shareWriteList=\".*$username.*\"" $file; then
      letter=$(grep -e "shareComment=.*mountpoint.*" $file)
      [[ $letter =~ \(mountpoint\ (.*{1})\) ]]
      export letter=${BASH_REMATCH[1]}

      if [[ -z "${letter+x}" ]]; then continue; fi

      main=$(echo -n "$main$template" | perl -pe 's/\$(\{)?([a-zA-Z_]\w*)(?(1)\})/$ENV{$2}/g')
   fi
done

echo "$header"
echo "$main"
echo "$footer"
