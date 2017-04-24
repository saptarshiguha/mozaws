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


theme_set( theme_bw()  %+replace% theme(axis.title = element_text(size=8) ,
                                 axis.text.x  = element_text(angle=0, size=6),
                                 axis.text.y  = element_text(angle=0, size=6),
                                 strip.text.y = element_text(size =8,angle=90,lineheight=0.8),
                                 plot.title = element_text(lineheight=.8,size=9),
                                 panel.margin = unit(0.1,"cm")
                                 ))
lattice.options(default.theme = standard.theme(color = FALSE))
library(latticeExtra)
a <-  custom.theme.2()
a$superpose.polygon$col <- c(brewer.pal(9,"Set1"))
a$superpose.symbol$col <- c(brewer.pal(9,"Set1")) #length(a$strip.background$col)
a$superpose.line$col <- c(brewer.pal(9,"Set1")) #length(a$strip.background$col)
a$strip.background <- list( alpha = 1, col =  c(brewer.pal(8,"Paired")))
lattice.options(default.theme =a)
rm(a)





rsp <- function(o,cnames=NULL,r=NA){
          ## converts key-value pairs from HAdoop MApReduce Jobs to data tables
    fixup <- function(s,r) if(is.null(s) || length(s)==0) r else s
    x <- o[[1]]
    k <- x[[1]];v <- x[[2]]
    if( is(k, "list") && length(k)>=1){
        ## key is list with names (presumably) nd these form columns
        m <- list()
        for(i in 1:length(k)){
            m[[ length(m) +1 ]] <- unlist(lapply(o,function(s){ fixup(s[[1]][[i]],r) }))
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



   
print.sparky <- function(l){
    x <- l[[1]]
    pN <- function(s) prettyNum(s,big.mark=",",scientific=FALSE,preserve.width="none")
    inpRec <- tryCatch(pN(x$counters$`Map-Reduce Framework`['Map input records',][[1]]),error=function(e) "0")
    oupRec <- tryCatch(pN(x$counters$`Map-Reduce Framework`['Reduce output records',][[1]]),error=function(e) "0")
    oupMap <- tryCatch(pN(x$counters$`Map-Reduce Framework`['Map output records',][[1]]),error=function(e) "0")
    oupsize <- tryCatch(pN(x$counters$`File Output Format Counters `['Bytes Written',][[1]]),error=function(e) "0")
    ifo <- paste(l[[2]]$lines$rhipe_input_folder,collapse=":")
    ifo <-sprintf( "%s ...",substr(ifo,1, min(100,nchar(ifo))))
    lfo <- l[[2]]$lines$rhipe_output_folder
    cat(sprintf("%s\n",paste(strwrap(sprintf("Job read from %s, wrote to %s, input records where %s and wrote %s map records and %s reduce records occupying %s bytes.
Use $join() to join an asynchronous job, $output to get the output location, and $collect() to get results\n\n",
            ifo, lfo, inpRec, oupMap, oupRec, oupsize),width=120),collapse="\n")))
}

rh <- function(src,setups){
    function(...){
        l <- list(...)
        if(!is.null(l$take)){
                  return( rhread(src, max=l$take))
         }
        if(is.null(l$input)) l$input <- src
        if(is.null(l$setup)) l$setup <- setups
        if(is.null(l$reduce)) l$reduce <-  rhoptions()$tem$colsummer
        l$readback=FALSE
        r <- do.call(rhwatch,l)
        o <- r[[2]]$lines$rhipe_output_folder
        col <- function() rhread(r[[2]]$lines$rhipe_output_folder)
        take = function(n=1) rhread(r[[2]]$lines$rhipe_output_folder,max=n)
        count = function() rhwatch(map=function(a,b) rhcollect(1,1), reduce=rhoptions()$tem$colsummer,input=o)
        class(r) <- c(class(r),"sparky")
        list(result=r, join=function(mon.sec=10){
            s <- list(rhstatus(r,mon.sec=mon.sec),r[[2]])
            class(s) <- c(class(s),"sparky")
            list(result=s,output=o, join=function() NULL,collect=col,input=src)
        } ,output=o, input=src,collect=col,take=take,count=count)
    }
}


dtbinder = function (r = NULL, combine = TRUE)
{
    ..r <- substitute(r)
    r <- if (is(..r, "name"))
        get(as.character(..r))
    else ..r
    def <- if (is.null(r))
        TRUE
    else FALSE
    r <- if (is.null(r))
        substitute({
            rhcollect(reduce.key, .r)
        })
    else r
    y <- bquote(expression(pre = {
        .r <- NULL
    }, reduce = {
         .r <- rbind(.r,rbindlist(reduce.values))
    }, post = {
        .(P)
    }), list(P = r))
    y <- if (combine || def)
        structure(y, combine = TRUE)
    else y
    environment(y) <- .BaseNamespaceEnv
    y
}

CS <- rhoptions()$tem$colsummer
E <- expression({
          set.seed(20)
    suppressPackageStartupMessages(library(data.table))
    suppressPackageStartupMessages(library(Hmisc))
    suppressPackageStartupMessages(library(rjson))
})
isn <- function(x,r=NA) if(is.null(x) || length(x)==0) r else x



setwd("~/r")

