#!/usr/bin/env bash

STATUS_ALL=0

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

echo "Copare output from repoquery"

docker exec -i test_fedora bash -c "dnf repoquery -q --releasever=23 --disablerepo=\* --enablerepo=updates > /dnf/deltametadata_pkgs.txt"
docker exec -i test_fedora bash -c "dnf repoquery -q --disableplugin zsync --disablerepo=\* --enablerepo=updates --releasever=23 > /dnf/updates_pkgs.txt"
diff /dnf/deltametadata_pkgs.txt /dnf/updates_pkgs.txt
STATUS_ALL=$?

exit $STATUS_ALL
