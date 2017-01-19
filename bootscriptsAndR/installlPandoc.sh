#!/bin/sh
wget -qO- https://get.haskellstack.org/ | sh

git clone https://github.com/jgm/pandoc
cd pandoc
git submodule update --init 

stack setup
stack install --test
echo "export PATH=$PATH:$HOME/.local/bin" >> ~/.bash_profile

