function [b, answer, apiResponse, apiURL] = getFileTier(cloudDatasetID, cloudDocumentID)
%GETFILETIER Read the cached files-tier summary for one document.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.getFileTier(...
%       CLOUDDATASETID, CLOUDDOCUMENTID)
%
%   Answers "what tier are this document's files on?" from the doc's cached
%   `filesTier` summary. Backed by GET /datasets/{d}/documents/{doc} (via
%   ndi.cloud.api.documents.getDocument) -- there is no dedicated tier read
%   endpoint because the server keeps a per-doc summary alongside the doc,
%   recomputed by the tier worker after every job. See
%   ndi-cloud-node/manuals/file-tier-design.md.
%
%   Inputs:
%       cloudDatasetID   - The ID of the dataset (string).
%       cloudDocumentID  - The cloud API ID of the document.
%
%   Outputs:
%       b            - True on a successful get-document call. False on any
%                      transport/HTTP failure -- the caller sees the same
%                      status that getDocument would surface.
%       answer       - On success, a struct with:
%                         counts     - per-tier file-count map (STANDARD |
%                                      STANDARD_IA | GLACIER_IR | GLACIER |
%                                      DEEP_ARCHIVE | PSEUDO_COLD -> integer).
%                                      Empty struct when the doc has never
%                                      had a tier operation.
%                         dominant   - the coldest tier with a non-zero
%                                      count (the design's `dominantFileTier`
%                                      shorthand). "" if no tier state yet.
%                         notes      - cell array of divergence notes, e.g.
%                                      "warmest-wins overruled a freeze
%                                      because sibling doc needs file warm".
%                                      Empty when clean.
%                         updatedAt  - timestamp of the last summary write.
%                                      Missing until the first tier job runs.
%                         raw        - the full get-document response, for
%                                      callers that want the whole doc.
%                      On failure, the getDocument error payload.
%       apiResponse  - The ResponseMessage from getDocument.
%       apiURL       - The URL of the underlying getDocument call.
%
%   Example:
%       [ok, tier] = ndi.cloud.api.files.getFileTier("d-12345", "doc-abc");
%       if ok
%           fprintf('dominant tier: %s\n', tier.dominant);
%       end
%
%   See also: ndi.cloud.api.documents.getDocument,
%             ndi.cloud.api.files.setFileTier,
%             ndi.cloud.api.files.getFileTierJob

    arguments
        cloudDatasetID  (1,1) string
        cloudDocumentID (1,1) string
    end

    [b, doc, apiResponse, apiURL] = ndi.cloud.api.documents.getDocument(...
        cloudDatasetID, cloudDocumentID);

    if ~b
        % Propagate the underlying error unchanged so the caller sees the
        % same shape (status code, error body) it would from getDocument.
        answer = doc;
        return;
    end

    % Project the tier summary out of the doc. Absent fields become empty --
    % a caller can rely on `dominant` and `counts` existing.
    answer = struct( ...
        'counts',    struct(), ...
        'dominant',  "", ...
        'notes',     {{}}, ...
        'updatedAt', missing, ...
        'raw',       doc);

    if isstruct(doc) && isfield(doc, 'filesTier') && ~isempty(doc.filesTier) ...
            && isstruct(doc.filesTier)
        summary = doc.filesTier;
        if isfield(summary, 'counts') && ~isempty(summary.counts)
            answer.counts = summary.counts;
        end
        if isfield(summary, 'dominant') && ~isempty(summary.dominant)
            answer.dominant = string(summary.dominant);
        end
        if isfield(summary, 'notes') && ~isempty(summary.notes)
            % jsondecode gives a cellstr for arrays of strings; keep that
            % shape so callers can iterate with for k = 1:numel(notes).
            if iscell(summary.notes)
                answer.notes = summary.notes;
            else
                answer.notes = cellstr(string(summary.notes));
            end
        end
        if isfield(summary, 'updatedAt') && ~isempty(summary.updatedAt)
            answer.updatedAt = summary.updatedAt;
        end
    end
end
