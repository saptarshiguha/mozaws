# Introduction #

With this package the user can create AWS clusters. Control the world. No. It
depends on the following tools

- rjson
- data.tables
- devtools
- infuser
- AWS command line tools

# Starting  #
You will need a working AWS CLI tools. Check that it works by e.g.

    aws s3 mb somebucketname

Also you will need an EC2 Key which can be created in the EC2 console. Download
and save the PEM files, you will need to them to SSH into the cluster (worst
case).

It also recommended you have public keys which will be copied to the cluster so
that you can log into it easily (without using the PEM file above).

## Initialize the Package

    aws.init(localpubkey="~/.ssh/id_dsa.pub")

If ``ec2key`` is left empty, the function will use the first EC2 key it can find
(by querying the AWS console).

You can set many options through this function. For example, to set the default
number of workers and to run a file across all the nodes at cluster startup time,

    aws.init(localpubkey="~/.ssh/id_dsa.pub",opts=list(numworkers=5,
    customscript='https://raw.githubusercontent.com/saptarshiguha/mozaws/master/bootscriptsAndR/sample.sh'))

    aws.init(localpubkey="~/.ssh/id_dsa.pub",opts=list(numworkers=5,inst.type  = c(worker="c3.xlarge",master="c3.xlarge")))


View the options using the function ``aws.options()``.

## Before Starting
Before you start the cluster, notice the value of

    aws.options()[c("s3bucket","loguri")]
    $s3bucket
    [1] "mozillametricsemrscripts"
     
    $loguri
    [1] "s3://mozillametricsemrscripts/logs"

The value _mozillametricsemrscripts_ will need to be changed to S3 bucket you
have read/write permissions to. Once done, change these values in the
options. And you need to copy all the files in ``bootscriptsAndR`` to
this S3 bucket.

## Start a Cluster
Simple enough. This will create a cluster with the default number of workers and
default instance types 

    cl <- aws.clus.create(wait=TRUE)

By default, ``wait`` is ``FALSE``. To wait for the end of cluster startup, do

    cl <- aws.clus.wait(cl)

Different number of workers, and worker types?

    cl <- aws.clus.create(workers=list(1,"c3.2xlarge"),master="c3.2xlarge")
    cl <- aws.clus.create(workers=3)

Run a R script (or any shell script) after cluster startup (and kill the cluster
after one day)

    cl <- aws.clus(workers=1, timeout=1440,customscript="https://raw.githubusercontent.com/saptarshiguha/mozaws/master/bootscriptsAndR/sample2.sh")

## Describe the Cluster
Once you've done the above, calling ``aws.clus.info`` will return detailed
information. It has a customized print statement, but calling
``unclass(aws.clus.info(clobject))`` will return a very detailed list.

    Cluster ID: j-24XY7LVL8TZL9
    This Information As of: 2015-05-31 14:25:54
    Name: 'sguha cluster: 2'
    State: RUNNING
    Started At : 2015-05-31 14:09:51
    Message: Running step
    IP: ec2-52-26-3-44.us-west-2.compute.amazonaws.com
    SOCKS: ssh -ND 8157 hadoop@ec2-52-26-3-44.us-west-2.compute.amazonaws.com (and use FoxyProxy for Firefox or SwitchySharp for Chrome)
    Rstudio: http://ec2-52-26-3-44.us-west-2.compute.amazonaws.com
    Shiny: http://ec2-52-26-3-44.us-west-2.compute.amazonaws.com:3838
    JobTrakcer: http://ec2-52-26-3-44.us-west-2.compute.amazonaws.com:9026 (needs a socks)
    Master Type: c3.2xlarge (and is running: TRUE)
    Core Nodes: 1 of  c3.2xlarge
     
     
    https://us-west-2.console.aws.amazon.com/elasticmapreduce/home?region=us-west-2#cluster-details:j-24XY7LVL8TZL9    

## Growing the Cluster

