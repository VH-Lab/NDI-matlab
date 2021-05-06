function S = marderlab(ref, dirname)
% ndi.setup.marderlab - initialize an NDI_SESSION_DIR with MARDERLAB devices
%
%  S = ndi.setup.marderlab(REF, DIRNAME)
%
%  Initializes an ndi.session.dir object for the directory
%  DIRNAME with the standard compliment of MARDERLAB devices, as
%  found in ndi.setup.daq.system.marderlab.
%
%  If the devices are already added, they are not re-created.
%

S = ndi.session.dir(ref, dirname);

marderlabdevnames = ndi.setup.daq.system.marderlab();

for i=1:numel(marderlabdevnames),
	dev = S.daqsystem_load('name',marderlabdevnames{i});
	if isempty(dev),
		S = ndi.setup.daq.system.marderlab(S, marderlabdevnames{i});
	end
end

