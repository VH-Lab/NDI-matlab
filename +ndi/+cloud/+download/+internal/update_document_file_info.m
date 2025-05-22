function updatedNdiDocuments = update_document_file_info(ndiDocuments, synchMode, fileDirectory)
% UPDATE_DOCUMENT_FILE_INFO - Update file info parameters for ndi.documents different modes
%
% UPDATEDNDIDOCUMENTS = ndi.cloud.download.internal.UPDATE_DOCUMENT_FILE_INFO(NDIDOCUMENTS, MODE, FILEDIRECTORY)
%
% Given a cell array of ndi.documents, set the 'delete_original' and 'ingest' 
% fields of the document_properties.files.file_info.location as appropriate to 
% the mode.
%
% The MODE can be 'local' or 'hybrid'. If MODE is 'local', then
%   'delete_original' and 'ingest' are set to 1. Otherwise,
%   the are set to 0.
%
% FILEDIRECTORY is the location of any locally downloaded files (for 'local' MODE).

    arguments
        ndiDocuments
        synchMode (1,1) ndi.cloud.sync.enum.SyncMode
        fileDirectory (1,1) string
    end

    updatedNdiDocuments = ndiDocuments;
    
    numDocuments = numel(ndiDocuments);
    for iDocument = 1:numDocuments
    
        document = ndiDocuments{iDocument};
    
        if document.has_files()
            if synchMode == "Local"
                updatedNdiDocuments{iDocument} = ...
                    updateDocumentForLocalFiles(document, fileDirectory);
            else
                updatedNdiDocuments{iDocument} = ...
                    updateDocumentForCloudFiles(document);
            end
        end
    end
end

function updatedDocument = updateDocumentForLocalFiles(document, fileDirectory)

    originalFileInfo = document.document_properties.files.file_info;
    document = document.reset_file_info();

    for i = 1:numel(originalFileInfo)
        file_uid = originalFileInfo(i).locations(1).uid;
        file_location = fullfile(fileDirectory, file_uid);

        filename = originalFileInfo(i).name; % name for ingestion
        if isfile(file_location)
            document = document.add_file(filename, file_location);
        else
            warning('Local file does not exist for document "%s"', ...
                document.document_properties.base.id)
        end
    end
    updatedDocument = document;
end

function updatedDocument = updateDocumentForCloudFiles(document)
    
    updatedFileInfo = document.document_properties.files.file_info;
    
    for i = 1:numel(updatedFileInfo)
        for j = 1:numel(updatedFileInfo(i).locations)
            updatedFileInfo(i).locations(j).delete_original = 0;
            updatedFileInfo(i).locations(j).ingest = 0;
        end
    end
    updatedDocument = document.setproperties('files.file_info', updatedFileInfo);
end
