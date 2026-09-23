function document = updateFileInfoForLocalFiles(document, fileDirectory, cloudDatasetId)
% updateFileInfoForLocalFiles - Update file info of document for local files
%
% Syntax:
%   document = ndi.cloud.sync.internal.updateFileInfoForLocalFiles(document, fileDirectory)
%   document = ndi.cloud.sync.internal.updateFileInfoForLocalFiles(document, fileDirectory, cloudDatasetId)
%       updates the file info of the document to point to a file in the
%       provided (local) file directory
%
%       When CLOUDDATASETID is supplied and the document declares any file
%       series with n_present > 0, the series' ingest_locations are
%       reconstructed from the downloaded manifest file (one entry per
%       present member, ingest=0). This satisfies DID-matlab #185's
%       MembersNotLocatable guard, which refuses a document whose series
%       records n_present members but records no way to locate any of
%       them -- exactly the shape a cloud round trip produces, because
%       ingest_locations is stripped at store time. See NDI-matlab #958.
%
% Input Arguments:
%   document       - The document object that contains file info to be updated
%   fileDirectory  - The directory where local files are stored
%   cloudDatasetId - Optional; the cloud dataset id, used to build the
%                    'ndic://' location strings of the reconstructed
%                    series ingest_locations. When "" (the default) the
%                    ingest_locations are not reconstructed, and any
%                    series with n_present > 0 will hit DID's guard on
%                    the following add_docs.
%
% Output Arguments:
%   document - The updated document object with new file info
%
% See also:
%   ndi.cloud.sync.internal.updateFileInfoForRemoteFiles

    arguments
        document
        fileDirectory (1,1) string
        cloudDatasetId (1,1) string = ""
    end

    if document.has_files()
        originalFileInfo = document.document_properties.files.file_info;

        % reset_file_info clears files.series_info along with file_info -- see
        % did.document/reset_file_info, "A series' per-instance record is reset
        % with the rest". The loop below only restores file_info, so without
        % this a downloaded document loses the per-series record entirely and
        % reports zero members for a populated series. Silently: isFileSeries
        % reads files.file_series, the class declaration, which the reset
        % leaves alone, so only seriesCount notices and it returns 0 rather
        % than erroring. See VH-Lab/NDI-matlab#945.
        %
        % Carried across verbatim. The record holds name, count, n_present and
        % source_root; its ingest_locations were already emptied on the way
        % into storage, and nothing here re-ingests members, so there is
        % nothing to recompute.
        hasSeriesInfo = isfield(document.document_properties.files, 'series_info');
        if hasSeriesInfo
            originalSeriesInfo = document.document_properties.files.series_info;
        end

        document = document.reset_file_info();
    
        for i = 1:numel(originalFileInfo)
            file_uid = originalFileInfo(i).locations(1).uid;
            file_location = fullfile(fileDirectory, file_uid);
    
            filename = originalFileInfo(i).name; % name for ingestion
            if isfile(file_location)
                document = document.add_file(filename, file_location);

                % A SERIES MANIFEST also keeps the cloud reference it came
                % from, as a second location alongside the local copy.
                %
                % Its members are still on the cloud -- they are left there
                % deliberately, so that opening a dataset does not drag down
                % a 28,000-member series -- and a member has no location of
                % its own. DID resolves one by handing the MANIFEST's
                % location to the customFileHandler with the member's uid in
                % the context, so that location is the only thing telling the
                % handler where to look. With the local path alone,
                % download_file_from_cloud is handed a path that does not
                % start with 'ndic://' and raises
                % NDI:Didsqlite:UnsupportedFileLocationType, which DID takes
                % as a plain miss -- so every member of a downloaded series
                % is unreadable, silently. See VH-Lab/NDI-matlab#966.
                %
                % The uid in the reference is the file's ORIGINAL uid, the
                % one the cloud knows it by. add_file mints a fresh uid for
                % this second location's own record, which is harmless: DID
                % passes only the location STRING to the handler, and the
                % member's uid comes from the context.
                %
                % Manifests only. Every other file is already here, and a
                % second location on each would be rows to no purpose.
                if strlength(cloudDatasetId) > 0 && document.isFileSeries(filename)
                    % ndi.document.add_file recognizes 'ndic://' and supplies
                    % ingest 0, delete_original 0, location_type 'ndicloud'.
                    document = document.add_file(filename, ...
                        sprintf('ndic://%s/%s', cloudDatasetId, file_uid));
                end
            else
                warning('Local file does not exist for document "%s"', ...
                    document.document_properties.base.id)
            end
        end

        if hasSeriesInfo
            if strlength(cloudDatasetId) > 0
                originalSeriesInfo = ndi.cloud.sync.internal.reconstructSeriesIngestLocations( ...
                    originalSeriesInfo, originalFileInfo, fileDirectory, cloudDatasetId);
            end
            document = document.setproperties('files.series_info', originalSeriesInfo);
        end
    end
end
