# gather common display tasks
using PyPlot,PyCall
PyDict(pyimport("matplotlib")["rcParams"])["font.family"]=["serif"]
PyDict(pyimport("matplotlib")["rcParams"])["xtick.major.size"]=[6]
PyDict(pyimport("matplotlib")["rcParams"])["ytick.major.size"]=[6]
PyDict(pyimport("matplotlib")["rcParams"])["xtick.minor.size"]=[6]
PyDict(pyimport("matplotlib")["rcParams"])["ytick.minor.size"]=[6]
PyDict(pyimport("matplotlib")["rcParams"])["xtick.major.width"]=[1]
PyDict(pyimport("matplotlib")["rcParams"])["ytick.major.width"]=[1]
PyDict(pyimport("matplotlib")["rcParams"])["xtick.minor.width"]=[1]
PyDict(pyimport("matplotlib")["rcParams"])["ytick.minor.width"]=[1]
PyDict(pyimport("matplotlib")["rcParams"])["lines.markeredgewidth"]=[1]
#PyDict(pyimport("matplotlib")["rcParams"])["legend.numpoints"]=[1]
#PyDict(pyimport("matplotlib")["rcParams"])["legend.handletextpad"]=[0.3]

PyDict(pyimport("matplotlib")["rcParams"])["legend.numpoints"]=[10]
PyDict(pyimport("matplotlib")["rcParams"])["legend.handletextpad"]=[0.5]

colors=["black","darkgreen","firebrick","forestgreen","peru","navy","gray","darkorange","lime","orange",
"fuchsia","saddlebrown","red","darkslateblue","blueviolet","indigo","blue","dodgerblue",
"sienna","olive","purple","darkorchid","tomato","darkturquoise","steelblue","seagreen","darkgoldenrod","darkseagreen"]


edit_oifits_remove_point_button=1
edit_oifits_remove_point_double_click=true
edit_oifits_remove_point_cancel_button=3
edit_oifits_remove_point_finish_and_save_button=2
delete_x=[]
delete_y=[]
delete_err=[]
#allow removing of numpoints
function onclickv2(event)
    clicktype=event[:button]
    xdat=deepcopy(data.v2_baseline)./1e6
    ydat=deepcopy(data.v2)
    errdat=deepcopy(data.v2_err)
    if clicktype == edit_oifits_remove_point_button    #if not a left click
        if event[:dblclick] == edit_oifits_remove_point_double_click
            ax=gca()
            ymin,ymax=ax[:get_ylim]()
            xmin,xmax=ax[:get_xlim]()
            normfactor=abs(xmax-xmin)/abs(ymax-ymin)
            xclick=event[:xdata]
            yclick=event[:ydata]
            diffx=abs.(xdat.-xclick)
            diffy=abs.(ydat.-yclick)
            diffr=sqrt.((xdat.-xclick).^2+((ydat.-yclick).*normfactor).^2)
            indx_remove=indmin(diffr)
            closestx=xdat[indx_remove]
            closesty=ydat[indx_remove]
            closesterr=errdat[indx_remove]
            println(closestx," ",xclick," ",closesty," ",yclick)
            errorbar(closestx,closesty,yerr=closesterr,fmt="o", markersize=3,color="Red")
            push!(delete_x,closestx)
            push!(delete_y,closesty)
            push!(delete_err,closesterr)
            println(delete_x)
        end
    elseif clicktype == edit_oifits_remove_point_cancel_button
        println("Cancelling!")
        clf()
        errorbar(xdat,ydat,yerr=errdat,fmt="o", markersize=3,color="Black")
    elseif clicktype == edit_oifits_remove_point_finish_and_save_button
        filter!(a->a∉delete_x,xdat)
        filter!(a->a∉delete_y,ydat)
        filter!(a->a∉delete_err,errdat)
        clf()
        errorbar(xdat,ydat,yerr=errdat,fmt="o", markersize=3,color="Black")
        # save

    end
end

# double check by plotting uv coverage
function uvplot(data::OIdata)
uvplot(data.uv)
end

