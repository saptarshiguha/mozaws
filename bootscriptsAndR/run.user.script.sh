#!/bin/sh
TFILE="/tmp/$(basename $1).$$"

if [[ $1 == s3://*  ]]; then
    echo "S3 file"
    aws s3 cp $1 $TFILE
else
    echo "regular file"
    curl  $1 -o  $TFILE
fi

echo "Downloaded" $1 "to" $TFILE
chmod +x $TFILE
exec $TFILE $@

