function stimCensus(file, label, v1Bodies, zipBodies)
%STIMCENSUS THROWAWAY (never merged): stimulus presentations before and after
%   migration, the body-less Stimulator manipulations, and the ingested
%   stimulus bodies (coordinator, 2026-11-09: a bodyResolver.m comment says
%   "Dab ... 1242 presentations"; the epoch census found B with 1,242
%   manipulations owning a body; count, don't infer).
%
%   v1Bodies  the v1 documents migrated (JSON text; for Dab AFTER the B filter)
%   zipBodies every v1 document in the corpus zip (JSON text)
%   file      the migrated did_v2 sqlite

fprintf('\n  STIM CENSUS (%s, %s)\n', label, file);
fprintf('    V1 (before migration)\n');
[spIds, ingIds] = v1Count('migrated input', v1Bodies);
if ~isequal(numel(zipBodies), numel(v1Bodies))
    v1Count('whole corpus zip', zipBodies);
else
    fprintf('      whole corpus zip: same %d documents as the migrated input\n', numel(zipBodies));
end

dbid = mksqlite(0, 'open', file);
c = onCleanup(@() mksqlite(dbid, 'close'));
q = @(sql) mksqlite(dbid, sql);
fprintf('    V2 (after migration)\n');
t = q('SELECT COUNT(*) AS n FROM documents');
fprintf('      DENOMINATOR: %d document(s) in the database\n', t.n);
q('CREATE TEMP TABLE dep AS SELECT doc_id, name, document_id FROM depends_on');
q('CREATE INDEX temp.dep_doc ON dep(doc_id)');
q('CREATE INDEX temp.dep_tgt ON dep(document_id)');
q('CREATE TEMP TABLE sp1 (id TEXT PRIMARY KEY)');
q('CREATE TEMP TABLE ing1 (id TEXT PRIMARY KEY)');
insertIds(q, 'sp1', spIds); insertIds(q, 'ing1', ingIds);
q(['CREATE TEMP TABLE man AS SELECT d.id AS id, d.body AS body, ' ...
    'COALESCE((SELECT MIN(document_id) FROM dep WHERE doc_id = d.id AND name = ''session_id''), ''(none)'') AS sess ' ...
    'FROM documents d WHERE d.classname = ''manipulation''']);
q('CREATE INDEX temp.man_id ON man(id)');
q(['CREATE TEMP TABLE own AS SELECT o.doc_id AS body, b.classname AS bcls, o.document_id AS owner FROM dep o ' ...
    'JOIN documents b ON b.id = o.doc_id WHERE o.name = ''owner_id'' AND b.classname IN (''opaque_body'', ''sampled_body'')']);
q('CREATE INDEX temp.own_o ON own(owner)');
t = q('SELECT COUNT(*) AS n FROM man');
fprintf('      DENOMINATOR: %d manipulation document(s)\n', t.n);
r = q(['SELECT COALESCE(json_extract(body, ''$.statement.variable.node''), ''(none)'') || '' '' || ' ...
    'COALESCE(json_extract(body, ''$.statement.variable.name''), '''') AS v, COUNT(*) AS n, ' ...
    'SUM(id IN (SELECT owner FROM own)) AS nb FROM man GROUP BY v ORDER BY n DESC']);
fprintf('      manipulations by statement.variable (documents / owning a data body):\n');
for k = 1:numel(r); fprintf('        %-50s %6d / %6d\n', str(r(k).v), r(k).n, n0(r(k).nb)); end
r = q(['SELECT (SELECT group_concat(json_extract(s.value, ''$.class_name''), '','') FROM json_each(json_extract(m.body, ' ...
    '''$.document_class.superclasses'')) s) AS sc, COUNT(*) AS n FROM man m GROUP BY sc ORDER BY n DESC']);
