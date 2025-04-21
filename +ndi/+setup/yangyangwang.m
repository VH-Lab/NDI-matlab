function S = yangyangwang(ref, dirname, force)
    % ndi.setup.yangyangwang - initialize an ndi.session.dir with YANGYANGWANG devices
    %
    %  S = ndi.setup.yangyangwang(REF, DIRNAME, [FORCE])
    %
    %  Initializes an ndi.session.dir object for the directory
    %  DIRNAME with the standard compliment of YANGYANGWANG devices, as
    %  found in "ndi_common/daq_systems/yangyangwang"
    %
    %  If the devices are already added, they are not re-created unless
    %  FORCE is provided and is 1.

    if nargin < 3; force = 0; end

    S = ndi.session.dir(ref, dirname);
    S = ndi.setup.daq.addDaqSystems(S, 'yangyangwang', force);
end
