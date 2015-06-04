#B!/bin/sh
if [[ $1 == s3://*  ]]; then
    echo "S3 file"
    aws s3 cp $1 user.sh
else
    echo "regular file"
    curl  $1 -o user.sh
fi
chmod +x ./user.sh
exec ./user.sh "$@"

