function exp = ndi_vhlab_expdir(ref, dirname)
% NDI_VHLAB_EXPERDIR - initialize an NDI_EXPERIMENT_DIR with VHLAB devices
%
%  EXP = NDI_VHLAB_EXPDIR(REF, DIRNAME)
%
%  Initializes an NDI_EXPERIMENT_DIR object for the directory
%  DIRNAME with the standard compliment of VHLAB devices, as
%  found in NDI_VHLAB_MAKEDEV.
%
%  If the devices are already added, they are not re-created.
%

exp = ndi_experiment_dir(ref, dirname);

vhlabdevnames = ndi_vhlab_makedev;

devclocks = {};

for i=1:numel(vhlabdevnames),
	dev = exp.iodevice_load('name',vhlabdevnames{i});
	if isempty(dev),
		exp = ndi_vhlab_makedev(exp, vhlabdevnames{i});
	end
	dev = exp.iodevice_load('name',vhlabdevnames{i});
end

 % update SYNCGRAPH

nsf = ndi_syncrule_filematch(struct('number_fullpath_matches',2));

exp.syncgraph_addrule(nsf);

