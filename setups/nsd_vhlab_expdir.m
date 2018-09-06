function exp = nsd_vhlab_expdir(ref, dirname)
% NSD_VHLAB_EXPERDIR - initialize an NSD_EXPERIMENT_DIR with VHLAB devices
%
%  EXP = NSD_VHLAB_EXPDIR(REF, DIRNAME)
%
%  Initializes an NSD_EXPERIMENT_DIR object for the directory
%  DIRNAME with the standard compliment of VHLAB devices, as
%  found in NSD_VHLAB_MAKEDEV.
%
%  If the devices are already added, they are not re-created.
%

exp = nsd_experiment_dir(ref, dirname);

vhlabdevnames = nsd_vhlab_makedev;

devclocks = {};

for i=1:numel(vhlabdevnames),
	dev = exp.iodevice_load('name',vhlabdevnames{i});
	if isempty(dev),
		exp = nsd_vhlab_makedev(exp, vhlabdevnames{i});
	end
	dev = exp.iodevice_load('name',vhlabdevnames{i});
end

 % update SYNCGRAPH

nsf = nsd_syncrule_filematch(struct('number_fullpath_matches',2));

exp.syncgraph_addrule(nsf);

