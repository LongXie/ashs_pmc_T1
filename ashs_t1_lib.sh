#!/bin/bash
source dss_common.sh

# Set the path to ASHS
export ASHS_ROOT=/data/picsl/pauly/wolk/ashs-fast
ASHS_ATLAS=/home/longxie/ASHS_T1/ASHSexp/exp201/atlas/final
MATLAB_BIN=/share/apps/matlab/R2017a/bin/matlab
SRMATLABCODEDIR=/home/longxie/ASHS_PHC/SuperResolution/SRToolBox/matlabfunction
C3DPATH=$ASHS_ROOT/ext/$(uname)/bin/

# TMPDIR
if [[ ! $TMPDIR ]]; then
  TMPDIR=/tmp
fi

function SR()
{
  infile=$1
  outfile=$2

  # get orientation code
  orient_code=$($C3DPATH/c3d $infile -info | cut -d ';' -f 5 | cut -d ' ' -f 5)
  if [[ $orient_code == "Oblique," ]]; then
  orient_code=$($C3DPATH/c3d $infile -info | cut -d ';' -f 5 | cut -d ' ' -f 8)
  fi

  # determine upsample factors
  IDX=999
  for ((i=0;i<3;i++)); do
    CODE=$(echo ${orient_code:$i:1})
    if [[ $CODE == "A" || $CODE == "P" ]]; then
      IDX=$i
    fi
  done
  if [[ $IDX == 0 ]]; then
    RS="100x200x200%"
    RS1="1,2,2"
  elif [[ $IDX == 1 ]]; then
    RS="200x100x200%"
    RS1="2,1,2"
  elif [[ $IDX == 2 ]]; then
    RS="200x200x100%"
    RS1="2,2,1"
  else
    echo "ERROR: invalid orientation code $orient_code of the T1 scan."
    exit
  fi

  # perform upsampling
  # unzip file
  gunzip -f -c  $infile > \
    $TMPDIR/${filename}.nii

  $C3DPATH/c3d $TMPDIR/${filename}.nii \
    -resample $RS \
    -o $TMPDIR/${filename}_upsampled.nii

  # run matlab to denoise T1 and T2 images
  $MATLAB_BIN -nojvm -nosplash -nodesktop <<-MATCODE
    addpath('$SRMATLABCODEDIR/denoising');
    denoise('$TMPDIR/${filename}.nii','$TMPDIR/${filename}_denoised.nii');

    disp('Done denoising!');

    addpath('$SRMATLABCODEDIR/NLMUpsample');
    NLMUpsample2_v2('$TMPDIR/${filename}_denoised.nii','$TMPDIR/${filename}_upsampled.nii','$TMPDIR/${filename}_denoised_SR.nii',${RS1});

    disp('Done upsampling')

MATCODE

  $C3DPATH/c3d $TMPDIR/${filename}_denoised_SR.nii \
      -clip 0 inf \
      -o $outfile
}