function uvplot(uv::Array{Float64,2})
u = uv[1,:]/1e6
v = uv[2,:]/1e6
fig = figure("UV plot",figsize=(8,8),facecolor="White")
clf();
ax = gca()
minorticks_on
markeredgewidth=0.1
ax[:locator_params](axis ="y", nbins=20)
ax[:locator_params](axis ="x", nbins=20)
scatter(u, v,alpha=0.5, color="Black")
scatter(-u, -v,alpha=0.5, color="Black")
title("UV coverage")
xlabel(L"U (M$\lambda$)")
ylabel(L"V (M$\lambda$)")
ax[:grid](true);
tight_layout();
end


function uvplot_fancy(data::OIdata;filename="")
uvplot_fancy(data.uv,data.nv2,data.tel_name,data.v2_sta_index,data.v2_lam,colors;filename=filename)
end

function uvplot_fancy(uv::Array{Float64,2},nv2::Int64,tel_name::Array{String,1},v2_sta_index::Array{Int64,2},v2_lam::Array{Float64,1},colors::Array{String,1};filename="")
baseline_list=get_baseline_list(nv2,tel_name,v2_sta_index)
fig = figure("UV plot",figsize=(20,20),facecolor="White")
clf();
ax = gca()
minorticks_on
markeredgewidth=0.1
ax[:locator_params](axis ="y", nbins=20)
ax[:locator_params](axis ="x", nbins=20)
axis("equal")
for i=1:length(unique(baseline_list))
    baseline=unique(baseline_list)[i]
    loc=findall(baseline_list->baseline_list==baseline,baseline_list)
    #scatter(uv[1,loc[1]:loc[length(loc)]].*v2_lam[loc[1]:loc[length(loc)]], uv[2,loc[1]:loc[length(loc)]].*v2_lam[loc[1]:loc[length(loc)]],alpha=0.5, color=colors[i],label=baseline)
    #scatter(-uv[1,loc[1]:loc[length(loc)]].*v2_lam[loc[1]:loc[length(loc)]], -uv[2,loc[1]:loc[length(loc)]].*v2_lam[loc[1]:loc[length(loc)]],alpha=0.5, color=colors[i])
    scatter(uv[1,loc]/1e6, uv[2,loc]/1e6,alpha=0.5, color=colors[i],label=baseline)
    scatter(-uv[1,loc]/1e6,-uv[2,loc]/1e6,alpha=0.5, color=colors[i])

end
ax[:legend](bbox_to_anchor=[0.925,1.0],loc=2,borderaxespad=0)
title("UV coverage")
xlabel(L"U (M$\lambda$)")
ylabel(L"V (M$\lambda$)")
ax[:grid](true);
tight_layout();
if filename !=""
    savefig(filename)
end
end




function v2plot_modelvsdata(baseline_v2::Array{Float64,1},v2_data::Array{Float64,1},v2_data_err::Array{Float64,1}, v2_model::Array{Float64,1}; logplot = false) #plots V2 data vs v2 model
fig = figure("V2 plot - Model vs Data",figsize=(8,8),facecolor="White")
clf();
subplot(211)
ax = gca();
if logplot==true
ax[:set_yscale]("log")
end
errorbar(baseline_v2/1e6,v2_data,yerr=v2_data_err,fmt="o", markersize=2,color="Black")
plot(baseline_v2/1e6, v2_model, color="Red", linestyle="none", marker="o", markersize=3)
title("Squared Visbility Amplitudes - Model vs data plot")
#xlabel(L"Baseline (M$\lambda$)")
ylabel("Squared Visibility Amplitudes")
ax[:grid](true);
subplot(212)
plot(baseline_v2/1e6, (v2_model - v2_data)./v2_data_err,color="Black", linestyle="none", marker="o", markersize=3)
xlabel(L"Baseline (M$\lambda$)")
ylabel("Residuals (number of sigma)")
ax = gca();
ax[:grid](true);
tight_layout()
end



# This draws a continuous line based on the analytic function
function v2plot_modelvsfunc(baseline_v2::Array{Float64,1},v2_data::Array{Float64,1},v2_data_err::Array{Float64,1}, visfunc, params; drawpoints = false, yrange=[], drawfunc = true, logplot = false) #plots V2 data vs v2 model
# Compute model points (discrete)
cvis_model = visfunc(params,sqrt.(data.uv[1,:].^2+data.uv[2,:].^2));
v2_model = cvis_to_v2(cvis_model, data.indx_v2); # model points
# Compute model curve (continous)
r = sqrt.(data.uv[1,data.indx_v2].^2+data.uv[2,data.indx_v2].^2)
range = linspace(minimum(r),maximum(r),1000);
cvis_func = visfunc(params,range);
v2_func = abs2.(cvis_func);


