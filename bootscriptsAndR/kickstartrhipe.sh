while [ $# -gt 0 ]; do
	case "$1" in
		--public-key)
			shift
			PUBLIC_KEY=$1
			;;
		--timeout)
			shift
			TIMEOUT=$1
			;;
		-*)
			# do not exit out, just note failure
			echo "unrecognized option: $1"
			;;
		*)
			break;
			;;
	esac
	shift
done

if [ -n "$PUBLIC_KEY" ]; then
    echo "Given Public Key"
    echo $PUBLIC_KEY >> $HOME/.ssh/authorized_keys
fi

# Schedule shutdown at timeout (minutes)
if [ ! -z $TIMEOUT ]; then
    echo "Setting timeout"
    sudo shutdown -h +$TIMEOUT&
fi

export MYHOME=/home/hadoop

## What i can yum, i shall yum
echo "Installing Packages"
sudo yum -y install git emacs tbb tbb-devel jq jq-devel tmux libffi-devel htop libcurl-devel openssl-devel openssl098e


## Prepare Hadoop Related variables
cd $MYHOME
echo 'export R_LIBS=/usr/local/rlibs' | sudo tee -a /etc/bashrc
echo 'export HADOOP=/home/hadoop' | sudo tee -a /etc/bashrc
echo 'export HADOOP_HOME=/home/hadoop'  | sudo tee -a /etc/bashrc
echo 'export HADOOP_CONF_DIR=/home/hadoop/conf/' | sudo tee -a /etc/bashrc
echo 'export RHIPE_HADOOP_TMP_FOLDER=/tmp/' | sudo tee -a /etc/bashrc
echo 'export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig' | sudo tee -a /etc/bashrc
echo "export HADOOP_LIBS=`hadoop classpath | tr -d '*'`" | sudo tee -a /etc/bashrc


echo "Compiling Protobuf"

export PROTO_BUF_VERSION=2.5.0
wget https://protobuf.googlecode.com/files/protobuf-$PROTO_BUF_VERSION.tar.bz2
tar jxvf protobuf-$PROTO_BUF_VERSION.tar.bz2
cd protobuf-$PROTO_BUF_VERSION
./configure && make -j4
sudo make install
sudo echo "/usr/local/lib" | sudo tee -a /etc/ld.so.conf
sudo ldconfig
cd ..


## Setup environment variables

source  /etc/bashrc

## Put the following into .Renviron
echo "HADOOP=${HADOOP}" | sudo  tee -a /usr/lib64/R/etc/Renviron 
echo "HADOOP_HOME=${HADOOP_HOME}" | sudo  tee -a /usr/lib64/R/etc/Renviron 
echo "HADOOP_CONF_DIR=${HADOOP_CONF_DIR}" | sudo  tee -a /usr/lib64/R/etc/Renviron 
echo "RHIPE_HADOOP_TMP_FOLDER=${RHIPE_HADOOP_TMP_FOLDER}" | sudo tee -a /usr/lib64/R/etc/Renviron 
echo "PKG_CONFIG_PATH=${PKG_CONFIG_PATH}" | sudo tee -a /usr/lib64/R/etc/Renviron 
echo "HADOOP_LIBS=${HADOOP_LIBS}"| sudo  tee -a /usr/lib64/R/etc/Renviron 
echo "R_LIBS=/usr/local/rlibs"| sudo  tee -a /usr/lib64/R/etc/Renviron 
sudo chmod -R 777 /mnt


Y1=`Rscript -e 'cat(strsplit(readLines("/home/hadoop/.aws/config")[2],"=[ ]+")[[1]][[2]])'`
Y2=`Rscript -e 'cat(strsplit(readLines("/home/hadoop/.aws/config")[3],"=[ ]+")[[1]][[2]])'`
(
    
cat <<EOF

export AWS_ACCESS_KEY_ID=${Y1}
export AWS_SECRET_ACCESS_KEY=${Y2}

EOF
) >> $MYHOME/.bashrc

cd /home/hadoop
