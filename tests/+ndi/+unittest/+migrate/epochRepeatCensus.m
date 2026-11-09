function epochRepeatCensus(file, label)
%EPOCHREPEATCENSUS THROWAWAY (never merged): which epoch-tied documents in a
%   migrated database record the same fact again in several epochs (Jess
%   Haley, 2026-11-09, "Count them"). Generalises testWiringRepeats.
%
%   EPOCHS: `entity` documents whose entity.type (name) is `epoch`, UNION the
%   targets of an ingestion_manifest's `epoch_id` edge. Both sets and their
%   overlap are printed.
%   ANCHORS: documents with a `referent_id` edge onto an epoch (by class).
%   FAMILY T (asked): documents with a time_reference_id or
%   time_reference_id_<n> edge onto an anchor.
%   FAMILY D (extra): documents NOT in T with any other edge (not referent_id)
%   straight onto an epoch.
%   KEY: class name | the body without `base` and `depends_on` (every other
%   block as stored) | every depends_on edge (name=target, sorted) EXCEPT
%   session_id and time_reference_id[_n]; family D also drops its edges onto
%   epochs.

dbid = mksqlite(0, 'open', file);
c = onCleanup(@() mksqlite(dbid, 'close'));
q = @(sql) mksqlite(dbid, sql);
fprintf('\n  EPOCH REPEATS (%s, %s)\n', label, file);
t = q('SELECT COUNT(*) AS n FROM documents');
fprintf('    DENOMINATOR: %d document(s) in the database\n', t.n);
q('CREATE TEMP TABLE dep AS SELECT doc_id, name, document_id FROM depends_on');
q('CREATE INDEX temp.dep_doc ON dep(doc_id)');
q('CREATE INDEX temp.dep_tgt ON dep(document_id)');
t = q('SELECT COUNT(*) AS n FROM dep');
fprintf('    DENOMINATOR: %d depends_on row(s)\n', t.n);

% ---- epochs
ty = q(['SELECT COALESCE(json_extract(body, ''$.entity.type.name''), json_extract(body, ''$.entity.type''), ''(none)'') AS t, ' ...
    'COUNT(*) AS n FROM documents WHERE classname = ''entity'' GROUP BY t ORDER BY n DESC']);
fprintf('    entity types (entity documents per type):');
for k = 1:numel(ty); fprintf(' %s %d;', str(ty(k).t), ty(k).n); end
fprintf('\n');
q('CREATE TEMP TABLE ep (id TEXT PRIMARY KEY)');
q(['INSERT OR IGNORE INTO ep SELECT id FROM documents WHERE classname = ''entity'' AND ' ...
    '(json_extract(body, ''$.entity.type.name'') = ''epoch'' OR json_extract(body, ''$.entity.type'') = ''epoch'')']);
nT = q('SELECT COUNT(*) AS n FROM ep');
sqlM = ['SELECT DISTINCT d.document_id FROM dep d JOIN documents m ON m.id = d.doc_id ' ...
    'WHERE m.classname = ''ingestion_manifest'' AND d.name = ''epoch_id'''];
nM = q(['SELECT COUNT(*) AS n FROM (' sqlM ')']);
nTM = q(['SELECT COUNT(*) AS n FROM (' sqlM ') WHERE document_id IN (SELECT id FROM ep)']);
mc = q(['SELECT COALESCE(classname, ''(absent)'') AS c, COUNT(*) AS n FROM (' sqlM ') x LEFT JOIN documents d ON d.id = x.document_id GROUP BY c']);
q(['INSERT OR IGNORE INTO ep ' sqlM]);
nE = q('SELECT COUNT(*) AS n FROM ep');
fprintf(['    EPOCHS: %d entity(type epoch); %d named by an ingestion_manifest epoch_id edge (%d of them typed epoch);' ...
    ' union %d\n'], nT.n, nM.n, nTM.n, nE.n);