fig = figure("V2 plot - Model vs Data",figsize=(8,8),facecolor="White")
clf();
subplot(211)
ax = gca();
if logplot==true
ax[:set_yscale]("log")
end

if yrange !=[]
ylim((yrange[1], yrange[2]))
end

errorbar(baseline_v2/1e6,v2_data,yerr=v2_data_err,fmt="o", markersize=2,color="Black")
if drawpoints == true
plot(baseline_v2/1e6, v2_model, color="Red", linestyle="none", marker="o", markersize=3)
end

if drawfunc == true
plot(range/1e6, v2_func, color="Red", linestyle="-", markersize=3)
end

title("Squared Visbility Amplitudes - Model vs data plot")
#xlabel(L"Baseline (M$\lambda$)")
ylabel("Squared Visibility Amplitudes")
ax[:grid](true);
subplot(212)
plot(baseline_v2/1e6, (v2_model - v2_data)./v2_data_err,color="Black", linestyle="none", marker="o", markersize=3)
xlabel(L"Baseline (M$\lambda$)")
ylabel("Residuals (number of sigma)")
ax = gca();
ax[:grid](true);
tight_layout()
end

function v2plot(data::OIdata;logplot=false,remove=false)
v2plot(data.v2_baseline,data.v2,data.v2_err,logplot=logplot,remove=remove);
end


function v2plot(baseline_v2::Array{Float64,1},v2_data::Array{Float64,1},v2_data_err::Array{Float64,1}; logplot = false, remove = false ) # plots v2 data only
fig = figure("V2 data",figsize=(10,5),facecolor="White");
clf();
ax = gca();
if logplot==true
ax[:set_yscale]("log")
end
if remove == true
fig[:canvas][:mpl_connect]("button_press_event",onclickv2)
end
errorbar(baseline_v2/1e6,v2_data,yerr=v2_data_err,fmt="o", markersize=3,color="Black")
title("Squared Visibility Amplitude Data")
xlabel(L"Baseline (M$\lambda$)")
ylabel("Squared Visibility Amplitudes")
ax[:grid](true)
tight_layout()
end


function v2plot_fancy(data::OIdata,colors;logplot=false,remove=false,filename="")
    v2plot_fancy(data.v2_baseline,data.v2,data.v2_err,data.nv2,data.tel_name,data.v2_sta_index,colors,logplot=logplot,remove=remove,filename=filename);
end


function v2plot_fancy(baseline_v2::Array{Float64,1},v2_data::Array{Float64,1},v2_data_err::Array{Float64,1},nv2::Int64,tel_name::Array{String,1},v2_sta_index::Array{Int64,2},colors::Array{String,1}; logplot = false, remove = false, filename="" ) # plots v2 data only
    baseline_list=get_baseline_list(nv2,tel_name,v2_sta_index)
    fig = figure("V2 data",figsize=(10,5),facecolor="White");
    clf();
    ax = gca();
    if logplot==true
        ax[:set_yscale]("log")
    end
    if remove == true
        fig[:canvas][:mpl_connect]("button_press_event",onclickv2)
    end
    for i=1:length(unique(baseline_list))
        baseline=unique(baseline_list)[i]
        loc=findall(baseline_list->baseline_list==baseline,baseline_list)
        errorbar(baseline_v2[loc]/1e6,v2_data[loc],yerr=v2_data_err[loc],fmt="o", markeredgecolor=colors[i],markersize=3,ecolor=colors[i],color=colors[i],label=baseline)
    end
    ax[:legend](bbox_to_anchor=[0.925,1.0],loc=2,borderaxespad=0)
    title("Squared Visibility Amplitude Data")
    xlabel(L"Baseline (M$\lambda$)")
    ylabel("Squared Visibility Amplitudes")
    ax[:grid](true)
    tight_layout()
    if filename !=""
        savefig(filename)
    end
end


function t3phiplot(data::OIdata)
t3phiplot(data.t3_maxbaseline,data.t3phi,data.t3phi_err);
end

