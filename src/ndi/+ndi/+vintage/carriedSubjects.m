function [subjectId, found, carried, sources] = carriedSubjects(S, elementId)
%CARRIEDSUBJECTS The v1 subjects a migration held in its report's carried fields.
%
%   [SUBJECTID, FOUND] = ndi.vintage.carriedSubjects(S, ELEMENTID) is the v1
%   `depends_on subject_id` of the migrated element ELEMENTID that the
%   migration report of the session S (an ndi.session) holds as a carried
%   field, and whether one is held ('' and false when none).
%
%   [~, ~, CARRIED, SOURCES] = ndi.vintage.carriedSubjects(S) is every one: a
%   containers.Map from element id to subject id, and the ids of the
%   documents they were read from (the `migration` records and their report
%   bodies), for a derived row that depends on them
%   (ndi.vintage.prefetchElementFields).
%
%   THE DECISIONS (Jess Haley, 2026-11-19, did-schema
%   docs/plans/did_v2_standing_wiring_plan.md; carry register row carry-172):
%     [stimulator subject carried as needing information]  a migrated
%                 stimulator whose v1 `subject_id` no statement names gets no
%                 `observes`; its v1 subject is recorded as needing
%                 information;
%     [one-field carry in the migration report]  it is held in the run's
%                 migration report, a "carried fields" list {document_id,
%                 class, field, value, carry, reason}, written by NDI's
%                 second pass (ndi.migrate.internal.observesRetirement,
%                 through did2.convert.carryElementSubject);
%     [recording probe subject carried the same way]  likewise for a
%                 recording probe with no recording observation.
%   ndi.vintage.elementFields reads it as the element's `subject_id` where
%   no observation and no `observes` relation names one, so the v1 element
%   reads back as it was (`direct` true).
%
%   WHERE THE REPORT IS. A migration writes one `migration` document per
%   dataset (else per session), its report the `opaque_body` that names it
%   as `owner_id` (member `body_data_0`, a JSON file:
%   did2.convert.migrationRecord). The record names the dataset as its
%   session, so it is searched with the dataset's documents
%   (ndi.session/database_search_with_dataset) where the session can.
%
%   WHILE A MIGRATION RUNS (the record is not written yet), the run's own
%   report is read (did2.convert.carriedElementSubject) for an element the
%   stored records do not list.
%
%   CACHED. Each report file's carried fields are read once per MATLAB
%   session, keyed by the file's path, size and time (a record is written
%   once and never edited); the searches that find the session's records
%   and their files are made once per call, and inside an
%   ndi.vintage.elementFieldsScope once per scope.
%   ndi.vintage.carriedSubjects('clear') forgets the cache.
%
%   A record that cannot be read (no body, a file that is not the report)
%   lists nothing and warns once (NDI:vintage:migrationReportUnreadable): the
%   element then reads as before this field was carried.
%
%   See also ndi.vintage.elementFields, ndi.vintage.prefetchElementFields,
%   did2.convert.carriedElementSubject, did2.convert.migrationRecord.

persistent byRecord   % report file key -> containers.Map element id -> subject id
persistent hasRunApi  % did2.convert.carriedElementSubject is on the path
if isempty(byRecord)
    byRecord = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
subjectId = '';
found = false;
carried = containers.Map('KeyType', 'char', 'ValueType', 'char');
sources = {};
if ischar(S) && strcmp(S, 'clear')
    byRecord = containers.Map('KeyType', 'char', 'ValueType', 'any');
    return;
end
if nargin < 2
    elementId = '';
end
elementId = char(elementId);

sid = '';
try
    sid = char(S.id());
catch
end
scopeKey = '';
if ~isempty(sid) && ndi.vintage.elementFieldsScope('isopen')
    scopeKey = ['carried|' sid];
end
hit = false;
if ~isempty(scopeKey)
    [cached, hit] = ndi.vintage.elementFieldsScope('get', scopeKey);
end
if hit
    carried = cached.carried;
    sources = cached.sources;