fprintf('    manifest-named epoch targets by class:');
for k = 1:numel(mc); fprintf(' %s %d;', str(mc(k).c), mc(k).n); end
fprintf('\n');
ein = q(['SELECT COALESCE(s.classname, ''(absent)'') AS c, d.name AS e, COUNT(*) AS n FROM dep d LEFT JOIN documents s ON s.id = d.doc_id ' ...
    'WHERE d.document_id IN (SELECT id FROM ep) GROUP BY c, e ORDER BY n DESC']);
fprintf('    EDGES ONTO EPOCHS (source class / edge name / rows):\n');
for k = 1:numel(ein); fprintf('      %-32s %-28s %d\n', str(ein(k).c), str(ein(k).e), ein(k).n); end

% ---- anchors and ties
q(['CREATE TEMP TABLE anc AS SELECT DISTINCT doc_id AS anchor, document_id AS epoch FROM dep ' ...
    'WHERE name = ''referent_id'' AND document_id IN (SELECT id FROM ep)']);
q('CREATE INDEX temp.anc_a ON anc(anchor)');
ac = q(['SELECT COALESCE(d.classname, ''(absent)'') AS c, COUNT(DISTINCT a.anchor) AS n, COUNT(DISTINCT a.epoch) AS e ' ...
    'FROM anc a LEFT JOIN documents d ON d.id = a.anchor GROUP BY c']);
