using FITSIO
using OIFITS
using Statistics

include("remove_redundance.jl")
mutable struct OIdata
  visamp::Array{Float64,1}
  visamp_err::Array{Float64,1}
  visphi::Array{Float64,1}
  visphi_err::Array{Float64,1}
  v2::Array{Float64,1}
  v2_err::Array{Float64,1}
  v2_baseline::Array{Float64,1}
  v2_mjd::Array{Float64,1}
  mean_mjd::Float64
  v2_lam::Array{Float64,1}
  v2_dlam::Array{Float64,1}
  v2_flag::Array{Bool,1}
  t3amp::Array{Float64,1}
  t3amp_err::Array{Float64,1}
  t3phi::Array{Float64,1}
  t3phi_err::Array{Float64,1}
  t3_baseline::Array{Float64,1}
  t3_maxbaseline::Array{Float64,1}
  t3_mjd::Array{Float64,1}
  t3_lam::Array{Float64,1}
  t3_dlam::Array{Float64,1}
  t3_flag::Array{Bool,1}
  uv::Array{Float64,2}
  nvisamp::Int64
  nvisphi::Int64
  nv2::Int64
  nt3amp::Int64
  nt3phi::Int64
  nuv::Int64
  indx_v2::Array{Int64,1}
  indx_t3_1::Array{Int64,1}
  indx_t3_2::Array{Int64,1}
  indx_t3_3::Array{Int64,1}
  sta_name::Array{String,1}
  tel_name::Array{String,1}
  sta_index::Array{Int64,1}
  v2_sta_index::Array{Int64,2}
  t3_sta_index::Array{Int64,2}
end

# Experimental version with target fitering for NPOI
#  How to use the readoifits_timespec function:
#    - Insert the name of your oifits file to readoifits_timespec
#    - If user wants to have a spectral bin, one could put as
#    spectralbin = [[1.e-6,1.5e-6]] (e.g., in microns) where this array would only
#    include wavelengths within this range. If spectralbin = [[1.e-6,1.5e-6],[1.5e-6,1.6e-6,1.6e-6,1.7e-6]]
#    then the first array would be an array of wavelengths from a given interval and
#    the second array would be a set of ranges in which the user wants their data
#    individually from the first set. This code can also "exclude" ranges into a
#    seperate array [[1.e-6,1.5e-6,1.6e-6,2.e-6],[1.5e-6,1.6e-6]] where the first
#    array is all the data from 1.e-6 to 1.5e-6 microns AND 1.6e-6 to 2.e-6 microns.
#    That second array would only include data from 1.5e-6 to 1.6e-6 (e.g., used for
#    when there would be a feature to be studied, like an emission line).
#    - temporalbin works the same way as spectralbin.
#
#    How to use the time_split function:
#    Once readoifits_timespec is given a first run through, then if the user wanted
#    to split up data with a given period (in days), the user inputs the full mjd
#    and the period desired. The output would be a temporalbin that could be used on
#    readoifits_timespec second run though. This is in the range of [start, end).


function readoifits(oifitsfile; targetname ="", spectralbin=[[]], temporalbin=[[]], binning = false,  get_specbin_file=true, get_timebin_file=true,redundance_chk=false,uvtol=1.e3, filter_bad_data=false, force_full_t3 = false, filter_v2_snr_threshold=0.5)
  # oifitsfile="AlphaCenA.oifits";spectralbin=[[]]; temporalbin=[[]];  get_specbin_file=false; get_timebin_file=true;redundance_chk=true;uvtol=1.e3;
  tables = OIFITS.load(oifitsfile);
  wavtable = OIFITS.select(tables,"OI_WAVELENGTH");
  wavtableref = [wavtable[i][:insname] for i=1:length(wavtable)];

  # In case of multiple targets (NPOI !), select only the corresponding data
  targetid_filter = [];
  targettables = OIFITS.select(tables, "OI_TARGET");
  if(targetname !="")
    if length(targettables)>1
      error("The OIFITS file has several target tables -- import not implemented yet for this case");
    else
      targettables = targettables[1];
    end
    targetid_filter = targettables[:target_id][findall(targettables[:target].==targetname)]; # match target ids to target name
  else
    targetid_filter = [targettables[i][:target_id] for i=1:length(targettables)];
  end

  arraytables=OIFITS.select(tables,"OI_ARRAY")
  array_ntables=length(arraytables)

