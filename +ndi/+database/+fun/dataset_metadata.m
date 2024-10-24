function dataset_metadata(S, new, options) % ,varargin)
    % DATASET_METADATA - opens a MATLAB app for users to enter metadata
    % information
    %
    % ndi.database.fun.dataset_metadata(S, NEW)
    %
    % Inputs:
    %   S - an ndi.session object
    %   NEW - create a new metadata form enter 1. Otherwise enter 0.

    arguments
        S ndi.session       % An NDI session object
        new (1,1) logical   % A boolean flag specifying whether to create new metadata or edit existing
        options.Debug (1,1) logical = false
    end

    if nargin == 2
        disp("Opening metadata app, please wait a moment...");
        metadataRootPath = fullfile( S.path, ".ndi", "NDIDatasetUpload");

        if (new)
            if ~isfolder(metadataRootPath); mkdir(metadataRootPath); end

            ido_ = ndi.ido;
            rand_num = ido_.identifier;
            temp_filename = sprintf("metadata_%s.mat", rand_num);
            file_path = fullfile(metadataRootPath, temp_filename);
            a = ndi.database.metadata_app.Apps.MetadataEditorApp(S,file_path,options.Debug);
        else
            file_list = dir(fullfile(metadataRootPath, 'metadata_*.mat'));
            for i = 1:numel(file_list)
                full_file_path = fullfile(metadataRootPath, file_list(i).name);
                a = ndi.database.metadata_app.Apps.MetadataEditorApp(S,full_file_path,options.Debug);
            end
        end
    end
