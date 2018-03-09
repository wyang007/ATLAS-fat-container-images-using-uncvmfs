#!/bin/sh -x
datestamp=`date +%Y%m%d%H%M`
nerscsqsh="/global/cscratch1/sd/yangw/shifter-imgs-4-atlas/centos6-cvmfs.atlas.cern.ch.sqsh"
sqshimg="/data/yangw/images/centos6-cvmfs.atlas.cern.ch.${datestamp}.sqsh"
singimg="/data/yangw/images/centos6-cvmfs.atlas.cern.ch.${datestamp}.img"
latestsingimg="/data/yangw/images/centos6-cvmfs.atlas.cern.ch.img"
cmt="x86_64-slc6-gcc49+"

script=$(readlink -f $0)
scriptdir=$(dirname $script)

exec > /tmp/sync-atlas-uncvmfs.log 2>&1
date

# /data/yangw/uncvmfs/root is the root file system extracted from ATLAS cent6 image.i
# Owership of 'cvmfs' may need to be adjusted to allow writing by script runner.
cd /data/yangw/uncvmfs/root
date > creation_time
mkdir -p cvmfs/atlas-condb.cern.ch cvmfs/atlas-nightlies.cern.ch cvmfs/sft.cern.ch
[ -d var/lib/condor-ce ] || echo "WARNING: var/lib/condor-ce does not exist!" 

# Symlink needed at NERSC
[ -L project ] || ln -s /global/project project
# Directories needed by Titon
mkdir -p lustre autofs ccs
# /ustlas has to exist in order to run "singularity exec -w" at BNL
mkdir -p usatlas 
# /u has to exist in order to run "singularity exec -w" at SLAC
mkdir -p u 

echo ""
echo "---------- Update cvmfs"
echo ""
uncvmfs -vv -n16 $scriptdir/uncvmfs.conf atlas
#uncvmfs -vv -n8 $HOME/local/etc/uncvmfs/uncvmfs.conf atlas
# yampl is needed by Event Service
rsync -aO --no-o --no-g --delete -H --no-A --no-X -v \
    /cvmfs/atlas.cern.ch/repo/sw/local/x86_64-slc5-gcc43-opt/yampl \
    cvmfs/atlas.cern.ch/repo/sw/local/x86_64-slc5-gcc43-opt/
find etc ! -perm -u=r -exec chmod u+r {} \;
find usr ! -perm -u=r -exec chmod u+r {} \;
date

createSquashfsImg() {
    exec > /tmp/sync-atlas-squashfs.log 2>&1
    date
    echo ""
    echo "---------- Making squashfs image"
    echo ""
    /sbin/mksquashfs * $sqshimg -no-progress -no-xattrs -wildcards \
                                -e 'cvmfs/atlas.cern.ch/repo/images/*' \
                                -e 'cvmfs/atlas.cern.ch/repo/containers/*' \
                                -e 'cvmfs/atlas.cern.ch/repo/sw/database/GroupData/FTK/*' 

    ssh dtn01.nersc.gov "rm ${nerscsqsh}.completed"
    bbcp -s 16 -f $sqshimg dtn01.nersc.gov:$nerscsqsh
    ssh dtn01.nersc.gov "touch ${nerscsqsh}.completed"
    date
}
createSquashfsImg &

exec > /tmp/sync-atlas-singularity.log 2>&1
date
if [ ! -f $latestsingimg ]; then
    echo ""
    echo "---------- Making a new singularity image"
    echo ""

    #cd /data/yangw/images
    #cp /cvmfs/atlas.cern.ch/repo/images/singularity/x86_64-centos6.img $singimg
    #singularity expand -s 460800 $latestsingimg
    singularity image.create -s 512000 $latestsingimg
    ln $latestsingimg $singimg

    # add the following empty directories to the image
    #mkdir -p workdir/usatlas
    #cd workdir
    #find . -type f -exec rm {} \;
    #tar cf - * | singularity import $latestsingimg
    #cd /data/yangw/uncvmfs/root

    # this command can also be used standalone to refresh the contents of the cent6 OS part.
    tar --no-acls --no-xattrs --exclude=cvmfs/atlas.cern.ch/repo -cvf - * | singularity import $latestsingimg
