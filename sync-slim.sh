#!/bin/sh -x
datestamp=`date +%Y%m%d%H%M`
singimg="/data/yangw/images/centos6-cvmfs.atlas.cern.ch.mini.img"
latestsingimg="/data/yangw/images/centos6-cvmfs.atlas.cern.ch.mini.img"
cmt="x86_64-slc6-gcc49-opt"

script=$(readlink -f $0)
scrpitdir=$(dirname $SCRIPT)

exec > /tmp/sync-single-singularity.log 2>&1
date
cd /data/yangw/uncvmfs/root
if [ ! -f $latestsingimg ]; then
    echo ""
    echo "---------- Making a new singularity image"
    echo ""

    #cd /data/yangw/images
    #cp /cvmfs/atlas.cern.ch/repo/images/singularity/x86_64-centos6.img $singimg
    #singularity expand -s 460800 $latestsingimg
    singularity create -s 102400 $latestsingimg

    # add the following empty directories to the image
    #mkdir -p workdir/usatlas
    #cd workdir
    #find . -type f -exec rm {} \;
    #tar cf - * | singularity import $latestsingimg
    #cd /data/yangw/uncvmfs/root
    tar --no-acls --no-xattrs --exclude=cvmfs/atlas.cern.ch/repo -cvf - * | singularity import $latestsingimg
else
    echo ""
    echo "---------- Updatng singularity image"
    echo ""
fi

echo ">>> rsync ATLASLocalRootBase"
# we can not exclude java and x86_64-slc6-gcc62-opt from ATLASLocalRootBase, or voms-proxy-info will 
# not work (and rucio may not work either)
singularity exec -w -B /data/yangw/uncvmfs/root/cvmfs:/mnt \
                    -B ${scriptdir}/rsync-exclude.rules.txt:/tmp/rsync-exclude.rules.txt $latestsingimg \
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
        
echo ">>> rsync other things, excluding ATLASLocalRootBase"
# sw/software and database/DBReleases will be rsync-ed later
singularity exec -w -B /data/yangw/uncvmfs/root/cvmfs:/mnt \
                    -B ${scriptdir}/rsync-exclude.rules.txt:/tmp/rsync-exclude.rules.txt $latestsingimg \
    rsync -aO --no-o --no-g --delete -H --no-A --no-X -v \
        --filter='. /tmp/rsync-exclude.rules.txt' \
        --filter='P /atlas.cern.ch/repo/ATLASLocalRootBase' \
        --filter='-s /atlas.cern.ch/repo/sw/BOINC' \
        --filter='-s /atlas.cern.ch/repo/sw/Generators' \
        --filter='-s /atlas.cern.ch/repo/sw/arc' \
        --filter='P /atlas.cern.ch/repo/sw/database/DBRelease' \
        --filter='-s /atlas.cern.ch/repo/sw/database/*' \
        --filter='-s /atlas.cern.ch/repo/sw/muon' \
        --filter='-s /atlas.cern.ch/repo/sw/pacman*' \
        --filter='P /atlas.cern.ch/repo/sw/software/21.0' \
        --filter='-s /atlas.cern.ch/repo/sw/software/*' \
        --filter='-s /atlas.cern.ch/repo/sw/tdaq' \
        --filter='-s /atlas.cern.ch/repo/sw/tzero' \
        --filter='+s /atlas.cern.ch/repo/sw' \
        --filter='+s /atlas.cern.ch/repo/conditions' \
        --filter='-s /atlas.cern.ch/repo/*' \
        /mnt/ /cvmfs

echo ">>> rsync sw/software/xxx"
singularity exec -w -B /data/yangw/uncvmfs/root/cvmfs:/mnt \
                    -B ${scriptdir}/rsync-exclude.rules.txt:/tmp/rsync-exclude.rules.txt $latestsingimg \
    rsync -aO --no-o --no-g --delete -H --no-A --no-X -v \
        --filter='. /tmp/rsync-exclude.rules.txt' \
        --filter='-s **/lcg/releases/R' \
        --filter='-s **/21.0.[0-1]' \
        --filter='-s **/21.0.[0-1].*' \
        --filter='-s **/21.0.1[0-4]*' \
        --filter='-s **/21.0.1[6-9]*' \
        --filter='-s **/21.0.[2-9]*' \
        --filter='+s /21.0' \
        --filter='-s /*' \
        /mnt/atlas.cern.ch/repo/sw/software/ /cvmfs/atlas.cern.ch/repo/sw/software

echo ">>> rsync sw/database/DBRelease"
singularity exec -w -B /data/yangw/uncvmfs/root/cvmfs:/mnt \
                    -B ${scriptdir}/rsync-exclude.rules.txt:/tmp/rsync-exclude.rules.txt $latestsingimg \
    rsync -aO --no-o --no-g --delete -H --no-A --no-X -v -L \
        --filter='. /tmp/sync-exclude.rules.txt' \
        --filter='+s /DBRelease/current' \
        --filter='-s /DBRelease/*' \
        --filter='+s /DBRelease' \
        --filter='-s /*' \
        /mnt/atlas.cern.ch/repo/sw/database/ /cvmfs/atlas.cern.ch/repo/sw/database

echo ">>> Update current DBRelease link"
singularity exec -w -B /data/yangw/uncvmfs/root/cvmfs:/mnt $latestsingimg sh -x <<EOF
#!/bin/sh
cd /mnt/atlas.cern.ch/repo/sw/database/DBRelease
tgtdbrel=\$(readlink current)
cd /cvmfs/atlas.cern.ch/repo/sw/database/DBRelease
rm -rf \$tgtdbrel
ln -s current \$tgtdbrel
EOF
 
echo ">>> shrine the image size"
tmpimg=$latestsingimg.TMP
dd if=$latestsingimg bs=1M count=1 | dd ibs=31 skip=1 of=$tmpimg
dd if=$latestsingimg bs=1M skip=1 of=$tmpimg oflag=append conv=notrunc
sync
resize2fs -f -M $tmpimg 
dd if=$latestsingimg ibs=31 count=1 > $latestsingimg.$cmt
dd if=$tmpimg bs=1M of=$latestsingimg.$cmt oflag=append conv=notrunc
rm $tmpimg
date
