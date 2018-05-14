#
# BOOTSTRAP EXAMPLE
#

include("oitools.jl");

# VLTI example
oifitsfile = "AlphaCenA.oifits";
data = (readoifits(oifitsfile))[1,1];

# NPOI example
# filename = "HD48329_oidata.fits";
# targetname =  "FKV0254";
# data = (readoifits(filename, targetname=targetname, filter_bad_data = true, filter_v2_snr_threshold=1.0))[1,1];

params,params_err = bootstrap_v2_fit(1000, data, visibility_ud, [8.0]);
params,params_err = bootstrap_v2_fit(1000, data, visibility_ldquad, [8.0,0.1,0.1]);