library(devtools)
library(rjson)
library(data.table)

.onLoad <- function(libname, pkgname) {
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
            user        = Sys.info()[["user"]],
            s3bucket    = "mozillametricsemrscripts",
            hadoopops   = c(
                c("-y","yarn.resourcemanager.scheduler.class=org.apache.hadoop.yarn.server.resourcemanager.scheduler.fair.FairScheduler"),
                c("-c","fs.s3n.multipart.uploads.enabled=true"),
                c("-c","fs.s3n.multipart.uploads.split.size=524288000"),
                c("-m","mapred.reduce.tasks.speculative.execution=false"),
                c("-m","mapred.map.tasks.speculative.execution=false"),
                c("-m","mapred.map.child.java.opts=-Xmx1024m"),
                c("-m","mapred.reduce.child.java.opts=-Xmx1024m"),
                c("-m","mapred.job.reuse.jvm.num.tasks=1")),
            inst.type  = c(worker="c3.2xlarge",master="c3.2xlarge"))
        )


tryCatch({
    library(infuser)
    if(!packageVersion("infuser")>="0.2") stop("Higher Version Required")
},error=function(e){
    install_github("Bart6114/infuser")
    library(infuser)
})

}
