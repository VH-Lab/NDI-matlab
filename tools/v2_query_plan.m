function T = v2_query_plan(datasetPath, options)
%V2_QUERY_PLAN Why a search through an ndi.dataset is slower than through its session.
%
%   T = v2_query_plan(DATASETPATH) takes one worm from a session of the V2
%   dataset at DATASETPATH and runs the query its statements() makes (isa
%   subject_statement AND depends_on subject_id = the worm) three ways:
%
%     dataset   the query as the ndi.dataset sends it
%     session   the same AND base.session_id = the session (what an
%               ndi.session adds to every search)
%     by edge   hand-written SQL that starts from the depends_on index
%               (the edge) and only then checks the class: what the plan
%               would be if SQLite chose the edge first
%
%   For each it prints the SQL, SQLite's EXPLAIN QUERY PLAN, the number of
%   hits and the time of the SQL alone (median of 'Repeats' runs); and the
%   time of the same search through ndi.dataset/database_search and
%   ndi.session/database_search, which adds reading each document. T is a
%   table of the timings.
%
%   It opens a second, read-only use of the dataset's database file and
%   writes nothing. Needs did2.database.sqlitedb's testHookExplain
%   (DID-matlab PR #218).
%
%   Options:
%     'Session'  the session reference (default: the first concentration one)
%     'Repeats'  timing runs per query (default 3)
%
%   See also v2_object_layer_tryout, did2.database.compileQuery.

arguments
    datasetPath (1,:) char {mustBeFolder}
    options.Session (1,:) char = ''
    options.Repeats (1,1) double {mustBePositive, mustBeInteger} = 3
end

D = 'ndi.database.implementations.database.did2sqlite';
dbFile = fullfile(datasetPath, '.ndi', feval([D '.DEFAULTFILENAME']));

% ---- the dataset, a session, a worm ---------------------------------------------
ds = ndi.dataset.dir(datasetPath);
[refs, ids] = ds.session_list();
ref = options.Session;
if isempty(ref), ref = refs{find(startsWith(refs, 'concentration'), 1)}; end
S = ds.open_session(ids{strcmp(refs, ref)});
sp = S.database_search(ndi.query('', 'isa', 'velocity_calculation', ''));
wormId = ndi.v2.edgeIds(ndi.v2.props(sp{1}), 'subject_id');
wormId = wormId{1};
fprintf('dataset %s\nsession %s (%s)\nworm    %s\n', datasetPath, ref, S.id(), wormId);

qBase = ndi.query('', 'isa', 'subject_statement', '') & ...
    ndi.query('', 'depends_on', 'subject_id', wormId);
qSession = qBase & ndi.query('base.session_id', 'exact_string', S.id(), '');

db = did2.database.sqlitedb(dbFile);
closer = onCleanup(@() db.close());
% the connection number is re-read before each use: ndi.dataset closes
% connections by number, and the database reopens on a new one (#218)
dbid = @() db.testHookDbId();

% ---- the size of each part --------------------------------------------------------
n = @(sql, varargin) double(firstRow(mksqlite(dbid(), sql, varargin{:})));
fprintf('\n== the parts ==\n');
fprintf('DENOMINATOR: %d document(s) in the file\n', n('SELECT COUNT(*) AS n FROM documents'));
fprintf('  isa subject_statement:          %d\n', ...
    n('SELECT COUNT(*) AS n FROM superclasses WHERE classname = ?', 'subject_statement'));
fprintf('  depends_on subject_id = worm:   %d\n', ...
    n('SELECT COUNT(*) AS n FROM depends_on WHERE name = ? AND document_id = ?', 'subject_id', wormId));
fprintf('  base.session_id = session:      %d\n', ...
    n('SELECT COUNT(*) AS n FROM documents WHERE session_id = ?', S.id()));
idx = mksqlite(dbid(), 'SELECT name, tbl_name FROM sqlite_master WHERE type = ''index'' ORDER BY tbl_name, name');
fprintf('  indexes: %s\n', strjoin(arrayfun(@(r) sprintf('%s(%s)', r.name, r.tbl_name), idx, ...
    'UniformOutput', false), ', '));
st = mksqlite(dbid(), 'SELECT name FROM sqlite_master WHERE name = ''sqlite_stat1''');
fprintf('  ANALYZE statistics (sqlite_stat1): %s\n', yesno(~isempty(st)));

% ---- each query ---------------------------------------------------------------------
rows = {};
for form = ["dataset", "session"]
    if form == "dataset", q = qBase; else, q = qSession; end
    q2 = feval([D '.toDid2Query'], q);
    r = db.testHookExplain(q2);
    fprintf('\n== %s ==\nSQL:\n  %s\nparams: %s\nplan:\n', form, r.sql, ...
        strjoin(cellfun(@toText, r.params, 'UniformOutput', false), ' | '));
    printPlan(r.plan);
    [t, hits] = timeIt(@() numel(db.searchIds(q2)), options.Repeats);
    fprintf('SQL + did2 post-filter: %d hit(s), %.3f s (median of %d)\n', hits, t, options.Repeats);
    rows(end+1, :) = {form, "did2 searchIds", hits, t}; %#ok<AGROW>
end

% the same question, starting from the edge
sqlEdge = ['SELECT documents.id FROM depends_on d JOIN documents ON documents.id = d.doc_id ' ...
    'WHERE d.name = ? AND d.document_id = ? AND EXISTS (SELECT 1 FROM superclasses sc ' ...
    'WHERE sc.doc_id = documents.id AND sc.classname = ?) ORDER BY documents.rowid ASC'];
pEdge = {'subject_id', wormId, 'subject_statement'};
fprintf('\n== by edge (hand-written) ==\nSQL:\n  %s\nplan:\n', sqlEdge);
printPlan(mksqlite(dbid(), ['EXPLAIN QUERY PLAN ' sqlEdge], pEdge{:}));
[t, hits] = timeIt(@() numel(mksqlite(dbid(), sqlEdge, pEdge{:})), options.Repeats);
fprintf('SQL alone: %d hit(s), %.3f s (median of %d)\n', hits, t, options.Repeats);
rows(end+1, :) = {"by edge", "SQL alone", hits, t};

% ---- through NDI ----------------------------------------------------------------------
fprintf('\n== through NDI (search + reading each document) ==\n');
[t, hits] = timeIt(@() numel(ds.database_search(qBase)), options.Repeats);
fprintf('ndi.dataset/database_search: %d hit(s), %.3f s\n', hits, t);
rows(end+1, :) = {"dataset", "ndi database_search", hits, t};
[t, hits] = timeIt(@() numel(S.database_search(qBase)), options.Repeats);
fprintf('ndi.session/database_search: %d hit(s), %.3f s\n', hits, t);
rows(end+1, :) = {"session", "ndi database_search", hits, t};

T = cell2table(rows, 'VariableNames', {'query', 'through', 'hits', 'seconds'});
fprintf('\n== summary ==\n');
disp(T);
end

% -----------------------------------------------------------------------------------
function printPlan(plan)
% EXPLAIN QUERY PLAN rows as a tree (indented by parent)
depth = containers.Map('KeyType', 'double', 'ValueType', 'double');
depth(0) = 0;
for k = 1:numel(plan)
    p = double(plan(k).parent);
    d = 1;
    if isKey(depth, p), d = depth(p) + 1; end
    depth(double(plan(k).id)) = d;
    fprintf('  %s%s\n', repmat('  ', 1, d - 1), plan(k).detail);
end
end

function [t, out] = timeIt(fn, repeats)
times = zeros(1, repeats);
for k = 1:repeats
    t0 = tic;
    out = fn();
    times(k) = toc(t0);
end
t = median(times);
end

function v = firstRow(rows)
v = rows(1).n;
end

function s = toText(x)
if ischar(x) || isstring(x), s = char(x); else, s = mat2str(x); end
end

function s = yesno(tf)
if tf, s = 'yes'; else, s = 'no (the planner has no table sizes)'; end
end
