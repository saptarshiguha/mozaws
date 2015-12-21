library(Rhipe)
rhinit()
f <- rhwatch(map=function(a,b) tryCatch(rhcollect(rjson:::fromJSON(b)$geo,1),error=function(e) rhcounter("rerror",as.character(e),1))
      , reduce = rhoptions()$templ$colsummer
      , input  = rhfmt(folder="s3://mozillametricsfhrsamples/1pct/part-r-00199",type="sequence",recordsAsText=TRUE)
      , output = rhfmt(type='text',folder="/myout", field.sep = "\t", stringquote = "")
      , mapred = list(mapred.output.compress="false",mapreduce.output.fileoutputformat.compress="false")
      , read   = FALSE
      , mon.sec=Inf)

if(f$state=="SUCCEEDED"){
    rhread("/myout",type='text',max=10)
    rhcp("/myout","s3://telemetry-test-bucket/sguhatmp/")
}
