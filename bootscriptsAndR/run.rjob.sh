!/bin/sh
TFILE="/tmp/$(basename $2).$$"


if [[ $2 == s3://*  ]]; then
    echo "S3 file"
    aws s3 cp $2 $TFILE
else
    echo "regular file"
    curl  $2 -o $TFILE
fi
R CMD BATCH $TFILE $TFILE.log --args $@{:3}


