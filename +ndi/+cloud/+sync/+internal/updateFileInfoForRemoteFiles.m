function document = updateFileInfoForRemoteFiles(document, cloudDatasetId)
% updateFileInfoForRemoteFiles - Update file info of document for remote (cloud-only) files
%
% Syntax:
%   document = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles(document, cloudDatasetId)
%   This function updates the file information in the provided document
%   object for files that are stored remotely in NDI cloud.
%
%   The following changes are made to the file location structure:
%       1. set the 'delete_original' and 'ingest' fields to false.
%       2. set the location field using the template "ndic://{dataset_id}/{file_uid}"
%       3. set the location_type field to "ndicloud"
%
% Input Arguments:
%   document          - The document object containing file information.
%   cloudDatasetId    - The unique identifier for the cloud dataset.
%
% Output Arguments:
%   document          - The updated document object with modified file info.
%
% See also:
%   ndi.cloud.sync.internal.updateFileInfoForLocalFiles

    if document.has_files()
        updatedFileInfo = document.document_properties.files.file_info;
        
        for i = 1:numel(updatedFileInfo)
            % Replace/override 1st file location
            updatedFileInfo(i).locations(1).delete_original = 0;
            updatedFileInfo(i).locations(1).ingest = 0;
    
            fileUid = updatedFileInfo(i).locations(1).uid;
            fileLocation = sprintf('ndic://%s/%s', cloudDatasetId, fileUid);
            updatedFileInfo(i).locations(1).location = fileLocation;
            updatedFileInfo(i).locations(1).location_type = 'ndicloud';
        end
        document = document.setproperties('files.file_info', updatedFileInfo);
    end
end
