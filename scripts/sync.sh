#!/bin/bash

home_dir="/var/lib/openshift/56fbf20c2d527133cb00022a/"
repo_path="${home_dir}app-root/repo/"
zsyncmake="${home_dir}httpd/opt/zsync-0.6.2/zsyncmake"
local_path="${repo_path}local/"
backup_path="${repo_path}backup/"
script_path=${repo_path}"scripts/"
repodata_url="http://mirror.vutbr.cz/fedora/updates/23/x86_64/repodata/"

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
            dir_num=$(ls "${backup_path}${date}" -v | tail -n 1)
            ((++dir_num))
        fi

        mkdir "${backup_path}${date}/${dir_num}"
        printf "Creating backup\n"
        mv ${local_path}* "${backup_path}${date}/${dir_num}"
    fi

    #download new data
    printf "Downloading and unpacking filelists.xml.gz and primary.xml.gz\n"
    printf "Downloading prestodelta.xml.xz, updateinfo.xml.xz and comps-f23.xml.xz\n"
    for i in $hash
    do
      curl --silent -o ${local_path}$i $repodata_url$i
    done
    gzip -d ${local_path}*.gz
    printf "Repacking with rsyncable\n"
    gzip -n --rsyncable ${local_path}*.xml
    pushd ${local_path} >/dev/null 2>&1
    checksum_filelists=$(sha256sum *-filelists.xml.gz | cut -d ' ' -f1)
    mv *-filelists.xml.gz ${checksum_filelists}-filelists.xml.gz
    checksum_primary=$(sha256sum *-primary.xml.gz | cut -d ' ' -f1)
    mv *-primary.xml.gz ${checksum_primary}-primary.xml.gz
    printf "Creating zsync files\n"
    for f in *.gz; do
        printf "| Processing ${f} ...\n"
        ${zsyncmake} -u ${f} -e ${f} >/dev/null
    done
    printf "Downloading repomd.xml\n"
    mv /tmp/repomd.xml "${local_path}repomd.xml"
    printf "Changing repomd.xml\n"
    ${script_path}parse_repomd.py repomd.xml "$checksum_filelists" "$checksum_primary"
    popd >/dev/null 2>&1
}

date '+%Y-%m-%d %T'
printf "%s\n"

curl --silent -o /tmp/repomd.xml $repodata_url"repomd.xml"

#check if files exist
if [ "$(ls -A ${local_path})" ]
then
    hash=$(${script_path}parse_repomd.py /tmp/repomd.xml ${local_path}repomd.xml)
else
    hash=$(${script_path}parse_repomd.py /tmp/repomd.xml)
fi

#check if repomd.xml is changed
if [ "$hash" ]
then
    sync
else
    printf "Repomd.xml is up-to-date\n"
    if [ $(date '+%H') == "00" ]
    then
        backup_date=$(date +%s)
        ((backup_date -= 43200))
        dir_name=$(date --date="@${backup_date}" "+%F")
        mkdir "${backup_path}${dir_name}" 2>/dev/null
    fi;
fi

echo "------------------------------------------------------------------------"
