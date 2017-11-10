#!/bin/sh
# valid the singularity image:

# singularity exec image_file sh this_scrip

export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
source $ATLAS_LOCAL_ROOT_BASE/user/atlasLocalSetup.sh --quiet
localSetupROOT
which root
export RUCIO_ACCOUNT="yangw"
localSetupRucioClients
which rucio
voms-proxy-info -all
