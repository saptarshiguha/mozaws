#B!/bin/sh
curl  $1 -o user.sh
chmod +x ./user.sh
exec ./user.sh

