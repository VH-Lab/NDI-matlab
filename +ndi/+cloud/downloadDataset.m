function ndiDataset = downloadDataset(cloudDatasetId, targetFolder, options)
% DOWNLOADDATASET - Downloads a dataset from the NDI Cloud to a local folder.
%
% Syntax:
%   NDIDATASET = ndi.cloud.DOWNLOADDATASET(CLOUDDATASETID, TARGETFOLDER, OPTIONS)
%   Downloads a dataset specified by CLOUDDATASETID to TARGETFOLDER,
%   with additional options for synchronization mode.
%
% Inputs:
%   CLOUDDATASETID (string)         - Identifier for the dataset in the cloud.
%   TARGETFOLDER (string)           - Local folder to save the downloaded dataset.
%   OPTIONS.SynchMode (SynchMode)   - Mode of synchronization (default: Hybrid).
%
% Outputs:
%   NDIDATASET - An ndi.dataset object representing the downloaded dataset.

    arguments
        cloudDatasetId (1,1) string = missing
        targetFolder (1,1) string = missing
        options.SynchMode (1,1) ndi.cloud.synch.enum.SynchMode = "Hybrid"
        options.Verbose (1,1) logical = true
    end
    
    import ndi.cloud.synch.enum.SynchMode

    % Prompt user for required values if missing
    if ismissing(cloudDatasetId)
        cloudDatasetId = ndi.cloud.ui.dialog.selectCloudDataset();
    end
    if ismissing(targetFolder)
        targetFolder = uigetdir(pwd, 'Select a dataset target folder');
        if targetFolder == 0
            error('NDI:DownloadCloudDataset:UserCanceled', ...
                'Operation aborted during selection of a dataset target folder.')
        end
    end

    targetFolder = fullfile(targetFolder, cloudDatasetId);
    if ~isfolder(targetFolder)
        mkdir(targetFolder)
    end
    
    if options.Verbose
        disp('Downloading dataset documents...')
    end
    ndiDocuments = ndi.cloud.download.download_document_collection(cloudDatasetId);

    if options.SynchMode == SynchMode.Local
        ndi.cloud.download.download_dataset_files(...
            cloudDatasetId, ...
            targetFolder, ...
            "Verbose", options.Verbose)
    end

    ndiDocuments = ndi.cloud.download.internal.update_document_file_info(...
        ndiDocuments, options.SynchMode, fullfile(targetFolder, 'download', 'files')); %todo: path to downloaded files should not be hardcoded here.

    if options.Verbose
        disp('Building dataset from documents...')
        if options.SynchMode == SynchMode.Local
            disp('Will copy downloaded files into dataset. May take several minutes if the dataset is large...')
        end
    end
    ndiDataset = ndi.dataset.dir([], targetFolder, ndiDocuments);

    % Check if document is already here...
    doc = ndiDataset.database_search( ndi.query('','isa','dataset_remote') );
    if isempty(doc)
        % Create a document with the identifier and organization of the dataset
        remoteDatasetDoc = ndi.cloud.internal.create_remote_dataset_doc(cloudDatasetId, ndiDataset);
        ndiDataset.database_add(remoteDatasetDoc);
    end
end
