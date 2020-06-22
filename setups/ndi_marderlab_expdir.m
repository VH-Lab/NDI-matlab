function E = ndi_marderlab_expdir(ref, dirname)
% NDI_MARDERLAB_EXPERDIR - initialize an NDI_SESSION_DIR with MARDERLAB devices
%
%  E = NDI_MARDERLAB_EXPDIR(REF, DIRNAME)
%
%  Initializes an NDI_SESSION_DIR object for the directory
%  DIRNAME with the standard compliment of MARDERLAB devices, as
%  found in NDI_MARDERLAB_MAKEDEV.
%
%  If the devices are already added, they are not re-created.
%

E = ndi_session_dir(ref, dirname);

marderlabdevnames = ndi_marderlab_makedev;

devclocks = {};

for i=1:numel(marderlabdevnames),
	dev = E.daqsystem_load('name',marderlabdevnames{i});
	if isempty(dev),
		E = ndi_marderlab_makedev(E, marderlabdevnames{i});
	end
	dev = E.daqsystem_load('name',marderlabdevnames{i});
end
