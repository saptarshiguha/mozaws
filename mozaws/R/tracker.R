library(httr)
library(infuser)
isn <- function(s,r=NA) if(length(s)==0 || is.null(s)) r else s

## Find a list of running spark applications Every invocationof
## ipython creates a new application.

#options(mozremote = (ssh <- sprintf("ssh hadoop@%s",cl$MasterPublicDnsName)))

getAppId <- function(remotenode,port){
        x <- scApplicationList(remotenode,port)
        x[!x$done,][,id[1]]
}
        
scApplicationList <- function(remotenode,port=4040,verbose=FALSE){
    ## 18080 for history
    if(missing(remotenode)) remotenode <- tail(options("mozremote"),1)
    l <- paste(system(x<-infuse("{{SSH}} 'curl -L -H \"Accept: application/json\" http://localhost:{{port}}/api/v1/applications 2>/dev/null' 2>/dev/null",port=port,SSH=remotenode), intern=TRUE),collapse="\n")
    if(l=="") stop("No data? Try using port 18080. It might be that you do not have a notebook/ipython session running. Start one and then the port 4040 might work")
    if(verbose) print(x)
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

scJobsForApplication <- function(appid,remotenode,port=4040,verbose=FALSE){
    if(missing(remotenode)) remotenode <- tail(options("mozremote"),1)
    if(missing(appid)) appid <- getAppId(remotenode,port)
    l <- paste(system(x <- infuse("{{SSH}} 'curl -L  -H \"Accept: application/json\" http://localhost:{{port}}/api/v1/applications/{{appid}}/jobs 2>/dev/null' 2>/dev/null",port=port,SSH=remotenode,appid=appid), intern=TRUE),collapse="\n")
    if(verbose) print(x)
    tryCatch(a <- fromJSON(l),error=function(e){
        cat(sprintf("mozaws: There was an error running the command to get jobs. Command is \n%s\nOutput is\n", x,l))
        e
    })
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

as.character.HRBytes <- function(s0){
    s0 <- as.numeric(s0)
    sapply(s0,function(s){
        if(s<1024) sprintf("%s bytes",formatC(round(s, 2), big.mark=",",format="f", drop0trailing = TRUE))
        else if(s < 1024*1024) sprintf("%s KB",formatC(round(s/1024, 2), big.mark=",",format="f", drop0trailing = TRUE))
        else if(s < 1024*1024*1024) sprintf("%s MB",formatC(round(s/1024^2, 2), big.mark=",",format="f", drop0trailing = TRUE))
        else sprintf("%s GB",formatC(round(s/1024^3, 2), big.mark=",",format="f", drop0trailing = TRUE))
    })
}
as.character.HRNumber <- function(s0){
    s0 <- as.numeric(s0)
    sapply(s0,function(s){
        (formatC(round(s,0), big.mark=",",format="f", drop0trailing = TRUE))
    })
}
print.HRBytes <- function(s){
    print(as.character.HRBytes(s))
}
print.HRNumber <- function(s){
    print(as.character.HRNumber(s))
}
as.data.frame.HRBytes <- as.data.frame.vector
format.HRBytes <- function(x,...){
    l <- as.character(x)
    format(l,...)
}
as.data.frame.HRNumber <- as.data.frame.vector
format.HRNumber <- function(x,...){
    l <- as.character(x)
    format(l,...)
}


HRBytes <- function(s){
    s <- isn(s)
    class(s) <- "HRBytes"
    s
}
HRNumber <- function(s){
    s <- isn(s)
    class(s) <- "HRNumber"
    s
}

scStages <- function(appid,remotenode,port=4040,verbose=FALSE){
    if(missing(remotenode)) remotenode <- tail(options("mozremote"),1)
    if(missing(appid)) appid <- getAppId(remotenode,port)
    l <- (paste(system(x<-infuse(" {{SSH}} 'curl -L  -H \"Accept: application/json\" http://localhost:{{port}}/api/v1/applications/{{appid}}/stages 2>/dev/null' 2>/dev/null",port=port,SSH=remotenode,appid=appid), intern=TRUE),collapse="\n"))
    if(verbose) print(x)
    tryCatch(a <- fromJSON(l),error=function(e){
        cat(sprintf("mozaws: There was an error running the command to get stages. Command is \n%s\nOutput is\n", x,l))
        e
    })
    rbindlist(Map(function(s){
        data.table(stageId=s$stageId,
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


makeProgressString <- function(appid,remotenode, port=4040){
    if(missing(remotenode)) remotenode <- tail(options("mozremote"),1)
    if(missing(appid)) appid <- getAppId(remotenode,port)
    js <- head(scJobsForApplication(appid,remotenode, port)[status=="RUNNING",],1)
    if(nrow(js)==0) return(NULL)
    s1 <- "App:{{app}} Job[id:{{id}}, name:'{{name}}'] started at: {{start}}, duration: {{dura}} min\nTasks(c,f/all,%): {{tdone}},{{tfail}}/{{tall}},{{tpct}} Stages(c,f/all,%): {{sdone}},{{sfail}}/{{sall}},{{spct}}\n"
    u <- list( app=appid,id = js$id, name=js$name, start=js$started, dura = if(is.na(js$end)) round(as.numeric(Sys.time() - js$started,"mins"),2) else round(as.numeric(j$end- js$started,"mins"),2),
         tdone=js$tComplete, tfail=js$tFailed, tall=js$tTasks, tpct=round(js$tComplete/js$tTasks*100,1),
         sdone = js$sComplete, sfail =js$sFailed, sall = length(js$stageId[[1]]), spct=round(js$sComplete/length(js$stageId[[1]])*100,1))
    u <- infuse(s1, key_value_list=u)
    sgs <- js$stageId[[1]]
    sg <- scStages(appid,remotenode,port)
    j <- paste(capture.output(print(sg[stageId %in% sgs,])),collapse="\n")
    (sprintf("%s%s",u,j))
}

monitorCurrentApplication <- function(cl,port=4040, mon.sec=5){
    ssh <- sprintf("ssh hadoop@%s",cl$MasterPublicDnsName)
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
            nr <- sum(ceiling((1+nchar(allTxt))/width))
        }
        if (nr > 0) {
            esc <- paste("\033[", nr, "A100\033[", width, "D", sep = "")
            cat(esc)
        }
        msg <- makeProgressString(appid, ssh,port)
        if(is.null(msg)) 
            msg <- sprintf("[%s] No jobs running on %s", Sys.time(), appid)
        allTxt <- msg
        cat(allTxt, sep = "\n")
        flush.console()
        Sys.sleep(max(1, as.integer(mon.sec)))
    }
}
