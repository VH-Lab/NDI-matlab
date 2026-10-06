function report = verifyDataset(path, options)
%VERIFYDATASET Check a written Haley V2 dataset against what the import built.
%
%   REPORT = ndi.setup.conv.haley.verifyDataset(PATH) reads the V2 dataset
%   at PATH (the folder holding .ndi, e.g. <data>/haley_V2/dataset) and
%   checks it, printing each check's denominator first:
%
%     1 open      ndi.dataset.dir opens it; every session it lists opens,
%                 with the reference it is listed under
%     2 census    documents per class and per session, read from the
%                 database; with 'Expected', compared to what the import
%                 counted before writing (differences listed)
%     3 edges     every depends_on value names a document in the database
%                 (dangling ones counted by class and edge name)
%     4 files     every file the database records exists: an ingested one
%                 in .ndi/files, one recorded by location where it points
%     5 hashes    every ingested body whose document records an MD5
%                 content_hash still has that MD5 ('Hashes', false skips)
%
%   Options:
%     'Expected'  the import's result (r = import_V2(...)); its
%                 r.dataset.report.documents is the expected census
%     'Hashes'    default true
%
%   REPORT has one field per check, and `failed`, the names of the checks
%   that found a problem. It writes nothing.
%
%   See also ndi.setup.conv.haley.import_V2, ndi.setup.V2.createDataset.

arguments
    path (1,:) char {mustBeFolder}
    options.Expected = []
    options.Hashes (1,1) logical = true
end

report = struct('failed', {{}});
ndiDir = fullfile(path, '.ndi');
dbFile = fullfile(ndiDir, ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME());
if ~isfile(dbFile)
    error('ndi:setup:conv:haley:noDataset', 'No V2 database at %s.', dbFile);
end

% ---- 1 open -------------------------------------------------------------------
fprintf('\n== 1 open ==\n');
ds = ndi.dataset.dir(path);
[refs, ids] = ds.session_list();
bad = {};
for k = 1:numel(ids)
    try
        s = ds.open_session(ids{k});
        if ~strcmp(s.reference, refs{k})
            bad{end+1} = sprintf('%s opened with reference %s', refs{k}, s.reference); %#ok<AGROW>
        end
    catch err
        bad{end+1} = sprintf('%s: %s', refs{k}, err.message); %#ok<AGROW>
    end
end
fprintf('DENOMINATOR: dataset %s; %d session(s) listed, %d opened\n', ds.id(), numel(ids), ...
    numel(ids) - numel(bad));
printList(bad);
report.open = struct('datasetId', ds.id(), 'sessions', {refs}, 'problems', {bad});
if ~isempty(bad), report.failed{end+1} = 'open'; end

db = did2.database.sqlitedb(dbFile);
closer = onCleanup(@() db.close());
q = @(sql) mksqlite(db.testHookDbId(), sql);

% ---- 2 census -----------------------------------------------------------------
fprintf('\n== 2 census ==\n');
byClass = struct2table(q(['SELECT classname AS class, COUNT(*) AS n FROM documents ' ...
    'GROUP BY classname ORDER BY classname']), 'AsArray', true);
bySession = struct2table(q(['SELECT session_id, COUNT(*) AS n FROM documents ' ...
    'GROUP BY session_id ORDER BY session_id']), 'AsArray', true);
total = sum(byClass.n);
fprintf('DENOMINATOR: %d document(s) in %d class(es) and %d session id(s)\n', total, ...
    height(byClass), height(bySession));
report.census = struct('total', total, 'byClass', byClass, 'bySession', bySession, ...
    'differences', {{}});
if ~isempty(options.Expected)
    E = options.Expected.dataset.report.documents;
    d = [compareCounts(E.byClass, 'class', byClass, 'class', 'class'), ...
         compareCounts(E.bySession, 'session_id', bySession, 'session_id', 'session')];
    fprintf('  compared with the import''s own count: %d difference(s)\n', numel(d));
    printList(d);
    report.census.differences = d;
    if ~isempty(d), report.failed{end+1} = 'census'; end
else
    fprintf('  (no ''Expected'': counts reported, not compared)\n');
end
disp(byClass);

% ---- 3 edges ------------------------------------------------------------------
fprintf('\n== 3 edges ==\n');
n = q('SELECT COUNT(*) AS n FROM depends_on WHERE document_id <> ''''');
dang = q(['SELECT d.classname AS class, e.name AS edge, COUNT(*) AS n ' ...
    'FROM depends_on e JOIN documents d ON d.id = e.doc_id ' ...
    'LEFT JOIN documents t ON t.id = e.document_id ' ...
    'WHERE e.document_id <> '''' AND t.id IS NULL GROUP BY d.classname, e.name']);
