
## Download Protobuf Packages (2.5) and install
wget http://cbs.centos.org/kojifiles/packages/protobuf/2.5.0/10.el7.centos/x86_64/protobuf-2.5.0-10.el7.centos.x86_64.rpm
wget http://cbs.centos.org/kojifiles/packages/protobuf/2.5.0/10.el7.centos/x86_64/protobuf-devel-2.5.0-10.el7.centos.x86_64.rpm
wget http://cbs.centos.org/kojifiles/packages/protobuf/2.5.0/10.el7.centos/x86_64/protobuf-compiler-2.5.0-10.el7.centos.x86_64.rpm
sudo yum -y install protobuf-2.5.0-10.el7.centos.x86_64.rpm protobuf-compiler-2.5.0-10.el7.centos.x86_64.rpm protobuf-devel-2.5.0-10.el7.centos.x86_64.rpm


## Set Hadoop Config VAriables that RHIPE requires
echo ""  >> /home/hadoop/.bash_profile
echo "export HADOOP_LIBS=/usr/lib/hadoop/client:/usr/lib/hadoop-lzo/lib:/usr/lib/hadoop/lib:/usr/lib/hadoop:/usr/lib/hadoop-hdfs/:/usr/lib/hadoop-yarn/:/usr/lib/hadoop-mapreduce/:/usr/share/aws/emr/emrfs/conf:/usr/share/aws/emr/emrfs/lib/:/usr/share/aws/emr/emrfs/auxlib/:/usr/share/aws/aws-java-sdk/" >> /home/hadoop/.bash_profile
echo "export HADOOP_CONF_DIR=/etc/hadoop/conf" >> /home/hadoop/.bash_profile
echo  "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/lib/hadoop-lzo/lib/native/" >> /home/hadoop/.bash_profile

aws s3 cp s3://mozilla-metrics/share/R.tar.gz /tmp/
hadoop dfs -put  /tmp/R.tar.gz /

cd /home/hadoop/
rm -rf /home/hadoop/rhipe.r
wget https://raw.githubusercontent.com/saptarshiguha/mozaws/master/bootscriptsAndR/rhipe.r

echo "echo \"Remember to call source('~/rhipe.r') if you want RHIPE\"" >> ~/.bash_profile

## Download the R packages and copy them into the folder
## Note, hat RHIPE was compiled by
## cloning RHIPE (As of commit: d3eed56735ece58a7a39e44cd48cfd3522212766)
## and compiling for hadoop-2 (not CDH etc)
## The R library tarball was built as: tar cvf Rlibraries_c34xlarge.tar /home/hadoop/R_libs
cd /home/hadoop/
aws s3 cp s3://mozilla-metrics/share/Rlibraries_c34xlarge.tar /home/hadoop/
tar xvf /home/hadoop/Rlibraries_c34xlarge.tar --strip-components=2



yum -y install inotify-tools
cd /hom/hadoop
wget https://raw.githubusercontent.com/saptarshiguha/mozaws/master/bootscriptsAndR/monitor.sh


