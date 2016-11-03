buildingR <- function(excludeLibs=c(),exclude=NULL,iterate=TRUE,verbose=1,nameof="Rfolder-test",destpath){
  library(Rhipe)
  rhinit()
  ## if(USER=="") print("=================USER is empty=====================")
  local({
    tfolder <- sprintf("%s/Rdist",tempdir())
    ## delete folder if it exists!
    dir.create(tfolder)
    execu <- if ("package:Rhipe" %in% search()) rhoptions()$RhipeMapReduce else sprintf("/home/%s/software/R_LIBS/Rhipe/bin/RhipeMapReduce",USER)
    ## execu <- if ("package:Rhipe" %in% search()) rhoptions()$Rhipe else sprintf("/home/%s/software/R_LIBS/Rhipe/libs/Rhipe.so",USER)
    getLB <- function(n){
        a <- system(sprintf("ldd  %s",n),intern=TRUE)
        b <- lapply(strsplit(a,"=>"), function(r) if (length(r)>=2) r[2] else NULL)
        b <- strsplit(unlist(b)," ")
        b <- unlist(lapply(b,"[[",2))
        b <- unique(unlist( sapply(b, function(r) if(nchar(r)>1) r else NULL)))
        names(b) <- NULL
        if(verbose>=1){
        cat(sprintf("\n%s depends on:\n",n))
        cat(paste(b,sep=":",collapse=" "))
        cat(sprintf("\n---------------\n"))
        if(verbose>10) print(a)
      }
      b
    }
    b <- getLB(execu)
    ## b <- unique(b[!grepl("(libc.so)",b)])
    for(x in b) {
      cat(sprintf("Copying %s to %s\n",x,tfolder))
      file.copy(x,tfolder) ##copies the linked .so files
    }
    file.copy(execu,tfolder,overwrite=TRUE)  ## copies the RHIPE C engine
    file.copy(R.home(),tfolder,recursive=TRUE)
    ## R_LIBS
    x <- .libPaths() ##Sys.getenv("R_LIBS")
    if(TRUE){
      for(y in list.files(x,full.names=TRUE)){
        if(all( sapply(excludeLibs,function(h) !grepl(h,y))))
          file.copy(y,sprintf("%s/R/library/",tfolder), recursive=TRUE)
      }
      allfiles <- list.files(x,full.names=TRUE,rec=TRUE)
      allsofiles <- allfiles[grepl(".so$",allfiles)]
      alldeps <- sort(unique(unlist(sapply(allsofiles, getLB))))
      id <- 1
      if(iterate){
        while(TRUE){
          message(sprintf("iteration %s", id))
          alldeps2 <- sort(unique(unlist(sapply(alldeps, getLB))))
          newones <- sum(!(alldeps2 %in% alldeps))
          if(newones>0){
            message(sprintf("There were %s additions(total=%s), iterating till this becomes zero", length(newones), length(alldeps2)))
            id=id+1
            alldeps=alldeps2
          }else  break
        }
      }
      if(!is.null(exclude)) alldeps <- alldeps[!grepl(exclude,alldeps)]
      for(x in alldeps) {
        cat(sprintf("Copying %s to %s\n",x,tfolder))
        file.copy(x,tfolder) ##copies the linked .so files
      }
    }
  })
  cat(sprintf("Building a gzipped tar archive at %s/%s.tar.gz\n",tempdir(),nameof))
  system (sprintf("tar z --create --file=%s/%s.tar.gz -C %s/Rdist .",tempdir(),nameof, tempdir()))
  cat(sprintf("Copying gzipped tar archive to HDFS (see %s) in user folder\n",sprintf("%s.tar.gz",nameof)))
  if ("package:Rhipe" %in% search()) rhput(sprintf("%s/%s.tar.gz",tempdir(),nameof),destpath)
}

