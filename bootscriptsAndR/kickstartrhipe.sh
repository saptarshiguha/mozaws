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

## force python 2.7
echo "Redoing Python"
sudo rm /usr/bin/python /usr/bin/pip
sudo ln -s /usr/bin/python2.7 /usr/bin/python
sudo ln -s /usr/bin/pip-2.7 /usr/bin/pip
sudo sed -i '1c\#!/usr/bin/python2.6' /usr/bin/yum

installShinyServer(){
        # shiny Server
    ver=$(wget -qO- https://s3.amazonaws.com/rstudio-shiny-server-os-build/centos-5.9/x86_64/VERSION)
    wget https://s3.amazonaws.com/rstudio-shiny-server-os-build/centos-5.9/x86_64/shiny-server-${ver}-rh5-x86_64.rpm
    sudo yum install -y --nogpgcheck shiny-server-${ver}-rh5-x86_64.rpm
    
    sudo mkdir -p /srv/shiny-server/examples
    sudo cp -R /usr/lib64/R/library/shiny/examples/* /srv/shiny-server/examples
    sudo chown -R shiny:shiny /srv/shiny-server/examples
    sudo chmod 777 /srv/shiny-server/
}

installRstudio(){
    sudo yum install -y openssl098e

    wget -q https://s3.amazonaws.com/rstudio-server/current.ver -O currentVersion.txt
    ver=$(cat currentVersion.txt)
    wget http://download2.rstudio.org/rstudio-server-rhel-${ver}-x86_64.rpm
    sudo yum install -y --nogpgcheck rstudio-server-rhel-${ver}-x86_64.rpm
    rm rstudio-server-*-x86_64.rpm
    echo "www-port=80" | sudo tee -a /etc/rstudio/rserver.conf
    echo "rsession-ld-library-path=/usr/local/lib" | sudo tee -a /etc/rstudio/rserver.conf
    echo "r-libs-user=/usr/local/rlibs/" | sudo tee -a /etc/rstudio/rsession.conf
    sudo rstudio-server restart
}


## Prepare Hadoop Related variables
cd $MYHOME
echo 'export R_LIBS=/usr/local/rlibs' | sudo tee -a /etc/bashrc
echo 'export HADOOP=/home/hadoop' | sudo tee -a /etc/bashrc
echo 'export HADOOP_HOME=/home/hadoop'  | sudo tee -a /etc/bashrc
echo 'export HADOOP_CONF_DIR=/home/hadoop/conf/' | sudo tee -a /etc/bashrc
echo 'export RHIPE_HADOOP_TMP_FOLDER=/tmp/' | sudo tee -a /etc/bashrc
echo 'export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig' | sudo tee -a /etc/bashrc
echo "export HADOOP_LIBS=`hadoop classpath | tr -d '*'`" | sudo tee -a /etc/bashrc

#sudo sed -i "s/.*PasswordAuthentication no.*/PasswordAuthentication yes/"  /etc/ssh/sshd_config
#sudo service  sshd restart


# sudo yum -y install openssl098e # Required only for RedHat/CentOS 6 and 7
# aws s3 cp s3://mozillametricsemrscripts/rstudio/rstudio-server-0.98.1102-x86_64.rpm $MYHOME/
# sudo yum -y install --nogpgcheck $MYHOME/rstudio-server-0.98.1102-x86_64.rpm
# sudo chmod aou=rw /etc/rstudio/rsession.conf 


## Setup Emacs
echo "Setting up Emacs"
sudo mkdir -p /usr/local/site-lisp
sudo chmod -R 4777 /usr/local/site-lisp
aws s3 cp s3://mozillametricsemrscripts/ess/ess-15.03.zip /usr/local/site-lisp/
cd /usr/local/site-lisp
unzip ess-15.03.zip
(
cat <<'EOF'
(load "/usr/local/site-lisp/ess-15.03/lisp/ess-site")
EOF
)> $HOME/.emacs
cd $HOME


## Create the user and install rserver
echo "Creating Users"
for auser in metrics dzeber cchoi aalmossawi bcolloran rweiss jjensen hulmer sguha joy
do
    sudo useradd -m ${auser}
    echo "${auser}:${auser}" | sudo chpasswd
    echo ${auser} | su -c  'mkdir $HOME/.ssh; chmod 700 $HOME/.ssh' ${auser}
    echo ${auser} | su -c  "echo \"${PUBLIC_KEY}\" >> /home/${auser}/.ssh/authorized_keys"  ${auser} 
    sudo chmod 600 /home/${auser}/.ssh/authorized_keys
    sudo cp /home/hadoop/.emacs /home/${auser}/
    sudo chown ${auser} /home/${auser}/.emacs
done


# cd $MYHOME
# mkdir -p proto
# aws s3 sync s3://mozillametricsemrscripts/proto/25/ $MYHOME/proto/
# sudo yum -y install $MYHOME/proto/protobuf-2.5.0-16.1.x86_64.rpm
# sudo yum -y install $MYHOME/proto/protobuf-compiler-2.5.0-16.1.x86_64.rpm
# sudo yum -y install $MYHOME/proto/protobuf-devel-2.5.0-16.1.x86_64.rpm

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


## Now download the archives of /usr/local/share/rlibraries/ which
## is the archive the packages i installed 
# aws s3 cp s3://mozillametricsemrscripts/rlibraries/rlibs.tgz $MYHOME/
# sudo mv $MYHOME/rlibs.tgz /usr/local/
# cd /usr/local
# sudo tar xfz rlibs.tgz --strip-components=2 
# sudo chmod -R 4777 /usr/local/rlibs/

echo "R Packages...."
sudo R CMD javareconf
sudo mkdir -p /usr/local/rlibs
sudo chmod -R 4777 /usr/local/rlibs/
## Install your version of RAmazonS3
R -e 'for(x in c("rJava","roxygen2","RCurl","XML","rmarkdown","shiny")){ tryCatch(install.packages(x,lib="/usr/local/rlibs/",repos="http://cran.cnr.Berkeley.edu",dep=TRUE),error=function(e) print(e))}'
R -e 'for(x in c("Hmisc","rjson","httr","devtools","forecast","zoo","latticeExtra","maps","mixtools","lubridate")){ tryCatch(install.packages(x,lib="/usr/local/rlibs/",repos="http://cran.cnr.Berkeley.edu",dep=TRUE),error=function(e) print(e))}'
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('saptarshiguha/rhekajq')"
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('saptarshiguha/RAmazonS3')"
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('daattali/shinyjs')"
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('Rdatatable/data.table', build_vignettes = FALSE)"
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('hafen/housingData')"

wget https://github.com/saptarshiguha/terrific/releases/download/1.4/rterra_1.4.tar.gz
R CMD INSTALL -l /usr/local/rlibs/ /home/hadoop/rterra_1.4.tar.gz
sudo chmod -R 4777 /usr/local/rlibs/

##RHIPE
echo "Installing Rhipe"
ver=$(wget -qO- http://ml.stat.purdue.edu/rhipebin/current.ver)
export RHIPE_VERSION=${ver}_hadoop-2
wget http://ml.stat.purdue.edu/rhipebin/Rhipe_$RHIPE_VERSION.tar.gz
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
R CMD INSTALL -l /usr/local/rlibs/ Rhipe_$RHIPE_VERSION.tar.gz

## Teserra
R -e "options(unzip = 'unzip', repos = 'http://cran.rstudio.com/'); library(devtools); tryCatch(install_github('datadr', 'tesseradata'),error=function(e) print(e))"
R -e "options(unzip = 'unzip', repos = 'http://cran.rstudio.com/'); library(devtools); tryCatch(install_github('trelliscope', 'tesseradata'),error=function(e) print(e))"



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


################################################################################
## Only master needs to do this
## 1. Start Rstudio, Shiny
## quoting EOF turns of substitution
################################################################################
(
cat <<'EOF'
require 'emr/common'
instance_info = Emr::JsonInfoFile.new('instance')
$is_master =  instance_info['isMaster'].to_s == 'true' 
print $is_master
EOF
) > /tmp/isThisMaster


isMaster=`ruby /tmp/isThisMaster`
if [ $isMaster = "true" ]; then
    echo "Running In Master"
    installRstudio
    installShinyServer
fi

Y1=`Rscript -e 'cat(strsplit(readLines("/home/hadoop/.aws/config")[2],"=[ ]+")[[1]][[2]])'`
Y2=`Rscript -e 'cat(strsplit(readLines("/home/hadoop/.aws/config")[3],"=[ ]+")[[1]][[2]])'`
(
    
cat <<EOF

export AWS_ACCESS_KEY_ID=${Y1}
export AWS_SECRET_ACCESS_KEY=${Y2}

EOF
) >> $MYHOME/.bashrc

cd $MYHOME

## BOOM!

# Check for master node
# IS_MASTER=true
# if [ -f /mnt/var/lib/info/instance.json ]
# then
# 	IS_MASTER=$(jq .isMaster /mnt/var/lib/info/instance.json)
# fi
## is 'true' if so
