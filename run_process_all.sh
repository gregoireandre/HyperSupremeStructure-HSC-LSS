#!/bin/bash

predir_out=/global/cscratch1/sd/damonge/HSC

do_cleanup=false
do_process=false
do_sysmap=false
do_cat_sample=true
do_power_spectra=false

recompute_mcm=false
covar_option=data
pz_bins_file=4bins_hsc #Currently available: nbins (with n=1,2,3,4,5,6) and 4bins_hsc (HSC shear binning)
ell_bins_file=200 #Currently available: 400 (constant bandpowers with width 400) and hsc (HSC ell binning)
theory_prediction_file=NONE
nz_method=pdfstack #Currently available: zmc, pdfstack, cosmos30

#First clean up the metadata
for table in WIDE DEEP UDEEP
do
    if [ "$do_cleanup" = true ]; then
	python process_metadata.py --input-file ${predir_out}/HSC_${table}_frames.fits --output-file ${predir_out}/HSC_processed/HSC_${table}_frames_proc.fits
    fi
done

#Now clean up the WIDE and DEEP fields
for field in WIDE_AEGIS WIDE_GAMA09H WIDE_GAMA15H WIDE_HECTOMAP WIDE_VVDS WIDE_WIDE12H WIDE_XMMLSS DEEP_COSMOS DEEP_DEEP23 DEEP_ELAISN1 DEEP_XMMLSS UDEEP_COSMOS UDEEP_SXDS
do
    dirname=${predir_out}/HSC_processed/${field}
    mkdir -p ${dirname}
    if [ "$do_process" = true ]; then
	echo $field
	python process.py --input-field ${field} --resolution 0.01 --field-padding 0.1 --output-prefix ${dirname}/${field} --save-systematics --save-masks --save-depth-maps --min-snr 10.0 --depth-cut 24.5 --flat-project CAR
    fi
done

#Compute per-frame systematic maps
for field in WIDE_AEGIS WIDE_GAMA09H WIDE_GAMA15H WIDE_HECTOMAP WIDE_VVDS WIDE_WIDE12H WIDE_XMMLSS
do
    if [ "$do_sysmap" = true ]; then
	echo $field
	dirname=${predir_out}/HSC_processed/${field}
	python map_obscond.py --input-frames ${predir_out}/HSC_processed/HSC_WIDE_frames_proc.fits --map-sample ${dirname}/${field}_MaskedFraction.fits --output-prefix ${dirname}/${field}
    fi
done

#Compute galaxy count maps for each field
for field in WIDE_AEGIS WIDE_GAMA09H WIDE_GAMA15H WIDE_HECTOMAP WIDE_VVDS WIDE_WIDE12H WIDE_XMMLSS
do
    if [ "$do_cat_sample" = true ]; then
	echo $field
	dirname=${predir_out}/HSC_processed/${field}
	exc="python cat_sampler.py --input-prefix ${dirname}/${field} --output-file ${dirname}/${field}_Ngal_bins_eab_best_pzb${pz_bins_file}_${nz_method}.fits --pz-type ephor_ab --pz-mark best --pz-bins photoz_binning/photoz_bin_edges_${pz_bins_file}.txt --map-sample ${dirname}/${field}_MaskedFraction.fits --analysis-band i --depth-cut 24.5 --nz-max 4. --nz-bins 100"
	if [ "$nz_method" = pdfstack ]; then
	    exc+=" --use-pdf=True"
	elif [ "$nz_method" = cosmos30 ]; then
	    exc+=" --use-cosmos=True"
	fi
	${exc}
    fi
done

#Compute cross-power spectra for each field
for field in WIDE_AEGIS WIDE_GAMA09H WIDE_GAMA15H WIDE_HECTOMAP WIDE_VVDS WIDE_WIDE12H WIDE_XMMLSS
do
    if [ "$do_power_spectra" = true ]; then
	echo $field
	dirname=${predir_out}/HSC_processed/${field}
	fname_mcm=${dirname}/${field}_bpw${ell_bins_file}_mcm.dat
	fname_cov_mcm=${dirname}/${field}_bpw${ell_bins_file}_cov_mcm.dat
	if [ "$recompute_mcm" = true ]; then	
	    rm -f ${fname_mcm} ${fname_cov_mcm}
	fi
	python power_specter.py --output-file ${dirname}/${field}_spectra_eab_best_pzb${pz_bins_file}_bpw${ell_bins_file}_cov${covar_option}_cont_dpt_dst_str_ams_fwh_ssk.sacc --input-prefix ${dirname}/${field} --input-maps ${dirname}/${field}_Ngal_bins_eab_best_pzb${pz_bins_file}_${nz_method}.fits --ell-bins ell_binning/ell_bins_${ell_bins_file}.txt --mcm-output ${fname_mcm} --hsc-field HSC_${field} --covariance-option ${covar_option} --theory-prediction ${theory_prediction_file} --covariance-coupling-file ${fname_cov_mcm} --cont-depth --cont-dust --cont-stars --cont-oc airmass,seeing,sigma_sky --cont-deproj-bias --cont-deproj-bias-option ${covar_option}
	python power_specter.py --output-file ${dirname}/${field}_spectra_eab_best_pzb${pz_bins_file}_bpw${ell_bins_file}_cov${covar_option}_nocont.sacc                       --input-prefix ${dirname}/${field} --input-maps ${dirname}/${field}_Ngal_bins_eab_best_pzb${pz_bins_file}_${nz_method}.fits --ell-bins ell_binning/ell_bins_${ell_bins_file}.txt --mcm-output ${fname_mcm} --hsc-field HSC_${field} --covariance-option ${covar_option} --theory-prediction ${theory_prediction_file} --covariance-coupling-file ${fname_cov_mcm}
    fi
done

#So far we've only looked at the WIDE fields
exit

for field in COSMOS_WIDE_BEST COSMOS_WIDE_MEDIAN COSMOS_WIDE_WORST 
do
    dirname=${predir_out}/HSC_processed/${field}
    mkdir -p ${dirname}
    python process.py --input-field ${field} --resolution 0.01 --field-padding 0.1 --output-prefix ${dirname}/${field} --save-systematics --save-masks --save-depth-maps --gen-plots --min-snr 10.0 --depth-cut 24.5
done

for field in DEEP_COSMOS DEEP_DEEP32 DEEP_ELAISN1 DEEP_XMMLSS
do
    dirname=${predir_out}/HSC_processed/${field}
    mkdir -p ${dirname}
    python process.py --input-field ${field} --resolution 0.01 --field-padding 0.1 --output-prefix ${dirname}/${field} --save-systematics --save-masks --save-depth-maps --gen-plots --min-snr 10.0 --depth-cut 24.5
done

for field in UDEEP_COSMOS UDEEP_SXDS
do
    dirname=${predir_out}/HSC_processed/${field}
    mkdir -p ${dirname}
    python process.py --input-field ${field} --resolution 0.01 --field-padding 0.1 --output-prefix ${dirname}/${field} --save-systematics --save-masks --save-depth-maps --gen-plots --min-snr 10.0 --depth-cut 24.5
done
