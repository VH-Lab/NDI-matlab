function report = compareDatasetSummary(summary1, summary2, options)
% COMPAREDATASETSUMMARY - compare two dataset summaries and return a report
%
% REPORT = NDI.UTIL.COMPAREDATASETSUMMARY(SUMMARY1, SUMMARY2, ...)
%
% Compares SUMMARY1 and SUMMARY2, identifying any differences in
% the dataset-level metadata (numSessions, references, sessionIds)
% and the per-session summaries (using ndi.util.compareSessionSummary).
%
% Returns a cell array of character arrays with one entry per
% difference noted. If no differences are found, returns an empty
% cell array {}.
%
% This function accepts name-value pair arguments:
%   'excludeFiles' - A cell array of strings or character arrays
%       specifying filenames (or directories) to ignore when
%       comparing session summaries. Passed through to
%       ndi.util.compareSessionSummary.
%

arguments
    summary1 (1,1) struct
    summary2 (1,1) struct
    options.excludeFiles (1,:) cell = {}
end

report = {};

% 1. Compare numSessions
if isfield(summary1, 'numSessions') && isfield(summary2, 'numSessions')
    if summary1.numSessions ~= summary2.numSessions
        report{end+1} = sprintf('numSessions differs: %d vs %d', ...
            summary1.numSessions, summary2.numSessions);
        return; % No point continuing if session counts differ
    end
elseif isfield(summary1, 'numSessions') ~= isfield(summary2, 'numSessions')
    report{end+1} = 'numSessions field is missing from one summary';
    return;
end

numSessions = summary1.numSessions;

% 2. Compare references
refs1 = ensureCellStr(summary1, 'references');
refs2 = ensureCellStr(summary2, 'references');
if ~isequal(sort(refs1), sort(refs2))
    report{end+1} = sprintf('Session references differ: {%s} vs {%s}', ...
        strjoin(sort(refs1), ', '), strjoin(sort(refs2), ', '));
end

% 3. Compare sessionIds
ids1 = ensureCellStr(summary1, 'sessionIds');
ids2 = ensureCellStr(summary2, 'sessionIds');
if ~isequal(sort(ids1), sort(ids2))
    report{end+1} = sprintf('Session IDs differ: {%s} vs {%s}', ...
        strjoin(sort(ids1), ', '), strjoin(sort(ids2), ', '));
    return; % Can't match sessions if IDs differ
end

% 4. Compare per-session summaries
ss1 = ensureCell(summary1, 'sessionSummaries');
ss2 = ensureCell(summary2, 'sessionSummaries');

for i = 1:numSessions
    sid = ids1{i};

    % Find matching session summary in each by sessionId
    idx1 = findSessionSummaryBySessionId(ss1, sid);
    idx2 = findSessionSummaryBySessionId(ss2, sid);

    if isempty(idx1)
        report{end+1} = sprintf('No session summary found for session ID %s in summary1', sid);
        continue;
    end
    if isempty(idx2)
        report{end+1} = sprintf('No session summary found for session ID %s in summary2', sid);
        continue;
    end

    sessionReport = ndi.util.compareSessionSummary(ss1{idx1}, ss2{idx2}, ...
        'excludeFiles', options.excludeFiles);
    for k = 1:numel(sessionReport)
        report{end+1} = sprintf('Session %s: %s', sid, sessionReport{k});
    end
end

% 5. Compare document counts if both have them
if isfield(summary1, 'documentCounts') && isfield(summary2, 'documentCounts')
    dc1 = ensureCell(summary1, 'documentCounts');
    dc2 = ensureCell(summary2, 'documentCounts');
    for i = 1:numSessions
        sid = ids1{i};
        count1 = findDocumentCount(dc1, sid);
        count2 = findDocumentCount(dc2, sid);
        if ~isempty(count1) && ~isempty(count2) && count1 ~= count2
            report{end+1} = sprintf('Document count mismatch for session %s: %d vs %d', ...
                sid, count1, count2);
        end
    end
end

end

function c = ensureCellStr(s, fieldName)
% Ensure a field is a cell array of strings (handles jsondecode char case)
    if ~isfield(s, fieldName)
        c = {};
        return;
    end
    c = s.(fieldName);
    if ischar(c)
        c = {c};
    elseif isstring(c)
        c = cellstr(c);
    end
    % Ensure row vector
    c = c(:)';
end

function c = ensureCell(s, fieldName)
% Ensure a field is a cell array (handles jsondecode struct array case)
    if ~isfield(s, fieldName)
        c = {};
        return;
    end
    c = s.(fieldName);
    if ~iscell(c)
        if isstruct(c)
            % Convert struct array to cell array
            c = arrayfun(@(x) x, c, 'UniformOutput', false);
        else
            c = {c};
        end
    end
end

function idx = findSessionSummaryBySessionId(summaries, sessionId)
% Find the index of a session summary with a given sessionId
    idx = [];
    for j = 1:numel(summaries)
        if isstruct(summaries{j}) && isfield(summaries{j}, 'sessionId') && ...
                strcmp(summaries{j}.sessionId, sessionId)
            idx = j;
            return;
        end
    end
end

function count = findDocumentCount(docCounts, sessionId)
% Find the document count for a given sessionId
    count = [];
    for j = 1:numel(docCounts)
        if isstruct(docCounts{j}) && isfield(docCounts{j}, 'sessionId') && ...
                strcmp(docCounts{j}.sessionId, sessionId)
            count = docCounts{j}.count;
            return;
        end
    end
end
