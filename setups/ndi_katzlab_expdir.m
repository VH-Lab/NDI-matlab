function E = ndi_katzlab_expdir(ref, dirname)
% NDI_KATZLAB_EXPERDIR - initialize an NDI_SESSION_DIR with KATZLAB devices
%
%  E = NDI_KATZLAB_EXPDIR(REF, DIRNAME)
%
%  Initializes an NDI_SESSION_DIR object for the directory
%  DIRNAME with the standard compliment of KATZLAB devices, as
%  found in NDI_KATZLAB_MAKEDEV.
%
%  If the devices are already added, they are not re-created.
%

E = ndi_session_dir(ref, dirname);

katzlabdevnames = ndi_katzlab_makedev;

devclocks = {};

for i=1:numel(katzlabdevnames),
	dev = E.daqsystem_load('name',katzlabdevnames{i});
	if isempty(dev),
		E = ndi_katzlab_makedev(E, katzlabdevnames{i});
	end
	dev = E.daqsystem_load('name',katzlabdevnames{i});
end

