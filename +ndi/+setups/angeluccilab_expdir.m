function E = angeluccilab_expdir(ref, dirname)
% ANGELUCCILAB_EXPERDIR - initialize an NDI_SESSION_DIR with ANGELUCCILAB devices
%
%  E = ndi.setups.angeluccilab_expdir(REF, DIRNAME)
%
%  Initializes an ndi.session.dir object for the directory
%  DIRNAME with the standard compliment of ANGELUCCILAB devices, as
%  found in ndi.setups.angeluccilab_makedev.
%
%  If the devices are already added, they are not re-created.
%

E = ndi.session.dir(ref, dirname);

angeluccilabdevnames = ndi.setups.angeluccilab_makedev();

devclocks = {};

for i=1:numel(angeluccilabdevnames),
	dev = E.daqsystem_load('name',angeluccilabdevnames{i});
	if isempty(dev),
		E = ndi.setups.angeluccilab_makedev(E, angeluccilabdevnames{i});
	end
	dev = E.daqsystem_load('name',angeluccilabdevnames{i});
end

 % update SYNCGRAPH

nsf = ndi.time.syncrule.filematch(struct('number_fullpath_matches',2));

E.syncgraph_addrule(nsf);

