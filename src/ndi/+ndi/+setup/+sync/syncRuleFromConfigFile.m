function syncRule = syncRuleFromConfigFile(configFilePath)
    % syncRuleFromConfigFile - Construct an ndi.time.syncrule from a JSON config file
    %
    %   SYNCRULE = ndi.setup.sync.syncRuleFromConfigFile(CONFIGFILEPATH)
    %
    %   Reads a JSON synchronization-rule configuration file and constructs the
    %   corresponding ndi.time.syncrule object.
    %
    %   The JSON file must contain the following fields:
    %       syncrule_class - Full class name of the ndi.time.syncrule subclass
    %                        to instantiate (e.g. "ndi.time.syncrule.filefind").
    %       parameters     - A structure of parameters that is passed directly
    %                        to the constructor of that class.
    %
    %   Inputs:
    %       configFilePath - Full path to an existing JSON configuration file.
    %
    %   Outputs:
    %       syncRule - An ndi.time.syncrule object.
    %
    %   See also: ndi.setup.sync.addSyncRules, ndi.time.syncrule

    arguments
        configFilePath (1,:) {mustBeFile}
    end

    S = jsondecode(fileread(configFilePath));

    if ~isfield(S, 'syncrule_class') || ~isfield(S, 'parameters')
        error('NDI:Setup:InvalidSyncRuleConfig', ...
            ['Sync rule configuration file (%s) must contain both a ' ...
            '''syncrule_class'' field and a ''parameters'' field.'], ...
            configFilePath);
    end

    syncRule = feval(char(S.syncrule_class), S.parameters);
end
