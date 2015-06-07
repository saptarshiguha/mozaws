#!/bin/sh

IS_MASTER=true
if [ -f /mnt/var/lib/info/instance.json ]
then
	IS_MASTER=$(jq .isMaster /mnt/var/lib/info/instance.json)
fi

sleep 30
sudo -E R -e 'install.packages("binda", repos="http://cran.cnr.Berkeley.edu",dep=TRUE)'