function t3phiplot(baseline_t3,t3phi_data,t3phi_data_err) # plots v2 data only
  fig = figure("Closure phase data",figsize=(10,5),facecolor="White");
  clf();
  errorbar(baseline_t3/1e6,t3phi_data,yerr=t3phi_data_err,fmt="o", markersize=3,color="Black")
  title("Closure phase data")
  xlabel(L"Maximum Baseline (M$\lambda$)")
  ylabel("Closure phase (degrees)")
  ax=gca();
  ax[:grid](true)
  tight_layout()
end

function t3phiplot_fancy(data::OIdata,colors;filename="")
    t3phiplot_fancy(data.t3_maxbaseline,data.t3phi,data.t3phi_err,data.nt3phi,data.tel_name,data.t3_sta_index,colors;filename=filename);
end

function t3phiplot_fancy(baseline_t3,t3phi_data,t3phi_data_err,nt3phi,tel_name,t3_sta_index,colors;filename="") # plots v2 data only
  baseline_list=get_baseline_list_t3phi(nt3phi,tel_name,t3_sta_index)
  fig = figure("Closure phase data",figsize=(10,5),facecolor="White");
  clf();
  ax=gca();
  for i=1:length(unique(baseline_list))
      baseline=unique(baseline_list)[i]
      loc=findall(baseline_list->baseline_list==baseline,baseline_list)
      errorbar(baseline_t3[loc]/1e6,t3phi_data[loc],yerr=t3phi_data_err[loc],fmt="o",markeredgecolor=colors[i], markersize=3,ecolor=colors[i],color=colors[i],label=baseline)
  end
  ax[:legend](bbox_to_anchor=[1.0,1.0],loc=1,borderaxespad=0.5)
  title("Closure phase data")
  xlabel(L"Maximum Baseline (M$\lambda$)")
  ylabel("Closure phase (degrees)")
  ax[:grid](true)
  tight_layout()
  if filename !=""
      savefig(filename)
  end
end


const axgrid = PyNULL()
copy!(axgrid, pyimport("mpl_toolkits.axes_grid1"))

function imdisp(image; cmap = "hot", pixscale = -1.0, tickinterval = 10, colorbar = false, beamsize = -1, beamlocation = [.9, .9])
 fig = figure("Image",figsize=(6,6),facecolor="White")
 nx=ny=-1;
 pixmode = false;
 if pixscale == -1
     pixmode = true;
     pixscale = 1
 end
 if ndims(image) ==1
   ny=nx=Int64(sqrt(length(image)))
   imshow(rotl90(reshape(image,nx,nx)), ColorMap(cmap), interpolation="none", extent=[-0.5*nx*pixscale,0.5*nx*pixscale,-0.5*ny*pixscale,0.5*ny*pixscale]); # uses Monnier's orientation
 else
   nx,ny = size(image);
   imshow(rotl90(image), ColorMap(cmap), interpolation="none", extent=[-0.5*nx*pixscale,0.5*nx*pixscale,-0.5*ny*pixscale,0.5*ny*pixscale]); # uses Monnier's orientation
 end
 if pixmode == false
 xlabel("RA (mas)")
 ylabel("DEC (mas)")
end

 ax = gca()
 ax[:set_aspect]("equal")
 mx = matplotlib[:ticker][:MultipleLocator](tickinterval) # Define interval of minor ticks
 ax[:xaxis][:set_minor_locator](mx) # Set interval of minor ticks
 ax[:yaxis][:set_minor_locator](mx) # Set interval of minor ticks
 ax[:xaxis][:set_tick_params](which="major",length=10,width=2)
 ax[:xaxis][:set_tick_params](which="minor",length=5,width=1)
 ax[:yaxis][:set_tick_params](which="major",length=10,width=2)
 ax[:yaxis][:set_tick_params](which="minor",length=5,width=1)

 if colorbar == true
  divider = axgrid.make_axes_locatable(ax)
  cax = divider[:append_axes]("right", size="5%", pad=0.05)
  colorbar(image, cax=cax)
 end

  if beamsize > 0
   c = matplotlib[:patches][:Circle]((0.5*nx*pixscale*beamlocation[1],-0.5*ny*pixscale*beamlocation[2]),beamsize,fc="white",ec="white",linewidth=.5)
   ax[:add_artist](c)
  end
 tight_layout()
end

#TODO: work for rectangular
function imdisp_polychromatic(image_vector::Union{Array{Float64,1}, Array{Float64,2},Array{Float64,3}}; imtitle="Polychromatic image", nwavs = 1, cmap = "hot", pixscale = -1.0, tickinterval = 10, colorbar = false, beamsize = -1, beamlocation = [.9, .9])

