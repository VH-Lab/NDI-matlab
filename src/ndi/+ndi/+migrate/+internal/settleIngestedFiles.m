function [docs, report] = settleIngestedFiles(docs, ndiDir)
%SETTLEINGESTEDFILES Point migrated documents' ingested files at bytes v1 already ingested.
%
%   [DOCS, REPORT] = ndi.migrate.internal.settleIngestedFiles(DOCS, NDIDIR)
%   rewrites the `files.file_info` locations of the migrated documents DOCS
%   (a cell array of did2.document) before they are added to the did2
%   database under NDIDIR (the session's .ndi directory).
%
%   WHY. A v1 document records each file as it was when the document was
%   FIRST added: `ingest` 1, `location` the path the bytes came from (often
%   a temporary file), usually `delete_original` 1. The legacy backend
%   (did.implementations.sqlitedb) carried that out at the time -- it copied
%   the bytes to <.ndi>/files/<uid> and deleted the original -- and kept the
%   record unchanged. did2.database.sqlitedb (DID-matlab b351ea7, 2026-10-04)
%   now ingests on add as well, from the recorded location, and REFUSES the
%   whole batch when that location is gone (did2:database:ingestSourceMissing).
%   So re-adding a v1 document asks for an ingestion that already happened,
%   from a path that no longer exists, and the migration writes nothing.
%   Measured on the 20211116 corpus: 473 documents (hartley_calc 210,
%   element_epoch 252, stimulus_presentation 11), every location `ingest` 1,
%   `delete_original` 1, at a path on the author's computer.
%
%   WHAT IT DOES, per location with `ingest` true:
%     * the bytes are already in the store (<NDIDIR>/files/<uid>, the layout
%       did2.database.sqlitedb shares with the legacy backend): the location
%       becomes that path, so did2 finds identical bytes at the destination
%       and copies nothing. Counted `inStore`.
%     * not in the store, but at the recorded location (a 'file'): left as
%       it is, and did2 ingests it. Counted `atSource`.
%     * neither: the bytes are not on this computer (a document-only corpus,
%       or a session copied without its files/ directory). The location is
%       recorded BY REFERENCE (`ingest` 0) at the store path for a 'file'
%       location, or where it is for any other location type, so the
%       document migrates and the file reads the moment its bytes are put
%       in the store. Counted `missing`, and warned
%       (NDI:migrate:ingestedFileMissing), never silent.
%       DECIDED (Jess Haley, 2026-10-21): migrate and warn, rather than refuse
%       the session or flag each document; the warning and the `missing`
%       count are the record of what is absent.
%   `delete_original` is set to 0 on every ingested location: v1 already
%   acted on it, and a migration must never delete a file.
%
%   A location whose uid is not a plain file name (did.file.isSafeUid) is
%   left untouched, so did2 refuses it with its own error.
%
%   REPORT (denominator first): documents, documentsWithFiles,
%   ingestLocations, inStore, atSource, missing, unsafeUid, changedDocuments,
%   missingExamples (up to 5 'name of document id (location)' strings).
%
%   See also ndi.migrate.local, did2.database.sqlitedb,
%            ndi.database.implementations.database.did2sqlite.

arguments
    docs cell
    ndiDir (1,:) char
end

storeDir = fullfile(ndiDir, 'files');
report = struct( ...
    'documents',          numel(docs), ...
    'documentsWithFiles', 0, ...
    'ingestLocations',    0, ...
    'inStore',            0, ...
    'atSource',           0, ...
    'missing',            0, ...
    'unsafeUid',          0, ...
    'changedDocuments',   0, ...
    'missingExamples',    {{}});

for k = 1:numel(docs)
    s = docs{k}.toStruct();
    if ~isfield(s, 'files') || ~isstruct(s.files) || ~isfield(s.files, 'file_info') ...
            || isempty(s.files.file_info)
        continue;
    end
    report.documentsWithFiles = report.documentsWithFiles + 1;
    docId = '';
    if isfield(s, 'base') && isstruct(s.base) && isfield(s.base, 'id')
        docId = char(s.base.id);
    end
    fi = s.files.file_info;
    changed = false;
    for i = 1:numel(fi)
        if iscell(fi)
            entry = fi{i};
        else
            entry = fi(i);
        end
        [entry, c, report] = settleEntry(entry, storeDir, docId, report);
        if c
            changed = true;
            if iscell(fi)
                fi{i} = entry;
            else
                fi(i) = entry;
            end
        end
    end
    if changed
        s.files.file_info = fi;
        docs{k} = did2.document(s);
        report.changedDocuments = report.changedDocuments + 1;
    end
end

if report.missing > 0
    warning('NDI:migrate:ingestedFileMissing', ...
        ['%d of %d ingested file location(s) (over %d document(s), %d with files) ' ...
         'have their bytes neither in %s nor at the recorded location; they are ' ...
         'recorded by reference at the store path and read once the bytes are ' ...
         'put there. First: %s'], ...
        report.missing, report.ingestLocations, report.documents, ...
        report.documentsWithFiles, storeDir, report.missingExamples{1});
end
end

function [entry, changed, report] = settleEntry(entry, storeDir, docId, report)
changed = false;
if ~isstruct(entry) || ~isfield(entry, 'locations') || isempty(entry.locations)
    return;
end
name = '';
if isfield(entry, 'name'), name = char(entry.name); end
locs = entry.locations;
for j = 1:numel(locs)
    if iscell(locs)
        L = locs{j};
    else
        L = locs(j);
    end
    [L, c, report] = settleLocation(L, storeDir, name, docId, report);
    if c
        changed = true;
        if iscell(locs)
            locs{j} = L;
        else
            locs(j) = L;
        end
    end
end
if changed
    entry.locations = locs;
end
end

function [L, changed, report] = settleLocation(L, storeDir, name, docId, report)
changed = false;
if ~isstruct(L) || ~isfield(L, 'ingest') || isempty(L.ingest) || ~logical(L.ingest(1))
    return;
end
report.ingestLocations = report.ingestLocations + 1;
uid = '';
if isfield(L, 'uid'), uid = L.uid; end
if isstring(uid), uid = char(uid); end
if ~ischar(uid) || ~did.file.isSafeUid(uid)
    report.unsafeUid = report.unsafeUid + 1;
    return;
end
type = 'file';
if isfield(L, 'location_type') && ~isempty(L.location_type)
    type = lower(strtrim(char(L.location_type)));
end
source = '';
if isfield(L, 'location') && ~isempty(L.location)
    source = char(L.location);
end

% v1 already carried out delete_original; a migration never deletes a file.
if isfield(L, 'delete_original') && ~isempty(L.delete_original) ...
        && logical(L.delete_original(1))
    L.delete_original = sameKind(L.delete_original, false);
    changed = true;
end

stored = fullfile(storeDir, uid);
if isfile(stored)
    report.inStore = report.inStore + 1;
    if isfield(L, 'location') && (~strcmp(source, stored) || ~strcmp(type, 'file'))
        L.location = stored;
        if isfield(L, 'location_type')
            L.location_type = 'file';
        end
        changed = true;
    end
    return;
end
if strcmp(type, 'file') && ~isempty(source) && isfile(source)
    report.atSource = report.atSource + 1;
    return;
end

report.missing = report.missing + 1;
if numel(report.missingExamples) < 5
    report.missingExamples{end+1} = sprintf('%s of document %s (%s)', ...
        name, docId, source);
end
L.ingest = sameKind(L.ingest, false);
% Only an existing field is assigned: a struct-array element must keep the
% same fields as its siblings.
if strcmp(type, 'file') && isfield(L, 'location')
    L.location = stored;
end
changed = true;
end

function v = sameKind(old, tf)
% Keep a numeric flag numeric (v1 writes 0/1) and a logical one logical.
if isnumeric(old)
    v = double(tf);
else
    v = logical(tf);
end
end
