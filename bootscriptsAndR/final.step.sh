## Must be run as a step, not a bootstrap

IS_MASTER=true
if [ -f /mnt/var/lib/info/instance.json ]
then
	IS_MASTER=$(jq .isMaster /mnt/var/lib/info/instance.json)
fi

if [ "$IS_MASTER" = true ]; then
    hdfs dfs -chmod -R 777 /
    sudo chmod -R 777 /mnt
fi


installShinyServer(){
    # shiny Server
    ver=$(wget -qO- https://s3.amazonaws.com/rstudio-shiny-server-os-build/centos-5.9/x86_64/VERSION)
    wget https://s3.amazonaws.com/rstudio-shiny-server-os-build/centos-5.9/x86_64/shiny-server-${ver}-rh5-x86_64.rpm
    sudo yum install -y --nogpgcheck shiny-server-${ver}-rh5-x86_64.rpm
    
    sudo mkdir -p /srv/shiny-server/examples
    sudo cp -R /usr/lib64/R/library/shiny/examples/* /srv/shiny-server/examples
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
    echo "hadoop:hadoop" | sudo chpasswd
    sudo sed  -i -e  's/uid >= 500/uid >= 450/' /etc/pam.d/rstudio ## allows hadoop to login
    sudo rstudio-server restart
}

echo "R Packages...."
sudo R CMD javareconf
sudo mkdir -p /usr/local/rlibs
sudo chmod -R 4777 /usr/local/rlibs/

R -e 'for(x in c("rJava","roxygen2","RCurl","XML","rmarkdown","shiny")){ tryCatch(install.packages(x,lib="/usr/local/rlibs/",repos="http://cran.cnr.Berkeley.edu",dep=TRUE),error=function(e) print(e))}'
R -e 'for(x in c("Hmisc","rjson","httr","devtools","forecast","zoo","latticeExtra","maps","mixtools","lubridate")){ tryCatch(install.packages(x,lib="/usr/local/rlibs/",repos="http://cran.cnr.Berkeley.edu",dep=TRUE),error=function(e) print(e))}'

wget https://github.com/saptarshiguha/terrific/releases/download/1.4/rterra_1.4.tar.gz
R CMD INSTALL -l /usr/local/rlibs/ /home/hadoop/rterra_1.4.tar.gz
sudo chmod -R 4777 /usr/local/rlibs/

#RHIPE
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

## Other Packages
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('saptarshiguha/rhekajq')"
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('saptarshiguha/RAmazonS3')"
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('daattali/shinyjs')"
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('Rdatatable/data.table', build_vignettes = FALSE)"
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('hafen/housingData')"


if [ "$IS_MASTER" = false ]; then
     exit
fi

installRstudio
installShinyServer
