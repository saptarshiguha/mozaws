rhwatch(map=function(a,b) rhcollect(a,fromJSON(b)$geo)
      , reduce = rhoptions()$templ$colsummer
      , input  = rhfmt(folder="s3://mozillametricsfhrsamples/1pct",type="sequence",recordsAsText=TRUE)
      , output = rhfmt(type='text',folder="s3://mozillametricsfhrsamples/tmp/myout", field.sep = "\t", stringquote = "")
      , mapred = list(mapred.output.compress="false",mapreduce.output.fileoutputformat.compress="false")
       ,setup = expression({library(rjson)})
      , read   = FALSE)
