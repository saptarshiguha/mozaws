##' Takes seconds and converts to human readable format
##' @param secs is the number of seconds
##' @return a string
##' @export
secondsToString <- function(secs,rnd=2){
  Round <- function(a,b){
    format(round(a,b),nsmall=2)
  }
  if(secs<60) sprintf("%s seconds",Round(secs,rnd))
  else if(secs<60*60) sprintf("%s minutes",Round(secs/60,rnd))
  else if(secs< 86400) sprintf("%s hours", Round(secs/(60*60),rnd))
  else if(secs< (86400*30)) sprintf("%s days",Round(secs/(86400),rnd))
  else if(secs< (86400*365)) sprintf("%s months",Round(secs/(86400*30),rnd))
  else  sprintf("%s years",Round(secs/(86400*365),rnd))
}
        
#' Initialize the AWS System
#' @param ec2key this is your EC2 key that you created in the EC2 AWS Console
#' @param localpubkey this is for example the contents of
#' ~/.ssh/id_dsa.pub and if provided makes ssh'ing into the cluster
#' easier
#' @param optsmore more options that override the options
#' @details \code{optsmore} can be used to override the values in
#' aws.options(). If you don't provide the EC2 key, this
#' package will find the first available key
#' @examples
#' \dontrun{
#' aws.init(localpub="~/.ssh/id_dsa.pub")
#' aws.init(localpub="~/.ssh/id_dsa.pub",optsmore=list(customscript='https://raw.githubusercontent.com/saptarshiguha/mozaws/master/bootscriptsAndR/sample.sh'))
#' }
#' @export
aws.init <- function(ec2key=NULL,localpubkey=NULL,optsmore=NULL){
    opts <- aws.options()
    if(is.null(ec2key)){
        aaws <- if(is.null(optsmore$aws)) "aws" else optsmore$aws
        ec2key <- presult(system(sprintf("%s ec2 describe-key-pairs",aaws)
                                     ,intern=TRUE))
        kp <- ec2key$KeyPairs
        if(is.null(kp) || length(kp)==0) stop("No Key Pairs Present")
        opts$ec2key <- kp[[1]]$KeyName
        if(opts$ec2key =="None") stop("Could not find a key for the region")
        message(sprintf("Using first key found: %s",opts$ec2key))
    }else {
        opts$ec2key <- ec2key
        message(sprintf("Using provided key: %s", opts$ec2key))
    }
    if(!is.null(localpubkey)){
        if(file.exists(localpubkey)){ localpubkey <- readLines(localpubkey) }
        opts$localpubkey = localpubkey
    }
    if(!is.null(optsmore)) for(x in names(optsmore)) opts[[x]] <- optsmore[[x]]
    opts$init <- TRUE
    invisible(options(mzaws=opts))
}

checkIfStarted <- function(){
    if(aws.options()$init) TRUE else stop("call aws.init first")
}

presult <- function(s){
    fromJSON(paste(s,collapse="\n"))
}