if typeof(image_vector)==Array{Float64,2}
    nwavs = size(image_vector,2)
elseif typeof(image_vector)==Array{Float64,3}
    nwavs = size(image_vector,3)
end

fig = figure(imtitle,figsize=(nwavs*6,6),facecolor="White")
clf();
images_all =reshape(image_vector, (div(length(vec(image_vector)),nwavs), nwavs))
  for i=1:nwavs
    plotnum = 100+nwavs*10+i
    subplot(plotnum)
    title("Wave $i")
    image = images_all[:,i]
    nx=ny=-1;
    pixmode = false;
    if pixscale == -1
      pixmode = true;
      pixscale = 1
    end
    ny=nx=Int64.(sqrt(length(image)))
    imshow(rotl90(reshape(image,nx,nx)), ColorMap(cmap), interpolation="none", extent=[-0.5*nx*pixscale,0.5*nx*pixscale,-0.5*ny*pixscale,0.5*ny*pixscale]); # uses Monnier's orientation
    if pixmode == false
        xlabel("RA (mas)")
        ylabel("DEC (mas)")
    end

    ax = gca()
    ax[:set_aspect]("equal")
    mx = matplotlib[:ticker][:MultipleLocator](tickinterval) # Define interval of minor ticks
    ax[:xaxis][:set_minor_locator](mx) # Set interval of minor ticks
    ax[:yaxis][:set_minor_locator](mx) # Set interval of minor ticks
    ax[:xaxis][:set_tick_params](which="major",length=10,width=2)
    ax[:xaxis][:set_tick_params](which="minor",length=5,width=1)
    ax[:yaxis][:set_tick_params](which="major",length=10,width=2)
    ax[:yaxis][:set_tick_params](which="minor",length=5,width=1)

  if colorbar == true
    divider = axgrid.make_axes_locatable(ax)
    cax = divider[:append_axes]("right", size="5%", pad=0.05)
    colorbar(image, cax=cax)
  end

   if beamsize > 0
    c = matplotlib[:patches][:Circle]((0.5*nx*pixscale*beamlocation[1],-0.5*ny*pixscale*beamlocation[2]),beamsize,fc="white",ec="white",linewidth=.5)
    ax[:add_artist](c)
   end
  tight_layout()
  end
end

# TODO: rework for julia 1.0+
function imdisp_temporal(image_vector, nepochs; cmap = "hot", name="Image",pixscale = -1.0, tickinterval = 10, colorbar = false, beamsize = -1, beamlocation = [.9, .9])
  fig = figure(name,figsize=(nepochs*10,6+round(nepochs/3)),facecolor="White")
  images_all =reshape(image_vector, (div(length(image_vector),nepochs), nepochs))
  cols=6
  rows=div(nepochs,cols)+1
  for i=1:nepochs
    #plotnum = 100*(div(nepochs,9)+1)
    fig[:add_subplot](rows,cols,i)
    #subplot()
    title("Epoch $i")
    image = images_all[:,i]
    nx=ny=-1;
    pixmode = false;
    if pixscale == -1
      pixmode = true;
      pixscale = 1
    end
    if ndims(image) ==1
        ny=nx=Int64(sqrt(length(image)))
        imshow(rotl90(reshape(image,nx,nx)), ColorMap(cmap), interpolation="none", extent=[-0.5*nx*pixscale,0.5*nx*pixscale,-0.5*ny*pixscale,0.5*ny*pixscale]); # uses Monnier's orientation
    else
        nx,ny = size(image);
        imshow(rotl90(image), ColorMap(cmap), interpolation="none", extent=[-0.5*nx*pixscale,0.5*nx*pixscale,-0.5*ny*pixscale,0.5*ny*pixscale]); # uses Monnier's orientation
    end
    if pixmode == false
        if i > nepochs-cols
            xlabel("RA (mas)")
        end
        if i % cols == 1
            ylabel("DEC (mas)")
        end
    end
    ax = gca()
    ax[:set_aspect]("equal")
    mx = matplotlib[:ticker][:MultipleLocator](tickinterval) # Define interval of minor ticks
    ax[:xaxis][:set_minor_locator](mx) # Set interval of minor ticks
    ax[:yaxis][:set_minor_locator](mx) # Set interval of minor ticks
    ax[:xaxis][:set_tick_params](which="major",length=10,width=2)
    ax[:xaxis][:set_tick_params](which="minor",length=5,width=1)
    ax[:yaxis][:set_tick_params](which="major",length=10,width=2)
    ax[:yaxis][:set_tick_params](which="minor",length=5,width=1)
    if colorbar == true
        divider = axgrid.make_axes_locatable(ax)
        cax = divider[:append_axes]("right", size="5%", pad=0.05)
        colorbar(image, cax=cax)
    end
    if beamsize > 0
        c = matplotlib[:patches][:Circle]((0.5*nx*pixscale*beamlocation[1],-0.5*ny*pixscale*beamlocation[2]),beamsize,fc="white",ec="white",linewidth=.5)
        ax[:add_artist](c)
    end
    #tight_layout()
    end
