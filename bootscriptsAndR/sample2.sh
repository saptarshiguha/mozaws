#!/bin/sh

IS_MASTER=true
if [ -f /mnt/var/lib/info/instance.json ]
then
	IS_MASTER=$(jq .isMaster /mnt/var/lib/info/instance.json)
fi

sleep 30
R -e 'install.packages("binda", repos="http://cran.cnr.Berkeley.edu",dep=TRUE)'
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('saptarshiguha/rhekajq')"
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('saptarshiguha/RAmazonS3')"
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('daattali/shinyjs')"
R -e "options(repos = 'http://cran.rstudio.com/'); library(devtools); install_github('Rdatatable/data.table', build_vignettes = FALSE)"