#' Create a cluster
#' @param name is the name of the cluster, if not provided one will be created for you
#' @param workers defines the workers, see details
#' @param master defines master , see details
#' @param hadoopops options that overide 'hadoopops' from aws.options()
#' @param timeout over timeout from the options (minutes)
#' @param verbose be catty?
#' @param emrfs turns on emrfs and consistency
#' @param customscript override options
#' @param wait TRUE or FALSE for waiting. If FALSE, the function returns immediately or waits
#' @param spark if TRUE will start a spark interactive cluster. If a spark cluster is used, you cannot write interactive hadoop jobs.
#' @param noR do not install a zillion R packages (if you're using spark-python, you might want to set this to TRUE and save time)
#' @details The arguments \code{hadoopops, timeout, customscript} can
#' also be set in options. If \code{wait} is FALSE, the function will
#' return immediately and can be monitored using
#' \code{aws.clus.wait}. If \code{workers} is a number, then the type
#' is taken from aws.options(). If a string, this corresponds
#' to the instance type and the number is taken from
#' aws.options()$numworkers. If a list, it needs to of the
#' form \code{list(number, type)}. For \code{master}, it is enough to
#' leave as NULL (and will be inferred from options) or you pass a
#' type. The \code{timeout} is a set number of hours after which the
#' cluster is killed. You'll thank me later.
#' @examples
#' \dontrun{
#' s <- aws.clus.create(workers=1,wait=TRUE,customscript='https://raw.githubusercontent.com/saptarshiguha/mozaws/master/bootscriptsAndR/sample.sh')
#' s <- aws.clus.create(workers=1)
#' s <- aws.clus.wait(s) 
#' }
#' @export
aws.clus.create <- function(name=NULL, workers=NULL,master=NULL,hadoopops=NULL,timeout=NULL,verbose=FALSE,emrfs=FALSE
                           ,customscript=NULL,wait=FALSE,spark=FALSE,noR=FALSE){
    awsOpts <- aws.options()
    checkIfStarted()
    getWT <- function(s,k){
        if(is.null(s)) return(list(if(k=="master") 1 else awsOpts$numworkers, awsOpts$inst.type[[ k ]]))
        if(is.character(s)) return(list(if(k=="master") 1 else awsOpts$numworkers, s))
        if(is.numeric(s) && length(s)==1) return(list(s, awsOpts$inst.type[[ k ]]))
        if(is.list(s)) return(s)
    }
    if(is.null(name)){
        existingalready <- awsOpts$numcreated
            existingalready <- existingalready+1
            name <- sprintf("%s cluster: %s", awsOpts$user, existingalready+1)
    }
    if(is.null(customscript)) customscript <- aws.options()$customscript
    workers <- getWT(workers,"worker")
    master <- getWT(master,"master")
    hadoopargs <- paste(c(awsOpts$hadoopops,hadoopops),collapse=",")
    timeout <- if(is.null(timeout)) timeout else awsOpts$timeout
    if(emrfs) emrfs="--emrfs Consistent=true" else emrfs=""
    if(noR) norscript="" else norscript="Type=CUSTOM_JAR,Name=CustomJAR,ActionOnFailure=CONTINUE,Jar=s3://elasticmapreduce/libs/script-runner/script-runner.jar,Args=['s3://{{s3buk}}/r.step.sh']"
    if(!is.na(customscript)){
        customscript <- sprintf("Type=CUSTOM_JAR,Name=CustomJAR,ActionOnFailure=CONTINUE,Jar=s3://elasticmapreduce/libs/script-runner/script-runner.jar,Args=['s3://{{s3buk}}/run.user.script.sh','%s']"
                              , customscript)
    }else customscript=""
    sparkb=if(spark) {
        "Path='s3://support.elasticmapreduce/spark/install-spark','Install Spark',Args=['-v,1.2.1.a'] Path='s3://telemetry-spark-emr/telemetry.sh','SetupSpark'"
    } else ""
    args <- list(awscli = awsOpts$awscli, amiversion=awsOpts$amiversion,loguri=awsOpts$loguri
                ,name=name, ec2key=awsOpts$ec2key,mastertype=master[[2]], numworkers=workers[[1]],spark=sparkb,norscript=norscript
                ,workertype=workers[[2]],hadoopargs=hadoopargs, uusser=isn(awsOpts$user,isn(Sys.getenv("USERNAME"),"MysteriousI"))
                ,timeout=awsOpts$timeout, pubkey=awsOpts$localpubkey,emrfs=emrfs,customscript=customscript,s3buk=awsOpts$s3bucket)
    template = "{{awscli}} emr create-cluster {{emrfs}} --tags user='{{uusser}}' crtr=rmozaws-1 --visible-to-all-users  --ami-version '{{amiversion}}' --log-uri '{{loguri}}'  --name '{{name}}' --enable-debugging --ec2-attributes KeyName='{{ec2key}}' --instance-groups InstanceGroupType=MASTER,InstanceCount=1,InstanceType={{mastertype}}  InstanceGroupType=CORE,InstanceCount={{numworkers}},InstanceType={{workertype}}  --bootstrap-actions Path='s3://elasticmapreduce/bootstrap-actions/configure-hadoop',Args=[{{hadoopargs}}] Path='s3n://{{s3buk}}/kickstartrhipe.sh',Args=['--public-key,{{pubkey}}','--timeout,{{timeout}}'] {{spark}} --steps Type=CUSTOM_JAR,Name=CustomJAR,ActionOnFailure=CONTINUE,Jar=s3://elasticmapreduce/libs/script-runner/script-runner.jar,Args=['s3://{{s3buk}}/final.step.sh'] {{norscript}} {{customscript}}"
    template <- infuse(template, args)
    if(verbose) cat(sprintf("%s\n",template))
    res <- presult(system(template, intern=TRUE))
    awsOpts$numcreated <- awsOpts$numcreated+1
    options(mzaws=awsOpts)
    k <- list(Id=res$ClusterId,Name=name)
    class(k) <- "awsCluster"
    if(wait){
        res <- (aws.clus.wait(k))
        ## States: http://docs.aws.amazon.com/ElasticMapReduce/latest/DeveloperGuide/ProcessingCycle.html
        if(!(isn(res$Status$State,"") %in% c("RUNNING","WAITING"))){
            print(res)
            stop(sprintf("Cluster: %s Might Not have Started", res$Id))
        }
        res
    }else{
        k
    }
}

