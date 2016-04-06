#!/bin/bash
minute=$(date '+%M')

repo_path="/var/lib/openshift/56fbf20c2d527133cb00022a/app-root/repo/"
local_path="${repo_path}local/"
backup_path="${repo_path}backup/"
repodata_url="http://fr2.rpmfind.net/linux/fedora/linux/updates/23/x86_64/repodata/"

#if [ $minute != 30 ]; then
#    exit
#fi

#synchronize
function sync {

    #backup only if there is something to backup

   if [ "$(ls -A ${local_path})" ]; then
        date=$(date +%Y-%m-%d)
        #check current date directory
        if [ ! -d "${backup_path}${date}" ]; then
            mkdir ${backup_path}${date}
            dir_num="0"
        else
            dir_num=$(ls -v | tail -n 1)
            (($dir_num++))
        fi

        mkdir "${backup_path}${date}/${dir_num}"
        mv ${local_path}* "${backup_path}${date}/${dir_num}"
    fi

    #download new data
    curl --silent -o $local_filelists $remote_filelists
    gzip -d $local_filelists
    curl --silent -o $local_primary $remote_primary
    gzip -d $local_primary
    gzip --rsyncable ${local_path}*
    curl --silent -o "${local_path}repomd.xml" $remote_repomd
}

#remote files that are to be synchronized
filelists_file=$(curl -s ${repodata_url} --list-only | sed -n 's/.*href="\([^"]*filelists.xml.gz\).*/\1/p')
primary_file=$(curl -s ${repodata_url} --list-only | sed -n 's/.*href="\([^"]*primary.xml.gz\).*/\1/p')

remote_filelists="${repodata_url}${filelists_file}"
remote_primary="${repodata_url}${primary_file}"
remote_repomd="${repodata_url}repomd.xml"

#local files
local_filelists="${local_path}${filelists_file}"
local_primary="${local_path}${primary_file}"
local_repomd="${local_path}repomd.xml"

#check if files exist
[ ! "$(ls -A ${local_path})" ] && sync

#save last time of modification of remote files
mod_filelists=$(curl --silent --head $remote_filelists | awk -F: '/^Last-Modified/ { print $2 }')
mod_primary=$(curl --silent --head $remote_primary | awk -F: '/^Last-Modified/ { print $2 }')
mod_repomd=$(curl --silent --head $remote_repomd | awk -F: '/^Last-Modified/ { print $2 }')

#save modification timestamps of remote and local files
remote_ctime_filelists=$(date --date="$mod_filelists" +%s)
remote_ctime_primary=$(date --date="$mod_primary" +%s)
remote_ctime_repomd=$(date --date="$mod_repomd" +%s)

local_ctime_filelists=$(stat -c %z "$local_filelists")
local_ctime_filelists=$(date --date="$local_ctime_filelists" +%s)

local_ctime_primary=$(stat -c %z "$local_primary")
local_ctime_primary=$(date --date="$local_ctime_primary" +%s)

local_ctime_repomd=$(stat -c %z "$local_repomd")
local_ctime_repomd=$(date --date="$local_ctime_repomd" +%s)

#compare local and remote timestamps
[ $local_ctime_filelists -lt $remote_ctime_filelists ] ||
[ $local_ctime_primary -lt $remote_ctime_primary ] ||
[ $local_ctime_repomd -lt $remote_ctime_repomd ] &&
sync
