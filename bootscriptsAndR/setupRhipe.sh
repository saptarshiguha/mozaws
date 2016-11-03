
## Download Protobuf Packages (2.5) and install
wget http://cbs.centos.org/kojifiles/packages/protobuf/2.5.0/10.el7.centos/x86_64/protobuf-2.5.0-10.el7.centos.x86_64.rpm
wget http://cbs.centos.org/kojifiles/packages/protobuf/2.5.0/10.el7.centos/x86_64/protobuf-devel-2.5.0-10.el7.centos.x86_64.rpm
wget http://cbs.centos.org/kojifiles/packages/protobuf/2.5.0/10.el7.centos/x86_64/protobuf-compiler-2.5.0-10.el7.centos.x86_64.rpm
sudo yum -y install protobuf-2.5.0-10.el7.centos.x86_64.rpm protobuf-compiler-2.5.0-10.el7.centos.x86_64.rpm protobuf-devel-2.5.0-10.el7.centos.x86_64.rpm


## Set Hadoop Config VAriables that RHIPE requires
echo ""  >> /home/hadoop/.bash_profile
echo "export HADOOP_LIBS=/usr/lib/hadoop/client:/usr/lib/hadoop/lib:/usr/lib/hadoop:/usr/lib/hadoop-hdfs/:/usr/lib/hadoop-yarn/:/usr/lib/hadoop-mapreduce/:/usr/share/aws/emr/emrfs/conf:/usr/share/aws/emr/emrfs/lib/:/usr/share/aws/emr/emrfs/auxlib/" >> /home/hadoop/.bash_profile
echo "export HADOOP_CONF_DIR=/etc/hadoop/conf" >> /home/hadoop/.bash_profile


aws s3 s3://mozilla-metrics/user/sguha/tmp/R.tar.gz /tmp/
hadoop dfs -put  /tmp/R.tar.gz /

cat << EOF > /home/hadoop/rhipe.r
library(Rhipe)
rhinit()
RDIST <- "R" 
m <- rhoptions()$mropts
m$mapred.reduce.tasks = 50
m$R_ENABLE_JIT        = 2
m$R_HOME              = sprintf("%s/R",RDIST)
m$R_HOME_DIR          = sprintf("./%s/R",RDIST)
m$R_SHARE_DIR         = sprintf("./%s/R/share",RDIST)
m$R_INCLUDE_DIR       = sprintf("./%s/R/include",RDIST)
m$R_DOC_DIR           = sprintf("./%s/R/doc",RDIST)
m$PATH                = sprintf("./%s/R/bin:./%s/:$PATH",RDIST,RDIST)
m$LD_LIBRARY_PATH     = sprintf("./%s/:./%s/R/lib:/usr/lib64",RDIST,RDIST)
rhoptions(HADOOP.TMP.FOLDER = sprintf("/tmp/"))
rhoptions(runner            = sprintf("./%s/RhipeMapReduce --silent --vanilla",RDIST),
          zips              = c(sprintf("/%s.tar.gz",RDIST)),
          HADOOP.TMP.FOLDER = sprintf("/tmp/"),
          mropts            = m,
          job.status.overprint =TRUE,
          write.job.info    =TRUE)

EOF

echo "echo \"Remember to call source('~/rhipe.r') if you want RHIPE\"" >> ~/.bash_profile

## Download the R packages and copy them into the folder
## Note, hat RHIPE was compiled by
## cloning RHIPE (As of commit: d3eed56735ece58a7a39e44cd48cfd3522212766)
## and compiling for hadoop-2 (not CDH etc)
## The R library tarball was built as: tar cvf Rlibraries_c34xlarge.tar /home/hadoop/R_libs
## cd /home/hadoop/
## aws s3 cp s3://mozilla-metrics/user/sguha/tmp/Rlibraries_c34xlarge.tar /home/hadoop/
## tar xvf /home/hadoop/Rlibraries_c34xlarge.tar





