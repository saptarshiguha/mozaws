library(devtools)
library(rjson)
library(data.table)

tryCatch({
    library(infuser)
    if(!packageVersion("infuser")>="0.2") stop("Higher Version Required")
},error=function(e){
    install_github("Bart6114/infuser")
    library(infuser)
})


options(mzaws=list(
            init       = FALSE,
            awscli     = "aws",
            amiversion = "3.6.0",
            timeout    = "2880",
            loguri     = "s3://mozillametricsemrscripts/logs",
            numworkers = 3,
            numcreated = 0,
            localpubkey= NA,
            ec2key     = NA,
            customscript = NA,
            hadoopops  = c(
                c("-y","yarn.resourcemanager.scheduler.class=org.apache.hadoop.yarn.server.resourcemanager.scheduler.fair.FairScheduler"),
                c("-c","fs.s3n.multipart.uploads.enabled=true"),
                c("-c","fs.s3n.multipart.uploads.split.size=524288000"),
                c("-m","mapred.reduce.tasks.speculative.execution=false"),
                c("-m","mapred.map.tasks.speculative.execution=false"),
                c("-m","mapred.map.child.java.opts=-Xmx1024m"),
                c("-m","mapred.reduce.child.java.opts=-Xmx1024m"),
                c("-m","mapred.job.reuse.jvm.num.tasks=1")),
            inst.type  = c(worker="c3.xlarge",master="c3.xlarge"))
        )
        

aws.init <- function(ec2key=NULL,localpubkey=NULL,optsmore=NULL){
    opts <- options("mzaws")[[1]]
    if(is.null(ec2key)){
        opts$ec2key <- system("aws ec2 describe-key-pairs --output text --query 'KeyPairs[0].KeyName'",intern=TRUE)
        if(opts$ec2key =="None") stop("Could not find a key for the region")
        message(sprintf("Using first key found: %s",opts$ec2key))
    }
    if(!is.null(localpubkey)){
        if(file.exists(localpubkey)){ localpubkey <- readLines(localpubkey) }
        opts$localpubkey = localpubkey
    }
    if(!is.null(optsmore)) for(x in names(optsmore)) opts[[x]] <- optsmore[[x]]
    opts$init <- TRUE
    options(mzaws=opts);opts
}

checkIfStarted <- function(){
    if(options("mzaws")[[1]]$init) TRUE else stop("call aws.init first")
}

presult <- function(s){
    fromJSON(paste(s,collapse="\n"))
}


aws.clus.create <- function(name=NULL, workers=NULL,master=NULL,hadoopops=NULL,timeout=NULL,verbose=FALSE,emrfs=FALSE
                           ,customscript=options("mzaws")[[1]]$customscript,wait=FALSE){
    awsOpts <- options("mzaws")[[1]]
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
            name <- sprintf("%s cluster: %s", Sys.info()[["user"]], existingalready+1)
    }
    workers <- getWT(workers,"worker")
    master <- getWT(master,"master")
    hadoopargs <- paste(c(awsOpts$hadoopops,hadoopops),collapse=",")
    timeout <- if(is.null(timeout)) timeout else awsOpts$timeout
    if(emrfs) emrfs="--emrfs Consistent=true" else emrfs=""
    if(!is.na(customscript)){
        customscript <- sprintf("Type=CUSTOM_JAR,Name=CustomJAR,ActionOnFailure=CONTINUE,Jar=s3://elasticmapreduce/libs/script-runner/script-runner.jar,Args=['s3://mozillametricsemrscripts/run.user.script.sh','%s']", customscript)
    }else customscript=""
    args <- list(awscli = awsOpts$awscli, amiversion=awsOpts$amiversion,loguri=awsOpts$loguri
                ,name=name, ec2key=awsOpts$ec2key,mastertype=master[[2]], numworkers=workers[[1]]
                ,workertype=workers[[2]],hadoopargs=hadoopargs
                ,timeout=awsOpts$timeout, pubkey=awsOpts$localpubkey,emrfs=emrfs,customscript=customscript)
    template = "{{awscli}} emr create-cluster {{emrfs}} --visible-to-all-users  --ami-version '{{amiversion}}' --log-uri '{{loguri}}'  --name '{{name}}' --enable-debugging --ec2-attributes KeyName='{{ec2key}}' --instance-groups InstanceGroupType=MASTER,InstanceCount=1,InstanceType={{mastertype}}  InstanceGroupType=CORE,InstanceCount={{numworkers}},InstanceType={{workertype}}  --bootstrap-actions Path='s3://elasticmapreduce/bootstrap-actions/configure-hadoop',Args=[{{hadoopargs}}] Path='s3n://mozillametricsemrscripts/kickstartrhipe.sh',Args=['--public-key,{{pubkey}}','--timeout,{{timeout}}'] --steps Type=CUSTOM_JAR,Name=CustomJAR,ActionOnFailure=CONTINUE,Jar=s3://elasticmapreduce/libs/script-runner/script-runner.jar,Args=['s3://mozillametricsemrscripts/final.step.sh'] {{customscript}}"
    template <- infuse(template, args)
    if(verbose) cat(sprintf("%s\n",template))
    res <- presult(system(template, intern=TRUE))
    awsOpts$numcreated <- awsOpts$numcreated+1
    options(mzaws=awsOpts)
    k <- list(Id=res$ClusterId,Name=name)
    class(k) <- "awsCluster"
    if(wait){
        return(aws.clus.wait(k))
    }else{
        k
    }
}

