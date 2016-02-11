

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
sudo yum -y install epel-release readline-devel libcurl  libcurl-devel libxml2 libxml2-devel libpng-devel cairo-devel
sudo ldconfig

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

# ## Put the following into .Renviron
# echo "HADOOP=${HADOOP}" | sudo  tee -a /usr/lib64/R/etc/Renviron
# echo "HADOOP_HOME=${HADOOP_HOME}" | sudo  tee -a /usr/lib64/R/etc/Renviron
# echo "HADOOP_CONF_DIR=${HADOOP_CONF_DIR}" | sudo  tee -a /usr/lib64/R/etc/Renviron
# echo "RHIPE_HADOOP_TMP_FOLDER=${RHIPE_HADOOP_TMP_FOLDER}" | sudo tee -a /usr/lib64/R/etc/Renviron
# echo "PKG_CONFIG_PATH=${PKG_CONFIG_PATH}" | sudo tee -a /usr/lib64/R/etc/Renviron
# echo "HADOOP_LIBS=${HADOOP_LIBS}"| sudo  tee -a /usr/lib64/R/etc/Renviron
# echo "R_LIBS=/usr/local/rlibs"| sudo  tee -a /usr/lib64/R/etc/Renviron
# sudo chmod -R 777 /mnt



# echo '/usr/java/jdk1.7.0_65/jre/lib/amd64/server/' | sudo tee -a  /etc/ld.so.conf.d/jre.conf
# echo '/usr/java/jdk1.7.0_65/jre/lib/amd64/'        | sudo tee -a  /etc/ld.so.conf.d/jre.conf
# echo '/home/hadoop/.versions/2.4.0/lib/native/'    | sudo tee -a  /etc/ld.so.conf.d/hadoop.conf
# sudo ldconfig

# eVal 'HADOOP=/home/hadoop'
# eVal 'HADOOP_HOME=/home/hadoop'
# eVal 'HADOOP_CONF_DIR=/home/hadoop/conf'
# eVal 'HADOOP_BIN=/home/hadoop/bin'
# eVal 'HADOOP_OPTS=-Djava.awt.headless=true'
# eVal 'HADOOP_LIBS=/home/hadoop/conf:/home/hadoop/share/hadoop/common/lib/:/home/hadoop/share/hadoop/common/:/home/hadoop/share/hadoop/hdfs:/home/hadoop/share/hadoop/hdfs/lib/:/home/hadoop/share/hadoop/hdfs/:/home/hadoop/share/hadoop/yarn/lib/:/home/hadoop/share/hadoop/yarn/:/home/hadoop/share/hadoop/mapreduce/lib/:/home/hadoop/share/hadoop/mapreduce/:/usr/share/aws/emr/emrfs/lib/:/usr/share/aws/emr/lib/'
# eVal 'LD_LIBRARY_PATH=/usr/local/lib:/home/hadoop/lib/native:/usr/local/lib64:/usr/lib64:/usr/local/cuda/lib64:/usr/local/cuda/lib:$LD_LIBRARY_PATH'

# cd /home/hadoop