else
    for r = recordsOf(S)
        [files, bodyIds] = reportFiles(S, r{1});
        sources = [sources, {char(r{1}.id())}, bodyIds]; %#ok<AGROW>
        for f = files
            % keyed by the file and its size and time: a corpus migrated
            % again in the same MATLAB session writes a new file
            key = f{1};
            d = dir(key);
            if isscalar(d)
                key = sprintf('%s|%d|%.10f', key, d.bytes, d.datenum);
            end
            if ~isKey(byRecord, key)
                byRecord(key) = readReport(f{1}, char(r{1}.id()));
            end
            m = byRecord(key);
            ks = keys(m);
            for k = 1:numel(ks)
                carried(ks{k}) = m(ks{k});
            end
        end
    end
    if ~isempty(scopeKey)
        ndi.vintage.elementFieldsScope('put', scopeKey, ...
            struct('carried', carried, 'sources', {sources}));
    end
end

if isempty(elementId)
    return;
end
if isKey(carried, elementId)
    subjectId = carried(elementId);
    found = true;
    return;
end
% a migration in progress: its own report, before the record is written
if isempty(hasRunApi)
    hasRunApi = ~isempty(which('did2.convert.carriedElementSubject'));
end
if hasRunApi && did2.convert.migrationReport('active')
    [subjectId, found] = did2.convert.carriedElementSubject(elementId);
end
end

function recs = recordsOf(S)
% the `migration` documents S can see, its dataset's included
recs = {};
q = ndi.query('', 'isa', 'migration', '');
try
    if ismethod(S, 'database_search_with_dataset')
        recs = S.database_search_with_dataset(q);
    else
        recs = S.database_search(q);
    end
catch
    recs = {};
end
recs = reshape(recs, 1, []);
end

function [files, bodyIds] = reportFiles(S, rec)
% the report files of the migration record REC: the member body_data_0 of
% each opaque_body naming it as owner_id, in the session's database or its
% dataset's
files = {};
bodyIds = {};
rid = char(rec.id());
q = ndi.query('', 'isa', 'opaque_body', '') & ndi.query('', 'depends_on', 'owner_id', rid);
bodies = {};
try
    if ismethod(S, 'database_search_with_dataset')
        bodies = S.database_search_with_dataset(q);
    else
        bodies = S.database_search(q);
    end
catch
end
if isempty(bodies)
    warnOnce(rid, 'it has no report body');
    return;
end
for b = 1:numel(bodies)
    bodyIds{end+1} = char(bodies{b}.id()); %#ok<AGROW>
    tf = false;
    p = '';
    try
        [tf, p] = S.database_existbinarydoc(bodies{b}, 'body_data_0');
    catch
    end
    if ~tf
        try
            if ~isempty(S.datasetDatabase)
                [tf, p] = S.datasetDatabase.existbinarydoc(bodies{b}, 'body_data_0');
            end
        catch
        end
    end
    if tf && ~isempty(p)
        files{end+1} = char(p); %#ok<AGROW>
    else
        warnOnce(rid, sprintf('its report body %s has no file', char(bodies{b}.id())));
    end
end
end

function m = readReport(file, rid)
% element id -> subject id, from the carried fields of one report file
m = containers.Map('KeyType', 'char', 'ValueType', 'char');
report = [];
try
    report = jsondecode(fileread(file));
catch ME
    warnOnce(rid, ME.message);
end
if ~isstruct(report) || ~isfield(report, 'carried_fields')
    return;   % a report written before carried fields lists none
end
entries = report.carried_fields;
if isstruct(entries)
    entries = num2cell(entries);
end
if ~iscell(entries)
    return;
end
field = 'depends_on subject_id';
if ~isempty(which('did2.convert.carriedElementSubject'))
    field = did2.convert.carriedElementSubject('field');
end
for k = 1:numel(entries)
    e = entries{k};
    if ~isstruct(e) || ~isfield(e, 'document_id') || ~isfield(e, 'field') ...
            || ~isfield(e, 'value') || ~strcmp(char(e.field), field)
        continue;
    end
    v = e.value;
    if isstring(v) && isscalar(v)
        v = char(v);
    end
    if ischar(v) && ~isempty(strtrim(v))
        m(char(e.document_id)) = strtrim(v);
    end
end
end

function warnOnce(rid, why)
persistent said
if isempty(said)
    said = {};
end
if any(strcmp(said, rid))
    return;
end
said{end+1} = rid;
warning('NDI:vintage:migrationReportUnreadable', ...
    ['The migration record %s could not be read (%s); its carried fields ' ...
     '([one-field carry in the migration report]) are not read.'], rid, why);
end
