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
load("/tmp/x")
ssh <- sprintf("ssh hadoop@%s",cl$MasterPublicDnsName)
y <- makeProgressString(remote=ssh)
if(is.null(y) || length(y)==0 || y=="") {
    isRunning <- TRUE
    y <- "Nothing running"
} else {
    isRunning <- FALSE
    y <- y
}

if(isRunning){
    cat("SparkTracker ")
} else {
    cat("SparkTracking | color=green\n")
    cat("---\n")
    y <- paste(y, c(" | trim=false font=Monaco size=10"))
    cat(y, sep='\n')
}
               
