#!/usr/local/bin/Rscript
suppressPackageStartupMessages(library(mozaws))
suppressMessages(aws.init(ec2key="mozilla_vitillo"
         ,localpubkey = "~/.ssh/id_dsa.pub"
         ,opts = list(loguri= "s3://telemetry-test-bucket/sguhatmp/logs/"
                      ,s3bucket = "telemetry-test-bucket/sguhatmp/bootscriptsAndR"
                      ,timeout = "1440"
                      ,ec2attributes = "InstanceProfile='telemetry-spark-cloudformation-TelemetrySparkInstanceProfile-1SATUBVEXG7E3'"
                      ,configfile="https://s3-us-west-2.amazonaws.com/telemetry-spark-emr-2/configuration/configuration.json"
                     )))
load("/tmp/spz")
ssh <- sprintf("ssh hadoop@%s",tail(X,1)[[1]]$MasterPublicDnsName)
STATUS <- "okay"
L <- NULL
y <- tryCatch(
    makeProgressString(remote=ssh)
   ,warning=function(e){
       if(grepl("status 255",as.character(e))) STATUS <<- "timeout"
       if(grepl("status 7",as.character(e))) STATUS <<- "barderror"
       as.character(e)
    }
   ,error=function(e){
       as.character(e)
   })


if(STATUS == "timeout"){
    cat("No Sparks\n")
    cat("---\n")
    y <- paste(y, c(" | trim=false font=Monaco size=10"))
    paste(y)
} else if(STATUS=="barderror"){
    cat("Spark: No Application?\n")
    cat("---\n")
    y <- paste(y, c(" | trim=false font=Monaco size=10"))
    paste(y)
}else if(STATUS=="okay" & length(y)==0){
    cat("Spark:Tracker")
} else if(STATUS=="okay" & length(y)>0) {
    cat("Spark:Tracking | color=green\n")
    cat("---\n")
    y <- paste(y, c(" | trim=false font=Monaco size=10"))
    cat(y, sep='\n')
}
               
