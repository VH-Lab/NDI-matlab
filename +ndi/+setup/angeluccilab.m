function S = angeluccilab(ref, dirname)
% ndi.setup.angeluccilab - initialize an NDI_SESSION_DIR with ANGELUCCILAB devices
%
%  S = ndi.setup.angeluccilab(REF, DIRNAME)
%
%  Initializes an ndi.session.dir object for the directory
%  DIRNAME with the standard compliment of ANGELUCCILAB devices, as
%  found in ndi.setup.daq.system.angeluccilab_makedev.
%
%  If the devices are already added, they are not re-created.
%

S = ndi.session.dir(ref, dirname);

angeluccilabdevnames = ndi.setup.daq.system.angeluccilab();

for i=1:numel(angeluccilabdevnames),
	dev = S.daqsystem_load('name',angeluccilabdevnames{i});
	if isempty(dev),
		S = ndi.setup.daq.system.angeluccilab(S, angeluccilabdevnames{i});
	end
end

 % update SYNCGRAPH

nsf = ndi.time.syncrule.filematch(struct('number_fullpath_matches',2));

S.syncgraph_addrule(nsf);