as.awsCluster <- function(clusterid,name=NA){
    if(is.character(clusterid)) structure(list(Id=clusterid, Name=name),class="awsCluster")
    else structure(clusterid, class="awsCluster")
}

aws.kill <- function(clusters){
    awsOpts <- options("mzaws")[[1]]
    checkIfStarted()
    clusters <- if(is(clusters,"awsCluster")) list(s)
    clusterids <- unlist(lapply(clusters,function(s) s$Id))
    template <- infuse("{{awscli}} emr terminate-clusters --cluster-ids {{cid}}", awscli=awsOpts$awscli, cid=paste(clusterids, collapse=" "))
    system(template,intern=TRUE)
}

aws.clus.wait <- function(clusters,mon.sec=5,silent=FALSE){
    awsOpts <- options("mzaws")[[1]]
    checkIfStarted()
    if(!is(clusters,"awsCluster")) stop("cluster must be of class awsCluster")
    ac <- clusters
    acid <-  ac$Id
    while(TRUE){
        temp <- infuse("{{awscli}} emr describe-cluster --cluster-id {{id}} --output text --query 'Cluster.Status.State'"
                      ,awscli=awsOpts$awscli,id=acid)
        res <- system(temp, intern=TRUE)
        if(!(res %in% c("STARTING","BOOTSTRAPPING"))){ cat("\n"); break}
        if(!silent){cat(".")}
        Sys.sleep(mon.sec)
    }
    cat(sprintf("Cluster[id=%s, name='%s'] has finished starting(or failing :)\n",ac$Id, ac$Name))
    aws.clus.info(ac)
}

aws.clus.info <- function(cl){
    awsOpts <- options("mzaws")[[1]]
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
        sprintf("Number of Instance Groups: %s\n%s\n", length(grp),paste(unlist(lapply(grp,function(s){
                   if(s$Market=="SPOT"){
                       sprintf("\tID:%s, name: '%s' state:%s requested:%s (at $%s), running: %s", s$Id,s$Name,s$Status$State,
                               s$RequestedInstanceCount, s$BidPrice, s$RunningInstanceCount)
                   }else{
                       sprintf("\tID:%s, name: '%s' state:%s requested:%s, running: %s", s$Id,s$Name,s$Status$State,
                               s$RequestedInstanceCount, s$RunningInstanceCount)
                   }
               })),collapse="\n"))
    }else ""
    awsconsole=sprintf("https://us-west-2.console.aws.amazon.com/elasticmapreduce/home?region=us-west-2#cluster-details:%s",r$Id)
    temp <- infuse("Cluster ID: {{clid}}
This Information As of: {{dd}}
Name: '{{name}}'
State: {{state}}
Started At : {{started}}
Message: {{currently}}
IP: {{dns}}
SOCKS: ssh -ND 8157 hadoop@{{dns}} (and use FoxyProxy for Firefox or SwitchySharp for Chrome)
Rstudio: http://{{dns}}
Shiny: http://{{dns}}:3838
JobTrakcer: http://{{dns}}:9026 (needs a socks)
Master Type: {{master}} (and is running: {{isrunning}})
Core Nodes: {{nworker}} of  {{ workerstype }}
{{gtext}}

{{awsconsole}}
",list(clid=r$Id, dd=r$timeupdated,name=name, state=state, started=started, currently=currently, dns=dns, master=master['type'], isrunning=as.logical(master['running']), nworker=workers.core$'running', workerstype=workers.core$type,gtext=gtext,awsconsole=awsconsole))
    cat(temp)
}

