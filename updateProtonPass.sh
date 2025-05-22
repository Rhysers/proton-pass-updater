#!/bin/bash
JSON=$(curl -s https://proton.me/download/PassDesktop/linux/x64/version.json)

#Get Version of newest version from JSON file.
AvailableVersion=$(echo $JSON | jq -r '.Releases[0].Version')

#Get currently installed version
CurrentVersion=$(dpkg-query --showformat='${Version}' --show proton-pass)

#Determine if update is necessary
if [ "$AvailableVersion" != "$CurrentVersion" ]; then
    #Need Upgrade
    echo "Upgrade/Install needed, proceeding"
    #Download file. First we need to find the link to the deb file
    FileType='';ValidFound=false
    for i in 0 1
    do
        FileType=$(jq -r --argjson i "$i" '.Releases[0].File[$i].Identifier' <<< "$JSON")
        if [ "$FileType" == ".deb (Ubuntu/Debian)" ]; then
            ValidFound=true
            break
        fi
    done
    #Make sure we got something valid
    if [ "$ValidFound" = false ];then
        echo "No valid file candidate found!"
        exit 1
    fi
    #If we're here, we found a vaild file type and $i is set to it.
    #Lets download the file
    DownloadLink=$(jq -r --argjson i "$i" '.Releases[0].File[$i].Url' <<< "$JSON")
    filename=$(wget -P /tmp "$DownloadLink" 2>&1 | grep 'Saving to:' | sed -E 's/.*‘(.*)’/\1/')
    ExpectedSum=$(jq -r --argjson i "$i" '.Releases[0].File[$i].Sha512CheckSum' <<< "$JSON")
    echo "$ExpectedSum $filename" | sha512sum --check --status
    ExitCode=$?
    if [ $ExitCode -ne 0 ]; then
        echo "Checksum Failure!"
        exit 1
    fi
    if [ "$EUID" -ne 0 ]; then
        echo "Root needed for install. Please provide password."
    else
        echo "Installing $AvailableVersion..."
    fi
    sudo dpkg -i "$filename"
else
    echo "No upgrade required. Current version: $CurrentVersion"
fi
