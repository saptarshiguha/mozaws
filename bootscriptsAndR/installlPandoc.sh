#!/bin/sh
cd /home/hadoop

# the long and slow way to install from source
#wget -qO- https://get.haskellstack.org/ | sh
#sudo yum -y install libffi zlib gmp-devel 
#git clone https://github.com/jgm/pandoc
#cd pandoc
#git submodule update --init 
#/usr/local/bin/stack setup
#/usr/local/bin/stack install --test
#echo "export PATH=\$PATH:\$HOME/.local/bin" >> ~/.bash_profile

# from https://github.com/rstudio/rmarkdown/blob/master/PANDOC.md
wget https://download2.rstudio.org/rstudio-server-rhel-1.0.136-x86_64.rpm
sudo yum -y install --nogpgcheck rstudio-server-rhel-1.0.136-x86_64.rpm
sudo ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc /usr/local/bin
sudo ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc-citeproc /usr/local/bin