We can add on-demand nodes and spot nodes.

    cl <- aws.modify.groups(cl, n=1, spot="ondemand",name="DMD1")
    cl <- aws.modify.groups(cl, n=1,name="Spot1") ## will automatically choose a spot price for the default worker type
    'Using a spot price of 0.0765'

    cl
    Cluster ID: j-24XY7LVL8TZL9
    This Information As of: 2015-05-31 14:41:56
    Name: 'sguha cluster: 2'
    State: WAITING
    Started At : 2015-05-31 14:09:51
    Message: Waiting after step failed
    IP: ec2-52-26-3-44.us-west-2.compute.amazonaws.com
    SOCKS: ssh -ND 8157 hadoop@ec2-52-26-3-44.us-west-2.compute.amazonaws.com (and use FoxyProxy for Firefox or SwitchySharp for Chrome)
    Rstudio: http://ec2-52-26-3-44.us-west-2.compute.amazonaws.com
    Shiny: http://ec2-52-26-3-44.us-west-2.compute.amazonaws.com:3838
    JobTrakcer: http://ec2-52-26-3-44.us-west-2.compute.amazonaws.com:9026 (needs a socks)
    Master Type: c3.2xlarge (and is running: TRUE)
    Core Nodes: 1 of  c3.2xlarge
    Number of Instance Groups: 2
        ID:ig-W84RQA8PLUR9, name: 'Spot1' state:PROVISIONING requested:1 (at $0.076), running: 0
        ID:ig-2UQ1SUVODUBJX, name: 'DMD1' state:RESIZING requested:1, running: 0
     
    https://us-west-2.console.aws.amazon.com/elasticmapreduce/home?region=us-west-2#cluster-details:j-24XY7LVL8TZL9
    

We can delete that costly On-Demand group ($0.420/hr) and add one more spot node.

    grps <- aws.list.groups(cl)
    idtodel <- Filter(function(s) s$Name=="DMD1", grps)[[1]]$Id
    cl <- aws.modify.groups(cl, n=0, groupid=idtodel)
    cl <- aws.modify.groups(cl, n=2, groupid=Filter(function(s) s$Name=="Spot1", grps)[[1]]$Id)
    cl
    Cluster ID: j-24XY7LVL8TZL9
    This Information As of: 2015-05-31 15:03:20
    Name: 'sguha cluster: 2'
    State: WAITING
    Started At : 2015-05-31 14:09:51
    Message: Waiting after step failed
    IP: ec2-52-26-3-44.us-west-2.compute.amazonaws.com
    SOCKS: ssh -ND 8157 hadoop@ec2-52-26-3-44.us-west-2.compute.amazonaws.com (and use FoxyProxy for Firefox or SwitchySharp for Chrome)
    Rstudio: http://ec2-52-26-3-44.us-west-2.compute.amazonaws.com
    Shiny: http://ec2-52-26-3-44.us-west-2.compute.amazonaws.com:3838
    JobTrakcer: http://ec2-52-26-3-44.us-west-2.compute.amazonaws.com:9026 (needs a socks)
    Master Type: c3.2xlarge (and is running: TRUE)
    Core Nodes: 1 of  c3.2xlarge
    Number of Instance Groups: 1
        ID:ig-CQB9ZB9PNQPH, name: 'Spot1' state:RESIZING requested:2 (at $0.076), running: 0

    https://us-west-2.console.aws.amazon.com/elasticmapreduce/home?region=us-west-2#cluster-details:j-24XY7LVL8TZL9

You can quote your own spot price based on spot price history. To retrieve this
history, type

    aws.spot.price(type="c3.2xlarge", hrsInPast=1)

which will return spot prices for the last 1 hr for ``c3.2xlarge`` instance
types. By default, the instance type is the one in
``aws.options()$inst.type['worker']``

## Running Scripts (e.g. adding R packages) Across All the Nodes

Once the cluster has started, you can submit 'scripts' to be run on all the
nodes. For example you might want to install and R package. You also might want
to submit a long running job and terminate the cluster after job completion. An
example of one such script can be found at
[https://github.com/saptarshiguha/mozaws/blob/master/bootscriptsAndR/sample2.sh](https://github.com/saptarshiguha/mozaws/blob/master/bootscriptsAndR/sample2.sh)
. To launch a script(which are also called _steps_ in AWS land), type

    cl <- aws.step.run(cl,
    "https://github.com/saptarshiguha/mozaws/blob/master/bootscriptsAndR/sample2.sh",
    ,name="Install R Package",wait=TRUE)

details of steps(success/failure etc) can be found in ``cl$steps``. The above
command will return immediately when ``wait=FALSE`` is used. You can monitor the
state of the step/script by polling the value of ``cl$steps`` and extracting the
step id (most recent first) 

## Running Scripts on Just the Master Node
You would want packages to be installed on all the nodes
### 1. SCP and run file remotely

### 2. Using Scripts and Monitoring for Script to End

    
