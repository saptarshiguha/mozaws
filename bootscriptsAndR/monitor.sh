#!/bin/bash


inotifywait -mr  --timefmt '%d/%m/%y %H:%M' --format '%T %w %f' -e close_write ~/r | while read date time dir file; do
    rsync -zvrae 'ssh -p 9999' ~/r sguha@localhost:/Users/sguha/Sites/tmp/
done


































