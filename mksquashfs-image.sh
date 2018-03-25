#!/bin/sh -x
exec > /tmp/mksquashfs-atlas.log 2>&1

script=$(readlink -f $0)
scriptdir=$(dirname $script)

date
# when changing CMT, remember to update mksquashfs-exclude.rules.txt
cmt=x86_64-slc6-gcc49n62
cmt=x86_64-slc6-gcc62
datestamp=`date +%Y%m%d%H%M`
sqshimg=/data/yangw/images/centos6-cvmfs.atlas.cern.ch.$cmt.$datestamp.sqsh
rm $sqshimg

cd /data/yangw/root
find etc ! -perm -u=r -exec chmod u+r {} \;
find usr ! -perm -u=r -exec chmod u+r {} \;
/sbin/mksquashfs `find $PWD -maxdepth 1 -exec basename {} \;` $sqshimg -no-progress 

cd /data/yangw/uncvmfs/data
rsync -aO --no-o --no-g --delete -H --no-A --no-X -v \
    /cvmfs/atlas.cern.ch/repo/sw/local/x86_64-slc5-gcc43-opt/yampl \
    cvmfs/atlas.cern.ch/repo/sw/local/x86_64-slc5-gcc43-opt/
# -no-duplicates
/sbin/mksquashfs * $sqshimg -keep-as-directory -no-progress -no-duplicates -wildcards \
                            -ef $scriptdir/mksquashfs-exclude.rules.txt
