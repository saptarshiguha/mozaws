library(httr)
library(infuser)
isn <- function(s,r=NA) if(length(s)==0 || is.null(s)) r else s

## Find a list of running spark applications Every invocationof
## ipython creates a new application.

#options(mozremote = (ssh <- sprintf("ssh hadoop@%s",cl$MasterPublicDnsName)))
## if running in remote server, replace ssh = 'sh -c'
getAppId <- function(remotenode,port){
        x <- scApplicationList(remotenode,port)
        x[!x$done,][,id[1]]
}
        
##' Get all applications that talk to spark 
##' @param remotenode a string that is used to talk to the spark server like a ssh command string. See details
##' @param port default is 4040 (current running application) or the history server 18080
##' @param verbose default is FALSE, when TRUE prints out the main curl command
##' @details Typically the remotenode command is a ssh command which will run a curl query on the remote. See examples.
##' If \code{remotenode} is missing, it will be taken from the last value in  \code{options('mozremote')}.
##' See \href{http://spark.apache.org/docs/latest/monitoring.html} for more details
##' @examples
#' \dontrun{
#' cl <- aws.clus.create(workers=2,spark=TRUE,ver=TRUE)
#' scApplicationList(remote=sprintf("ssh hadoop ATSIGN %s",cl$MasterPublicDnsName))
#' scApplicationList() ## takes remote from options("mozremote") which gets populated by aws.clus.create
#' scApplicationList(remotenode="sh -c") ## If you wish to run this on the remote AWS console, then call
#' }
##' @export
scApplicationList <- function(remotenode,port=4040,verbose=FALSE){
    ## 18080 for history
    if(missing(remotenode)) remotenode <- tail(options("mozremote")[[1]],1)[[1]]$ssh
    x<-infuse("{{SSH}} 'curl -L -H \"Accept: application/json\" http://localhost:{{port}}/api/v1/applications 2>/dev/null' 2>/dev/null",port=port,SSH=remotenode)
    if(verbose) print(x)
    l <- paste(system(x, intern=TRUE),collapse="\n")
    if(l=="") stop("No data? Try using port 18080. It might be that you do not have a notebook/ipython session running. Start one and then the port 4040 might work")
    tryCatch(a <- fromJSON(l),error=function(e){
        cat(sprintf("mozaws: There was an error running the command to get applications. Command is \n%s\nOutput is\n", x,l))
        e
    })
    y <- rbindlist(Map(function(x){
        data.table(id=x$id,name=x$name,
                   started=as.POSIXct(as.POSIXct(x$attempts[[1]]$startTime
                                     ,format="%Y-%m-%dT%H:%M:%S",tz="GMT"
                                     ,origin="1970-01-01"),tz=Sys.timezone())
                  ,done=x$attempts[[1]]$completed)
    },a))
    if(sum(!y$done)>1) warning("You have multiple spark-python applications that are still running, this might lead to problems ...")
    y
}

##' Get a list of all jobs that were run on the application
##' @param appid is an application id taken from \code{scApplicationList}. It can be missing anf if is so, it will be taken from the first currently running application
##' @param remotenode see \code{scApplicationList}.
##' @param port is 4040
##' @param verbose set to TRUE for actual command run
##' @export
scJobsForApplication <- function(appid,remotenode,port=4040,verbose=FALSE){
    if(missing(remotenode)) remotenode <- tail(options("mozremote")[[1]],1)[[1]]$ssh
    if(missing(appid)) appid <- getAppId(remotenode,port)
    l <- paste(system(x <- infuse("{{SSH}} 'curl -L  -H \"Accept: application/json\" http://localhost:{{port}}/api/v1/applications/{{appid}}/jobs 2>/dev/null' 2>/dev/null",port=port,SSH=remotenode,appid=appid), intern=TRUE),collapse="\n")
    if(verbose) print(x)
    tryCatch(a <- fromJSON(l),error=function(e){
        cat(sprintf("mozaws: There was an error running the command to get jobs. Command is \n%s\nOutput is\n", x,l))
        e
    })
    if(length(a)==0) return(data.table())
    rbindlist(Map(function(s){
        data.table(id=s$jobId,
                   name=s$name,
                   status = s$status,
                   desc=isn(s$description),
                   started=as.POSIXct(isn(s$submissionTime)
                                     ,format="%Y-%m-%dT%H:%M:%S",tz="GMT"
                                     ,origin="1970-01-01"),
                   end=as.POSIXct(isn(s$completionTime)
                                 ,format="%Y-%m-%dT%H:%M:%S",tz="GMT"
                                 ,origin="1970-01-01"),
                   tTasks=s$numTasks,
                   tActive = s$numActiveTasks,
                   tFailed = s$numFailedTasks,
                   tComplete = s$numCompletedTasks,
                   tSkipped = s$numSkippedTasks,
                   sActive = s$numActiveStages,
                   sComplete = s$numCompletedStages,
                   sFailed = s$numFailedStages,
                   stageId=list(s$stageIds),
                   group=isn(s$jobGroup))
    },a))[order(-started),]
}    

