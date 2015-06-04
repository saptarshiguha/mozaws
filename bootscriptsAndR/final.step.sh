## Must be run as a step, not a bootstrap

IS_MASTER=true
if [ -f /mnt/var/lib/info/instance.json ]
then
	IS_MASTER=$(jq .isMaster /mnt/var/lib/info/instance.json)
fi

hdfs dfs -chmod -R 777 /
sudo chmod -R 777 /mnt


