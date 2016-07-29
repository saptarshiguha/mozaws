## Must be run as a step, not a bootstrap

IS_MASTER=true
if [ -f /mnt/var/lib/info/instance.json ]
then
	IS_MASTER=$(jq .isMaster /mnt/var/lib/info/instance.json)
fi

export DOWNLOAD_DIR=/var/tmp
export R_HOME=/usr

## CONFIG
function eVal {
    echo        $1 |      tee -a /home/hadoop/.Renviron
    echo        $1 | sudo tee -a $R_HOME/lib64/R/etc/Renviron.site
    echo export $1 |      tee -a /home/hadoop/.bashrc
}


#sudo mkdir     -p /home/hadoop
#sudo chmod 777 -R /home/hadoop
echo '/usr/java/jdk1.7.0_65/jre/lib/amd64/server/' | sudo tee -a  /etc/ld.so.conf.d/jre.conf
echo '/usr/java/jdk1.7.0_65/jre/lib/amd64/'        | sudo tee -a  /etc/ld.so.conf.d/jre.conf
echo '/home/hadoop/.versions/2.4.0/lib/native/'    | sudo tee -a  /etc/ld.so.conf.d/hadoop.conf
sudo ldconfig


eVal 'HADOOP=/home/hadoop'
eVal 'HADOOP_HOME=/home/hadoop'
eVal 'HADOOP_CONF_DIR=/home/hadoop/conf'
eVal 'HADOOP_BIN=/home/hadoop/bin'
eVal 'HADOOP_OPTS=-Djava.awt.headless=true'
eVal 'HADOOP_LIBS=/home/hadoop/conf:/home/hadoop/share/hadoop/common/lib/:/home/hadoop/share/hadoop/common/:/home/hadoop/share/hadoop/hdfs:/home/hadoop/share/hadoop/hdfs/lib/:/home/hadoop/share/hadoop/hdfs/:/home/hadoop/share/hadoop/yarn/lib/:/home/hadoop/share/hadoop/yarn/:/home/hadoop/share/hadoop/mapreduce/lib/:/home/hadoop/share/hadoop/mapreduce/:/usr/share/aws/emr/emrfs/lib/:/usr/share/aws/emr/lib/'
#eVal 'LD_LIBRARY_PATH=/usr/local/lib:/home/hadoop/lib/native:/usr/local/lib64:/usr/lib64:/usr/local/cuda/lib64:/usr/local/cuda/lib:$LD_LIBRARY_PATH'
# sudo R CMD javareconf
# sudo ldconfig
export LD_LIBRARY_PATH=$R_HOME/lib64/R/lib:/usr/local/lib64:/usr/local/lib:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig
sudo ldconfig
echo "options(bitmapType='cairo')"		 | sudo tee -a $R_HOME/lib64/R/etc/Rprofile.site

echo "R Packages...."
sudo R CMD javareconf
sudo -E  R -e 'for(x in c("rJava")){ tryCatch(install.packages(x,repos="http://cran.cnr.Berkeley.edu",dep=TRUE),error=function(e) print(e))}'


sudo -E  R -e 'for(x in c("devtools","rJava","roxygen2","RCurl","XML","rmarkdown")){ tryCatch(install.packages(x,repos="http://cran.cnr.Berkeley.edu",dep=TRUE),error=function(e) print(e))}'
sudo -E  R -e 'for(x in c("Hmisc","rjson","httr","infuser")){ tryCatch(install.packages(x,repos="http://cran.cnr.Berkeley.edu",dep=TRUE),error=function(e) print(e))}'
sudo -E R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('Rdatatable/data.table', build_vignettes = FALSE)"
sudo -E R -e "library(devtools); devtools::install_github('argparse', 'trevorld')"




#RHIPE
echo "Installing Rhipe"
sudo yum -y install protobuf-devel
ver=$(wget -qO- http://ml.stat.purdue.edu/rhipebin/current.ver)
export RHIPE_VERSION=${ver}_hadoop-2
wget http://ml.stat.purdue.edu/rhipebin/Rhipe_$RHIPE_VERSION.tar.gz
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
sudo -E R CMD INSTALL  Rhipe_$RHIPE_VERSION.tar.gz