aws.script.wait <- function(cl, s,verb=TRUE,mon.sec=5){
    awsOpts <- options("mzaws")[[1]]
    checkIfStarted()
    if(!is(cl,"awsCluster")) stop("cluster must be of class awsCluster")
    r <- presult(system(infuse("{{awscli}} emr describe-step --cluster-id {{ cid}} --step-id {{sid}}",awscli=awsOpts$awscli, cid=cl$Id, sid=s),intern=TRUE))
    while(TRUE){
        if(!is.null(r$Step$Status$Timeline$EndDateTime)){
            ss <- r$Step$Status$State
            if(ss=="FAILED") warning("the step failed")
            return(aws.clus.info(cl))
        }
        cat(".")
        if(verb) Sys.sleep(mon.sec)
    }
}

aws.script.run <- function(cl,script,wait=TRUE){
    awsOpts <- options("mzaws")[[1]]
    checkIfStarted()
    if(!is(cl,"awsCluster")) stop("cluster must be of class awsCluster")
    temp=infuse("{{awscli}} emr add-steps --cluster-id {{cid}} --steps Type=CUSTOM_JAR,Name=CustomJAR,ActionOnFailure=CONTINUE,Jar=s3://elasticmapreduce/libs/script-runner/script-runner.jar,Args=['s3://mozillametricsemrscripts/run.user.script.sh','{{scripturl}}']", cid=cl$Id,awscli=awsOpts$awscli, scripturl=script)
    x <- presult( system(temp,intern=TRUE))$StepIds
    cl <- aws.clus.info(cl)
    if(wait) aws.script.wait(cl,x) else cl
}


aws.spot.price <- function(type=as.character(options("mzaws")[[1]]$inst.type['worker']), hrsInPast=6){
    awsOpts <- options("mzaws")[[1]]
    checkIfStarted()
    since <- strftime(Sys.time()-hrsInPast*3600,"%Y-%m-%dT%H:%M:%S.000Z")
    temp <- presult(system(infuse("{{awscli}} ec2 describe-spot-price-history --product-description \"Linux/UNIX (Amazon VPC)\" --instance-types {{type}} --start-time {{start}}", awscli=awsOpts$awscli,type=type, start=since),intern=TRUE))
    f <- rbindlist(lapply(temp$SpotPriceHistory, as.data.table))
    f$Timestamp <- as.POSIXct(f$Timestamp,format="%Y-%m-%dT%H:%M:%S.000Z")
    f$SpotPrice <- as.numeric(f$SpotPrice)
    f[order(-Timestamp),]
}

aws.modify.groups <- function(cl,n,groupid=NULL, type=as.character(options("mzaws")[[1]]$inst.type['worker'])
                            , spotPrice = NULL,name=sprintf("Group: %s", strftime(Sys.time(),"%Y-%m-%d:%H:%M"))){
    awsOpts <- options("mzaws")[[1]]
    checkIfStarted()
    n <- max(n,0)
    if(!is.null(groupid)){
        temp=infuse("{{awscli}} emr modify-instance-groups  --instance-groups InstanceGroupId={{gid}},InstanceCount={{n}}", awscli=awsOpts$awscli, gid=groupid,n= as.integer(n))
        system(temp)
        return(aws.clus.info(cl))
    }
    if(is.character(spotPrice) && spotPrice=="ondemand"){
        name= sprintf("On Demand %s", name)
        spotq=""
    }else{
        if(is.null (spotPrice)){
            p <- quantile(aws.spot.price(type=type, hrsInPast=0.30)$SpotPrice,0.8)
            message(sprintf("Using a spot price of %s", p))
        }else p <- spotPrice
        p <- as.character(round(p,2))
        spotq <- sprintf("BidPrice=%s,", p)
        name= sprintf("Spot %s", name)
    }
    temp=infuse("{{awscli}} emr add-instance-groups --cluster-id  {{clid}} --instance-groups InstanceCount={{n}},{{spotq}}InstanceGroupType=task,InstanceType={{mtype}},Name='{{foo}}'", awscli=awsOpts$awscli,clid=cl$Id,n=as.integer(n),spotq=spotq, mtype=as.character(type),foo=name)
    l <- presult(system(temp,intern=TRUE))
    aws.clus.info(cl)
}


aws.list.groups <- function(cl){
    awsOpts <- options("mzaws")[[1]]
    checkIfStarted()
    if(!is(cl,"awsCluster")) stop("cluster must be of class awsCluster")
    Map(function(s) {
            s
        },Filter(function(s) s$InstanceGroupType=="TASK", cl$InstanceGroups))
}

