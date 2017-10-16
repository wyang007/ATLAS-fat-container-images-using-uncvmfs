# Build ATLAS Fat Container Images using Uncvmfs
Scripts and configuration files in this repo is used to create Singularity and [Shifter](https://github.com/NERSC/shifter) container images with a base CentOS 6 OS environment, plus most of the /cvmfs/atlas.cern.ch. This container is usually several O(100) GB in size. They can be used at HPC sites with Singularity or Shifter is available, but CVMFS is not available.

Fat containers like this is used to distribute software for the LHC ATLAS experiment to places like HPC centers and opportunisitc sites, where CVMFS is not available. It is also a good (and proven) method to avoid putting high IO load (mainly file look up) on those HPC's shared file systems.  

## The Build Environment
The build environment should be a CentOS 7 machine with "uncvmfs" and squashfs-tools, singularity 2.3.1+, [bbcp](https://www.slac.stanford.edu/~abh/bbcp/), and 2TB+ ext3 file system mounted at /data/yangw/uncvmfs. It also assume sufficient space (2TB+) in /data/yangw/images to hold images.

The build environment has a one time dependence on /cvmfs/atlas.cern.ch/repo/sw/local/x86_64-slc5-gcc43-opt/yampl, though this can be copied from elsewhere to /data/yangw/uncvmfs/root/cvmfs/...

## Directory Tree
/data/yangw/uncvmfs/metadata is used to host uncvmfs metadata

/data/yangw/uncvmfs/cvmfs is used to host extracted cvmfs tree such as /cvmfs/atlas-condb.cern.ch, but not /cvmfs/atlas.cern.ch

/data/yangw/uncvmfs/root is used to host the CentOS 6 (it came from /cvmfs/atlas.cern.ch/repo/images/singularity/x86_64-centos6.img). 

extracted /cvmfs/atlas.cern.ch is placed under /data/yangw/uncvmfs/root/cvmfs

## Uncvmfs
[Uncvmfs](https://github.com/ic-hep/uncvmfs) is used to extract files from /cvmfs/... It also de-duplicate to as much as the file system (/data/yangw/uncvmfs) allows. For this reason, we choose ext3 filesystem for /data/yangw/uncvmfs (because the default singularity images use ext3 filesystem).

The role of uncvmfs can be replaced by other tool such as Stratrum-R.
