function document = updateFileInfoForRemoteFiles(document, cloudDatasetId, manifestFolder)
% updateFileInfoForRemoteFiles - Update file info of document for remote (cloud-only) files
%
% Syntax:
%   document = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles(document, cloudDatasetId)
%   document = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles(document, cloudDatasetId, manifestFolder)
%
%   Update the file information in DOCUMENT for files that live remotely
%   in NDI Cloud. Every file_info entry gets its primary location rewritten
%   to "ndic://{cloudDatasetId}/{file_uid}" with location_type "ndicloud",
%   ingest=0 and delete_original=0.
%
%   SERIES MANIFESTS ARE INSTALLED LOCALLY WHEN AVAILABLE. When
%   MANIFESTFOLDER holds the manifest bytes of a series declared by this
%   document (file at fullfile(MANIFESTFOLDER, manifest_uid)), the
%   manifest entry is rebuilt as two locations -- the local copy first,
%   the ndic:// URI second -- mirroring what updateFileInfoForLocalFiles
%   does on the SyncFiles=true path. DID's add_docs then copies the
%   manifest into the destination database's FileDir, so DID-python's
%   _series_manifest_path (which only looks on local disk through
%   cached_path_for_uid) can enumerate members WITHOUT a lazy manifest
%   fetch. Without the local copy the reader raises
%   "the series ... manifest is not on this machine" on the first member
%   open, because the DID series-member customFileHandler is scoped to
%   MEMBERS, not manifests.
%
%   With MANIFESTFOLDER given, series_info.ingest_locations are also
%   reconstructed from the same manifest bytes -- one entry per present
%   member, ingest=0, location "ndic://{cloudDatasetId}/{member_uid}" --
%   so DID-matlab #185's MembersNotLocatable guard on do_add_doc passes.
%
% Input Arguments:
%   document       - The document object containing file information.
%   cloudDatasetId - The unique identifier for the cloud dataset.
%   manifestFolder - Optional; a directory holding pre-fetched series
%                    manifest files, keyed by manifest uid, as
%                    reconstructSeriesIngestLocations expects. Empty
%                    (the default) keeps the pure in-place rewrite --
%                    OK when this document declares no series, but
%                    fails downstream on a series-bearing document
%                    (add_docs trips the guard, or the reader can't
%                    open members).
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

    if ~document.has_files()
        return
    end

    originalFileInfo = document.document_properties.files.file_info;

    hasSeriesInfo = isfield(document.document_properties.files, 'series_info') ...
        && ~isempty(document.document_properties.files.series_info);
    if hasSeriesInfo
        originalSeriesInfo = document.document_properties.files.series_info;
    end

    % A local manifest copy is available for entry i when MANIFESTFOLDER
    % holds a file named by that entry's uid AND the entry is declared as
    % a file series on this document (only manifests get installed
    % locally on this path). Everything else stays cloud-only.
    manifestFolderChar = char(manifestFolder);
    installLocallyAt = strings(1, numel(originalFileInfo));
    if strlength(manifestFolder) > 0
        for i = 1:numel(originalFileInfo)
            entry = originalFileInfo(i);
            if isempty(entry.locations)
                continue
            end
            if ~document.isFileSeries(entry.name)
                continue
            end
            candidate = fullfile(manifestFolderChar, char(entry.locations(1).uid));
            if isfile(candidate)
                installLocallyAt(i) = string(candidate);
            end
        end
    end
    hasLocals = any(strlength(installLocallyAt) > 0);

    if hasLocals
        % One or more manifests to install: use the reset-then-add_file
        % path so DID handles the copy into FileDir and the ndic:// alias
        % goes on as a second location.
        document = document.reset_file_info();
        for i = 1:numel(originalFileInfo)
            entry = originalFileInfo(i);
            filename = entry.name;
            file_uid = entry.locations(1).uid;
            cloudLocation = sprintf('ndic://%s/%s', cloudDatasetId, file_uid);
            if strlength(installLocallyAt(i)) > 0
                document = document.add_file(filename, char(installLocallyAt(i)));
            end
            document = document.add_file(filename, cloudLocation);
        end
    else
        % No local copies: fast in-place location rewrite. Preserves the
        % legacy shape for docs that declare no series (or when nothing
        % was fetched to install).
        updatedFileInfo = originalFileInfo;
        for i = 1:numel(updatedFileInfo)
            updatedFileInfo(i).locations(1).delete_original = 0;
            updatedFileInfo(i).locations(1).ingest = 0;
            fileUid = updatedFileInfo(i).locations(1).uid;
            updatedFileInfo(i).locations(1).location = ...
                sprintf('ndic://%s/%s', cloudDatasetId, fileUid);
            updatedFileInfo(i).locations(1).location_type = 'ndicloud';
        end
        document = document.setproperties('files.file_info', updatedFileInfo);
    end

    if hasSeriesInfo
        if strlength(manifestFolder) > 0
            originalSeriesInfo = ndi.cloud.sync.internal.reconstructSeriesIngestLocations( ...
                originalSeriesInfo, originalFileInfo, manifestFolder, cloudDatasetId);
        end
        document = document.setproperties('files.series_info', originalSeriesInfo);
    end
end
