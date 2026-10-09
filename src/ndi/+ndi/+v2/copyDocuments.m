function report = copyDocuments(sourceDb, targetDb, docs, options)
%COPYDOCUMENTS Copy V2 documents, and the files they ingested, to another database.
%
%   REPORT = ndi.v2.copyDocuments(SOURCEDB, TARGETDB, DOCS) adds DOCS (a cell
%   of document property structs, read from SOURCEDB) to TARGETDB. Both are
%   did2.database.sqlitedb objects (an ndi session's is its
%   database.db). Each file a document INGESTED into SOURCEDB is ingested
%   into TARGETDB from SOURCEDB's copy (<its folder>/files/<uid>), which is
%   left in place; a file recorded BY LOCATION (`ingest` 0) stays where it is
%   and is recorded the same way. Ids, edges and session ids are unchanged.
%
%   Nothing is written when a file a document ingested is missing from
%   SOURCEDB: the copy would lose it.
%
%   REPORT: documents (how many copied), ingested (files copied into
%   TARGETDB's store) and byLocation (files still recorded by location).
%
%   Options:
%     'BatchSize'  documents per write (default 2000)
%     'Validate'   default false: the documents were validated when written
%                  to SOURCEDB
%
%   See also ndi.dataset, did2.database.sqlitedb.

arguments
    sourceDb
    targetDb
    docs cell
    options.BatchSize (1,1) double {mustBePositive, mustBeInteger} = 2000
    options.Validate (1,1) logical = false
end

report = struct('documents', numel(docs), 'ingested', 0, 'byLocation', 0);
missing = {};
for i = 1:numel(docs)
    [docs{i}, nIn, nBy, miss] = fromStore(docs{i}, sourceDb.fileDir);
    report.ingested = report.ingested + nIn;
    report.byLocation = report.byLocation + nBy;
    missing = [missing, miss]; %#ok<AGROW>
end
if ~isempty(missing)
    error('ndi:v2:copyDocuments:fileMissing', ...
        ['%d ingested file(s) are missing from %s, so nothing was copied (the copy ' ...
         'would lose them):\n  %s'], numel(missing), sourceDb.fileDir, ...
        strjoin(missing(1:min(end, 20)), '\n  '));
end
for b = 1:options.BatchSize:numel(docs)
    part = docs(b:min(b + options.BatchSize - 1, numel(docs)));
    targetDb.add(cellfun(@(d) did2.document(d), part, 'UniformOutput', false), ...
        'Validate', options.Validate);
end
end

% -----------------------------------------------------------------------------
function [d, nIn, nBy, missing] = fromStore(d, fileDir)
% D with every ingested location pointed at FILEDIR's copy, kept there
nIn = 0; nBy = 0; missing = {};
if ~isfield(d, 'files') || ~isstruct(d.files) || ~isfield(d.files, 'file_info') ...
        || isempty(d.files.file_info)
    return;
end
fi = d.files.file_info;
if iscell(fi), fi = [fi{:}]; end
for a = 1:numel(fi)
    if ~isfield(fi(a), 'locations'), continue; end
    if iscell(fi(a).locations), fi(a).locations = [fi(a).locations{:}]; end
    for c = 1:numel(fi(a).locations)
        L = fi(a).locations(c);
        if isfield(L, 'ingest') && logical(L.ingest)
            src = fullfile(fileDir, char(L.uid));
            if ~isfile(src)
                missing{end+1} = sprintf('%s of document %s (%s)', char(fi(a).name), ...
                    d.base.id, src); %#ok<AGROW>
            end
            fi(a).locations(c).location = src;
            fi(a).locations(c).delete_original = 0;
            nIn = nIn + 1;
        else
            nBy = nBy + 1;
        end
    end
end
d.files.file_info = fi;
end
