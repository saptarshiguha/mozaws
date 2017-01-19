#!/bin/sh
cd /home/hadoop
wget -qO- https://get.haskellstack.org/ | sh
sudo yum -y install libffi zlib gmp-devel 

git clone https://github.com/jgm/pandoc
cd pandoc
git submodule update --init 

/usr/local/bin/stack setup
/usr/local/bin/stack install --test
echo "export PATH=\$PATH:\$HOME/.local/bin" >> ~/.bash_profile

