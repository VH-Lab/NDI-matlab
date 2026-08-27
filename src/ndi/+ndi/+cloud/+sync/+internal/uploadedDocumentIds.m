function ids = uploadedDocumentIds(uploadReport)
% UPLOADEDDOCUMENTIDS - IDs that uploadDocumentCollection actually uploaded
%
%   IDS = ndi.cloud.sync.internal.uploadedDocumentIds(UPLOADREPORT)
%
%   Returns, as a string row vector, the NDI document IDs that were uploaded
%   successfully according to UPLOADREPORT (the report returned by
%   ndi.cloud.upload.uploadDocumentCollection). Only manifest entries whose
%   corresponding status is 'success' contribute; the intended-to-upload list
%   is never assumed.
%
%   uploadDocumentCollection reports two manifest shapes:
%     * serial: each manifest entry is a single document ID string.
%     * batch:  each manifest entry is a cell array of the document IDs in that
%               batch; a successful batch means all of its IDs were uploaded.
%   Both are handled here.
%
%   This exists because uploadReport has no 'uploaded_document_ids' field, so
%   the callers (mirrorToRemote, twoWaySync) previously fell through to
%   reporting *every* intended ID as uploaded even when the upload failed.

    ids = string.empty(1, 0);

    if ~isstruct(uploadReport) ...
            || ~isfield(uploadReport, 'manifest') ...
            || ~isfield(uploadReport, 'status')
        return;
    end

    n = min(numel(uploadReport.manifest), numel(uploadReport.status));
    for i = 1:n
        if strcmp(uploadReport.status{i}, 'success')
            entry = uploadReport.manifest{i};
            if iscell(entry)
                ids = [ids, string(reshape(entry, 1, []))]; %#ok<AGROW>
            else
                ids = [ids, string(entry)]; %#ok<AGROW>
            end
        end
    end
end
