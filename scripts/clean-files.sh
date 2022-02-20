#!/bin/bash -e

## Reading action's global setting
if [[ ! -z $BASH_SOURCE ]]; then
    ACTION_BASE_DIR=$(dirname $BASH_SOURCE)
    source $(find $ACTION_BASE_DIR/.. -type f | grep general.ini)
elif [[ $(find . -type f -name general.ini | wc -l) > 0 ]]; then
    source $(find . -type f | grep general.ini)
elif [[ $(find .. -type f -name general.ini | wc -l) > 0 ]]; then
    source $(find .. -type f | grep general.ini)
else
    echo "[ERROR] $BASH_SOURCE (line:$LINENO): Unable to find and source general.ini"
    exit 1
fi

importerFilename=$(echo "$1" |xargs)

if [[ "$importerFilename" == "" ]]; then
    importerFilename=$FINAL_CONVERSION_FILE
fi

if [[ -f "$importerFilename" ]]; then
    echo [INFO] Cleaning $importerFilename
    rm -f $importerFilename
fi

if [[ -f "$SUB_DEFAULT_KEY_LIST_FILE" ]]; then
    echo [INFO] Cleaning $SUB_DEFAULT_KEY_LIST_FILE
    rm -f $SUB_DEFAULT_KEY_LIST_FILE
fi

if (ls *.kv-tmp 2>/dev/null >/dev/null); then
   ls *.kv-tmp | xargs -i rm -f {} 
fi