##' @export
as.character.HRBytes <- function(s0){
    s0 <- as.numeric(s0)
    sapply(s0,function(s){
        if(s<1024) sprintf("%s bytes",formatC(round(s, 2), big.mark=",",format="f", drop0trailing = TRUE))
        else if(s < 1024*1024) sprintf("%s KB",formatC(round(s/1024, 2), big.mark=",",format="f", drop0trailing = TRUE))
        else if(s < 1024*1024*1024) sprintf("%s MB",formatC(round(s/1024^2, 2), big.mark=",",format="f", drop0trailing = TRUE))
        else sprintf("%s GB",formatC(round(s/1024^3, 2), big.mark=",",format="f", drop0trailing = TRUE))
    })
}
##' @export
as.character.HRNumber <- function(s0){
    s0 <- as.numeric(s0)
    sapply(s0,function(s){
        (formatC(round(s,0), big.mark=",",format="f", drop0trailing = TRUE))
    })
}
##' @export
print.HRBytes <- function(s){
    print(as.character.HRBytes(s))
}
##' @export
print.HRNumber <- function(s){
    print(as.character.HRNumber(s))
}
##' @export
as.data.frame.HRBytes <- as.data.frame.vector
##' @export
format.HRBytes <- function(x,...){
    l <- as.character(x)
    format(l,...)
}
as.data.frame.HRNumber <- as.data.frame.vector
format.HRNumber <- function(x,...){
    l <- as.character(x)
    format(l,...)
}

##' @export
HRBytes <- function(s){
    s <- isn(s)
    class(s) <- "HRBytes"
    s
}
##' @export
HRNumber <- function(s){
    s <- isn(s)
    class(s) <- "HRNumber"
    s
}

##' Get all stages run on this application
##' @param appid is an application id taken from \code{scApplicationList}. It can be missing anf if is so, it will be taken from the first currently running application
##' @param remotenode see \code{scApplicationList}
##' @param port is 4040
##' @param verbose set to TRUE for the command
##' @export
scStages <- function(appid,remotenode,port=4040,verbose=FALSE){
    if(missing(remotenode)) remotenode <- tail(options("mozremote")[[1]],1)[[1]]$ssh
    if(missing(appid)) appid <- getAppId(remotenode,port)
    l <- (paste(system(x<-infuse(" {{SSH}} 'curl -L  -H \"Accept: application/json\" http://localhost:{{port}}/api/v1/applications/{{appid}}/stages 2>/dev/null' 2>/dev/null",port=port,SSH=remotenode,appid=appid), intern=TRUE),collapse="\n"))
    if(verbose) print(x)
    tryCatch(a <- fromJSON(l),error=function(e){
        cat(sprintf("mozaws: There was an error running the command to get stages. Command is \n%s\nOutput is\n", x,l))
        e
    })
    rbindlist(Map(function(s){
        data.table(stageId=s$stageId,
                   name = s$name,
                   status=s$status,
                   tActive=s$numActiveTasks,
                   tCompleted=isn(s$numCompleteTasks),
                   tFailed = s$numFailedTasks,
                   tInputBytes = HRBytes(s$inputBytes),
                   tOutputBytes = HRBytes(s$outputBytes),
                   tInputRecords = HRNumber(s$inputRecords),
                   tOutputRecords = HRNumber(s$outputRecords),
                   shufflesBytes = HRBytes(s$shuffleReadBytes))
    }, a))[order(-stageId),]
}


