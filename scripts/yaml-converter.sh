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
subPathFilterList=$(echo "$4" | xargs | sed 's/ //g')
skipIfNotFound=$(if [[ -z "$5" ]]; then echo false;else echo true;fi)

if [[ ! -f "$inputYaml" ]]; then
  echo "[ERROR] $BASH_SOURCE (line:$LINENO): Unable to locate yaml file: $inputYaml"
  exit 1
fi

# Default to initial start if no key path
if [[ "$pathFilter" == "" ]]; then
    pathFilter='.'
fi

## Initialize the temporary files
if [[ "$importerFilename" == "" ]]; then
    importerFilename=$FINAL_CONVERSION_FILE
fi

function getKeys()
{
    local currentKey=$1
    local outputimporterFilename=$2
    local createIsolateKVFile=${3:-false}

    keyValueListFile=current-kv.tmp
    rm -f $keyValueListFile

    if [[ ! "$createIsolateKVFile" == "true" ]]; then
        createIsolateKVFile=false
    fi

    # Default to initial start if no key path
    if [[ "$currentKey" == "" ]]; then
        currentKey='.'
    fi

    if (cat $inputYaml | yq -e "$currentKey" -o props 2>/dev/null >/dev/null); then
        cat $inputYaml | yq -o props "$currentKey" | grep -v '^$' | grep -v '^#' | sed "s/ = /=/g" > $keyValueListFile
        if [[ "$createIsolateKVFile" == "true" ]]; then
            isolateKVFile=$(echo $currentKey | sed "s/^$pathFilter\.//g")
            cat $keyValueListFile >> $isolateKVFile.kv-tmp
        fi
        # Init vars
        regex='^.*\.[0-9]+$'
        prevKeyWithList="NIL_KEY"
        currentValueWithList="["

        # Convert to map array
        mapfile -t keyValueList < <(cat $keyValueListFile) 
        for element in "${keyValueList[@]}"
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
                    # echo "echo ::set-output name=$tmpCurrentKey::\"$currentValueWithList\"" >> $outputimporterFilename
                    storeForGitHubEnv "$tmpCurrentKey" "$currentValueWithList" "$outputimporterFilename"
                    currentValueWithList="["
                    prevKeyWithList="NIL_KEY"
                fi

            else
                if [[ "$prevKeyWithList" != "NIL_KEY" ]]; then
                    currentValueWithList="$currentValueWithList ]"
                    tmpCurrentKey=${prevKeyWithList//\./\_}
                    # echo "echo ::set-output name=$tmpCurrentKey::\"$currentValueWithList\"" >> $outputimporterFilename
                    storeForGitHubEnv "$tmpCurrentKey" "$currentValueWithList" "$outputimporterFilename"
                    currentValueWithList="["
                    prevKeyWithList="NIL_KEY"
                fi
            fi
            currentKey=${currentKey//\./\_}
            # echo "echo ::set-output name=$currentKey::\"$currentValue\"" >> $outputimporterFilename
            storeForGitHubEnv "$currentKey" "$currentValue" "$outputimporterFilename"
            if [[ "$element" == "${keyValueList[-1]}" ]] && [[ ! "$currentValueWithList" == "[" ]] ; then
                currentValueWithList="$currentValueWithList ]"
                tmpCurrentKey=${prevKeyWithList//\./\_}
                # echo "echo ::set-output name=$tmpCurrentKey::\"$currentValueWithList\"" >> $outputimporterFilename
                storeForGitHubEnv "$tmpCurrentKey" "$currentValueWithList" "$outputimporterFilename"
                currentValueWithList="["
                prevKeyWithList="NIL_KEY"
            fi
        done
    else
        if ("${skipIfNotFound}"); then
            echo "[WARNING] $BASH_SOURCE (line:$LINENO): Failed querying path: $currentKey"
            if [[ ! -f "$outputimporterFilename" ]]; then
                echo "[ERROR] $BASH_SOURCE (line:$LINENO): Importer file [$outputimporterFilename] not present. At least one yaml file or query path must be valid. Check yaml and query path for invalid parameters"
            else
                echo "[INFO] Skipping.. importer file present: $outputimporterFilename"
                exit 0
            fi

        else
            echo "[ERROR] $BASH_SOURCE (line:$LINENO): Failed querying path: $currentKey"
            rm -f $keyValueListFile
            exit 1
        fi
    fi
    rm -f $keyValueListFile
}

## Store format based on the character in the value
function storeForGitHubEnv() {
    local storeKey=$1
    local storeValue=$2
    local storeFile=$3
    local tmpStoreKey=""
    if [[ "$storeValue" =~ [\|\>\<\&\\] ]]; then
        echo "echo $storeKey=\"$storeValue\" >> \$GITHUB_OUTPUT" >> $storeFile
        ## Must normalized to underscore before pushing into github_env
        tmpStoreKey=$(echo $storeKey | sed "s/_/__/g" | sed "s/-/_/g")
        echo "echo $tmpStoreKey=\"$storeValue\" >> \$GITHUB_ENV" >> $storeFile
    else
        echo "echo $storeKey=$storeValue >> \$GITHUB_OUTPUT" >> $storeFile
        ## Must normalized to underscore before pushing into github_env
        tmpStoreKey=$(echo $storeKey | sed "s/_/__/g" | sed "s/-/_/g")
        echo "echo $tmpStoreKey=$storeValue >> \$GITHUB_ENV" >> $storeFile
    fi
}

echo [INFO] Reading $inputYaml...
echo [INFO] Path filter: [$pathFilter]
echo [INFO] Target imported file: [$importerFilename]
echo [INFO] Sub default query path: [$subPathFilterList]
export keyValueListFile=list.tmp
## Process the sub keys
if [[ ! "$subPathFilterList" == "" ]]; then
    IFS=', ' read -r -a subPathFilterArray <<< "$subPathFilterList"
    for eachSubPath in "${subPathFilterArray[@]}"
    do
        ## Store into a file for subsequent run
        finalSubKeyChild=$(echo $eachSubPath | sed "s/$pathFilter\.//g")
        echo $finalSubKeyChild >> $SUB_DEFAULT_KEY_LIST_FILE
        getKeys "$eachSubPath" "tmp.element" "true"
        rm -f tmp.element

    done
fi
## If sub default key list present
if [[ -f $SUB_DEFAULT_KEY_LIST_FILE ]]; then
    cat $SUB_DEFAULT_KEY_LIST_FILE | uniq > $SUB_DEFAULT_KEY_LIST_FILE.1
    mv $SUB_DEFAULT_KEY_LIST_FILE.1 $SUB_DEFAULT_KEY_LIST_FILE
    
    while IFS="" read -r eachSubPath || [ -n "$eachSubPath" ]
    do
        echo "[INFO] Processing sub-default query path: ${pathFilter}.${eachSubPath}"
        tmpSubQueryPath=${pathFilter}.${eachSubPath}
        parentKeyforSubDefault="${tmpSubQueryPath%.*}"
        subDefaultKey="${tmpSubQueryPath##*.}"
        ## reset to root if at top level
        if [[ "$parentKeyforSubDefault" == "" ]]; then
            parentKeyforSubDefault="."
        fi
         
        if (cat $inputYaml | yq -e "$parentKeyforSubDefault | keys" 2>/dev/null >/dev/null); then
            subKeyDefaultItemList=$(cat $inputYaml | yq "$parentKeyforSubDefault | keys" | cut -d" " -f2)
            IFS=' ' read -r -a subKeyDefaultItemListArray <<< "$(echo $subKeyDefaultItemList)"
            for subKeyElement in "${subKeyDefaultItemListArray[@]}"
            do
                if [[ ! "$subDefaultKey" == "$subKeyElement" ]]; then
                    finalSubDefaultKey=$(echo $parentKeyforSubDefault | sed "s/$pathFilter\.//g" | sed "s/\./_/g" )_$subKeyElement
                    if [[ -f "$eachSubPath.kv-tmp" ]]; then
                        while IFS="" read -r eachChildPath || [ -n "$eachChildPath" ]
                        do
                            subChildKey=$(echo $eachChildPath | cut -d"=" -f1)
                            subChildValue=$(echo $eachChildPath | cut -d"=" -f1 --complement)
                            # echo  "echo ::set-output name=${finalSubDefaultKey}_${subChildKey}::\"${subChildValue}\"" >> $importerFilename
                            storeForGitHubEnv "${finalSubDefaultKey}_${subChildKey}" "${subChildValue}" "$importerFilename"
                        done < $eachSubPath.kv-tmp
                    fi
                fi
                # getKeys "$subKeyElement" "tmp.element" "true"
                # rm -f tmp.element
            done
        else
            echo "[WARNING] $BASH_SOURCE (line:$LINENO): Failed querying sub key default path: $parentKeyforSubDefault"
        fi
    done < $SUB_DEFAULT_KEY_LIST_FILE
    # for eachSubPath in "$(cat $SUB_DEFAULT_KEY_LIST_FILE | xargs -i echo {} )"
    # do
    #     echo "[INFO] Processing sub-default query path: $eachSubPath"
    #     # parentKeyforSubDefault="${eachSubPath%.*}"
    #     # subDefaultKey="${eachSubPath##*.}"
    #     # ## reset to root if at top level
    #     # if [[ "$parentKeyforSubDefault" == "" ]]; then
    #     #     parentKeyforSubDefault="."
    #     # fi
    #     # if (cat $inputYaml | yq -e "$parentKeyforSubDefault | keys" 2>/dev/null >/dev/null); then
    #     #     subKeyDefaultItemList=$(cat $inputYaml | yq "$parentKeyforSubDefault | keys" | cut -d" " -f2)
    #     #     IFS=' ' read -r -a subKeyDefaultItemListArray <<< "$(echo $subKeyDefaultItemList)"
    #     #     for subKeyElement in "${subKeyDefaultItemListArray[@]}"
    #     #     do
    #     #         echo lalaaa $subKeyElement
    #     #     done
    #     # else
    #     #     echo "[ERROR] $BASH_SOURCE (line:$LINENO): Failed querying sub key default path: $currentKey"
    #     #     exit 1
    #     # fi
    # done
fi

## Process the primary keys
# keyValueListFile=kv.tmp
# rm -f $keyValueListFile
getKeys "$pathFilter" "$importerFilename" "false"

## Escape special chars
sed -i "s/\\\\\\\\\\$/\\\\\\\\\\\\$/g" "$importerFilename"

echo [INFO] Completed...

if [[ -f "$importerFilename" ]]; then
    chmod 755 $importerFilename
fi
