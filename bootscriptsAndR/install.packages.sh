#!/bin/sh

TFILE="/tmp/$$.R"

cat << EOF > $TFILE
args = (commandArgs(trailingOnly=TRUE))[-1]
cran <- c()
gh <- c()
CRAN <- FALSE;GH <- FALSE
for(x in args){
    if(x=="--cran"){
        CRAN <- TRUE;GH <- FALSE;
    }else if(x=="--github"){
        CRAN <- FALSE;GH <- TRUE;
    }else{
        if(CRAN) cran <- c(cran, x)
        if(GH) gh <- c(gh,x)
    }
}
for(p in cran) install.packages(p, repos="http://cran.cnr.Berkeley.edu",dependencies=TRUE)
library(devtools);
for(p in gh) install_github(p)
EOF

sudo -E Rscript $TFILE $@
