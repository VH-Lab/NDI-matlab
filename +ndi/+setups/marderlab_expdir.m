function E = ndi_marderlab_expdir(ref, dirname)
% NDI_MARDERLAB_EXPERDIR - initialize an NDI_SESSION_DIR with MARDERLAB devices
%
%  E = ndi.setups.marderlab.expdir(REF, DIRNAME)
%
%  Initializes an ndi.session.dir object for the directory
%  DIRNAME with the standard compliment of MARDERLAB devices, as
%  found in ndi.setups.marderlab.makedev.
%
%  If the devices are already added, they are not re-created.
%

E = ndi.session.dir(ref, dirname);

marderlabdevnames = ndi.setups.marderlab_makedev;

devclocks = {};

for i=1:numel(marderlabdevnames),
	dev = E.daqsystem_load('name',marderlabdevnames{i});
	if isempty(dev),
		E = ndi.setups.marderlab_makedev(E, marderlabdevnames{i});
	end
	dev = E.daqsystem_load('name',marderlabdevnames{i});
end
