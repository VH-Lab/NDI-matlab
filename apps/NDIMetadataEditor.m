function NDIMetadataEditor(datasetFolder, temporaryMetadataFile)
    arguments 
        datasetFolder (1,1) string {mustBeFolder} = uigetdir()
        temporaryMetadataFile (1,:) string = ...
            fullfile(userpath, 'NDIDatasetUpload', 'dataset_metadata.mat');
    end
    
    ndiDataset = ndi.dataset.dir('test', char(datasetFolder));

    ndi.database.metadata_app.Apps.MetadataEditorApp(ndiDataset, temporaryMetadataFile)
end