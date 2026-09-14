function manifestUids = collectSeriesManifestUids(documents)
%COLLECTSERIESMANIFESTUIDS Manifest uids for every series still missing ingest_locations.
%
%   MANIFESTUIDS = ndi.cloud.sync.internal.collectSeriesManifestUids(DOCS)
%
%   Walk DOCS (cell array of ndi.document) and collect the manifest file
%   uid of every ``files.series_info`` entry that (a) reports
%   ``n_present > 0`` and (b) carries no ``ingest_locations``. That is
%   exactly the shape a cloud-round-tripped document arrives in
%   (VH-Lab/NDI-matlab#958) -- and the shape
%   ``reconstructSeriesIngestLocations`` fixes when handed the manifest
%   bytes.
%
%   Returned as a unique, sorted ``string`` array (empty when no
%   reconstruction is needed). The caller uses this list to fetch just
%   the manifests through ``ndi.cloud.download.downloadDatasetFiles``
%   before running the pure-remote file-info update: manifests are
%   small, one per series document, and are the only bytes needed to
%   satisfy DID-matlab #185's MembersNotLocatable guard on
%   ``add_docs``.
%
%   See also:
%       ndi.cloud.sync.internal.downloadNdiDocuments
%       ndi.cloud.sync.internal.updateFileInfoForRemoteFiles
%       ndi.cloud.sync.internal.reconstructSeriesIngestLocations

    manifestUids = string.empty;

    if isempty(documents)
        return
    end

    if ~iscell(documents)
        documents = {documents};
    end

    for i = 1:numel(documents)
        doc = documents{i};
        if isempty(doc), continue, end
        if ~ismethod(doc, 'has_files') || ~doc.has_files(), continue, end
        files = doc.document_properties.files;
        if ~isfield(files, 'series_info') || isempty(files.series_info)
            continue
        end
        if ~isfield(files, 'file_info') || isempty(files.file_info)
            continue
        end
        seriesInfo = files.series_info;
        for k = 1:numel(seriesInfo)
            entry = seriesInfo(k);
            if ~isfield(entry, 'n_present') || isempty(entry.n_present) || entry.n_present <= 0
                continue
            end
            if isfield(entry, 'ingest_locations') && ~isempty(entry.ingest_locations)
                continue
            end
            uid = lookupManifestUid(files.file_info, entry.name);
            if ~isempty(uid)
                manifestUids(end+1) = string(uid); %#ok<AGROW>
            end
        end
    end

    if isempty(manifestUids)
        manifestUids = string.empty;
    else
        manifestUids = unique(manifestUids);
    end
end

function uid = lookupManifestUid(fileInfo, seriesName)
% The manifest is a plain file_info entry whose `name` matches the
% series' name; its ``locations(1).uid`` is what the cloud knows the
% manifest bytes by.
    uid = '';
    if isempty(seriesName), return, end
    seriesName = char(seriesName);
    for m = 1:numel(fileInfo)
        if ~strcmp(char(fileInfo(m).name), seriesName), continue, end
        if isempty(fileInfo(m).locations), return, end
        uid = char(fileInfo(m).locations(1).uid);
        return
    end
end
