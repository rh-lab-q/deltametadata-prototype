#!/usr/bin/env bash

STATUS_ALL=0
URL="http://dmd-deltametadata.rhcloud.com/local/"
CACHE_DIR="/var/cache/dnf/updates-*/repodata/"
GITROOT=$(pwd)$(git rev-parse --show-cdup)

echo "$GITROOT"

# For pull requests just compare target branch and github merge commit,
# TRAVIS_COMMIT_RANGE is unusable because there is commit from master
# and if pull request modifies old version, range is big and many files
# differ (may be bug in travis)
if [ "$TRAVIS_PULL_REQUEST" == "false" ] ; then
    COMMIT_RANGE=$TRAVIS_COMMIT_RANGE
else
    COMMIT_RANGE=$TRAVIS_BRANCH...FETCH_HEAD
fi

echo "Commit range: $COMMIT_RANGE"

docker exec -i test_fedora bash -c "dnf repoquery -q --releasever=23 --disablerepo=\* --enablerepo=updates > /dev/null"
((STATUS_ALL+=$?))
echo -en "travis_fold:start:zsync\\r"
docker exec -i test_fedora bash -c "mkdir /tmp/compare; cd /tmp/compare; STATUS_ALL=0;
                                    echo -en \"travis_fold:start:repomd.xml\\r\"
                                    wget $URL\"repomd.xml\" >output.out 2>&1
                                    echo -e \"diff files\" >>output.out
                                    diff repomd.xml ${CACHE_DIR}repomd.xml 2>>output.out
                                    STATUS=\$?
                                    if [ \$STATUS == 0 ] ; then
                                        echo \"Compare repomd.xml $(tput setaf 2)succeeded $(tput sgr0)\"
                                    else
                                        echo \"Compare repomd.xml $(tput setaf 1)failed$(tput sgr0)\"
                                    fi
                                    ((STATUS_ALL+=STATUS))
                                    cat output.out
                                    echo -en \"travis_fold:end:repomd.xml\\r\"
                                    diff repomd.xml ${CACHE_DIR}repomd.xml; ((STATUS+=\$?))
                                    for i in \$(/dnf/scripts/parse_repomd.py repomd.xml)
                                    do 
                                        echo -en \"travis_fold:start:\${i#*-}\\r\"
                                        wget $URL\$i >output.out 2>&1
                                        echo -e \"diff files\" >>output.out
                                        diff \$i ${CACHE_DIR}\$i 2>>output.out
                                        STATUS=\$?
                                        if [ \$STATUS == 0 ] ; then
                                            echo \"Compare \${i#*-} $(tput setaf 2)succeeded $(tput sgr0)\"
                                        else
                                            echo \"Compare \${i#*-} $(tput setaf 1)failed$(tput sgr0)\"
                                        fi
                                        ((STATUS_ALL+=STATUS))
                                        cat output.out
                                        echo -en \"travis_fold:end:\${i#*-}\\r\"
                                    done
                                    exit \$STATUS_ALL" >output.out 2>&1
STATUS=$?
if [ $STATUS == 0 ] ; then
    echo "Zsync $(tput setaf 2)succeeded $(tput sgr0)"
else
    echo "Zsync $(tput setaf 1)failed$(tput sgr0)"
fi
cat output.out
((STATUS_ALL+=$STATUS))
echo -en "travis_fold:end:zsync\\r"

echo -en "travis_fold:start:repoquery\\r"
docker exec -i test_fedora bash -c "dnf repoquery -q --releasever=23 --disablerepo=\* --enablerepo=updates > /dnf/deltametadata_pkgs.txt
                                    dnf repoquery -q --disableplugin dnf_zsync --disablerepo=\* --enablerepo=updates --releasever=23 > /dnf/updates_pkgs.txt
                                    diff /dnf/deltametadata_pkgs.txt /dnf/updates_pkgs.txt
                                    exit \$?" >output.out 2>&1
STATUS=$?
if [ $STATUS == 0 ] ; then
    echo "Copare output from repoquery $(tput setaf 2)succeeded $(tput sgr0)"
else
    echo "Copare output from repoquery $(tput setaf 1)failed$(tput sgr0)"
fi
cat output.out
((STATUS_ALL+=$STATUS))
echo -en "travis_fold:end:repoquery\\r"

exit $STATUS_ALL
