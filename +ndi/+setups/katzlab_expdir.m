function E = katzlab_expdir(ref, dirname)
% KATZLAB_EXPERDIR - initialize an NDI_SESSION_DIR with KATZLAB devices
%
%  E = ndi.setups.katzlab_expdir(REF, DIRNAME)
%
%  Initializes an ndi.session.dir object for the directory
%  DIRNAME with the standard compliment of KATZLAB devices, as
%  found in ndi.setups.katzlab_makedev.
%
%  If the devices are already added, they are not re-created.
%

E = ndi.session.dir(ref, dirname);

katzlabdevnames = ndi.setups.katzlab_makedev;

devclocks = {};

for i=1:numel(katzlabdevnames),
	dev = E.daqsystem_load('name',katzlabdevnames{i});
	if isempty(dev),
		E = ndi.setups.katzlab_makedev(E, katzlabdevnames{i});
	end
	dev = E.daqsystem_load('name',katzlabdevnames{i});
end

