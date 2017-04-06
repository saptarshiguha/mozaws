## This uses mozillas new emr-dfs persistant home directories
## so presumably you have installed the stuff in setupRhipe.sh
## already! 

## The lines here did not install stuff into the home folder 
## and therefore need to be installed again.

wget http://cbs.centos.org/kojifiles/packages/protobuf/2.5.0/10.el7.centos/x86_64/protobuf-2.5.0-10.el7.centos.x86_64.rpm
wget http://cbs.centos.org/kojifiles/packages/protobuf/2.5.0/10.el7.centos/x86_64/protobuf-devel-2.5.0-10.el7.centos.x86_64.rpm
wget http://cbs.centos.org/kojifiles/packages/protobuf/2.5.0/10.el7.centos/x86_64/protobuf-compiler-2.5.0-10.el7.centos.x86_64.rpm
sudo yum -y install protobuf-2.5.0-10.el7.centos.x86_64.rpm protobuf-compiler-2.5.0-10.el7.centos.x86_64.rpm protobuf-devel-2.5.0-10.el7.centos.x86_64.rpm


aws s3 cp s3://mozilla-metrics/share/R.tar.gz /tmp/
hadoop dfs -put  /tmp/R.tar.gz /

yum -y install inotify-tools

sudo yum -y install curl-devel
