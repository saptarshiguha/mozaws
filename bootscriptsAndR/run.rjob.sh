!/bin/sh
TFILE="/tmp/$(basename $2).$$"


if [[ $2 == s3://*  ]]; then
    echo "S3 file"
    aws s3 cp $2 $TFILE
else
    echo "regular file"
    curl  $2 -o $TFILE
fi


IS_MASTER=false
if [ -f /mnt/var/lib/info/instance.json ]
then
	IS_MASTER=$(jq .isMaster /mnt/var/lib/info/instance.json)
fi

if $IS_MASTER; then
    R CMD BATCH $TFILE $TFILE.log --args $@{:3}
fi
