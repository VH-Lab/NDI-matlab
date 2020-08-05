function E = ndi_angeluccilab_expdir(ref, dirname)
% NDI_ANGELUCCILAB_EXPERDIR - initialize an NDI_SESSION_DIR with ANGELUCCILAB devices
%
%  E = NDI_ANGELUCCILAB_EXPDIR(REF, DIRNAME)
%
%  Initializes an NDI_SESSION_DIR object for the directory
%  DIRNAME with the standard compliment of ANGELUCCILAB devices, as
%  found in NDI_ANGELUCCILAB_MAKEDEV.
%
%  If the devices are already added, they are not re-created.
%

E = ndi_session_dir(ref, dirname);

angeluccilabdevnames = ndi_angeluccilab_makedev();

devclocks = {};

for i=1:numel(angeluccilabdevnames),
	dev = E.daqsystem_load('name',angeluccilabdevnames{i});
	if isempty(dev),
		E = ndi_angeluccilab_makedev(E, angeluccilabdevnames{i});
	end
	dev = E.daqsystem_load('name',angeluccilabdevnames{i});
end

 % update SYNCGRAPH

nsf = ndi_syncrule_filematch(struct('number_fullpath_matches',2));

E.syncgraph_addrule(nsf);

