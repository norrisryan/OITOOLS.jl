if Pkg.installed("NLopt") != nothing
using NLopt

function fit_model_v2(data::OIdata, visfunc, init_param::Array{Float64,1})
  nparams=length(init_param)
  indx= data.indx_v2
  nv2 = length(data.v2[indx]);
  r=data.v2_baseline
  chisq=(param,g)->norm( (abs2.(visfunc(param,r))-data.v2[indx])./data.v2_err[indx])^2/nv2;
  opt = Opt(:LN_NELDERMEAD, nparams);
  min_objective!(opt, chisq)
  xtol_rel!(opt,1e-5)
  bounds = zeros(size(init_param)); # note: this enforces positivity on radius and coefficients
                                    # maybe not desirable for quadratic law ?
  lower_bounds!(opt, bounds);
  (minf,minx,ret) = optimize(opt, init_param);
  println("Chi2: $minf \t parameters:$minx \t \t $ret")
  cvis_model = visfunc(minx,sqrt.(data.uv[1,:].^2+data.uv[2,:].^2))
  return (minf,minx,cvis_model)
end

end


if Pkg.installed("MultiNest") != nothing

# function fit_model_v2(data, visfunc, init_param)
#   nparams=length(init_param)
#   indx= data.indx_v2
#   nv2 = length(data.v2[indx]);
#   r=data.v2_baseline
#   chisq=(param,g)->sum(((abs2.(visfunc(param,r))-data.v2[indx])./data.v2_err[indx]).^2)/nv2;
#   opt = Opt(:LN_NELDERMEAD, nparams);
#   #opt = Opt(:LD_MMA, nparams);
#   min_objective!(opt, chisq)
#   xtol_rel!(opt,1e-5)
#   (minf,minx,ret) = optimize(opt, init_param);
#   println("Chi2: $minf \t parameters:$minx \t \t $ret")
#   cvis_model = visfunc(minx,sqrt.(data.uv[1,:].^2+data.uv[2,:].^2))
#   return (minf,minx,cvis_model)
# end

end
