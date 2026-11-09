function epochSetCensus(file, label)
%EPOCHSETCENSUS THROWAWAY (never merged): how many distinct SETS of epochs the
%   repeated per-epoch facts are timed to (Jess Haley, 2026-11-09, "Count the
%   epoch groups"). Decides P1 (an epoch_id_# edge on one wiring relation) vs
%   T20 (one group entity of epochs + member_of per epoch).
%
%   Epochs, anchors, ties and keys are resolved exactly as epochRepeatCensus
%   (testEpochRepeats): EPOCHS = entity whose type name contains "epoch" UNION
%   ingestion_manifest epoch_id targets; a document is timed to an epoch when
%   its time_reference_id[_n] edge names an anchor whose referent_id is that
%   epoch; KEY = class name | body without base and depends_on | every
%   depends_on edge except session_id and time_reference_id[_n].
%   WIRING = family-T directed_relation keys. STIMULATOR = family-T
%   manipulation keys whose statement.variable.node is SNOMEDCT:36645008 and
%   that own no opaque_body / sampled_body (owner_id).
%   A key's EPOCH SET = the distinct epochs its documents are timed to.

dbid = mksqlite(0, 'open', file);
c = onCleanup(@() mksqlite(dbid, 'close'));
q = @(sql) mksqlite(dbid, sql);
fprintf('\n  EPOCH SETS (%s, %s)\n', label, file);
t = q('SELECT COUNT(*) AS n FROM documents');
fprintf('    DENOMINATOR: %d document(s) in the database\n', t.n);
q('CREATE TEMP TABLE dep AS SELECT doc_id, name, document_id FROM depends_on');
q('CREATE INDEX temp.dep_doc ON dep(doc_id)');
q('CREATE INDEX temp.dep_tgt ON dep(document_id)');
t = q('SELECT COUNT(*) AS n FROM dep');
fprintf('    DENOMINATOR: %d depends_on row(s)\n', t.n);

% ---- epochs (as epochRepeatCensus)
q('CREATE TEMP TABLE ep (id TEXT PRIMARY KEY)');
q(['INSERT OR IGNORE INTO ep SELECT id FROM documents WHERE classname = ''entity'' AND ' ...
    'lower(COALESCE(json_extract(body, ''$.entity.type.name''), json_extract(body, ''$.entity.type''), '''')) LIKE ''%epoch%''']);
nT = q('SELECT COUNT(*) AS n FROM ep');
q(['INSERT OR IGNORE INTO ep SELECT DISTINCT d.document_id FROM dep d JOIN documents m ON m.id = d.doc_id ' ...
    'WHERE m.classname = ''ingestion_manifest'' AND d.name = ''epoch_id''']);
nE = q('SELECT COUNT(*) AS n FROM ep');
% session of each epoch: the epoch document's own session_id edge
q(['CREATE TEMP TABLE eps AS SELECT e.id AS epoch, COALESCE((SELECT MIN(d.document_id) FROM dep d WHERE d.doc_id = e.id ' ...
    'AND d.name = ''session_id''), ''(none)'') AS sess FROM ep e']);
q('CREATE INDEX temp.eps_e ON eps(epoch)');
ns = q('SELECT COUNT(DISTINCT sess) AS n, SUM(sess = ''(none)'') AS nn FROM eps');
fprintf(['    DENOMINATOR: %d typed epoch(s) (entity type containing "epoch"); %d epoch(s) after adding manifest epoch_id targets; ' ...
    'in %d session(s) (by the epoch''s session_id edge; %d epoch(s) with none)\n'], nT.n, nE.n, ns.n, n0(ns.nn));

% ---- anchors, ties, keys (as epochRepeatCensus, family T only)
q(['CREATE TEMP TABLE anc AS SELECT DISTINCT doc_id AS anchor, document_id AS epoch FROM dep ' ...
    'WHERE name = ''referent_id'' AND document_id IN (SELECT id FROM ep)']);
q('CREATE INDEX temp.anc_a ON anc(anchor)');
q(['CREATE TEMP TABLE ties AS SELECT DISTINCT t.doc_id AS doc, a.epoch AS epoch FROM dep t ' ...
    'JOIN anc a ON a.anchor = t.document_id WHERE t.name = ''time_reference_id'' OR t.name LIKE ''time_reference_id\_%'' ESCAPE ''\''']);
q('CREATE INDEX temp.ties_doc ON ties(doc)');
q(['CREATE TEMP TABLE bodied AS SELECT DISTINCT o.document_id AS owner FROM dep o JOIN documents b ON b.id = o.doc_id ' ...
    'WHERE o.name = ''owner_id'' AND b.classname IN (''opaque_body'', ''sampled_body'')']);
q('CREATE INDEX temp.bodied_o ON bodied(owner)');
q(['CREATE TEMP TABLE kk AS SELECT x.doc AS doc, ' ...
    'CASE WHEN r.classname = ''directed_relation'' THEN ''W'' ELSE ''S'' END AS kind, ' ...
    'r.classname || ''|'' || COALESCE(json_remove(r.body, ''$.base'', ''$.depends_on''), ''null'') || ''|'' || ' ...
    'COALESCE((SELECT group_concat(e.name || ''='' || e.document_id, '';'') FROM ' ...
    '(SELECT name, document_id FROM dep WHERE doc_id = r.id AND name <> ''session_id'' ' ...
    'AND name <> ''time_reference_id'' AND name NOT LIKE ''time_reference_id\_%'' ESCAPE ''\'' ' ...
    'ORDER BY name, document_id) e), '''') AS k ' ...
    'FROM (SELECT DISTINCT doc FROM ties) x JOIN documents r ON r.id = x.doc ' ...
    'WHERE r.classname = ''directed_relation'' OR (r.classname = ''manipulation'' ' ...
    'AND json_extract(r.body, ''$.statement.variable.node'') = ''SNOMEDCT:36645008'' AND r.id NOT IN (SELECT owner FROM bodied))']);
q('CREATE INDEX temp.kk_doc ON kk(doc)');
allm = q(['SELECT COUNT(DISTINCT x.doc) AS n, SUM(json_extract(r.body, ''$.statement.variable.node'') = ''SNOMEDCT:36645008'') AS ns, ' ...
    'SUM(json_extract(r.body, ''$.statement.variable.node'') = ''SNOMEDCT:36645008'' AND r.id IN (SELECT owner FROM bodied)) AS nsb ' ...
    'FROM (SELECT DISTINCT doc FROM ties) x JOIN documents r ON r.id = x.doc WHERE r.classname = ''manipulation''']);
fprintf(['    DENOMINATOR: timed manipulation documents %d; with variable SNOMEDCT:36645008 %d, of which owning a body %d ' ...
    '(excluded)\n'], n0(allm.n), n0(allm.ns), n0(allm.nsb));
rt = q(['SELECT COALESCE(json_extract(r.body, ''$.directed_relation.relation.node''), ''(none)'') AS t, COUNT(*) AS n ' ...
    'FROM kk k JOIN documents r ON r.id = k.doc WHERE k.kind = ''W'' GROUP BY t']);
fprintf('    wiring (timed directed_relation) documents by relation node:');
for k = 1:numel(rt); fprintf(' %s %d;', str(rt(k).t), rt(k).n); end
fprintf('\n');
q('CREATE TEMP TABLE keys (kid INTEGER PRIMARY KEY, kind TEXT, k TEXT)');
q('INSERT INTO keys (kind, k) SELECT DISTINCT kind, k FROM kk');
q('CREATE INDEX temp.keys_k ON keys(kind, k)');
q('CREATE TEMP TABLE kd AS SELECT y.kid AS kid, k.doc AS doc FROM kk k JOIN keys y ON y.kind = k.kind AND y.k = k.k');
q('CREATE INDEX temp.kd_kid ON kd(kid)');
q('CREATE TEMP TABLE ke AS SELECT DISTINCT d.kid AS kid, t.epoch AS epoch FROM kd d JOIN ties t ON t.doc = d.doc');
q('CREATE INDEX temp.ke_kid ON ke(kid, epoch)');
R = q(['SELECT y.kid AS kid, y.kind AS kind, (SELECT COUNT(*) FROM kd WHERE kd.kid = y.kid) AS nd, ' ...
    '(SELECT COUNT(*) FROM ke WHERE ke.kid = y.kid) AS ne, ' ...
    '(SELECT COUNT(DISTINCT s.sess) FROM ke JOIN eps s ON s.epoch = ke.epoch WHERE ke.kid = y.kid) AS nsess, ' ...
    '(SELECT MIN(s.sess) FROM ke JOIN eps s ON s.epoch = ke.epoch WHERE ke.kid = y.kid) AS sess, ' ...
    '(SELECT group_concat(epoch, '','') FROM (SELECT epoch FROM ke WHERE ke.kid = y.kid ORDER BY epoch)) AS es ' ...
    'FROM keys y ORDER BY y.kid']);
SE = q('SELECT sess, COUNT(*) AS n FROM eps GROUP BY sess ORDER BY sess');
sessN = containers.Map(cellfun(@str, {SE.sess}, 'UniformOutput', false), num2cell(double([SE.n])));

kind = cellfun(@str, {R.kind}, 'UniformOutput', false);
nd = double([R.nd]); ne = double([R.ne]); nsess = double([R.nsess]);
sess = cellfun(@str, {R.sess}, 'UniformOutput', false);
es = cellfun(@str, {R.es}, 'UniformOutput', false);
fprintf('    DENOMINATOR: keyed documents %d (wiring %d, Stimulator %d); keys %d (wiring %d, Stimulator %d)\n', ...
    sum(nd), sum(nd(strcmp(kind, 'W'))), sum(nd(strcmp(kind, 'S'))), numel(R), nnz(strcmp(kind, 'W')), nnz(strcmp(kind, 'S')));
fprintf(['    keys whose copies outnumber their epochs (two copies in one epoch): %d; keys whose epochs span >1 session: %d\n'], ...
    nnz(nd ~= ne), nnz(nsess > 1));

fprintf('    CORPUS\n');
report('      ', kind, nd, ne, nsess, sess, es, sessN);

usess = unique(sess);
fprintf('    PER SESSION (keys assigned to the session of their epochs; keys spanning >1 session are counted under the first)\n');
fprintf(['      session | epochs | W docs | W keys | W sets | W set size min/med/max | S docs | S keys | S sets | ' ...
    'union sets | shared | sets = all session epochs | today docs | P1 W docs+edges | group docs (G + member_of + W + S)\n']);
for j = 1:numel(usess)
    m = strcmp(sess, usess{j});
    w = m & strcmp(kind, 'W'); s = m & strcmp(kind, 'S');
    uw = unique(es(w)); us = unique(es(s)); uu = unique(es(m));
    sz = cellfun(@numel, strsplit_(uu));
    nall = 0;
    if isKey(sessN, usess{j}); nall = nnz(sz == sessN(usess{j})); end
    ew = sessN_(sessN, usess{j});
    fprintf('      %s | %d | %d | %d | %d | %s | %d | %d | %d | %d | %d | %d | %d | %d+%d | %d+%d+%d+%d=%d\n', usess{j}, ew, ...
        sum(nd(w)), nnz(w), numel(uw), mmm(ne(w)), sum(nd(s)), nnz(s), numel(us), numel(uu), numel(intersect(uw, us)), nall, ...
        sum(nd(m)), nnz(w), sum(ne(w)), numel(uu), sum(sz), nnz(w), nnz(s), numel(uu) + sum(sz) + nnz(w) + nnz(s));
end
end

function report(ind, kind, nd, ne, nsess, sess, es, sessN)
names = {'W', 'WIRING (directed_relation keys)'; 'S', 'STIMULATOR (body-less SNOMEDCT:36645008 manipulation keys)'};
U = struct();
for r = 1:2
    m = strcmp(kind, names{r, 1});
    [u, ~, ix] = unique(es(m));
    if isempty(ix); kps = []; else; kps = accumarray(ix(:), 1); end
    sz = cellfun(@numel, strsplit_(u));
    ssm = sess(m); nsm = nsess(m);
    first = zeros(numel(u), 1);
    for i = 1:numel(u); first(i) = find(ix == i, 1); end
    nall = 0;
    for i = 1:numel(u)
        if nsm(first(i)) == 1 && isKey(sessN, ssm{first(i)}) && sz(i) == sessN(ssm{first(i)}); nall = nall + 1; end
    end
    fprintf('%s%s: documents %d; keys %d; distinct epoch sets %d\n', ind, names{r, 2}, sum(nd(m)), nnz(m), numel(u));
    fprintf('%s  set size per KEY min/median/max %s; per DISTINCT SET min/median/max %s\n', ind, mmm(ne(m)), mmm(sz));
    fprintf('%s  keys per distinct set min/median/max %s; sets with exactly 1 key %d\n', ind, mmm(kps), nnz(kps == 1));
    fprintf('%s  distinct sets equal to all epochs of their session %d (of %d; sets spanning >1 session %d)\n', ind, nall, numel(u), ...
        nnz(nsm(first) > 1));
    fprintf('%s  sum of set sizes over keys %d; sum of distinct-set sizes %d\n', ind, sum(ne(m)), sum(sz));
    U.(names{r, 1}) = u;
end
uu = unique(es);
szu = cellfun(@numel, strsplit_(uu));
sh = intersect(U.W, U.S);
nW = nnz(strcmp(kind, 'W')); nS = nnz(strcmp(kind, 'S'));
dW = sum(nd(strcmp(kind, 'W'))); dS = sum(nd(strcmp(kind, 'S')));
fprintf('%sACROSS BOTH: distinct sets in the union %d; sets used by both a wiring key and a Stimulator key %d; only wiring %d; only Stimulator %d\n', ...
    ind, numel(uu), numel(sh), numel(setdiff(U.W, U.S)), numel(setdiff(U.S, U.W)));
fprintf('%sDOCUMENT COST\n', ind);
fprintf('%s  (c) today: wiring %d + Stimulator %d = %d documents\n', ind, dW, dS, dW + dS);
fprintf('%s  (a) P1 edge design, wiring: %d wiring relations, %d epoch_id_# edges; Stimulator unchanged %d; total documents %d\n', ...
    ind, nW, sum(ne(strcmp(kind, 'W'))), dS, nW + dS);
fprintf('%s  (a'') P1 applied to Stimulator too: %d + %d = %d documents, %d edges\n', ind, nW, nS, nW + nS, sum(ne));
fprintf('%s  (b) group design: %d group entities + %d member_of + %d wiring + %d Stimulator = %d documents\n', ...
    ind, numel(uu), sum(szu), nW, nS, numel(uu) + sum(szu) + nW + nS);
szw = cellfun(@numel, strsplit_(U.W));
fprintf('%s  (b'') group design, wiring only: %d groups + %d member_of + %d wiring = %d documents (Stimulator unchanged %d; total %d)\n', ...
    ind, numel(U.W), sum(szw), nW, numel(U.W) + sum(szw) + nW, dS, numel(U.W) + sum(szw) + nW + dS);
end

function c = strsplit_(u)
c = cellfun(@(x) strsplit(x, ','), u, 'UniformOutput', false);
end

function n = sessN_(m, k)
if isKey(m, k); n = m(k); else; n = 0; end
end

function s = mmm(v)
if isempty(v); s = '-/-/-'; else; s = sprintf('%d/%g/%d', min(v), median(v), max(v)); end
end

function s = str(v)
if ischar(v); s = v; elseif isstring(v); s = char(v); elseif isempty(v); s = '(null)'; else; s = num2str(v); end
end

function v = n0(x)
if isempty(x); v = 0; else; v = double(x); end
end
