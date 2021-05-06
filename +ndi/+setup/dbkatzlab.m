function S = dbkatzlab(ref, dirname)
% KATZLAB_EXPERDIR - initialize an NDI_SESSION_DIR with KATZLAB devices
%
%  S = ndi.setup.dbkatzlab(REF, DIRNAME)
%
%  Initializes an ndi.session.dir object for the directory
%  DIRNAME with the standard compliment of KATZLAB devices, as
%  found in ndi.setup.daq.system.dbkatzlab.
%
%  If the devices are already added, they are not re-created.
%

S = ndi.session.dir(ref, dirname);

katzlabdevnames = ndi.setup.daq.system.dbkatzlab();

for i=1:numel(katzlabdevnames),
	dev = S.daqsystem_load('name',katzlabdevnames{i});
	if isempty(dev),
		S = ndi.setup.daq.system.dbkatzlab(S, katzlabdevnames{i});
	end
end

