function S = vhlab(ref, dirname, force)
% ndi.setup.vhlab - initialize an ndi.session.dir with VHLAB devices
%
%  S = ndi.setup.vhlab(REF, DIRNAME, [FORCE])
%
%  Initializes an ndi.session.dir object for the directory
%  DIRNAME with the standard compliment of VHLAB devices, as
%  found in ndi.setup.daq.system.vhlab.
%
%  If the devices are already added, they are not re-created.
%
%  If the devices are already added, they are not re-created unless
%  FORCE is provided and is 1.
%

if nargin<3,
	force = 0;
end;

S = ndi.session.dir(ref, dirname);
devnames = ndi.setup.daq.system.yangyangwang(); % returns list of daq system names

for i=1:numel(vhlabdevnames),
	dev = S.daqsystem_load('name',devnames{i});
	if force,
		S.daqsystem_rm(dev);
		dev = [];
	end;
	if isempty(dev),
		S = ndi.setup.daq.system.yangyangwang(S, devnames{i});
	end
end
