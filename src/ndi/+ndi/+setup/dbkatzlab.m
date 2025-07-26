function S = dbkatzlab(ref, dirname)
    % ndi.setup.dbkatzlab - initialize an NDI_SESSION_DIR with KATZLAB devices
    %
    %  S = ndi.setup.dbkatzlab(REF, DIRNAME)
    %
    %  Initializes an ndi.session.dir object for the directory
    %  DIRNAME with the standard compliment of KATZLAB devices, as
    %  found in "ndi_common/daq_systems/dbkatzlab".
    %
    %  If the devices are already added, they are not re-created.

    S = ndi.session.dir(ref, dirname);
    S = ndi.setup.daq.addDaqSystems(S, 'dbkatzlab');
end
