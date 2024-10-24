function S = lab(labname, ref, dirname)
    % ndi.setup.lab - initialize an NDI_SESSION_DIR with devices from a particular lab
    %
    %  S = ndi.setup.lab(LABNAME, REF, DIRNAME)
    %
    %  Initializes an ndi.session.dir object for the directory
    %  DIRNAME with the standard compliment of LABNAME devices, as
    %  found in "ndi_common/daq_systems/LABNAME".
    %
    %  Example:
    %
    %  S = ndi.setup.lab('marderlab','745',['path/to/my/files/745_003'])
    %
    %  If the devices are already added, they are not re-created.

    S = ndi.session.dir(ref, dirname);
    S = ndi.setup.daq.addDaqSystems(S, labname);
end
