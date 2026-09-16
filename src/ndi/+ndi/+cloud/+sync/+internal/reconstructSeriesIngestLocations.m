function seriesInfo = reconstructSeriesIngestLocations(seriesInfo, fileInfo, fileDirectory, cloudDatasetId)
%RECONSTRUCTSERIESINGESTLOCATIONS Rebuild series ingest_locations from a downloaded manifest.
%
%   SERIESINFO = ndi.cloud.sync.internal.reconstructSeriesIngestLocations( ...
%       SERIESINFO, FILEINFO, FILEDIRECTORY, CLOUDDATASETID)
%
%   For every series in SERIESINFO that declares `n_present > 0` and
%   carries no `ingest_locations`, this reads the downloaded manifest file
%   from FILEDIRECTORY and rebuilds a one-per-present-member
%   `ingest_locations` struct array. Every reconstructed entry is
%   `ingest = 0` and `delete_original = 0`: the point of the reconstruction
%   is to satisfy DID-matlab #185's MembersNotLocatable guard on the
%   following `add_docs`, not to trigger any member download at add time.
%
%   Motivation. `ingest_locations` is transient authoring data that DID
%   strips before storing a document, so a cloud round trip returns
%   `n_present` without any way to locate the uids. VH-Lab/DID-matlab#185
%   added a guard that refuses that shape ("its file series ... declares N
%   present members but records no location for any of them"), and every
%   `SyncFiles=true` cloud download hit the guard on the first document
%   with a series. This helper closes that gap on the download side: the
%   manifest bytes are on disk (SyncFiles just wrote them), so the uid of
%   each present slot can be read back and the entries reconstructed.
%   Tracked in VH-Lab/NDI-matlab#958.
%
%   Inputs:
%       seriesInfo      - The document's `files.series_info` struct array.
%                         Modified in place: each entry that qualifies for
%                         reconstruction has its `ingest_locations` field
%                         set on return.
%       fileInfo        - The document's `files.file_info` struct array.
%                         Used to look up the manifest's file uid: a series
%                         named NAME has an ordinary file_info entry whose
%                         `name` is NAME, whose `locations(1).uid` is the
%                         manifest's uid, and whose local copy therefore
%                         lives at fullfile(fileDirectory, manifestUid).
%       fileDirectory   - Directory that holds the downloaded files, i.e.
%                         the same directory the earlier per-file download
%                         wrote to.
%       cloudDatasetId  - The cloud dataset id. Reconstructed entries use
%                         'ndic://<cloudDatasetId>/<memberUid>' as their
%                         `location`, matching the URI scheme
%                         `download_file_from_cloud` understands.
%
%   Outputs:
%       seriesInfo      - The updated struct array.
%
%   A series whose manifest cannot be located (the file_info entry is
%   missing, the manifest file is not on disk, or `readSeriesManifest`
%   errors) is left alone -- the guard will fire on `add_docs`, which is
%   the right signal to give the caller when the download itself was
%   incomplete.
%
%   Every reconstructed entry carries the six fields
%       { index, uid, location, location_type, ingest, delete_original }
%   that the DID authoring path already uses, so the shape matches what
%   `did.implementations.sqlitedb/do_add_doc`'s member loop expects.
%
%   See also:
%       ndi.cloud.sync.internal.updateFileInfoForLocalFiles,
%       did.file.readSeriesManifest

    arguments
        seriesInfo
        fileInfo
        fileDirectory   (1,1) string
        cloudDatasetId  (1,1) string
    end

    if isempty(seriesInfo), return, end

    for k = 1 : numel(seriesInfo)
        entry = seriesInfo(k);
        if ~isfield(entry,'n_present') || isempty(entry.n_present) || entry.n_present <= 0
            continue
        end
        if isfield(entry,'ingest_locations') && ~isempty(entry.ingest_locations)
            continue
        end

        manifestUid = lookupManifestUid(fileInfo, entry.name);
        if isempty(manifestUid), continue, end

        manifestPath = char(fullfile(fileDirectory, manifestUid));
        if ~isfile(manifestPath), continue, end

        try
            manifest = did.file.readSeriesManifest(manifestPath);
        catch
            % A corrupt or short manifest is not something to fix here.
            % Leave the guard to raise on add_docs.
            continue
        end

        ingestLocations = buildIngestLocations(manifest, cloudDatasetId);
        if isempty(ingestLocations), continue, end

        seriesInfo(k).ingest_locations = ingestLocations;
    end
end

function manifestUid = lookupManifestUid(fileInfo, seriesName)
% Find the file_info entry whose `name` matches the series' name. Its
% locations(1).uid is the manifest file's uid.
    manifestUid = '';
    seriesName = char(seriesName);
    for m = 1 : numel(fileInfo)
        if ~strcmp(char(fileInfo(m).name), seriesName), continue, end
        if isempty(fileInfo(m).locations), return, end
        manifestUid = char(fileInfo(m).locations(1).uid);
        return
    end
end

function ingestLocations = buildIngestLocations(manifest, cloudDatasetId)
% One ingest_locations entry per present slot of the manifest.
% Order matches DID's authoring shape and its `sprintf('%s_%d', name, index)`
% naming (index is 1-based, same as manifest.uids{index}).
    ingestLocations = struct( ...
        'index', {}, ...
        'uid', {}, ...
        'location', {}, ...
        'location_type', {}, ...
        'ingest', {}, ...
        'delete_original', {});

    for slot = 1 : manifest.count
        memberUid = manifest.uids{slot};
        if isempty(memberUid), continue, end
        ingestLocations(end+1) = struct( ...
            'index',           slot, ...
            'uid',             memberUid, ...
            'location',        sprintf('ndic://%s/%s', char(cloudDatasetId), memberUid), ...
            'location_type',   'ndicloud', ...
            'ingest',          0, ...
            'delete_original', 0);  %#ok<AGROW>
    end
end
