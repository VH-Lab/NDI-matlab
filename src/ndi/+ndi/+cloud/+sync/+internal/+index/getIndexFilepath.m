function indexPath = getIndexFilepath(ndiDatasetPath, mode, options)
    arguments
        ndiDatasetPath (1,1) string {mustBeFolder}
        mode (1,1) string {mustBeMember(mode, ["read", "write"])}
        options.Verbose (1,1) logical = true
    end

    syncDirPath = fullfile(ndiDatasetPath, '.ndi', 'sync');
    if ~isfolder(syncDirPath)
        if mode == "write"
            if options.Verbose
                fprintf('Creating sync directory: %s\n', syncDirPath);
            end
            mkdir(syncDirPath);
        end
    end
    indexPath = fullfile(syncDirPath, 'index.json');
end
