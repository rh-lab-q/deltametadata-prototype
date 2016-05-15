#!/bin/bash
minute=$(date '+%M')

home_dir="/var/lib/openshift/56fbf20c2d527133cb00022a/"
repo_path="${home_dir}app-root/repo/"
zsyncmake="${home_dir}httpd/opt/zsync-0.6.2/zsyncmake"
local_path="${repo_path}local/"
backup_path="${repo_path}backup/"
repodata_url="http://fr2.rpmfind.net/linux/fedora/linux/updates/23/x86_64/repodata/"

#continue every 30 minutes
if [ $minute != 30 ]; then
    exit
fi

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
            $((++dir_num))
        fi

        mkdir "${backup_path}${date}/${dir_num}"
        printf "Creating backup\n"
        mv ${local_path}* "${backup_path}${date}/${dir_num}"
    fi

    #download new data
    printf "Downloading and unpacking filelists.xml.gz and primary.xml.gz\n"
    curl --silent -o ${local_path}${filelists_file} $remote_filelists
    curl --silent -o ${local_path}${primary_file} $remote_primary
    gzip -d ${local_path}*
    printf "Repacking with rsyncable\n"
    gzip --rsyncable ${local_path}*
    printf "Downloading repomd.xml\n"
    curl --silent -o "${local_path}repomd.xml" $remote_repomd
    printf "Creating zsync files\n"
    pushd ${local_path} >/dev/null 2>&1
    for f in *.gz; do
        printf "| Processing ${f} ...\n"
        ${zsyncmake} -e ${f} 2>/dev/null
    done
    popd >/dev/null 2>&1
}

#remote files that are to be synchronized
filelists_file=$(curl -s ${repodata_url} --list-only | sed -n 's/.*href="\([^"]*filelists.xml.gz\).*/\1/p')
primary_file=$(curl -s ${repodata_url} --list-only | sed -n 's/.*href="\([^"]*primary.xml.gz\).*/\1/p')

remote_filelists=${repodata_url}${filelists_file}
remote_primary=${repodata_url}${primary_file}
remote_repomd=${repodata_url}repomd.xml

#local files
local_filelists=${local_path}$(ls $local_path | grep "filelists.xml.gz")
local_primary=${local_path}$(ls $local_path | grep "primary.xml.gz")
local_repomd=${local_path}repomd.xml

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