#' Converts a cluster-id string into a cluster object
#' @param clusterid is the id string
#' @param name some name you want to give
#' @export
as.awsCluster <- function(clusterid,name=NA){
    if(is.character(clusterid)) structure(list(Id=clusterid, Name=name),class="awsCluster")
    else structure(clusterid, class="awsCluster")
}
#' Kills/Terminates the cluster
#' @param cluster object (from \code{aws.clus.create}, \code{aws.clus.info})
#' @export
aws.kill <- function(clusters){
    awsOpts <- aws.options()
    checkIfStarted()
    clusters <- if(is(clusters,"awsCluster")) list(s)
    clusterids <- unlist(lapply(clusters,function(s) s$Id))
    template <- infuse("{{awscli}} emr terminate-clusters --cluster-ids {{cid}}", awscli=awsOpts$awscli, cid=paste(clusterids, collapse=" "))
    system(template,intern=TRUE)
}

#' Waits for the cluster to start
#' @param clusters is an object obtained from \code{aws.clus.create}
#' @param mon.sec polling interval
#' @param silent chatty?
#' @return the cluster object. Save it.
#' @examples
#' \dontrun{
#'   s = aws.clus.wait(s)
#' }
#' @export
aws.clus.wait <- function(clusters,mon.sec=5,silent=FALSE){
    awsOpts <- aws.options()
    checkIfStarted()
    if(!is(clusters,"awsCluster")) stop("cluster must be of class awsCluster")
    ac <- clusters
    acid <-  ac$Id
    while(TRUE){
        temp <- infuse("{{awscli}} emr describe-cluster --cluster-id {{id}} --output text --query 'Cluster.Status.State'"
                      ,awscli=awsOpts$awscli,id=acid)
        res <- system(temp, intern=TRUE)
        if(!(res %in% c("STARTING","BOOTSTRAPPING","RUNNING"))){ cat("\n"); break}
        if(!silent){cat(".")}
        Sys.sleep(mon.sec)
    }
    cat(sprintf("Cluster[id=%s, name='%s'] has started\n",ac$Id, ac$Name))
    aws.clus.info(ac)
}

#' Describes the cluster
#' @param cl is what is returned from \code{aws.clus.create} or \code{aws.clus.wait}
#' @return an object of awsCluster. Very detailed object. Save it.
#' @export
aws.clus.info <- function(cl){
    awsOpts <- aws.options()
    checkIfStarted()
    if(!is(cl,"awsCluster")) stop("cluster must be of class awsCluster")
    acid <-  cl$Id
    r <- presult(system(infuse("{{awscli}} emr describe-cluster --cluster-id {{id}}",awscli=awsOpts$awscli,id=acid),intern=TRUE))
    r <- r$Cluster
    r$timeupdated <- Sys.time()
    r1 <- presult(system(infuse("{{awscli}} emr list-steps --cluster-id {{id}}",awscli=awsOpts$awscli,id=acid),intern=TRUE))$Steps
    r$steps <- r1
    class(r) <- "awsCluster"
    r
}

isn <- function(s,j=NA) if(is.null(s) || length(s)==0) j else s

