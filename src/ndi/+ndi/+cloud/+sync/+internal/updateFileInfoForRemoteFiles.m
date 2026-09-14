function document = updateFileInfoForRemoteFiles(document, cloudDatasetId, manifestFolder)
% updateFileInfoForRemoteFiles - Update file info of document for remote (cloud-only) files
%
% Syntax:
%   document = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles(document, cloudDatasetId)
%   document = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles(document, cloudDatasetId, manifestFolder)
%   This function updates the file information in the provided document
%   object for files that are stored remotely in NDI cloud.
%
%   The following changes are made to the file location structure:
%       1. set the 'delete_original' and 'ingest' fields to false.
%       2. set the location field using the template "ndic://{dataset_id}/{file_uid}"
%       3. set the location_type field to "ndicloud"
%
%   When MANIFESTFOLDER is supplied and the document declares any file
%   series with n_present > 0, the series' ingest_locations are
%   reconstructed from the manifest files staged in MANIFESTFOLDER --
%   one entry per present member, location_type "ndicloud",
%   location "ndic://{cloudDatasetId}/{memberUid}". Same DID-matlab #185
%   guard the SyncFiles=true path satisfies, closed on the pure-remote
%   path (NDI-matlab#958 follow-up).
%
% Input Arguments:
%   document       - The document object containing file information.
%   cloudDatasetId - The unique identifier for the cloud dataset.
%   manifestFolder - Optional; a directory holding pre-fetched series
%                    manifest files, keyed by manifest uid, as
%                    reconstructSeriesIngestLocations expects. Empty (the
%                    default) skips series reconstruction; a series with
%                    n_present > 0 will then hit DID's guard on the
%                    following add_docs, same as before this argument
%                    existed.
%
% Output Arguments:
%   document          - The updated document object with modified file info.
%
% See also:
%   ndi.cloud.sync.internal.updateFileInfoForLocalFiles
%   ndi.cloud.sync.internal.reconstructSeriesIngestLocations

    arguments
        document
        cloudDatasetId (1,1) string
        manifestFolder (1,1) string = ""
    end

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

        % Rebuild series ingest_locations from staged manifests, when the
        % caller provided a folder to read them from. The manifest bytes
        % themselves still live on the cloud (DID re-fetches at read
        % time); MANIFESTFOLDER only exists so we can enumerate member
        % uids for the DID-matlab #185 guard.
        if strlength(manifestFolder) > 0 ...
                && isfield(document.document_properties.files, 'series_info') ...
                && ~isempty(document.document_properties.files.series_info)
            seriesInfo = document.document_properties.files.series_info;
            seriesInfo = ndi.cloud.sync.internal.reconstructSeriesIngestLocations( ...
                seriesInfo, updatedFileInfo, manifestFolder, cloudDatasetId);
            document = document.setproperties('files.series_info', seriesInfo);
        end
    end
end
