#!/bin/sh

IS_MASTER=true
if [ -f /mnt/var/lib/info/instance.json ]
then
	IS_MASTER=$(jq .isMaster /mnt/var/lib/info/instance.json)
fi


R -e 'install.packages("survival", repos="http://cran.cnr.Berkeley.edu",dep=TRUE)'

