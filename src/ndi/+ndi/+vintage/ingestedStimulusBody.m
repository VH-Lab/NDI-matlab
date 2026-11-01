function doc = ingestedStimulusBody(session, readerId, epochId)
%INGESTEDSTIMULUSBODY A migrated epoch's ingested stimulus file, as its presentation's data body.
%
%   DOC = ndi.vintage.ingestedStimulusBody(SESSION, READERID, EPOCHID) is the
%   `opaque_body` (an ndi.document) that holds the ingested stimulus file of
%   epoch EPOCHID, read by the metadata reader READERID, in SESSION; [] when
%   SESSION holds none.
%
%   v1 NDI stores an epoch's stimulus file, on ingest, as a
%   `daqmetadatareader_epochdata_ingested` document (ndi.daq.metadatareader/
%   ingest_epochfiles): `data.bin`, a gzip'd .nbf.tgz written by
%   ndi.compress.compress_metadata, with an `epochid.epochid` field and a
%   `daqmetadatareader_id` edge. The V_eta migration makes it an
%   `opaque_body` of that epoch's stimulus-presentation manipulation, joined
%   by session and epoch id (Jess Haley, 2026-10-26, [ingested stimulus file
%   is a body of the presentation]; ndi.migrate.internal.ingestedStimulusBodies):
%   the same id, the same bytes as the body's one member `body_data_0`, and
%   the epoch and the reader named in its description
%   (ndi.vintage.ingestedStimulusKey), the only place the body records them.
%
%   THE LOOKUP (Jess Haley, 2026-10-26, [ingested stimulus reader finds the
%   body]): an `opaque_body` of this session whose `data_body.description`
%   opens with the key for this epoch and this reader, followed by a space
%   (the key ends at the reader id; ' (<class>)' or ' read from' follows), and
%   whose `data_body.filename` is the v1 file's name, 'data.bin'. The
%   description is matched in the query (contains_string) and again here
%   from its start, so 't0007' never matches epoch 't00074'.
%
%   MORE THAN ONE MATCH IS AN ERROR (NDI:vintage:severalIngestedStimulusBodies),
%   not a pick: the migration writes at most one per v1 document, and v1 NDI
%   writes one per reader per epoch.
%
%   See also ndi.vintage.ingestedStimulusKey, ndi.daq.metadatareader.

arguments
    session
    readerId {mustBeText}
    epochId {mustBeText}
end

doc = [];
readerId = char(readerId);
epochId = char(epochId);
if isempty(readerId) || isempty(epochId)
    return;
end
key = ndi.vintage.ingestedStimulusKey(epochId, readerId);
% the body's free text is `notes` since did-schema [one free-text field:
% notes] (Jess Haley, 2026-10-25), `description` before: either is searched
q = ndi.query('', 'isa', 'opaque_body', '') & ...
    (ndi.query('data_body.notes', 'contains_string', key, '') | ...
     ndi.query('data_body.description', 'contains_string', key, ''));
sid = '';
try
    sid = char(session.id());
catch
    % a session-like object with no id(): ndi.session scopes every search
    % to its own session anyway (ndi.session/database_search)
end
if ~isempty(sid)
    q = q & ndi.query('base.session_id', 'exact_string', sid, '');
end
hits = session.database_search(q);
keep = {};
for k = 1:numel(hits)
    p = ndi.v2.props(hits{k});
    if ~isfield(p, 'data_body') || ~isstruct(p.data_body)
        continue;
    end
    desc = ndi.v2.notesOf(p.data_body);
    if ~startsWith(desc, [key ' ']) || ~strcmp(textOf(p.data_body, 'filename'), 'data.bin')
        continue;
    end
    keep{end+1} = hits{k}; %#ok<AGROW>
end
if numel(keep) > 1
    ids = cellfun(@(d) char(d.id()), keep, 'UniformOutput', false);
    error('NDI:vintage:severalIngestedStimulusBodies', ...
        ['%d migrated ingested stimulus files name epoch %s and metadata reader ' ...
         '%s (%s); there should be at most one.'], numel(keep), epochId, readerId, ...
        strjoin(ids, ', '));
end
if ~isempty(keep)
    doc = keep{1};
end
end

function s = textOf(blk, name)
s = '';
if isfield(blk, name) && ~isempty(blk.(name)) && (ischar(blk.(name)) || isstring(blk.(name)))
    s = char(blk.(name));
end
end
