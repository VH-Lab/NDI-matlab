function S = marderlab(ref, dirname)
% ndi.setup.marderlab - initialize an NDI_SESSION_DIR with MARDERLAB devices
%
%  S = ndi.setup.marderlab(REF, DIRNAME)
%
%  Initializes an ndi.session.dir object for the directory
%  DIRNAME with the standard compliment of MARDERLAB devices, as
%  found in "ndi_common/daq_systems/marderlab".
%
%  If the devices are already added, they are not re-created.

    S = ndi.session.dir(ref, dirname);
    S = ndi.setup.daq.addDaqSystems(S, 'marderlab');
end