# singularity exec -w -B /data/yangw/uncvmfs/root:/mnt $latestsingimg /bin/sh \
#    (cd /mnt; tar --no-acls --no-xattrs -cf - cvmfs) | \
#    (cd /; tar --no-acls --no-xattrs --atime-preserve=system --delay-directory-restore -xvf -)

else
    echo ""
    echo "---------- Updatng singularity image"
    echo ""
    dd if=$latestsingimg of=$singimg bs=4096k
    rm $latestsingimg
    ln $singimg $latestsingimg
fi

echo ">>> rsync ATLASLocalRootBase"
# rsync-exclude.rules.txt needs to be copied everytime because each singularity rsync run maybe 
# have a big time gap and this file may be deleted during the gap.
cp $scriptdir/rsync-exclude.rules.txt /tmp/rsync-exclude.rules.txt
# we can not exclude java and x86_64-slc6-gcc62-opt from ATLASLocalRootBase, or voms-proxy-init will
# not work (and rucio may not work either)
singularity exec -w -B /data/yangw/uncvmfs/root/cvmfs:/mnt $latestsingimg \
    rsync -aO --no-o --no-g --delete -H --no-A --no-X -v \
        --filter='+s **/x86_64-slc6-gcc62-opt' \
        --filter='+s **/java' \
        --filter='+s **/*.java' \
        --filter='+s **/*.jar' \
        --filter='. /tmp/rsync-exclude.rules.txt' \
        --filter='-s /atlas.cern.ch/repo/ATLASLocalRootBase/logDir' \
        --filter='-s /atlas.cern.ch/repo/ATLASLocalRootBase/x86_64-MacOS' \
        --filter='+s /atlas.cern.ch/repo/ATLASLocalRootBase' \
        --filter='P /atlas.cern.ch/repo/*' \
        --filter='-s /atlas.cern.ch/repo/*' \
        /mnt/ /cvmfs

cp $scriptdir/rsync-exclude.rules.txt /tmp/rsync-exclude.rules.txt
echo ">>> rsync other things, excluding ATLASLocalRootBase"
singularity exec -w -B /data/yangw/uncvmfs/root/cvmfs:/mnt $latestsingimg \
    rsync -aO --no-o --no-g --delete -H --no-A --no-X -v \
        --filter='. /tmp/rsync-exclude.rules.txt' \
        --filter='P /atlas.cern.ch/repo/ATLASLocalRootBase' \
        --filter='+s /atlas.cern.ch/repo/sw/database/DBRelease' \
        --filter='-s /atlas.cern.ch/repo/sw/database/GroupData/FTK*' \
        --filter='+s /atlas.cern.ch/repo/sw/database/GroupData/*' \
        --filter='+s /atlas.cern.ch/repo/sw/database/GroupData' \
        --filter='-s /atlas.cern.ch/repo/sw/database/*' \
        --filter='-s /atlas.cern.ch/repo/sw/BOINC' \
        --filter='-s /atlas.cern.ch/repo/sw/Generators' \
        --filter='-s /atlas.cern.ch/repo/sw/arc' \
        --filter='-s /atlas.cern.ch/repo/sw/muon' \
        --filter='-s /atlas.cern.ch/repo/sw/pacman*' \
        --filter='-s /atlas.cern.ch/repo/sw/tdaq' \
        --filter='-s /atlas.cern.ch/repo/sw/tzero' \
        --filter='+s /atlas.cern.ch/repo/sw' \
        --filter='+s /atlas.cern.ch/repo/conditions' \
        --filter='-s /atlas.cern.ch/repo/*' \
        /mnt/ /cvmfs

echo ">>> shrine the image size"
tmpimg=$latestsingimg.TMP
dd if=$latestsingimg bs=1M count=1 | dd ibs=31 skip=1 of=$tmpimg
dd if=$latestsingimg bs=1M skip=1 of=$tmpimg oflag=append conv=notrunc
sync
/sbin/resize2fs -f -M $tmpimg 
dd if=/dev/zero bs=1M mount=100 of=$tmpimg oflag=append conv=notrunc
/sbin/e2fsck -fy $tmpimg
/sbin/resize2fs -f $tmpimg
/sbin/tune2fs -m 0 $tmpimg
dd if=$latestsingimg ibs=31 count=1 > $latestsingimg.$cmt.$datestamp
dd if=$tmpimg bs=1M of=$latestsingimg.$cmt.$datestamp oflag=append conv=notrunc
#rm $tmpimg
date
wait