fprintf('      manipulations by superclass list:\n');
for k = 1:numel(r); fprintf('        %-70s %6d\n', str(r(k).sc), r(k).n); end
r = q(['SELECT COALESCE(t.classname, ''(absent)'') AS c, COUNT(DISTINCT v.doc_id) AS n FROM dep v JOIN man m ON m.id = v.doc_id ' ...
    'LEFT JOIN documents t ON t.id = v.document_id WHERE v.name = ''value_id'' OR v.name LIKE ''value_id\_%'' ESCAPE ''\'' GROUP BY c']);
fprintf('      manipulations with a value_id edge, by target class:');
if isempty(r); fprintf(' none'); end
for k = 1:numel(r); fprintf(' %s %d;', str(r(k).c), r(k).n); end
fprintf('\n');
r = q(['SELECT SUM(id IN (SELECT id FROM sp1)) AS n, SUM(id IN (SELECT id FROM sp1) AND ' ...
    'EXISTS (SELECT 1 FROM json_each(json_extract(body, ''$.document_class.superclasses'')) s WHERE json_extract(s.value, ''$.class_name'') = ''item'')) AS ni, ' ...
    'SUM(id NOT IN (SELECT id FROM sp1) AND EXISTS (SELECT 1 FROM json_each(json_extract(body, ''$.document_class.superclasses'')) s ' ...
    'WHERE json_extract(s.value, ''$.class_name'') = ''item'')) AS nio, ' ...
    'SUM(id IN (SELECT id FROM sp1) AND id IN (SELECT owner FROM own)) AS nb FROM man']);
fprintf(['      STIMULUS-PRESENTATION manipulations (base.id = a migrated v1 stimulus_presentation id; the second pass keeps the id): %d ' ...
    '(listing item %d; owning a data body %d); item-valued manipulations with any other id %d\n'], n0(r.n), n0(r.ni), n0(r.nb), n0(r.nio));
r = q(['SELECT COUNT(*) AS n, COUNT(DISTINCT d.classname) AS nc, group_concat(DISTINCT d.classname) AS cs FROM sp1 s ' ...
    'JOIN documents d ON d.id = s.id']);
fprintf('      v1 stimulus_presentation ids present in v2: %d of %d (classes: %s)\n', n0(r.n), numel(spIds), str(r.cs));
r = q(['SELECT COALESCE(classname, ''(null)'') AS c, COUNT(*) AS n FROM documents WHERE classname IN (''stimulus_presentation'', ' ...
    '''daqmetadatareader_epochdata_ingested'', ''timed_sequence'', ''item'') OR json_extract(body, ''$.document_class.class_name'') IN ' ...
    '(''stimulus_presentation'', ''daqmetadatareader_epochdata_ingested'', ''timed_sequence'', ''item'') GROUP BY c']);
fprintf('      documents of class stimulus_presentation / daqmetadatareader_epochdata_ingested / timed_sequence / item (carried v1 or v2):');
if isempty(r); fprintf(' none'); end
for k = 1:numel(r); fprintf(' %s %d;', str(r(k).c), r(k).n); end
fprintf('\n');
r = q(['SELECT COUNT(*) AS n, SUM(json_extract(body, ''$.statement.variable.node'') = ''SNOMEDCT:36645008'' AND ' ...
    'id NOT IN (SELECT owner FROM own)) AS nbl, SUM(json_extract(body, ''$.statement.variable.node'') = ''SNOMEDCT:36645008'' AND ' ...
    'id IN (SELECT owner FROM own)) AS nb FROM man WHERE json_extract(body, ''$.statement.variable.node'') = ''SNOMEDCT:36645008''']);
fprintf('      STIMULATOR (SNOMEDCT:36645008) manipulations: %d; body-less %d; owning any data body %d\n', n0(r.n), n0(r.nbl), n0(r.nb));
r = q(['SELECT o.bcls AS bc, COALESCE(json_extract(m.body, ''$.statement.variable.name''), ''(none)'') AS v, ' ...
    'SUM(m.id IN (SELECT id FROM sp1)) AS nsp, COUNT(DISTINCT o.body) AS nb, COUNT(DISTINCT o.owner) AS nown, ' ...
    'SUM(o.body IN (SELECT id FROM ing1)) AS ning FROM own o JOIN man m ON m.id = o.owner GROUP BY bc, v']);
fprintf('      DATA BODIES owned by manipulations (body class | owner variable | bodies | owners | bodies whose owner is a stimulus presentation | body id = a v1 daqmetadatareader_epochdata_ingested id):\n');
if isempty(r); fprintf('        none\n'); end
for k = 1:numel(r)
    fprintf('        %-12s | %-30s | %6d | %6d | %6d | %6d\n', str(r(k).bc), str(r(k).v), r(k).nb, r(k).nown, n0(r(k).nsp), n0(r(k).ning));
end
r = q('SELECT COUNT(*) AS n, COUNT(DISTINCT d.classname) AS nc, group_concat(DISTINCT d.classname) AS cs FROM ing1 s JOIN documents d ON d.id = s.id');
fprintf('      v1 daqmetadatareader_epochdata_ingested ids present in v2: %d of %d (classes: %s)\n', n0(r.n), numel(ingIds), str(r.cs));
r = q(['SELECT m.sess AS s, SUM(m.id IN (SELECT id FROM sp1)) AS nsp, ' ...
    'SUM(json_extract(m.body, ''$.statement.variable.node'') = ''SNOMEDCT:36645008'') AS nst, ' ...
    'SUM(m.id IN (SELECT owner FROM own)) AS nb, COUNT(*) AS n FROM man m GROUP BY m.sess ORDER BY m.sess']);
fprintf('      PER SESSION (v2 session_id | manipulations | stimulus presentations | Stimulator | owning a body):\n');
for k = 1:numel(r); fprintf('        %s | %d | %d | %d | %d\n', str(r(k).s), r(k).n, n0(r(k).nsp), n0(r(k).nst), n0(r(k).nb)); end
end

function [spIds, ingIds] = v1Count(what, bodies)
cls = cell(numel(bodies), 1); ses = cls; ids = cls;
for k = 1:numel(bodies)
    j = jsondecode(bodies{k});
    cls{k} = '(none)'; ses{k} = '(none)'; ids{k} = '';
    try; cls{k} = char(j.document_class.class_name); catch; end
    try; ses{k} = char(j.base.session_id); catch; end
    try; ids{k} = char(j.base.id); catch; end
end
sp = strcmp(cls, 'stimulus_presentation'); ing = strcmp(cls, 'daqmetadatareader_epochdata_ingested');
spIds = ids(sp); ingIds = ids(ing);
fprintf('      %s: DENOMINATOR %d v1 document(s) in %d base.session_id value(s); stimulus_presentation %d; daqmetadatareader_epochdata_ingested %d\n', ...
    what, numel(bodies), numel(unique(ses)), nnz(sp), nnz(ing));
[us, ~, ix] = unique(ses);
fprintf('        per session (base.session_id | documents | stimulus_presentation | daqmetadatareader_epochdata_ingested):\n');
for k = 1:numel(us)
    m = ix == k;
    if nnz(m & (sp | ing)) == 0 && numel(us) > 40; continue; end
    fprintf('          %s | %d | %d | %d\n', us{k}, nnz(m), nnz(m & sp), nnz(m & ing));
end
end

function insertIds(q, tbl, ids)
for k = 1:200:numel(ids)
    chunk = ids(k:min(end, k + 199));
    vals = strjoin(cellfun(@(x) ['(''' strrep(x, '''', '''''') ''')'], chunk, 'UniformOutput', false), ',');
    q(sprintf('INSERT OR IGNORE INTO %s (id) VALUES %s', tbl, vals));
end
end

function s = str(v)
if ischar(v); s = v; elseif isstring(v); s = char(v); elseif isempty(v); s = '(null)'; else; s = num2str(v); end
end

function v = n0(x)
if isempty(x); v = 0; else; v = double(x); end
end