end

function imdisp_multiwave(image_vector, centralwaves,nwaves; cmap = "hot", name="Image",pixscale = -1.0, tickinterval = 10, colorbar = false, beamsize = -1, beamlocation = [.9, .9])
  fig = figure(name,figsize=(nwaves*10,6),facecolor="White")
  images_all =reshape(image_vector, (div(length(image_vector),nwaves), nwaves))
  cols=8
  rows=div(nwaves,cols)+1
  for i=1:nwaves
    #plotnum = 100*(div(nepochs,9)+1)
    fig[:add_subplot](rows,cols,i)
    #subplot()
    title(string(centralwaves[i])*L"$\mu$m")
    image = images_all[:,i]
    nx=ny=-1;
    pixmode = false;
    if pixscale == -1
      pixmode = true;
      pixscale = 1
    end
    if ndims(image) ==1
        ny=nx=Int64(sqrt(length(image)))
        imshow(rotl90(reshape(image,nx,nx)), ColorMap(cmap), interpolation="none", extent=[-0.5*nx*pixscale,0.5*nx*pixscale,-0.5*ny*pixscale,0.5*ny*pixscale]); # uses Monnier's orientation
    else
        nx,ny = size(image);
        imshow(rotl90(image), ColorMap(cmap), interpolation="none", extent=[-0.5*nx*pixscale,0.5*nx*pixscale,-0.5*ny*pixscale,0.5*ny*pixscale]); # uses Monnier's orientation
    end
    if pixmode == false
        if i > nwaves-cols
            xlabel("RA (mas)")
        end
        if i % cols == 1
            ylabel("DEC (mas)")
        end
    end
    ax = gca()
    ax[:set_aspect]("equal")
    mx = matplotlib[:ticker][:MultipleLocator](tickinterval) # Define interval of minor ticks
    ax[:xaxis][:set_minor_locator](mx) # Set interval of minor ticks
    ax[:yaxis][:set_minor_locator](mx) # Set interval of minor ticks
    ax[:xaxis][:set_tick_params](which="major",length=10,width=2)
    ax[:xaxis][:set_tick_params](which="minor",length=5,width=1)
    ax[:yaxis][:set_tick_params](which="major",length=10,width=2)
    ax[:yaxis][:set_tick_params](which="minor",length=5,width=1)
    if colorbar == true
        divider = axgrid.make_axes_locatable(ax)
        cax = divider[:append_axes]("right", size="5%", pad=0.05)
        colorbar(image, cax=cax)
    end
    if beamsize > 0
        c = matplotlib[:patches][:Circle]((0.5*nx*pixscale*beamlocation[1],-0.5*ny*pixscale*beamlocation[2]),beamsize,fc="white",ec="white",linewidth=.5)
        ax[:add_artist](c)
    end
    #tight_layout()
    end
end

function get_baseline_list(nv2,tel_names,v2_stations)
    baseline_list=Array{String}(undef,nv2)
    for i=1:nv2
        baseline_list[i]=string(tel_names[v2_stations[1,i]+1],"-",tel_names[v2_stations[2,i]+1])
    end
    return baseline_list
end

function get_baseline_list_t3phi(nt3phi,tel_names,t3_stations)
    baseline_list=Array{String}(undef,nt3phi)
    for i=1:nt3phi
        baseline_list[i]=string(tel_names[t3_stations[1,i]+1],"-",tel_names[t3_stations[2,i]+1],"-",tel_names[t3_stations[3,i]+1])
    end
    return baseline_list
end
