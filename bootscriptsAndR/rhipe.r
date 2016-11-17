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

library(data.table)
library(colorout)
library(Hmisc)
options(width=200)

rsp <- function(o,cnames=NULL,r=NA){
          ## converts key-value pairs from HAdoop MApReduce Jobs to data tables
    fixup <- function(s,r=r) if(is.null(s) || length(s)==0) r else s
    x <- o[[1]]
    k <- x[[1]];v <- x[[2]]
    if( is(k, "list") && length(k)>=1){
        ## key is list with names (presumably) nd these form columns
        m <- list()
        for(i in 1:length(k)){
            m[[ length(m) +1 ]] <- unlist(lapply(o,function(s){ fixup(s[[1]][[i]]) }))
        }
        p1 <- do.call(data.table,m)
    }else stop("key should be a list")
    p2 <- if(is(v,"data.table")) {
              do.call(rbindlist,lapply(o,function(s) s[[2]]))
          }else{
              data.table(do.call(rbind,lapply(o,function(s) s[[2]])))
          }
    x <- cbind(p1,p2)
    if(!is.null(cnames))  setnames(x,cnames)                                           
}
    
        
setwd("~/r")
