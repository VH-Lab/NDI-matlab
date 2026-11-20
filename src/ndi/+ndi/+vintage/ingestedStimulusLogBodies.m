function M = ingestedStimulusLogBodies(S, readerId, epochIds)
%INGESTEDSTIMULUSLOGBODIES The migrated stimulus logs of a reader's epochs, wherever they are owned.
%
%   M = ndi.vintage.ingestedStimulusLogBodies(SESSION, READERID, EPOCHIDS)
%   is a containers.Map from each epoch id of EPOCHIDS (a cellstr of v1
%   epoch ids, the `local_identifier`s of v2 epoch entities) that has one to
%   a cell of the data bodies (ndi.document) holding that epoch's stimulus
%   log for the reader READERID: the v1 ingested archive files of a stimulus
%   system (`channel_list.bin`, `evmktx_group<g>_seg.nbf_#`), moved to the
%   epoch's stimulus-presentation manipulation, or, with no presentation, to
%   an observation of the stimulus rig's device (Decided by Jess Haley,
%   2026-11-19 [stimulus log owned by its presentation], did-schema
%   docs/plans/did_v2_standing_wiring_plan.md). An epoch with none is not a
%   key. The bodies of an epoch are in the database's order.
%
%   THE LOOKUP. A data body of this session (`isa data_body`: an
%   opaque_body, or a sampled_body if a later pass converts one) whose
%   `data_body.notes` opens with ndi.vintage.ingestedStimulusLogKey(EPOCHID,
%   READERID), followed by a space or nothing, and whose `data_body.filename`
%   is an ingested archive series (`channel_list.bin`, or
%   `<ai|ao|ax|di|do|ti|evmktx>_group<g>_seg.nbf_#`). ONE search for all of
%   EPOCHIDS: the notes must contain the reader's part of the key
%   (contains_string), and each hit's epoch is read from the start of its
%   notes and checked here, so 't0007' never matches epoch 't00074' and
%   another reader's log is never taken. The owner is not read: whatever
%   owns the body (a presentation, which names no acquisition system, or the
%   fallback observation, which does), the body says whose log it is.
%
%   For a v2 database. EPOCHIDS empty, or READERID empty: M is empty and no
%   search is made.
%
%   See also ndi.vintage.ingestedStimulusLogKey, ndi.vintage.ingestedArchive,
%            ndi.vintage.ingestedArchives.

arguments
    S
    readerId (1,:) char
    epochIds
end

M = containers.Map('KeyType', 'char', 'ValueType', 'any');
epochIds = unique(reshape(cellstr(epochIds), 1, []), 'stable');
epochIds = epochIds(~cellfun(@isempty, epochIds));
if isempty(epochIds) || isempty(readerId)
    return;
end
readerPart = ndi.vintage.ingestedStimulusLogKey('', readerId);
q = ndi.query('', 'isa', 'data_body', '') & ...
    ndi.query('data_body.notes', 'contains_string', readerPart, '');
sid = '';
try
    sid = char(S.id());
catch
    % a session-like object with no id(): ndi.session scopes every search
    % to its own session anyway (ndi.session/database_search)
end
if ~isempty(sid)
    q = q & ndi.query('base.session_id', 'exact_string', sid, '');
end
hits = S.database_search(q);
prefix = 'The stimulus log of epoch ';
for k = 1:numel(hits)
    p = ndi.v2.props(hits{k});
    if ~isfield(p, 'data_body') || ~isstruct(p.data_body)
        continue;
    end
    notes = char(ndi.v2.notesOf(p.data_body));
    if ~startsWith(notes, prefix)
        continue;
    end
    i = strfind(notes, readerPart);
    if isempty(i)
        continue;
    end
    epochId = notes(numel(prefix)+1:i(1)-1);
    if ~any(strcmp(epochIds, epochId))
        continue;
    end
    key = ndi.vintage.ingestedStimulusLogKey(epochId, readerId);
    rest = notes(numel(key)+1:end);
    if ~startsWith(notes, key) || ~(isempty(rest) || startsWith(rest, ' '))
        continue;
    end
    if ~isSeries(filenameOf(p.data_body))
        continue;
    end
    held = {};
    if isKey(M, epochId); held = M(epochId); end
    held{end+1} = hits{k}; %#ok<AGROW>
    M(epochId) = held;
end
end

function tf = isSeries(fn)
% the series ndi.daq.reader.mfdaq/ingest_epochfiles attaches (private/archiveOf)
tf = strcmp(fn, 'channel_list.bin') || ...
    ~isempty(regexp(fn, '^(ai|ao|ax|di|do|ti|evmktx)_group\d+_seg\.nbf_#$', 'once'));
end

function s = filenameOf(blk)
s = '';
if isfield(blk, 'filename') && ~isempty(blk.filename) && ...
        (ischar(blk.filename) || isstring(blk.filename))
    s = char(blk.filename);
end
end