#' @export
print.awsCluster <- function(r){
    state <- isn(r$Status$State,NA)
    name <- isn(r$Name)
    started <- as.POSIXct(isn(r$Status$Timeline$CreationDateTime),origin="1970-01-01")
    currently <- isn(r$Status$StateChangeReason$Message)
    dns <- isn(r$MasterPublicDnsName)
    master <- unlist(lapply(r$InstanceGroups,function(s){
                         if(s$Name=="MASTER"){
                             data.table(type=s$InstanceType,running=s$RunningInstanceCount>0)
                         }
                     }))
    workers.core <- do.call(rbind,lapply(r$InstanceGroups,function(s){
                         if(s$Name=="CORE" && s$Market=="ON_DEMAND"){
                             data.table(type=s$InstanceType,running=s$RunningInstanceCount)
                         }
                     }))
    grp <- aws.list.groups(r)
    gtext <- if(length(grp)>0){
        sprintf("Number of Instance Groups: %s\n%s", length(grp),paste(unlist(lapply(grp,function(s){
                   if(s$Market=="SPOT" && s$RequestedInstanceCount>0){
                       sprintf("\tID:%s, name: '%s' state:%s requested:%s (at $%s), running: %s", s$Id,s$Name,s$Status$State,
                               s$RequestedInstanceCount, s$BidPrice, s$RunningInstanceCount)
                   }else if(s$RequestedInstanceCount>0){
                       sprintf("\tID:%s, name: '%s' state:%s requested:%s, running: %s", s$Id,s$Name,s$Status$State,
                               s$RequestedInstanceCount, s$RunningInstanceCount)
                   }
               })),collapse="\n"))
    }else ""
    awsconsole=sprintf("https://us-west-2.console.aws.amazon.com/elasticmapreduce/home?region=us-west-2#cluster-details:%s",r$Id)
    temp <- infuse("Cluster ID: {{clid}}
This Information as of: {{dd}} ago
Name        : '{{name}}'
State       : {{state}}
Started At  : {{started}}
Message     : {{currently}}
IP          : {{dns}}
SSH         : ssh hadoop@{{dns}} (assuming you aws.init(localpub=your-pub-key) else ssh -i path-to-aws-pem-file hadoop@{{dns}}
SOCKS       : ssh -ND 8157 hadoop@{{dns}} (and use FoxyProxy for Firefox or SwitchySharp for Chrome)
Rstudio     : http://{{dns}} (user/pass is metrics/metrics)
Shiny       : http://{{dns}}:3838
JobTracker  : http://{{dns}}:9026 (needs a socks)
Spark UI    : http://{{dns}}: ( if spark == TRUE )
Master Type : {{master}} (and is running: {{isrunning}})
Core Nodes  : {{nworker}} of  {{ workerstype }}
{{gtext}}

{{awsconsole}}
"
,list(clid  =r$Id, dd=secondsToString(as.numeric(Sys.time() - r$timeupdated,"secs"),2),name=name
, state     =state, started=started, currently=currently
, dns       =dns, master=master['type'],isrunning=as.logical(master['running'])
, nworker   =workers.core$'running', workerstype=workers.core$type,gtext=gtext
,awsconsole =awsconsole))
    cat(temp)
}

#' Waits for a script to run
#' @param cl is the cluster object returned from \code{aws.clus.create} and friends
#' @param s is the script id, which you will find in \code{aws.clus.info()$steps} (most recent first)
#' @param verb be chatty?
#' @details This function will return once the step has finished
#' @export
aws.step.wait <- function(cl, s,verb=TRUE,mon.sec=5){
    awsOpts <- aws.options()
    checkIfStarted()
    if(!is(cl,"awsCluster")) stop("cluster must be of class awsCluster")
    r <- presult(system(infuse("{{awscli}} emr describe-step --cluster-id {{ cid}} --step-id {{sid}}",awscli=awsOpts$awscli, cid=cl$Id, sid=s),intern=TRUE))
    while(TRUE){
        if(!is.null(r$Step$Status$Timeline$EndDateTime)){
            ss <- r$Step$Status$State
            if(ss=="FAILED") warning("the step failed")
            break
        }
        cat(".")
        if(verb) Sys.sleep(mon.sec)
    }
    return(aws.clus.info(cl))
}

#' Run a step
#' @param cl is a cluster object returned by \code{aws.clus.create} and friends
#' @param script is a URL (not a file name!, something like http://) to download and run. E.g. an Rscript file
#' @param wait is TRUE, will wait for result else a return a list with cluster object and the step id
#' @export
aws.step.run <- function(cl,script,name=NULL,wait=TRUE){
    awsOpts <- aws.options()
    checkIfStarted()
    if(!is(cl,"awsCluster")) stop("cluster must be of class awsCluster")
    temp=infuse("{{awscli}} emr add-steps --cluster-id {{cid}} --steps Type=CUSTOM_JAR,Name='{{myname}}',ActionOnFailure=CONTINUE,Jar=s3://elasticmapreduce/libs/script-runner/script-runner.jar,Args=['s3://{{s3buk}}/run.user.script.sh','{{scripturl}}']", cid=cl$Id,awscli=awsOpts$awscli, scripturl=script,s3buk=awsOpts$s3bucket,myname=if(!is.null(name)) name else "CustomStep")
    x <- presult( system(temp,intern=TRUE))$StepIds
    cl <- aws.clus.info(cl)
    if(wait) aws.step.wait(cl,x) else list(cl, x)
}

#' Get Spot Prices
#' @param type the type of the worker
#' @param hrsInPast prices since when as of now
#' @return a data table with prices
#' @export
aws.spot.price <- function(type=as.character(aws.options()$inst.type['worker']), hrsInPast=6){
    awsOpts <- aws.options()
    checkIfStarted()
    since <- strftime(Sys.time()-hrsInPast*3600,"%Y-%m-%dT%H:%M:%S.000Z")
    temp <- presult(system(infuse("{{awscli}} ec2 describe-spot-price-history --product-description \"Linux/UNIX (Amazon VPC)\" --instance-types {{type}} --start-time {{start}}"
         , awscli=awsOpts$awscli,type=type, start=since),intern=TRUE))
    f <- rbindlist(lapply(temp$SpotPriceHistory, as.data.table))
    f$Timestamp <- as.POSIXct(f$Timestamp,format="%Y-%m-%dT%H:%M:%S.000Z")
    f$SpotPrice <- as.numeric(f$SpotPrice)
    f[order(-Timestamp),]
}

#' Add new nodes to a cluster
#' @param cl is the cluster object. How many times must i repeat myself?
#' @param n number of nodes to add
#' @param groupid use this if you need to modify (resize) and exisiting group. These ids can be found via \code{aws.list.groups}
#' @param type Instance type for the worker
#' @param spotPrice is the price in dollars (numeric) you're willing
#' to pay. It will choose a default if not given. If \code{spotPrice}
#' is "ondemand", then OnDemand instances will be started at the OnDemand price
#' @details This returns the info from \code{aws.clus.info}. If you'd
#' like to delete this group, call the function with the
#' \code{groupid} and \code{n} set to 0.
#' @export
aws.modify.groups <- function(cl,n,groupid=NULL, type=as.character(aws.options()$inst.type['worker'])
                            , spotPrice = NULL,name=NULL){
    awsOpts <- aws.options()
    checkIfStarted()
    n <- max(n,0)
    if(!is.null(groupid)){
        temp=infuse("{{awscli}} emr modify-instance-groups  --instance-groups InstanceGroupId={{gid}},InstanceCount={{n}}", awscli=awsOpts$awscli, gid=groupid,n= as.integer(n))
        system(temp)
        return(aws.clus.info(cl))
    }
    if(is.character(spotPrice) && spotPrice=="ondemand"){
        name= if(is.null(name)) sprintf("On Demand %s", sprintf("Group: %s", strftime(Sys.time(),"%Y-%m-%d:%H:%M"))) else name
        spotq=""
    }else{
        if(is.null (spotPrice)){
            p <- quantile(aws.spot.price(type=type, hrsInPast=0.30)$SpotPrice,0.8)
            message(sprintf("Using a spot price of %s", p))
        }else p <- spotPrice
        p <- as.character(round(p,3))
        spotq <- sprintf("BidPrice=%s,", p)
        name= if(is.null(name)) sprintf("Spot %s", name) else name
    }
    temp=infuse("{{awscli}} emr add-instance-groups --cluster-id  {{clid}} --instance-groups InstanceCount={{n}},{{spotq}}InstanceGroupType=task,InstanceType={{mtype}},Name='{{foo}}'"
             , awscli=awsOpts$awscli,clid=cl$Id,n=as.integer(n),spotq=spotq, mtype=as.character(type),foo=name)
    l <- presult(system(temp,intern=TRUE))
    aws.clus.info(cl)
}

#' List the Instance group nodes (Task and Spot nodes)
#' @param cl is the once again the object from \code{aws.clus.create}
#' @export
aws.list.groups <- function(cl,reqGt0=TRUE){
    awsOpts <- aws.options()
    checkIfStarted()
    if(!is(cl,"awsCluster")) stop("cluster must be of class awsCluster")
    Map(function(s) {
        s 
        },Filter(function(s) s$InstanceGroupType=="TASK" & s$RequestedInstanceCount>0, cl$InstanceGroups))
}

#' Returns AWS options
#' @export
aws.options <- function() options("mzaws")[[1]]
