function S = addSyncRules(S, labName)
    % addSyncRules - Add lab-specific synchronization rules to an ndi session.
    %
    %   S = ndi.setup.sync.addSyncRules(S, LABNAME)
    %
    %   Adds the synchronization rules (ndi.time.syncrule objects) that are
    %   pre-configured for the lab LABNAME to the syncgraph of the ndi.session
    %   object S.
    %
    %   Rule definitions are read from JSON files located in
    %   'ndi_common/sync_rules/<labName>'. Each JSON file describes a single
    %   sync rule (see ndi.setup.sync.syncRuleFromConfigFile for the format).
    %   This is the synchronization-rule counterpart to
    %   ndi.setup.daq.addDaqSystems, which adds a lab's DAQ systems.
    %
    %   If no 'sync_rules/<labName>' folder exists, S is returned unchanged; a
    %   lab is not required to define any lab-specific rules. Rules that are
    %   already present in the syncgraph are not added again
    %   (see ndi.time.syncgraph/addrule).
    %
    %   Inputs:
    %       S       - An ndi.session object.
    %       labName - The name of the lab whose sync rules should be added
    %                 (char vector or string scalar, e.g. 'vhlab').
    %
    %   Outputs:
    %       S       - The ndi.session object, with the lab's sync rules added.
    %
    %   See also: ndi.setup.lab, ndi.setup.daq.addDaqSystems,
    %             ndi.setup.sync.syncRuleFromConfigFile, ndi.time.syncgraph

    importDir = fullfile(ndi.common.PathConstants.CommonFolder, 'sync_rules', char(labName));

    if ~isfolder(importDir)
        return; % no lab-specific sync rules are defined for this lab
    end

    L = dir(fullfile(importDir, '*.json'));

    for i = 1:numel(L)
        configFilePath = fullfile(importDir, L(i).name);
        syncRule = ndi.setup.sync.syncRuleFromConfigFile(configFilePath);
        S = S.syncgraph_addrule(syncRule);
    end
end
