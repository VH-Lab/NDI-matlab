function S = vhlab(ref, dirname)
% ndi.setup.vhlab - initialize an ndi.session.dir with VHLAB devices
%
%  S = ndi.setup.vhlab(REF, DIRNAME)
%
%  Initializes an ndi.session.dir object for the directory
%  DIRNAME with the standard compliment of VHLAB devices, as
%  found in ndi.setup.daq.system.vhlab.
%
%  If the devices are already added, they are not re-created.
%

S = ndi.session.dir(ref, dirname);
vhlabdevnames = ndi.setup.daq.system.vhlab(); % returns list of daq system names

for i=1:numel(vhlabdevnames),
	dev = S.daqsystem_load('name',vhlabdevnames{i});
	if isempty(dev),
		S = ndi.setup.daq.system.vhlab(S, vhlabdevnames{i});
	end
end

 % update SYNCGRAPH

nsf = ndi.time.syncrule.filematch(struct('number_fullpath_matches',2));
n_intan2spike2 = ndi.time.syncrule.filefind(struct('number_fullpath_matches',1, ...
	'syncfilename','vhintan_intan2spike2time.txt',...
	'daqsystem1','vhintan','daqsystem2','vhvis_spike2'));

S.syncgraph_addrule(nsf);
S.syncgraph_addrule(n_intan2spike2);
