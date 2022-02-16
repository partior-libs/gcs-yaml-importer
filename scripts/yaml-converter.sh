#!/bin/bash -e
## Prerequisite:
## - yq from https://github.com/mikefarah/yq
## - jq

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

inputYaml=$(echo "$1" |xargs)
pathFilter=$(echo "$2" |xargs)
importerFilename=$(echo "$3" |xargs)

if [[ ! -f "$inputYaml" ]]; then
  echo "[ERROR] $BASH_SOURCE (line:$LINENO): Unable to locate yaml file: $inputYaml"
  exit 1
fi

## Initialize the temporary files
if [[ "$importerFilename" == "" ]]; then
    importerFilename=$FINAL_CONVERSION_FILE
fi
export keyValueListFile=list.tmp
rm -f $importerFilename
rm -f $keyValueListFile

function getKeys()
{
    local currentKey=$1
    # Default to initial start if no key path
    if [[ "$currentKey" == "" ]]; then
        currentKey='.'
    fi

    if (cat $inputYaml | yq -e "$currentKey" -o props 2>/dev/null >/dev/null); then
        cat $inputYaml | yq -o props "$currentKey" | sed "s/ = /=/g" > $keyValueListFile

        # Init vars
        regex='^.*\.[0-9]+$'
        prevKeyWithList="NIL_KEY"
        currentValueWithList="["

        # Convert to map array
        mapfile -t batch_list < <(cat $keyValueListFile) 
        for element in "${batch_list[@]}"
        do
            currentKey=$(echo $element | cut -d"=" -f1)
            currentValue=$(echo $element |cut -d"=" -f1 --complement)
 
            ## Group list value into parent key, otherwise treat as single unique key
            if [[ "$currentKey" =~ $regex ]]; then
                currentParentKey="${currentKey%.*}"
                # echo [DEBUG] currentParentKey:::$currentParentKey
                # echo [DEBUG] currentValueWithList:::$currentValueWithList
                # echo [DEBUG] prevKeyWithList:::$prevKeyWithList
                if [[ "$prevKeyWithList" == "NIL_KEY" ]]; then
                    currentValueWithList="$currentValueWithList \"$currentValue\""
                    prevKeyWithList=$currentParentKey
                elif [[ "$prevKeyWithList" == "$currentParentKey" ]]; then
                    currentValueWithList="$currentValueWithList ,\"$currentValue\""
                    prevKeyWithList=$currentParentKey
                else
                    currentValueWithList="$currentValueWithList ]"
                    tmpCurrentKey=${currentParentKey//\./\_}
                    echo "echo ::set-output name=$tmpCurrentKey::$currentValueWithList" >> $importerFilename
                    currentValueWithList="["
                    prevKeyWithList="NIL_KEY"
                fi
            else
                if [[ "$prevKeyWithList" != "NIL_KEY" ]]; then
                    currentValueWithList="$currentValueWithList ]"
                    tmpCurrentKey=${prevKeyWithList//\./\_}
                    echo "echo ::set-output name=$tmpCurrentKey::$currentValueWithList" >> $importerFilename
                    currentValueWithList="["
                    prevKeyWithList="NIL_KEY"
                fi
                currentKey=${currentKey//\./\_}
                echo "echo ::set-output name=$currentKey::$currentValue" >> $importerFilename
            fi
            
        done
    else
        echo "[ERROR] $BASH_SOURCE (line:$LINENO): Failed querying path: $currentKey"
        exit 1
    fi
}

echo [INFO] Reading $inputYaml...
echo [INFO] Path filter: [$pathFilter]


getKeys "$pathFilter"

echo [INFO] Completed...

if [[ -f "$importerFilename" ]]; then
    chmod 755 $importerFilename
fi