#get info from array tables_
  station_name=Array{Array{String,1}}(undef, array_ntables)
  telescope_name=Array{Array{String,1}}(undef, array_ntables);
  station_index=Array{Array{Int64,1}}(undef, array_ntables);
  v2_sta_index=Array{Array{Int64,2}}(undef, array_ntables);
  t3_sta_index=Array{Array{Int64,3}}(undef, array_ntables);


  for itable = 1:array_ntables
      station_name[itable] = arraytables[itable][:sta_name]; # station_names
      telescope_name[itable] = arraytables[itable][:tel_name]; # tel_names
      station_index[itable] = arraytables[itable][:sta_index]; # station_indexes for matchin names to indexes in v2 and t3
  end


  v2table = OIFITS.select(tables,"OI_VIS2");
  v2_ntables = length(v2table);

  t3table = OIFITS.select(tables,"OI_T3");
  t3_ntables = length(t3table);

  # get V2 data from tables
  v2_old = Array{Array{Float64,2}}(undef, v2_ntables);
  v2_err_old = Array{Array{Float64,2}}(undef,v2_ntables);
  v2_ucoord_old = Array{Array{Float64,1}}(undef,v2_ntables);
  v2_vcoord_old = Array{Array{Float64,1}}(undef,v2_ntables);
  v2_mjd_old = Array{Array{Float64,2}}(undef,v2_ntables);
  v2_lam_old = Array{Array{Float64,2}}(undef,v2_ntables);
  v2_dlam_old = Array{Array{Float64,2}}(undef,v2_ntables);
  v2_flag_old = Array{Array{Bool,2}}(undef,v2_ntables);
  v2_u_old = Array{Array{Float64,1}}(undef,v2_ntables);
  v2_v_old = Array{Array{Float64,1}}(undef,v2_ntables);
  v2_uv_old = Array{Array{Float64,2}}(undef,v2_ntables);
  v2_baseline_old = Array{Array{Float64,1}}(undef,v2_ntables);
  v2_sta_index_old=Array{Array{Int64,2}}(undef, v2_ntables);
  v2_station_index_old=Array{Array{Int64,2}}(undef, v2_ntables);
  for itable = 1:v2_ntables
    v2_targetid_filter = findall(sum([v2table[itable][:target_id].==targetid_filter[i] for i=1:length(targetid_filter)],dims=1)[1].>0);
    v2_old[itable] = v2table[itable][:vis2data][:,v2_targetid_filter]; # Visibility squared
    v2_err_old[itable] = v2table[itable][:vis2err][:,v2_targetid_filter]; # error in Visibility squared
    v2_ucoord_old[itable] = -v2table[itable][:ucoord][v2_targetid_filter]; # u coordinate in uv plane
    v2_vcoord_old[itable] = v2table[itable][:vcoord][v2_targetid_filter]; #  v coordinate in uv plane
    v2_mjd_old[itable] = repeat(v2table[itable][:mjd][v2_targetid_filter]',
    outer=[size(v2_old[itable],1),1]); # Modified Julian Date (JD - 2400000.5)
    v2_sta_index_old[itable]=v2table[itable][:sta_index][:,v2_targetid_filter]  #station index
    whichwav = findall(v2table[itable][:insname].==wavtableref);
    if (length(whichwav) != 1)
      error("Wave table confusion -- Missing table ?\n");
    end
    v2_lam_old[itable] = repeat(wavtable[whichwav[1]][:eff_wave],  outer=[1,size(v2_old[itable],2)]); # spectral channels
    v2_dlam_old[itable] = repeat(wavtable[whichwav[1]][:eff_band], outer=[1,size(v2_old[itable],2)]); # width of spectral channels
    v2_flag_old[itable] = v2table[itable][:flag][:,v2_targetid_filter]; # flag for v2 table
    nv2_lam_old = length(v2_lam_old[itable][:,1]);
    v2_u_old[itable] = Float64[];
    v2_v_old[itable] = Float64[];
    v2_station_index_old[itable]=vcat(Int64[]',Int64[]')
    for u = 1:length(v2_ucoord_old[itable])
      v2_u_old[itable] = vcat(v2_u_old[itable],
      v2_ucoord_old[itable][u]./v2_lam_old[itable][:,1]);
      v2_v_old[itable] = vcat(v2_v_old[itable],
      v2_vcoord_old[itable][u]./v2_lam_old[itable][:,1]);
      v2_station_index_old[itable]=hcat(v2_station_index_old[itable],repeat(v2_sta_index_old[itable][:,u],outer=[1,8]))
    end
    v2_uv_old[itable] = hcat(vec(v2_u_old[itable]),vec(v2_v_old[itable]));
    v2_baseline_old[itable] = vec(sqrt.(v2_u_old[itable].^2 + v2_v_old[itable].^2));
  end

  # same with T3, VIS
  # Get T3 data from tables
  t3amp_old = Array{Array{Float64,2}}(undef,t3_ntables);
  t3amp_err_old = Array{Array{Float64,2}}(undef,t3_ntables);
  t3phi_old = Array{Array{Float64,2}}(undef,t3_ntables);
  t3phi_err_old = Array{Array{Float64,2}}(undef,t3_ntables);
  t3_u1coord_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_v1coord_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_u2coord_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_v2coord_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_u3coord_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_v3coord_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_mjd_old = Array{Array{Float64,2}}(undef,t3_ntables);
  t3_lam_old = Array{Array{Float64,2}}(undef,t3_ntables);
  t3_dlam_old = Array{Array{Float64,2}}(undef,t3_ntables);
  t3_flag_old = Array{Array{Bool,2}}(undef,t3_ntables);
  t3_u1_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_v1_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_u2_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_v2_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_u3_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_v3_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_baseline_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_maxbaseline_old = Array{Array{Float64,1}}(undef,t3_ntables);
  t3_sta_index_old=Array{Array{Int64,2}}(undef, t3_ntables);
  t3_station_index_old=Array{Array{Int64,2}}(undef, t3_ntables);
  for itable = 1:t3_ntables
    t3_targetid_filter = findall(sum([t3table[itable][:target_id].==targetid_filter[i] for i=1:length(targetid_filter)],dims=1)[1].>0);
    t3amp_old[itable] = t3table[itable][:t3amp][:,t3_targetid_filter];
    t3amp_err_old[itable] = t3table[itable][:t3amperr][:,t3_targetid_filter];
    t3phi_old[itable] = t3table[itable][:t3phi][:,t3_targetid_filter];
    t3phi_err_old[itable] = t3table[itable][:t3phierr][:,t3_targetid_filter];
    t3_u1coord_old[itable] = -t3table[itable][:u1coord][t3_targetid_filter];
    t3_v1coord_old[itable] = t3table[itable][:v1coord][t3_targetid_filter];
    t3_u2coord_old[itable] = -t3table[itable][:u2coord][t3_targetid_filter];
    t3_v2coord_old[itable] = t3table[itable][:v2coord][t3_targetid_filter];
    t3_u3coord_old[itable] = -(t3_u1coord_old[itable] + t3_u2coord_old[itable]); # the minus takes care of complex conjugate
    t3_v3coord_old[itable] = -(t3_v1coord_old[itable] + t3_v2coord_old[itable]);
    t3_mjd_old[itable] = repeat(t3table[itable][:mjd][t3_targetid_filter]',
    outer=[size(t3amp_old[itable],1),1]); # Modified Julian Date (JD - 2400000.5)
    t3_sta_index_old[itable]=t3table[itable][:sta_index][:,t3_targetid_filter]
    whichwav = findall(t3table[itable][:insname].==wavtableref);
    t3_lam_old[itable] = repeat(wavtable[whichwav[1]][:eff_wave],
    outer=[1,size(t3amp_old[itable],2)]); # spectral channels
    t3_dlam_old[itable] = repeat(wavtable[whichwav[1]][:eff_band],
    outer=[1,size(t3amp_old[itable],2)]); # width of spectral channels
    t3_flag_old[itable] = t3table[itable][:flag][:,t3_targetid_filter]; # flag for t3 table
    nt3_lam_old = length(t3_lam_old[itable][:,1]);

    t3_u1_old[itable] = Float64[];
    t3_v1_old[itable] = Float64[];
    t3_u2_old[itable] = Float64[];
    t3_v2_old[itable] = Float64[];
    t3_u3_old[itable] = Float64[];
    t3_v3_old[itable] = Float64[];
    t3_station_index_old[itable]=vcat(Int64[]',Int64[]',Int64[]')
    for u = 1:length(t3_u1coord_old[itable])
      t3_u1_old[itable] = vcat(t3_u1_old[itable],t3_u1coord_old[itable][u]./t3_lam_old[itable][:,1]);
      t3_v1_old[itable] = vcat(t3_v1_old[itable],t3_v1coord_old[itable][u]./t3_lam_old[itable][:,1]);
      t3_u2_old[itable] = vcat(t3_u2_old[itable],t3_u2coord_old[itable][u]./t3_lam_old[itable][:,1]);
      t3_v2_old[itable] = vcat(t3_v2_old[itable],t3_v2coord_old[itable][u]./t3_lam_old[itable][:,1]);
      t3_u3_old[itable] = vcat(t3_u3_old[itable],t3_u3coord_old[itable][u]./t3_lam_old[itable][:,1]);
      t3_v3_old[itable] = vcat(t3_v3_old[itable],t3_v3coord_old[itable][u]./t3_lam_old[itable][:,1]);
      t3_station_index_old[itable]=hcat(t3_station_index_old[itable],repeat(t3_sta_index_old[itable][:,u],outer=[1,8]))
    end

    t3_baseline_old[itable] = vec((sqrt.(t3_u1_old[itable].^2 + t3_v1_old[itable].^2).*sqrt.(t3_u2_old[itable].^2 + t3_v2_old[itable].^2).*
    sqrt.(t3_u3_old[itable].^2 + t3_v3_old[itable].^2)).^(1.0/3.0));
    t3_maxbaseline_old[itable] = vec(max.(sqrt.(t3_u1_old[itable].^2 + t3_v1_old[itable].^2), sqrt.(t3_u2_old[itable].^2 + t3_v2_old[itable].^2), sqrt.(t3_u3_old[itable].^2 + t3_v3_old[itable].^2)));

  end

  # combine all data into one
  v2_all = Float64[];
  v2_err_all = Float64[];
  v2_mjd_all = Float64[];
  v2_lam_all = Float64[];
  v2_dlam_all = Float64[];
  v2_flag_all = Bool[];
  v2_uv_all = vcat(Float64[]',Float64[]');
  v2_baseline_all = Float64[];
  v2_sta_index_all=vcat(Int64[]',Int64[]')
  t3amp_all = Float64[];
  t3amp_err_all = Float64[];
  t3phi_all = Float64[];
  t3phi_err_all = Float64[];
  t3_mjd_all = Float64[];
  t3_lam_all = Float64[];
  t3_dlam_all = Float64[];
  t3_flag_all = Float64[];
  t3_u1_all = Float64[];
  t3_v1_all = Float64[];
  t3_u2_all = Float64[];
  t3_v2_all = Float64[];
  t3_u3_all = Float64[];
  t3_v3_all = Float64[];
  t3_uv_all = vcat(Float64[]',Float64[]');
  t3_sta_index_all=vcat(Int64[]',Int64[]',Int64[]')
  t3_baseline_all = Float64[];
  t3_maxbaseline_all = Float64[];

  for i = 1:v2_ntables
    v2_all = vcat(v2_all,vec(v2_old[i]));
    v2_err_all = vcat(v2_err_all,vec(v2_err_old[i]));
    v2_mjd_all = vcat(v2_mjd_all,vec(v2_mjd_old[i]));
    v2_lam_all = vcat(v2_lam_all,vec(v2_lam_old[i]));
    v2_dlam_all = vcat(v2_dlam_all,vec(v2_dlam_old[i]));
    v2_flag_all = vcat(v2_flag_all,vec(v2_flag_old[i]));
    v2_uv_all = hcat(v2_uv_all,v2_uv_old[i]'); # Must have in this form for Fourier transform
    v2_baseline_all = vcat(v2_baseline_all,vec(v2_baseline_old[i]));
    v2_sta_index_all=hcat(v2_sta_index_all,v2_station_index_old[i])
  end

  for i = 1:t3_ntables
    t3amp_all = vcat(t3amp_all,vec(t3amp_old[i]));
    t3amp_err_all = vcat(t3amp_err_all,vec(t3amp_err_old[i]));
    t3phi_all = vcat(t3phi_all,vec(t3phi_old[i]));
    t3phi_err_all = vcat(t3phi_err_all,vec(t3phi_err_old[i]));
    t3_mjd_all = vcat(t3_mjd_all,vec(t3_mjd_old[i]));
    t3_lam_all = vcat(t3_lam_all,vec(t3_lam_old[i]));
    t3_dlam_all = vcat(t3_dlam_all,vec(t3_dlam_old[i]));
    t3_flag_all = vcat(t3_flag_all,vec(t3_flag_old[i]));
    t3_u1_all = vcat(t3_u1_all,vec(t3_u1_old[i]));
    t3_v1_all = vcat(t3_v1_all,vec(t3_v1_old[i]));
    t3_u2_all = vcat(t3_u2_all,vec(t3_u2_old[i]));
    t3_v2_all = vcat(t3_v2_all,vec(t3_v2_old[i]));
    t3_u3_all = vcat(t3_u3_all,vec(t3_u3_old[i]));
    t3_v3_all = vcat(t3_v3_all,vec(t3_v3_old[i]));
    #t3_uv_all = hcat(t3_uv_all,t3_uv_old[i]'); # Must have in this form for Fourier transform
    t3_baseline_all = vcat(t3_baseline_all,vec(t3_baseline_old[i]));
    t3_maxbaseline_all = vcat(t3_maxbaseline_all,vec(t3_maxbaseline_old[i]));
    t3_sta_index_all=hcat(t3_sta_index_all,t3_station_index_old[i])
  end
  t3_uv_all = hcat(vcat(t3_u1_all,t3_u2_all,t3_u3_all),vcat(t3_v1_all,t3_v2_all,t3_v3_all))';

#
# Binning logic
#

  if (temporalbin != [[]])||(spectralbin != [[]])
    binning = true
  end

  # calculate default timebin if user picks timebin = [[]]
  if ((temporalbin == [[]]) && (get_timebin_file == true))
    temporalbin = [[]]
    temporalbin[1] = [minimum(v2_mjd_all),maximum(v2_mjd_all)]; # start & end mjd
    temporalbin[1][2] += 0.001
  end

  # get spectralbin if get_spectralbin_from_file == true
  if ((spectralbin == [[]]) && (get_specbin_file == true))
    spectralbin[1] = vcat(spectralbin[1], minimum(v2_lam_all)-minimum(v2_dlam_all[argmin(v2_lam_all)])*0.5, maximum(v2_lam_all)+maximum(v2_dlam_all[argmax(v2_lam_all)])*0.5);
  end

  # count how many spectral bins user input into file
  nspecbin_old = length(spectralbin);
  ncombspec = Int(length(spectralbin[1])/2);
  if (nspecbin_old == 1) # exclude other data
    nspecbin = ntotspec = 1;
  elseif (nspecbin_old == 2)
    nsplitspec = Int(length(spectralbin[2])/2);
    ntotspec = ncombspec + nsplitspec;
    nspecbin = Int(1) + nsplitspec;
  end

  # count how many temporal bins user input into file
  ntimebin_old = length(temporalbin);
  ncombtime = Int(length(temporalbin[1])/2);
  if (ntimebin_old == 1)
    ntimebin = ntottime = 1;
  elseif (ntimebin_old == 2)
    nsplittime = Int(length(temporalbin[2])/2);
    ntottime = ncombtime + nsplittime;
    ntimebin = Int(1) + nsplittime;
  end

  OIdataArr = Array{OIdata}(undef, nspecbin,ntimebin);

  # Define new arrays so that they get binned properly
  v2_new = fill((Float64[]),nspecbin,ntimebin);
  v2_err_new = fill((Float64[]),nspecbin,ntimebin);
  v2_mjd_new = fill((Float64[]),nspecbin,ntimebin);
  v2_lam_new = fill((Float64[]),nspecbin,ntimebin);
  v2_dlam_new = fill((Float64[]),nspecbin,ntimebin);
  v2_flag_new = fill((Bool[]),nspecbin,ntimebin);
  v2_uv_new = fill((vcat(Float64[]',Float64[]')),nspecbin,ntimebin);
  v2_baseline_new = fill((Float64[]),nspecbin,ntimebin);
  t3amp_new = fill((Float64[]),nspecbin,ntimebin);
  t3amp_err_new = fill((Float64[]),nspecbin,ntimebin);
  t3phi_new = fill((Float64[]),nspecbin,ntimebin);
  t3phi_err_new = fill((Float64[]),nspecbin,ntimebin);
  t3_mjd_new = fill((Float64[]),nspecbin,ntimebin);
  t3_lam_new = fill((Float64[]),nspecbin,ntimebin);
  t3_dlam_new = fill((Float64[]),nspecbin,ntimebin);
  t3_flag_new = fill((Float64[]),nspecbin,ntimebin);
  t3_uv_new = fill((vcat(Float64[]',Float64[]')),nspecbin,ntimebin);
  t3_baseline_new = fill((Float64[]),nspecbin,ntimebin);
  t3_maxbaseline_new = fill((Float64[]),nspecbin,ntimebin);
  mean_mjd = Array{Float64}(undef, nspecbin,ntimebin);
  full_uv = Array{Array{Float64,2}}(undef, nspecbin,ntimebin);
  nv2 = Array{Int64}(undef,nspecbin,ntimebin);
  nt3amp = Array{Int64}(undef,nspecbin,ntimebin);
  nt3phi = Array{Int64}(undef,nspecbin,ntimebin);
  nuv = Array{Int64}(undef,nspecbin,ntimebin);
  indx_v2 = Array{Array{Int64,1}}(undef,nspecbin,ntimebin);
  indx_t3_1 = Array{Array{Int64,1}}(undef,nspecbin,ntimebin);
  indx_t3_2 = Array{Array{Int64,1}}(undef,nspecbin,ntimebin);
  indx_t3_3 = Array{Array{Int64,1}}(undef,nspecbin,ntimebin);
  v2_station_index_new=fill((vcat(Int64[]',Int64[]')),nspecbin,ntimebin);
  t3_station_index_new=fill((vcat(Int64[]',Int64[]',Int64[]')),nspecbin,ntimebin);


  iter_mjd = 0; iter_wav = 0;
  t3_uv_mjd = zeros(length(t3_mjd_all)*3);
  t3_uv_lam = zeros(length(t3_lam_all)*3);
  for i=1:length(t3_mjd_all)
    t3_uv_mjd[i*3-2:i*3] .= t3_mjd_all[i];
    t3_uv_lam[i*3-2:i*3] .= t3_lam_all[i];
  end

  # New iteration for binning data
  for itime = 1:ntottime
    # combine data to one bin
    iter_mjd += 1;
    if (itime <= ncombtime)
      itimebin = 1;
    else
      if (ncombtime == 0)
        itimebin = itime;
      else
        itimebin = itime - ncombtime + 1;
        if (itimebin == 2)
          iter_mjd = iter_mjd - ncombtime;
        end
      end
    end

    # get ranges for time binning
    if (itime == 1) # make sure logic is right
      lo_time = temporalbin[1][[(i%2 == 1) for i=1:length(temporalbin[1])]];
      hi_time = temporalbin[1][[(i%2 == 0) for i=1:length(temporalbin[1])]];
    else
      lo_time = temporalbin[2][[(i%2 == 1) for i=1:length(temporalbin[2])]];
      hi_time = temporalbin[2][[(i%2 == 0) for i=1:length(temporalbin[2])]];
    end

    for ispec = 1:ntotspec
      # combine data to one bin
      iter_wav += 1;
      if (ispec <= ncombspec)
        ispecbin = 1;
      else
        if (ncombspec == 0)
          ispecbin = ispec;
        else
          ispecbin = ispec - ncombspec + 1;
          if (ispecbin == 2)
            iter_wav = iter_wav - ncombspec;
          end
        end
      end

      # get ranges for wavelength binning
      if (ispec == 1) # make sure logic is right
        lo_wav = spectralbin[1][[(i%2 == 1) for i=1:length(spectralbin[1])]];
        hi_wav = spectralbin[1][[(i%2 == 0) for i=1:length(spectralbin[1])]];
      else
        lo_wav = spectralbin[2][[(i%2 == 1) for i=1:length(spectralbin[2])]];
        hi_wav = spectralbin[2][[(i%2 == 0) for i=1:length(spectralbin[2])]];
      end


      # Binning filter
      bin_v2=Bool[];bin_t3=Bool[]; bin_t3uv=Bool[]
      if binning == true
        bin_v2 = (v2_mjd_all.<=hi_time[iter_mjd]).&(v2_mjd_all.>=lo_time[iter_mjd]).&(v2_lam_all.<=hi_wav[iter_wav]).&(v2_lam_all.>=lo_wav[iter_wav]);
        bin_t3 = (t3_mjd_all.<=hi_time[iter_mjd]).&(t3_mjd_all.>=lo_time[iter_mjd]).&(t3_lam_all.<=hi_wav[iter_wav]).&(t3_lam_all.>=lo_wav[iter_wav]);
        bin_t3uv = (t3_uv_mjd.<=hi_time[iter_mjd]).&(t3_uv_mjd.>=lo_time[iter_mjd]).&(t3_uv_lam.<=hi_wav[iter_wav]).&(t3_uv_lam.>=lo_wav[iter_wav]);
        if length(findall(bin_v2.==false))>0
          print_with_color(:red, "$(length(findall(bin_v2.==false))) V2 points were filtered out during binning\n");
        end
        if length(findall(bin_t3.==false))>0
          print_with_color(:red, "$(length(findall(bin_t3.==false))) T3 points were filtered out during binning\n");
        end
        if length(findall(bin_t3uv.==false))>0
          print_with_color(:red, "$(length(findall(bin_t3uv.==false))) T3UV points were filtered out during binning\n");
        end
      else
        bin_v2 = Bool.(ones(length(v2_all)))
        bin_t3 = Bool.(ones(length(t3amp_all)))
        bin_t3uv = Bool.(ones(size(t3_uv_all,2)))
      end

      v2_new[ispecbin,itimebin] = vcat(v2_new[ispecbin,itimebin],v2_all[bin_v2]);
      v2_err_new[ispecbin,itimebin] = vcat(v2_err_new[ispecbin,itimebin],v2_err_all[bin_v2]);
      v2_mjd_new[ispecbin,itimebin] = vcat(v2_mjd_new[ispecbin,itimebin],v2_mjd_all[bin_v2]);
      v2_lam_new[ispecbin,itimebin] = vcat(v2_lam_new[ispecbin,itimebin],v2_lam_all[bin_v2]);
      v2_dlam_new[ispecbin,itimebin] = vcat(v2_dlam_new[ispecbin,itimebin],v2_dlam_all[bin_v2]);
      v2_flag_new[ispecbin,itimebin] = vcat(v2_flag_new[ispecbin,itimebin],v2_flag_all[bin_v2]);
      v2_uv_new[ispecbin,itimebin] = hcat(v2_uv_new[ispecbin,itimebin],vcat(v2_uv_all[1,:][bin_v2]',v2_uv_all[2,:][bin_v2]'));
      v2_baseline_new[ispecbin,itimebin] = vcat(v2_baseline_new[ispecbin,itimebin],v2_baseline_all[bin_v2]);
      v2_station_index_new[ispecbin,itimebin]=hcat(v2_station_index_new[ispecbin,itimebin],v2_sta_index_all[:,bin_v2]);


      t3amp_new[ispecbin,itimebin] = vcat(t3amp_new[ispecbin,itimebin],t3amp_all[bin_t3]);
      t3amp_err_new[ispecbin,itimebin] = vcat(t3amp_err_new[ispecbin,itimebin],t3amp_err_all[bin_t3]);
      t3phi_new[ispecbin,itimebin] = vcat(t3phi_new[ispecbin,itimebin],t3phi_all[bin_t3]);
      t3phi_err_new[ispecbin,itimebin] = vcat(t3phi_err_new[ispecbin,itimebin],t3phi_err_all[bin_t3]);
      t3_mjd_new[ispecbin,itimebin] = vcat(t3_mjd_new[ispecbin,itimebin],t3_mjd_all[bin_t3]);
      t3_lam_new[ispecbin,itimebin] = vcat(t3_lam_new[ispecbin,itimebin],t3_lam_all[bin_t3]);
      t3_dlam_new[ispecbin,itimebin] = vcat(t3_dlam_new[ispecbin,itimebin],t3_dlam_all[bin_t3]);
      t3_flag_new[ispecbin,itimebin] = vcat(t3_flag_new[ispecbin,itimebin],t3_flag_all[bin_t3]);
      t3_uv_new[ispecbin,itimebin] = hcat(t3_uv_new[ispecbin,itimebin],vcat(t3_uv_all[1,:][bin_t3uv]',t3_uv_all[2,:][bin_t3uv]'));
      t3_baseline_new[ispecbin,itimebin] = vcat(t3_baseline_new[ispecbin,itimebin],t3_baseline_all[bin_t3]);
      t3_maxbaseline_new[ispecbin,itimebin] = vcat(t3_maxbaseline_new[ispecbin,itimebin],t3_maxbaseline_all[bin_t3]);
      t3_station_index_new[ispecbin,itimebin]=hcat(t3_station_index_new[ispecbin,itimebin],t3_sta_index_all[:,bin_t3]);

      mean_mjd[ispecbin,itimebin] = mean(v2_mjd_new[ispecbin,itimebin]);
      full_uv[ispecbin,itimebin] = hcat(v2_uv_new[ispecbin,itimebin],t3_uv_new[ispecbin,itimebin]);
      nv2[ispecbin,itimebin] = length(v2_new[ispecbin,itimebin]);
      nt3amp[ispecbin,itimebin] = length(t3amp_new[ispecbin,itimebin]);
      nt3phi[ispecbin,itimebin] = length(t3phi_new[ispecbin,itimebin]);
      nuv[ispecbin,itimebin] = size(full_uv[ispecbin,itimebin],2);
      indx_v2[ispecbin,itimebin] = collect(1:nv2[ispecbin,itimebin]);
      indx_t3_1[ispecbin,itimebin] = collect(nv2[ispecbin,itimebin].+(1:nt3amp[ispecbin,itimebin]));
      indx_t3_2[ispecbin,itimebin] = collect(nv2[ispecbin,itimebin].+(nt3amp[ispecbin,itimebin]+1:2*nt3amp[ispecbin,itimebin]));
      indx_t3_3[ispecbin,itimebin] = collect(nv2[ispecbin,itimebin].+(2*nt3amp[ispecbin,itimebin]+1:3*nt3amp[ispecbin,itimebin]));

      if (redundance_chk == true) # temp fix?
        full_uv[ispecbin,itimebin], indx_redun = rm_redundance_kdtree(full_uv[ispecbin,itimebin],uvtol);
        nuv[ispecbin,itimebin] = size(full_uv[ispecbin,itimebin],2);
        indx_v2[ispecbin,itimebin] = indx_redun[indx_v2[ispecbin,itimebin]];
        indx_t3_1[ispecbin,itimebin] = indx_redun[indx_t3_1[ispecbin,itimebin]];
        indx_t3_2[ispecbin,itimebin] = indx_redun[indx_t3_2[ispecbin,itimebin]];
        indx_t3_3[ispecbin,itimebin] = indx_redun[indx_t3_3[ispecbin,itimebin]];
      end

      OIdataArr[ispecbin,itimebin] = OIdata([],[], [], [], v2_new[ispecbin,itimebin], v2_err_new[ispecbin,itimebin], v2_baseline_new[ispecbin,itimebin], v2_mjd_new[ispecbin,itimebin],
      mean_mjd[ispecbin,itimebin], v2_lam_new[ispecbin,itimebin], v2_dlam_new[ispecbin,itimebin], v2_flag_new[ispecbin,itimebin], t3amp_new[ispecbin,itimebin],
      t3amp_err_new[ispecbin,itimebin], t3phi_new[ispecbin,itimebin], t3phi_err_new[ispecbin,itimebin], t3_baseline_new[ispecbin,itimebin],t3_maxbaseline_new[ispecbin,itimebin],
      t3_mjd_new[ispecbin,itimebin], t3_lam_new[ispecbin,itimebin], t3_dlam_new[ispecbin,itimebin], t3_flag_new[ispecbin,itimebin], full_uv[ispecbin,itimebin],
      0, 0, nv2[ispecbin,itimebin], nt3amp[ispecbin,itimebin], nt3phi[ispecbin,itimebin], nuv[ispecbin,itimebin], indx_v2[ispecbin,itimebin],
      indx_t3_1[ispecbin,itimebin], indx_t3_2[ispecbin,itimebin], indx_t3_3[ispecbin,itimebin],station_name[1],telescope_name[1],station_index[:][1],v2_station_index_new[ispecbin,itimebin],t3_station_index_new[ispecbin,itimebin]);

      if (filter_bad_data==true)
        # Filter OBVIOUSLY bad V2 data
        v2_good = findall(  (OIdataArr[ispecbin,itimebin].v2_flag.==false) .& (OIdataArr[ispecbin,itimebin].v2_err.>0.0)
        .& (OIdataArr[ispecbin,itimebin].v2_err.<1.0) .& (OIdataArr[ispecbin,itimebin].v2.>-0.2)
        .& (OIdataArr[ispecbin,itimebin].v2.<1.2)
        .& .!isnan.(OIdataArr[ispecbin,itimebin].v2) .& .!isnan.(OIdataArr[ispecbin,itimebin].v2_err)
        .& (abs.(OIdataArr[ispecbin,itimebin].v2./OIdataArr[ispecbin,itimebin].v2_err).>filter_v2_snr_threshold))

        good_uv_v2 = OIdataArr[ispecbin,itimebin].indx_v2[v2_good]


        OIdataArr[ispecbin,itimebin].v2 = OIdataArr[ispecbin,itimebin].v2[v2_good]
        OIdataArr[ispecbin,itimebin].v2_err = OIdataArr[ispecbin,itimebin].v2_err[v2_good]
        OIdataArr[ispecbin,itimebin].v2_baseline = OIdataArr[ispecbin,itimebin].v2_baseline[v2_good]
        OIdataArr[ispecbin,itimebin].nv2 = length(OIdataArr[ispecbin,itimebin].v2)
        OIdataArr[ispecbin,itimebin].v2_mjd  = OIdataArr[ispecbin,itimebin].v2_mjd[v2_good]
        OIdataArr[ispecbin,itimebin].v2_lam  = OIdataArr[ispecbin,itimebin].v2_lam[v2_good]
        OIdataArr[ispecbin,itimebin].v2_dlam = OIdataArr[ispecbin,itimebin].v2_dlam[v2_good]
        OIdataArr[ispecbin,itimebin].v2_flag = OIdataArr[ispecbin,itimebin].v2_flag[v2_good]
        OIdataArr[ispecbin,itimebin].v2_sta_index = OIdataArr[ispecbin,itimebin].v2_sta_index[:,v2_good]
        # TODO: filter T3.t3amp

        t3amp_good =  (.!isnan.(OIdataArr[ispecbin,itimebin].t3amp )) .& (.!isnan.(OIdataArr[ispecbin,itimebin].t3amp_err )) .& (OIdataArr[ispecbin,itimebin].t3amp_err.>0.0)
        t3phi_good =  (.!isnan.(OIdataArr[ispecbin,itimebin].t3phi ) ).& (.!isnan.(OIdataArr[ispecbin,itimebin].t3phi_err )) .& (OIdataArr[ispecbin,itimebin].t3phi_err.>0.0)

        #if force_full_t3 is set to "true", then we require both t3amp and t3phi to be defined
        t3_good = []
        if force_full_t3 == false
          t3_good = findall(.!OIdataArr[ispecbin,itimebin].t3_flag .& (t3amp_good .| t3phi_good) )
        else
          t3_good = findall(.!OIdataArr[ispecbin,itimebin].t3_flag .& (t3amp_good .& t3phi_good) )
        end

        good_uv_t3_1 = OIdataArr[ispecbin,itimebin].indx_t3_1[t3_good]
        good_uv_t3_2 = OIdataArr[ispecbin,itimebin].indx_t3_2[t3_good]
        good_uv_t3_3 = OIdataArr[ispecbin,itimebin].indx_t3_3[t3_good]

        OIdataArr[ispecbin,itimebin].t3amp = OIdataArr[ispecbin,itimebin].t3amp[t3_good]
        OIdataArr[ispecbin,itimebin].t3amp_err = OIdataArr[ispecbin,itimebin].t3amp_err[t3_good]
        OIdataArr[ispecbin,itimebin].t3phi = OIdataArr[ispecbin,itimebin].t3phi[t3_good]
        OIdataArr[ispecbin,itimebin].t3phi_err = OIdataArr[ispecbin,itimebin].t3phi_err[t3_good]
        OIdataArr[ispecbin,itimebin].nt3amp = length(OIdataArr[ispecbin,itimebin].t3amp)
        OIdataArr[ispecbin,itimebin].nt3phi = length(OIdataArr[ispecbin,itimebin].t3phi)
        OIdataArr[ispecbin,itimebin].t3_baseline  = OIdataArr[ispecbin,itimebin].t3_baseline[t3_good]
        OIdataArr[ispecbin,itimebin].t3_maxbaseline  = OIdataArr[ispecbin,itimebin].t3_maxbaseline[t3_good]
        OIdataArr[ispecbin,itimebin].t3_mjd  = OIdataArr[ispecbin,itimebin].t3_mjd[t3_good]
        OIdataArr[ispecbin,itimebin].t3_lam  = OIdataArr[ispecbin,itimebin].t3_lam[t3_good]
        OIdataArr[ispecbin,itimebin].t3_dlam = OIdataArr[ispecbin,itimebin].t3_dlam[t3_good]
        OIdataArr[ispecbin,itimebin].t3_flag = OIdataArr[ispecbin,itimebin].t3_flag[t3_good]
        OIdataArr[ispecbin,itimebin].t3_sta_index = OIdataArr[ispecbin,itimebin].t3_sta_index[:,t3_good]
        # uv points filtering
        uv_select  = Array{Bool}(undef, size(OIdataArr[ispecbin,itimebin].uv,2))
        uv_select[:]  .= false;
        uv_select[good_uv_v2] .= true
        uv_select[good_uv_t3_1] .= true
        uv_select[good_uv_t3_2] .= true
        uv_select[good_uv_t3_3] .= true
        indx_conv = [sum(uv_select[1:i]) for i=1:length(uv_select)]
        OIdataArr[ispecbin,itimebin].uv = OIdataArr[ispecbin,itimebin].uv[:,findall(uv_select.==true)]
        OIdataArr[ispecbin,itimebin].indx_v2 =   indx_conv[good_uv_v2]
        OIdataArr[ispecbin,itimebin].indx_t3_1 = indx_conv[good_uv_t3_1]
        OIdataArr[ispecbin,itimebin].indx_t3_2 = indx_conv[good_uv_t3_2]
        OIdataArr[ispecbin,itimebin].indx_t3_3 = indx_conv[good_uv_t3_3]
      end

    end
    iter_wav = 0;
  end
  return OIdataArr;
end

function readoifits_multiepochs(oifitsfiles; filter_bad_data=false,  force_full_t3 = false) # read multiple files, each containing a single epochs
  nepochs = length(oifitsfiles);
  tepochs = Array{Float64}(undef, nepochs);
  data = Array{OIdata}(undef, nepochs);
  for i=1:nepochs
    data[i] = readoifits(oifitsfiles[i], filter_bad_data=filter_bad_data, force_full_t3 =force_full_t3 )[1,1];
    tepochs[i] = data[i].mean_mjd;
    println(oifitsfiles[i], "\t MJD: ", tepochs[i], "\t nV2 = ", data[i].nv2, "\t nT3amp = ", data[i].nt3amp, "\t nT3phi = ", data[i].nt3phi);
  end
  return nepochs, tepochs, data
end

function readoifits_multicolors(oifitsfiles; filter_bad_data=false,  force_full_t3 = false) # read multiple files, each containing a single wavelength
  nwavs = length(oifitsfiles);
  data = Array{OIdata}(undef, nwavs);
  for i=1:nwavs
    data[i] = readoifits(oifitsfiles[i], filter_bad_data=filter_bad_data, force_full_t3 =force_full_t3 )[1,1];
    println(oifitsfiles[i], "\t nV2 = ", data[i].nv2, "\t nT3amp = ", data[i].nt3amp, "\t nT3phi = ", data[i].nt3phi);
  end
  return data
end




# period in days
function time_split(mjd,period;mjd_start=mjd[1])
  timebins = (maximum(mjd) - mjd_start)/(period);
  itimebin = Int(ceil(timebins));
  temporalbin = [[],[]];
  temporalbin[1] = [mjd_start,mjd_start+period];
  temporalbin[2] = [mjd_start+period,mjd_start+2*period];
  for i = 3:itimebin
    temporalbin[2] = vcat(temporalbin[2],mjd_start+(i-1)*period);
    temporalbin[2] = vcat(temporalbin[2],mjd_start+(i)*period);
  end
  return temporalbin
end

function readfits(fitsfile; normalize = false, vectorize=false)
x = (read((FITS(fitsfile))[1]))
if normalize == true
 x ./= sum(x)
end
if vectorize == true
    x = vec(x)
end
return x;
end

function writefits(data, fitsfile)
f = FITS(fitsfile, "w");
write(f, data);
close(f);
end