##' creates string for tracking progress of the job
##' @param appid is an application id taken from \code{scApplicationList}. It can be missing anf if is so, it will be taken from the first currently running application
##' @param remotenode see \code{scApplicationList}
##' @param port is 4040
##' @export
makeProgressString <- function(appid,remotenode, port=4040){
    if(missing(remotenode)) remotenode <- tail(options("mozremote")[[1]],1)[[1]]$ssh
    if(missing(appid)) appid <- getAppId(remotenode,port)
    X <- scJobsForApplication(appid,remotenode, port)
    if(nrow(X)==0) return(NULL)
    js <- head(X[status=="RUNNING",],1)
    if(nrow(js)==0) return(NULL)
    s1 <- "App:{{app}} Job[id:{{id}}, name:'{{name}}'] started at: {{start}}, duration: {{dura}} min"
    s2 <- "Tasks(c,f/all,%): {{tdone}},{{tfail}}/{{tall}},{{tpct}}% Stages(c,f/all,%): {{sdone}},{{sfail}}/{{sall}},{{spct}}%"
    u <- list( app=appid,id = js$id, name=js$name, start=js$started, dura = if(is.na(js$end)) round(as.numeric(Sys.time() - js$started,"mins"),2) else round(as.numeric(j$end- js$started,"mins"),2),
         tdone=js$tComplete, tfail=js$tFailed, tall=js$tTasks, tpct=round(js$tComplete/js$tTasks*100,1),
         sdone = js$sComplete, sfail =js$sFailed, sall = length(js$stageId[[1]]), spct=round(js$sComplete/length(js$stageId[[1]])*100,1))
    s1 <- infuse(s1, u)
    s2 <- infuse(s2,u)
    sgs <- js$stageId[[1]]
    sg <- scStages(appid,remotenode,port)
    j <- capture.output(print(sg[stageId %in% sgs,]))
    c(s1,s2,j)
}

##' Will always run and update with the currently running job
##' @param cl is the output from \code{aws.clus.create}
##' @param port is 4040
##' @param mon.sec is the update frequency
##' @export
monitorCurrentSparkApplication <- function(cl,port=4040, mon.sec=5){
    if( "package:colorout" %in% search()) {
        tryCatch(noColorOut(), error=function(e) NULL)
    }
    on.exit({
        ## technically i should get the status and toggle of or on accordingly.
        if( "package:colorout" %in% search()) {
                tryCatch(ColorOut(), error=function(e) NULL)
        }
    })
                
    ssh <- sprintf("ssh -i %s hadoop@%s",aws.options()$pathtoprivkey,cl$MasterPublicDnsName)
    appid <- getAppId(ssh,port)
    nr <- 0
    orig_width <- getOption("width")
    width <- as.integer(Sys.getenv("COLUMNS"))
    if (is.na(width)) {
        width <- getOption("width")
    } else {
        options(width = width)
    }
    while (TRUE) {
        width <- as.integer(Sys.getenv("COLUMNS"))
        if (is.na(width)) 
            width <- getOption("width") + nchar(getOption("prompt"))
        if (exists("allTxt")) {
            nr <- sum(ceiling((nchar(allTxt))/width))
        }
        if (nr > 0) {
            esc <- paste("\033[", nr, "A100\033[", width, "D", sep = "")
            cat(esc)
        }
        allTxt <- makeProgressString(appid, ssh,port)
        if(is.null(allTxt)) 
            allTxt <- sprintf("[%s] No jobs running on %s", Sys.time(), appid)
        cat(allTxt, sep = "\n")
        flush.console()
        Sys.sleep(max(1, as.integer(mon.sec)))
    }
    
}
