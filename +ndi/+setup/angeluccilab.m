function S = angeluccilab(ref, dirname)
% ndi.setup.angeluccilab - initialize an NDI_SESSION_DIR with ANGELUCCILAB devices
%
%  S = ndi.setup.angeluccilab(REF, DIRNAME)
%
%  Initializes an ndi.session.dir object for the directory
%  DIRNAME with the standard compliment of ANGELUCCILAB devices, as
%  found in "ndi_common/daq_systems/angeluccilab".
%
%  If the devices are already added, they are not re-created.

    S = ndi.session.dir(ref, dirname);
    S = ndi.setup.daq.addDaqSystems(S, 'angeluccilab');

    % update SYNCGRAPH
    nsf = ndi.time.syncrule.filematch(struct('number_fullpath_matches',2));
    S.syncgraph_addrule(nsf);
end
