function summary = datasetSummary(dataset_obj, options)
% DATASETSUMMARY - create a summary structure of an ndi.dataset object
%
% SUMMARY = NDI.UTIL.DATASETSUMMARY(DATASET_OBJ)
%
% Returns a structure SUMMARY containing key fields and properties
% of the NDI.DATASET object DATASET_OBJ. This structure is intended
% for symmetry testing between different NDI language implementations.
%
% The summary includes:
%   - numSessions: number of sessions in the dataset
%   - references: cell array of session reference strings
%   - sessionIds: cell array of session ID strings
%   - sessionSummaries: cell array of session summary structs
%     (produced by ndi.util.sessionSummary for each session)
%   - documentCounts (optional): cell array of structs with
%     sessionId and count fields, one per session
%
% This function accepts name-value pair arguments:
%   'includeDocumentCounts' - Logical (default false). If true,
%       also counts documents per session and includes them in the
%       summary as a 'documentCounts' field.
%

arguments
    dataset_obj (1,1) {mustBeA(dataset_obj, "ndi.dataset")}
    options.includeDocumentCounts (1,1) logical = false
end

% Get session list from dataset
[ref_list, id_list] = dataset_obj.session_list();
numSessions = numel(ref_list);

% Build session summaries for each session in the dataset
sessionSummaries = cell(1, numSessions);
for i = 1:numSessions
    sess = dataset_obj.open_session(id_list{i});
    sessionSummaries{i} = ndi.util.sessionSummary(sess);
end

% Build the dataset summary structure
summary = struct();
summary.numSessions = numSessions;
summary.references = ref_list;
summary.sessionIds = id_list;
summary.sessionSummaries = sessionSummaries;

% Optionally record document counts per session
if options.includeDocumentCounts
    documentCounts = cell(1, numSessions);
    for i = 1:numSessions
        sess = dataset_obj.open_session(id_list{i});
        docs = sess.database_search(ndi.query('base.id', 'regexp', '(.*)'));
        documentCounts{i} = struct('sessionId', id_list{i}, 'count', numel(docs));
    end
    summary.documentCounts = documentCounts;
end

end
