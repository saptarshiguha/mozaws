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
#a <-  custom.theme.2()
#a$superpose.polygon$col <- c(brewer.pal(9,"Set1"))
#a$superpose.symbol$col <- c(brewer.pal(9,"Set1")) #length(a$strip.background$col)
#a$superpose.line$col <- c(brewer.pal(9,"Set1")) #length(a$strip.background$col)
#a$strip.background <- list( alpha = 1, col =  c(brewer.pal(8,"Paired")))
#lattice.options(default.theme =a)
#rm(a)


dtbinder <-  expression(
    pre = { .c = NULL },
    reduce = {
        .c <- rbind(.c,rbindlist(reduce.values))
    },
    post = {
        rhcollect(reduce.key, .c)
    })
attr(dtbinder,"combine") <- TRUE



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
   
print.sparky <- function(l){
    x <- l[[1]]
    pN <- function(s) prettyNum(s,big.mark=",",scientific=FALSE,preserve.width="none")
    inpRec <- pN(x$counters$`Map-Reduce Framework`['Map input records',][[1]])
    oupRec <- pN(x$counters$`Map-Reduce Framework`['Reduce output records',][[1]])
    oupsize <- pN(x$counters$`File Output Format Counters `['Bytes Written',][[1]])
    ifo <- paste(l[[2]]$lines$rhipe_input_folder,collapse=":")
    ifo <-sprintf( "%s ...",substr(ifo,1, min(100,nchar(ifo))))
    lfo <- l[[2]]$lines$rhipe_output_folder
    cat(paste(strwrap(sprintf("Job read from %s, wrote to %s, input records where %s and wrote %s records occupying %s bytes.
Use $join() to join an asynchronous job, $output to get the output location, and $collect() to get results\n\n",
            ifo, lfo, inpRec, oupRec, oupsize),width=120),collapse="\n"))
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
        class(r) <- c(class(r),"sparky")
        list(result=r, join=function(mon.sec=10){
            s <- list(rhstatus(r,mon.sec=mon.sec),r[[2]])
            class(s) <- c(class(s),"sparky")
            list(result=s,output=o, join=function() NULL,collect=col,input=src)
        } ,output=o, input=src,collect=col,take=take)
    }
}


                                              
setwd("~/r")