fprintf('    ANCHORS (referent_id onto an epoch), by class:');
for k = 1:numel(ac); fprintf(' %s %d anchor(s) onto %d epoch(s);', str(ac(k).c), ac(k).n, ac(k).e); end
fprintf('\n');
q(['CREATE TEMP TABLE ties AS SELECT DISTINCT t.doc_id AS doc, a.epoch AS epoch, 1 AS fam, t.name AS via FROM dep t ' ...
    'JOIN anc a ON a.anchor = t.document_id WHERE t.name = ''time_reference_id'' OR t.name LIKE ''time_reference_id\_%'' ESCAPE ''\''']);
q(['INSERT INTO ties SELECT DISTINCT d.doc_id, d.document_id, 2, d.name FROM dep d WHERE d.document_id IN (SELECT id FROM ep) ' ...
    'AND d.name <> ''referent_id'' AND d.doc_id NOT IN (SELECT doc FROM ties WHERE fam = 1)']);
q('CREATE INDEX temp.ties_doc ON ties(doc)');
vt = q(['SELECT t.fam AS fam, COALESCE(d.classname, ''(absent)'') AS c, t.via AS via, COUNT(*) AS n, COUNT(DISTINCT t.doc) AS nd, ' ...
    'COUNT(DISTINCT t.epoch) AS ne FROM ties t LEFT JOIN documents d ON d.id = t.doc GROUP BY fam, c, via ORDER BY fam, c, via']);
fprintf('    TIES (family / class / edge / tie rows / documents / epochs):\n');
for k = 1:numel(vt)
    fprintf('      %s %-32s %-24s %7d %7d %6d\n', famName(vt(k).fam), str(vt(k).c), str(vt(k).via), vt(k).n, vt(k).nd, vt(k).ne);
end
both = q(['SELECT COALESCE(d.classname, ''(absent)'') AS c, COUNT(DISTINCT t.doc) AS n FROM ties t JOIN documents d ON d.id = t.doc ' ...
    'JOIN dep x ON x.doc_id = t.doc AND x.document_id IN (SELECT id FROM ep) WHERE t.fam = 1 GROUP BY c']);
fprintf('    family T documents that ALSO have a direct edge onto an epoch (kept in the key):');
if isempty(both); fprintf(' none'); end
for k = 1:numel(both); fprintf(' %s %d;', str(both(k).c), both(k).n); end
fprintf('\n');
dpe = q(['SELECT c, MIN(n) AS mn, MAX(n) AS mx, COUNT(*) AS nd, SUM(n > 1) AS multi FROM (SELECT t.doc, COALESCE(d.classname, ''(absent)'') AS c, ' ...
    'COUNT(DISTINCT t.epoch) AS n FROM ties t LEFT JOIN documents d ON d.id = t.doc GROUP BY t.doc) GROUP BY c']);
fprintf('    epochs per DOCUMENT (class: min/max, documents tied to >1 epoch):');
for k = 1:numel(dpe); fprintf(' %s %d/%d, %d;', str(dpe(k).c), dpe(k).mn, dpe(k).mx, dpe(k).multi); end
fprintf('\n');

% ---- keys
q(['CREATE TEMP TABLE kk AS SELECT x.doc AS doc, x.fam AS fam, COALESCE(r.classname, ''(absent)'') AS cls, ' ...
    'COALESCE(r.classname, '''') || ''|'' || COALESCE(json_remove(r.body, ''$.base'', ''$.depends_on''), ''null'') || ''|'' || ' ...
    'COALESCE((SELECT group_concat(e.name || ''='' || e.document_id, '';'') FROM ' ...
    '(SELECT name, document_id FROM dep WHERE doc_id = r.id AND name <> ''session_id'' ' ...
    'AND name <> ''time_reference_id'' AND name NOT LIKE ''time_reference_id\_%'' ESCAPE ''\'' ' ...
    'AND NOT (x.fam = 2 AND document_id IN (SELECT id FROM ep)) ORDER BY name, document_id) e), '''') AS k ' ...
    'FROM (SELECT DISTINCT doc, fam FROM ties) x JOIN documents r ON r.id = x.doc']);
q('CREATE INDEX temp.kk_doc ON kk(doc)');
q('CREATE INDEX temp.kk_cls ON kk(cls, fam)');
nk = q('SELECT fam, COUNT(*) AS n FROM kk GROUP BY fam');
for k = 1:numel(nk); fprintf('    DENOMINATOR: %d document(s) keyed in family %s\n', nk(k).n, famName(nk(k).fam)); end
fprintf(['    KEY = class name | body without base and depends_on (all other blocks as stored) | depends_on edges ' ...
    '(name=target, sorted) EXCEPT session_id, time_reference_id[_n]; family D also drops its edges onto epochs\n']);
cls = q('SELECT cls, fam, COUNT(*) AS n FROM kk GROUP BY cls, fam ORDER BY fam, n DESC');
fprintf('    PER CLASS (family | class | documents | distinct keys | keys in exactly 1 epoch | epochs/key min/median/max | repeats = docs - keys, share)\n');
for k = 1:numel(cls)
    per = q(sprintf(['SELECT COUNT(DISTINCT k.doc) AS nd, COUNT(DISTINCT t.epoch) AS ne FROM kk k JOIN ties t ON t.doc = k.doc ' ...
        'WHERE k.cls = ''%s'' AND k.fam = %d GROUP BY k.k'], cls(k).cls, cls(k).fam));
    nd = double([per.nd]); ne = double([per.ne]);
    rep = sum(nd) - numel(per);
    fprintf('      %s | %-30s | %6d | %6d | %6d | %d/%g/%d | %d (%.1f%%)\n', famName(cls(k).fam), cls(k).cls, sum(nd), numel(per), ...
        nnz(ne == 1), min(ne), median(ne), max(ne), rep, 100 * rep / max(sum(nd), 1));
    if rep > 0
        ex = q(sprintf(['SELECT k.k AS k, COUNT(DISTINCT k.doc) AS nd, COUNT(DISTINCT t.epoch) AS ne, MIN(k.doc) AS d1, MAX(k.doc) AS d2 ' ...
            'FROM kk k JOIN ties t ON t.doc = k.doc WHERE k.cls = ''%s'' AND k.fam = %d GROUP BY k.k HAVING nd > 1 ' ...
            'ORDER BY ne DESC, nd DESC LIMIT 1'], cls(k).cls, cls(k).fam));
        kx = str(ex.k);
        fprintf('        EXAMPLE %s: %d documents over %d epochs (e.g. %s, %s): %s\n', cls(k).cls, ex.nd, ex.ne, ex.d1, ex.d2, kx(1:min(end, 900)));
        fprintf('        distribution: keys with >1 document %d; documents per key max %d\n', nnz(nd > 1), max(nd));
    end
    fv = q(sprintf(['SELECT b.key || ''.'' || COALESCE(f.key, '''') AS f, COUNT(*) AS n, COUNT(DISTINCT f.value) AS nd ' ...
        'FROM kk k JOIN documents d ON d.id = k.doc, json_each(d.body) b, json_each(CASE WHEN b.type = ''object'' THEN b.value ELSE ''{}'' END) f ' ...
        'WHERE k.cls = ''%s'' AND k.fam = %d AND b.key NOT IN (''base'', ''depends_on'') AND b.type = ''object'' ' ...
        'GROUP BY 1 ORDER BY 1'], cls(k).cls, cls(k).fam));
    fprintf('        fields (block.field holding/distinct):');
    for j = 1:numel(fv); fprintf(' %s %d/%d;', str(fv(j).f), fv(j).n, fv(j).nd); end
    fprintf('\n');
end

% ---- data bodies
q(['CREATE TEMP TABLE own AS SELECT o.doc_id AS body, o.document_id AS owner, b.classname AS bcls FROM dep o ' ...
    'JOIN documents b ON b.id = o.doc_id WHERE o.name = ''owner_id'' AND b.classname IN (''opaque_body'', ''sampled_body'') ' ...
    'AND o.document_id IN (SELECT doc FROM kk)']);
ob = q(['SELECT k.cls AS cls, k.fam AS fam, o.bcls AS bcls, COUNT(DISTINCT o.owner) AS nown, COUNT(DISTINCT o.body) AS nb, ' ...
    'SUM(COALESCE(json_extract(b.body, ''$.data_body.content_hash''), '''') <> '''') AS nh, ' ...
    'SUM(COALESCE(json_extract(b.body, ''$.data_body.size_bytes''), '''') <> '''') AS ns ' ...
    'FROM own o JOIN kk k ON k.doc = o.owner JOIN documents b ON b.id = o.body GROUP BY 1, 2, 3']);
fprintf('    DATA BODIES owned by keyed documents (class | body class | owners | bodies | with content_hash | with size_bytes):');
if isempty(ob); fprintf(' none'); end
fprintf('\n');
for k = 1:numel(ob)
    fprintf('      %s | %-30s | %-12s | %6d | %6d | %6d | %6d\n', famName(ob(k).fam), ob(k).cls, ob(k).bcls, ob(k).nown, ob(k).nb, ob(k).nh, ob(k).ns);
end
if isempty(ob); return; end
bc = q('SELECT DISTINCT bcls FROM own');
for k = 1:numel(bc)
    e1 = q(sprintf('SELECT b.body AS j FROM own o JOIN documents b ON b.id = o.body WHERE o.bcls = ''%s'' LIMIT 1', bc(k).bcls));
    j = str(e1.j);
    fprintf('    example %s: %s\n', bc(k).bcls, j(1:min(end, 1500)));
    fv = q(sprintf(['SELECT b.key || ''.'' || COALESCE(f.key, '''') AS f, COUNT(*) AS n, COUNT(DISTINCT f.value) AS nd ' ...
        'FROM (SELECT DISTINCT body FROM own WHERE bcls = ''%s'') o JOIN documents d ON d.id = o.body, json_each(d.body) b, json_each(CASE WHEN b.type = ''object'' THEN b.value ELSE ''{}'' END) f ' ...
        'WHERE b.key NOT IN (''base'', ''depends_on'') GROUP BY 1 ORDER BY 1'], bc(k).bcls));
    fprintf('      %s fields (holding/distinct):', bc(k).bcls);
    for j = 1:numel(fv); fprintf(' %s %d/%d;', str(fv(j).f), fv(j).n, fv(j).nd); end
    fprintf('\n');
end
q(['CREATE TEMP TABLE bsig AS SELECT owner, group_concat(h, '';'') AS sigH, group_concat(w, '';'') AS sigW, group_concat(body, '';'') AS sigI, ' ...
    'SUM(hh = '''') AS nunh FROM (SELECT o.owner AS owner, o.body AS body, ' ...
    'COALESCE(json_extract(b.body, ''$.data_body.content_hash''), '''') AS hh, ' ...
    'o.bcls || '':'' || COALESCE(json_extract(b.body, ''$.data_body.content_hash''), '''') || '':'' || COALESCE(json_extract(b.body, ''$.data_body.size_bytes''), '''') AS h, ' ...
    'o.bcls || '':'' || COALESCE(json_remove(b.body, ''$.base'', ''$.depends_on'', ''$.files''), '''') AS w ' ...
    'FROM own o JOIN documents b ON b.id = o.body ORDER BY o.owner, h, w, o.body) GROUP BY owner']);
q('CREATE INDEX temp.bsig_o ON bsig(owner)');
fprintf(['    BODIES ACROSS REPEATS: per owner class, over keys with >1 document. H = sorted (body class, content_hash, size_bytes);\n' ...
    '      W = sorted body documents without base/depends_on/files; I = the body document ids themselves.\n']);
oc = q('SELECT DISTINCT k.cls AS cls, k.fam AS fam FROM own o JOIN kk k ON k.doc = o.owner');
for k = 1:numel(oc)
    r = q(sprintf(['SELECT COUNT(*) AS rk, SUM(nh = 1) AS sh, SUM(nh > 1) AS dh, SUM(nw = 1) AS sw, SUM(nw > 1) AS dw, ' ...
        'SUM(ni = 1) AS si, SUM(ni > 1) AS di, SUM(nun > 0) AS un, SUM(nob > 0) AS nob, SUM(nd) AS docs FROM (' ...
        'SELECT k.k, COUNT(DISTINCT k.doc) AS nd, COUNT(DISTINCT COALESCE(s.sigH, ''(no body)'')) AS nh, ' ...
        'COUNT(DISTINCT COALESCE(s.sigW, ''(no body)'')) AS nw, COUNT(DISTINCT COALESCE(s.sigI, ''(no body)'')) AS ni, ' ...
        'SUM(COALESCE(s.nunh, 0) > 0) AS nun, SUM(s.owner IS NULL) AS nob ' ...
        'FROM kk k LEFT JOIN bsig s ON s.owner = k.doc WHERE k.cls = ''%s'' AND k.fam = %d GROUP BY k.k HAVING nd > 1)'], oc(k).cls, oc(k).fam));
    kb = q(sprintf(['SELECT COUNT(*) AS docs, COUNT(DISTINCT k.k) AS keys, COUNT(DISTINCT k.k || ''#'' || COALESCE(s.sigH, '''')) AS kh, ' ...
        'COUNT(DISTINCT k.k || ''#'' || COALESCE(s.sigW, '''')) AS kw, COUNT(DISTINCT k.k || ''#'' || COALESCE(s.sigI, '''')) AS ki ' ...
        'FROM kk k LEFT JOIN bsig s ON s.owner = k.doc WHERE k.cls = ''%s'' AND k.fam = %d'], oc(k).cls, oc(k).fam));
    fprintf(['      %s %s: repeat keys %d (%d docs); same H %d / differ H %d; same W %d / differ W %d; same I %d / differ I %d; ' ...
        'repeat keys with an unhashed body %d; repeat keys with a body-less document %d\n'], famName(oc(k).fam), oc(k).cls, ...
        n0(r.rk), n0(r.docs), n0(r.sh), n0(r.dh), n0(r.sw), n0(r.dw), n0(r.si), n0(r.di), n0(r.un), n0(r.nob));
    fprintf('        documents %d; distinct keys %d; distinct key+H %d (repeats %d); key+W %d (repeats %d); key+I %d (repeats %d)\n', ...
        kb.docs, kb.keys, kb.kh, kb.docs - kb.kh, kb.kw, kb.docs - kb.kw, kb.ki, kb.docs - kb.ki);
end
end

function s = str(v)
if ischar(v); s = v; elseif isstring(v); s = char(v); elseif isempty(v); s = '(null)'; else; s = num2str(v); end
end

function v = n0(x)
if isempty(x); v = 0; else; v = double(x); end
end

function s = famName(f)
if double(f) == 1; s = 'T'; else; s = 'D'; end
end
