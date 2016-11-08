#!/bin/bash

inotifywait -mr  --timefmt '%d/%m/%y %H:%M' --format '%T %w %f' -e close_write ~/public_html/tmp/ | while read date time dir file; do
    rsync -zvrae 'ssh -p 9999' ~/public_html/tmp/ localhost:/Users/sguha/Sites/tmp/
done


