nDang = 0;
if ~isempty(dang), nDang = sum([dang.n]); end
fprintf('DENOMINATOR: %d edge value(s) naming a document; %d dangling\n', n.n, nDang);
if nDang > 0, disp(struct2table(dang, 'AsArray', true)); end
report.edges = struct('checked', n.n, 'dangling', nDang, 'byClassEdge', dang);
if nDang > 0, report.failed{end+1} = 'edges'; end

% ---- 4 files ------------------------------------------------------------------
fprintf('\n== 4 files ==\n');
F = q('SELECT doc_id, filename, uid, location, ingested FROM files');
fileDir = fullfile(ndiDir, 'files');
missing = {};
nIngested = 0;
for k = 1:numel(F)
    if F(k).ingested
        nIngested = nIngested + 1;
        p = fullfile(fileDir, F(k).uid);
    else
        p = F(k).location;
    end
    if ~isfile(p)
        missing{end+1} = sprintf('%s (%s of document %s)', p, F(k).filename, F(k).doc_id); %#ok<AGROW>
    end
end
fprintf('DENOMINATOR: %d file(s) recorded: %d ingested, %d by location; %d missing\n', ...
    numel(F), nIngested, numel(F) - nIngested, numel(missing));
printList(missing, 20);
report.files = struct('recorded', numel(F), 'ingested', nIngested, 'missing', {missing});
if ~isempty(missing), report.failed{end+1} = 'files'; end

% ---- 5 hashes -----------------------------------------------------------------
if options.Hashes
    fprintf('\n== 5 hashes ==\n');
    B = q(['SELECT f.doc_id, f.uid, d.body FROM files f JOIN documents d ON d.id = f.doc_id ' ...
        'WHERE f.ingested = 1']);
    checked = 0; noHash = 0; wrong = {};
    for k = 1:numel(B)
        [h, alg] = recordedHash(jsondecode(B(k).body));
        if isempty(h) || ~strcmpi(alg, 'MD5')
            noHash = noHash + 1;
            continue;
        end
        p = fullfile(fileDir, B(k).uid);
        if ~isfile(p), continue; end            % counted under files
        checked = checked + 1;
        if ~strcmpi(ndi.fun.file.MD5(p), h)
            wrong{end+1} = sprintf('document %s: %s', B(k).doc_id, p); %#ok<AGROW>
        end
    end
    fprintf('DENOMINATOR: %d ingested file(s); %d with a recorded MD5 checked, %d with none; %d differ\n', ...
        numel(B), checked, noHash, numel(wrong));
    printList(wrong, 20);
    report.hashes = struct('ingested', numel(B), 'checked', checked, 'noHash', noHash, ...
        'differ', {wrong});
    if ~isempty(wrong), report.failed{end+1} = 'hashes'; end
end

fprintf('\n== verdict ==\n');
if isempty(report.failed)
    fprintf('all checks passed\n');
else
    fprintf('FAILED: %s\n', strjoin(report.failed, ', '));
end
end

% -----------------------------------------------------------------------------
function d = compareCounts(E, eKey, A, aKey, what)
% differences between the expected (groupsummary: GroupCount) and actual (n) counts
d = {};
e = containers.Map(cellstr(string(E.(eKey))), num2cell(E.GroupCount));
a = containers.Map(cellstr(string(A.(aKey))), num2cell(double(A.n)));
for k = union(keys(e), keys(a))
    x = 0; y = 0;
    if isKey(e, k{1}), x = e(k{1}); end
    if isKey(a, k{1}), y = a(k{1}); end
    if x ~= y
        d{end+1} = sprintf('%s %s: expected %d, found %d', what, k{1}, x, y); %#ok<AGROW>
    end
end
end

function [h, alg] = recordedHash(s)
% the content_hash and hash_algorithm of a body document, in whichever block holds them
h = ''; alg = '';
for f = reshape(fieldnames(s), 1, [])
    b = s.(f{1});
    if isstruct(b) && isscalar(b) && isfield(b, 'content_hash') && ~isempty(b.content_hash)
        h = char(b.content_hash);
        if isfield(b, 'hash_algorithm'), alg = char(b.hash_algorithm); end
        return;
    end
end
end

function printList(items, limit)
if nargin < 2, limit = Inf; end
for k = 1:min(numel(items), limit)
    fprintf('  %s\n', items{k});
end
if numel(items) > limit
    fprintf('  ... and %d more\n', numel(items) - limit);
end
end
