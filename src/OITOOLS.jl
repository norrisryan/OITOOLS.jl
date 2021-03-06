module OITOOLS
include("readoifits.jl");
include("write_oifits_ha.jl");
include("write_oifits_obs.jl");
include("simulate.jl");
include("oichi2.jl");
include("oiplot.jl");
include("vis_functions_classic.jl");
include("modelfit.jl");
include("utils.jl");
include("astrometry.jl");
export OIdata
export uvplot, onclickidentify, v2plot,v2plot_timelapse, t3phiplot, imdisp, imdisp_temporal, v2plot_modelvsdata, v2plot_modelvsfunc,v2plot,t3phiplot,v2plot_multifile,get_baseline_list,get_baseline_list_t3phi,imdisp_multiwave,imdisp_polychromatic
export readoifits, readoifits_multiepochs, readfits, writefits
export setup_dft, setup_nfft,setup_nfft_multiepochs, mod360, cvis_to_v2,cvis_to_t3, image_to_cvis_dft,image_to_cvis_nfft,chi2_dft_f,chi2_nfft_f,chi2_vis_nfft_f,chi2_vis_dft_fg,chi2_vis_nfft_fg,gaussian2d,cdg,reg_centering,tvsq,tv,regularization,crit_dft_fg,crit_nfft_fg, chi2_dft_fg,chi2_nfft_fg,crit_nfft_fg,crit_multitemporal_nfft_fg,reconstruct,reconstruct_multitemporal
export visibility_ud, visibility_ldpow, visibility_ldquad, visibility_ldlin, visibility_annulus
export fit_model_v2,bootstrap_v2_fit,fit_model_v2_nest,resample_v2_data
export get_uv,get_uv_indxes,get_simulated_image,prep_arrays,read_array_file,read_obs_file,read_comb_file,read_wave_file,simulate_ha,simulate_obs,cvis_to_t3_conj,get_v2_baselines,v2mapt3,get_t3_baselines,hour_angle_calc
export write_oi_header,write_oi_array,write_oi_target,write_oi_wavelength,write_oi_vis2,write_oi_t3
export readoifits_multicolors,setup_nfft_polychromatic,imdisp_polychromatic,reconstruct_polychromatic
export facility_info,obsv_info,combiner_info,wave_info,error_struct,read_facility_file,read_obs_file,read_wave_file,read_comb_file,define_errors
export make_spot_move,place_spot,make_disk
export setup_nfft_t4, cvis_to_t4
export model_chi2_v2,chi2_sparco_nfft_f,chi2_sparco_nfft_f_alt, chi2_sparco_nfft_fg,reconstruct_sparco_gray
export facility_info, obsv_info, combiner_info, wave_info, error_struct
export hours_to_hms, sunrise_sunset, hour_angle_calc, mjd_to_utc,dates_to_jd,jd_to_hour_angle,opd_limits,alt_az,geometric_delay,cart_delay
export query_simbad, ra_dec_from_simbad
end
