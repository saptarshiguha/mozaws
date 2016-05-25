#!/bin/sh
TFILE="/tmp/$(basename $2).$$"
echo "Downloading " $2
echo $TFILE


if [[ $2 == s3://*  ]]; then
    echo "S3 file"
    aws s3 cp $1 $TFILE
else
    echo "regular file"
    curl  $2 -o  $TFILE
fi

echo "Downloaded" $2 "to" $TFILE
chmod +x $TFILE
exec $TFILE $@

