function S = vhlab(ref, dirname, force)
    % ndi.setup.vhlab - initialize an ndi.session.dir with VHLAB devices
    %
    %  S = ndi.setup.vhlab(REF, DIRNAME, [FORCE])
    %
    %  Initializes an ndi.session.dir object for the directory
    %  DIRNAME with the standard compliment of VHLAB devices, as
    %  found in "ndi_common/daq_systems/vhlab".
    %
    %  If the devices are already added, they are not re-created unless
    %  FORCE is provided and is 1.

    if nargin < 3; force = 0; end

    S = ndi.session.dir(ref, dirname);
    S = ndi.setup.daq.addDaqSystems(S, 'vhlab', force);

    % update SYNCGRAPH
    % Default rule: match epochs whose underlying files share the same name.
    nsf = ndi.time.syncrule.filematch(struct('number_fullpath_matches',2));
    S.syncgraph_addrule(nsf);

    % Add the vhlab-specific synchronization rules (vhintan<->vhvis_spike2 and
    % vhtaste_sync<->vhtaste_bpod). These are defined declaratively in
    % ndi_common/sync_rules/vhlab so that ndi.setup.lab('vhlab',...) and
    % ndi.setup.vhlab(...) stay in sync from a single source of truth.
    S = ndi.setup.sync.addSyncRules(S, 'vhlab');

    % Synchronize vhneuropixelsGLX and vhajbpod_np. Both DAQ readers inherit
    % from the NDR neuropixelsGLX reader and share the per-epoch .nidq.meta
    % and .imec0.ap.meta files, so the default filematch rule (2 fullpath
    % matches) added above already groups their epochs. The vhajbpod_np
    % reader recovers event times directly from NI-DAQ digital input 1 of
    % the same SpikeGLX recording, so its mk1/mk2 events are already in the
    % NI-DAQ device-local time and no cross-clock mapping rule is needed.
end
