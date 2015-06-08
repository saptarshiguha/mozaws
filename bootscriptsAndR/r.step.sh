## Must be run as a step, not a bootstrap

IS_MASTER=true
if [ -f /mnt/var/lib/info/instance.json ]
then
	IS_MASTER=$(jq .isMaster /mnt/var/lib/info/instance.json)
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
# sudo mkdir -p /usr/local/rlibs
# sudo chmod -R 4777 /usr/local/rlibs/

sudo -E  R -e 'for(x in c("devtools","rJava","roxygen2","RCurl","XML","rmarkdown")){ tryCatch(install.packages(x,repos="http://cran.cnr.Berkeley.edu",dep=TRUE),error=function(e) print(e))}'
sudo -E  R -e 'for(x in c("Hmisc","rjson","httr","infuser")){ tryCatch(install.packages(x,repos="http://cran.cnr.Berkeley.edu",dep=TRUE),error=function(e) print(e))}'

# R -e 'for(x in c("forecast","zoo","latticeExtra","mixtools","maps","lubridate")){ tryCatch(install.packages(x,repos="http://cran.cnr.Berkeley.edu",dep=TRUE),error=function(e) print(e))}'

wget https://github.com/saptarshiguha/terrific/releases/download/1.4/rterra_1.4.tar.gz
sudo -E R CMD INSTALL -l /usr/local/rlibs/ /home/hadoop/rterra_1.4.tar.gz

#RHIPE
echo "Installing Rhipe"
ver=$(wget -qO- http://ml.stat.purdue.edu/rhipebin/current.ver)
export RHIPE_VERSION=${ver}_hadoop-2
wget http://ml.stat.purdue.edu/rhipebin/Rhipe_$RHIPE_VERSION.tar.gz
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
sudo -E R CMD INSTALL  Rhipe_$RHIPE_VERSION.tar.gz


## Other Packages
sudo -E R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('saptarshiguha/rhekajq')"
sudo -E R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('saptarshiguha/RAmazonS3')"
sudo -E R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('Rdatatable/data.table', build_vignettes = FALSE)"
sudo -E R -e "library(devtools); devtools::install_github('argparse', 'trevorld')"


## Teserra
# sudo -E R -e "options(unzip = 'unzip', repos = 'http://cran.rstudio.com/'); library(devtools); tryCatch(install_github('datadr', 'tesseradata'),error=function(e) print(e))"
# sudo -E R -e "options(unzip = 'unzip', repos = 'http://cran.rstudio.com/'); library(devtools); tryCatch(install_github('trelliscope', 'tesseradata'),error=function(e) print(e))"
# sudo -E R -e 'for(x in c("shiny")){ tryCatch(install.packages(x,repos="http://cran.cnr.Berkeley.edu",dep=TRUE),error=function(e) print(e))}'
# sudo -E R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('daattali/shinyjs')"
# sudo -E R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('hafen/housingData')"


if [ "$IS_MASTER" = true ]; then
    installRstudio
    installShinyServer
fi

