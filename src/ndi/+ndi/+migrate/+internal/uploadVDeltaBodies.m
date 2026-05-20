function report = uploadVDeltaBodies(datasetId, vDeltaBodies, options)
%UPLOADVDELTABODIES Bulk-upload V_delta document bodies to NDI Cloud.
%
%   REPORT = ndi.migrate.internal.uploadVDeltaBodies(DATASETID, BODIES)
%   serialises the V_delta struct bodies (cell array of structs) to a
%   single JSON file, zips it, requests a bulk-upload URL via
%   `ndi.cloud.api.documents.getBulkUploadURL`, and PUTs the zip there.
%
%   This mirrors the production bulk-upload flow used by
%   `ndi.cloud.upload.uploadDocumentCollection` but bypasses the
%   ndi.document wrapper because the migration command already holds
%   raw V_delta structs from `did2.convert.v1_to_v2`.
%
%   REPORT is a struct with fields:
%       uploadType - 'batch' or 'none' when BODIES was empty.
%       manifest   - cell array of `base.id` strings in this batch.
%       status     - 'success' or 'failure' per batch.
%       url        - the pre-signed URL that was used.
%
%   Name-value options:
%       BatchSize    - max bodies per zip (default Inf — one zip).
%       TargetFolder - where to write the temporary zip (default the
%                      NDI temp folder).
%
%   See also: ndi.cloud.upload.uploadDocumentCollection,
%             ndi.cloud.upload.internal.zip_documents_for_upload.

    arguments
        datasetId (1,1) string
        vDeltaBodies (1,:) cell
        options.BatchSize (1,1) double = Inf
        options.TargetFolder (1,1) string = ndi.common.PathConstants.TempFolder
    end

    report = struct();
    report.uploadType = 'none';
    report.manifest = {};
    report.status = {};
    report.url = '';

    if isempty(vDeltaBodies)
        return;
    end

    report.uploadType = 'batch';

    total = numel(vDeltaBodies);
    for i = 1:options.BatchSize:total
        startIdx = i;
        endIdx = min(i + options.BatchSize - 1, total);
        chunk = vDeltaBodies(startIdx:endIdx);
        ids = bodyIds(chunk);
        zipPath = '';
        try
            zipPath = writeChunkZip(chunk, char(datasetId), char(options.TargetFolder));

            [okURL, urlAnswer] = ndi.cloud.api.documents.getBulkUploadURL(datasetId);
            if ~okURL
                msg = '<no message>';
                if isstruct(urlAnswer) && isfield(urlAnswer, 'message')
                    msg = char(urlAnswer.message);
                end
                error('NDI:migrate:cloud:bulkUploadURLFailed', ...
                    'Failed to get bulk upload URL: %s', msg);
            end
            report.url = char(urlAnswer);

            okPut = ndi.cloud.api.files.putFiles(urlAnswer, zipPath);
            if ~okPut
                error('NDI:migrate:cloud:bulkUploadPutFailed', ...
                    'Bulk upload PUT failed for dataset "%s".', datasetId);
            end

            report.manifest{end+1} = ids;
            report.status{end+1}   = 'success';
        catch err
            % Partial uploads corrupt the migration — surface the
            % error so the caller can release the lock and abort
            % instead of silently leaving the dataset half-migrated.
            if isfile(zipPath)
                try delete(zipPath); catch, end
            end
            rethrow(err);
        end
        if isfile(zipPath)
            try delete(zipPath); catch, end
        end
    end
end

function ids = bodyIds(chunk)
    ids = cell(1, numel(chunk));
    for k = 1:numel(chunk)
        body = chunk{k};
        if isstruct(body) && isfield(body, 'base') && isfield(body.base, 'id')
            ids{k} = char(body.base.id);
        else
            ids{k} = '';
        end
    end
end

function zipPath = writeChunkZip(chunk, datasetId, targetFolder)
    properties = chunk(:).';
    jsonStr = did.datastructures.jsonencodenan(properties);

    jsonName = [ndi.file.temp_name() '.json'];
    fid = fopen(jsonName, 'wt');
    fprintf(fid, '%s', jsonStr);
    fclose(fid);

    id = ndi.ido;
    zipName = id.identifier;
    zipPath = fullfile(targetFolder, [datasetId '.' zipName '.zip']);
    zip(zipPath, jsonName);
    delete(jsonName);
end
