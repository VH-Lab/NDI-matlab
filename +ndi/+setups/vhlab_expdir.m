function E = vhlab_expdir(ref, dirname)
% NDI.VHLAB_EXPERDIR - initialize an ndi.session.dir with VHLAB devices
%
%  E = ndi.setups.vhlab_expdir(REF, DIRNAME)
%
%  Initializes an ndi.session.dir object for the directory
%  DIRNAME with the standard compliment of VHLAB devices, as
%  found in ndi.setups.vhlab_makedev.
%
%  If the devices are already added, they are not re-created.
%

E = ndi.session.dir(ref, dirname);

vhlabdevnames = ndi.setups.vhlab_makedev;

devclocks = {};

for i=1:numel(vhlabdevnames),
	dev = E.daqsystem_load('name',vhlabdevnames{i});
	if isempty(dev),
		E = ndi.setups.vhlab_makedev(E, vhlabdevnames{i});
	end
	dev = E.daqsystem_load('name',vhlabdevnames{i});
end

 % update SYNCGRAPH

nsf = ndi.time.syncrule.filematch(struct('number_fullpath_matches',2));
n_intan2spike2 = ndi.time.syncrule.filefind(struct('number_fullpath_matches',1, ...
	'syncfilename','vhintan_intan2spike2time.txt',...
	'daqsystem1','vhintan','daqsystem2','vhvis_spike2'));

E.syncgraph_addrule(nsf);
E.syncgraph_addrule(n_intan2spike2);

