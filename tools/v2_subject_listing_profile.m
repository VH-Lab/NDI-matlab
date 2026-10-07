function T = v2_subject_listing_profile(datasetPath, options)
%V2_SUBJECT_LISTING_PROFILE Where the time goes when every subject of a dataset is listed.
%
%   T = v2_subject_listing_profile(DATASETPATH) runs ndi.subject.search on the
%   V2 dataset at DATASETPATH, then times each layer it goes through, one
%   at a time, over the same subjects:
%
%     sql          the SELECT (id, body) for every `isa subject` document
%     jsondecode   decoding those bodies, nothing else
%     fromJSON     did2.document.fromJSON (decode + schema rehydration)
%     matches      did2's in-memory re-check of each document (q.matches)
%     search       did2 sqlitedb.search (the three above together)
%     get by id    did2 sqlitedb.get once per id (what NDI's backend does
%                  AFTER search, reading every document a second time)
%     normalize    ndi.database.internal.applyReadNormalization (the
%                  v1->V2 read pass NDI applies to every document read)
%     ndi.document ndi.document(struct), the object NDI hands back
%     database_search  ndi.dataset/database_search, all of the above
%     unique_id    did.ido.unique_id (each new ndi.subject makes one, then
%                  ndi.subject.fromDocument overwrites it)
%     fromDocument ndi.subject.fromDocument over the documents
%     find         ndi.subject.search, end to end
%
%   It prints each layer's time, per document and as a share of `find`. T
%   is the table. It writes nothing.
%
%   Options:
%     'Limit'  time the per-document layers over the first N subjects
%              only and scale up (default: all of them)
%
%   See also v2_query_plan, v2_object_layer_tryout.

arguments
    datasetPath (1,:) char {mustBeFolder}
    options.Limit (1,1) double = Inf
end

D = 'ndi.database.implementations.database.did2sqlite';
dbFile = fullfile(datasetPath, '.ndi', feval([D '.DEFAULTFILENAME']));
rows = {};
    function add(layer, seconds, n, note)
        rows(end+1, :) = {string(layer), n, seconds, seconds / max(n, 1) * 1000, string(note)};
        fprintf('  %-17s %8.3f s  %6d doc(s)  %7.3f ms/doc  %s\n', layer, seconds, n, ...
            seconds / max(n, 1) * 1000, note);
    end

ds = ndi.dataset.dir(datasetPath);
fprintf('dataset %s\n\n', datasetPath);

% ---- end to end first, cold -------------------------------------------------------
t0 = tic; s = ndi.subject.search(ds); tFind = toc(t0);
N = numel(s);
fprintf('ndi.subject.search: %d subject(s), %.3f s\n\nDENOMINATOR: %d subject document(s)', N, tFind, N);
M = min(N, options.Limit);
scale = N / M;
if M < N, fprintf('; per-document layers timed over the first %d and scaled x%.1f', M, scale); end
fprintf('\n\n');

db = did2.database.sqlitedb(dbFile);
closer = onCleanup(@() db.close());
cache = did2.schema.cache.shared();
q2 = did2.query('', 'isa', 'subject');

% ---- did2 layers ------------------------------------------------------------------------
fprintf('== did2 ==\n');
sql = ['SELECT id, body FROM documents WHERE EXISTS (SELECT 1 FROM superclasses sc ' ...
    'WHERE sc.doc_id = documents.id AND sc.classname = ?) ORDER BY rowid ASC'];
t0 = tic; r = mksqlite(db.testHookDbId(), sql, 'subject'); add('sql', toc(t0), numel(r), 'one query');
r = r(1:M);
t0 = tic; for k = 1:M, jsondecode(r(k).body); end; add('jsondecode', toc(t0) * scale, N, '');
t0 = tic; docs = cell(1, M);
for k = 1:M, docs{k} = did2.document.fromJSON(r(k).body, 'SchemaCache', cache); end
add('fromJSON', toc(t0) * scale, N, 'decode + schema rehydration');
t0 = tic; for k = 1:M, q2.matches(docs{k}); end; add('matches', toc(t0) * scale, N, 'in-memory re-check');
t0 = tic; found = db.search(q2); add('search', toc(t0), numel(found), 'sql + fromJSON + matches');
ids = cellfun(@(d) d.get('base.id'), found, 'UniformOutput', false);
t0 = tic; again = cell(1, M); for k = 1:M, again{k} = db.get(ids{k}); end
add('get by id', toc(t0) * scale, N, 'NDI reads every document a second time');

% ---- NDI layers ---------------------------------------------------------------------------
fprintf('== NDI ==\n');
t0 = tic; nd = cell(1, M);
for k = 1:M, nd{k} = ndi.database.internal.applyReadNormalization(again{k}); end
add('normalize', toc(t0) * scale, N, 'v1->V2 read pass + ndi.document');
structs = cellfun(@(d) d.toStruct(), again, 'UniformOutput', false);
t0 = tic; for k = 1:M, ndi.document(structs{k}); end
add('ndi.document', toc(t0) * scale, N, 'construction alone (inside normalize)');
t0 = tic; sd = ds.database_search(ndi.query('', 'isa', 'subject', ''));
add('database_search', toc(t0), numel(sd), 'all of the above');

% ---- the object layer ----------------------------------------------------------------------
fprintf('== object layer ==\n');
t0 = tic; for k = 1:M, did.ido.unique_id(); end
add('unique_id', toc(t0) * scale, N, 'made, then overwritten');
t0 = tic; for k = 1:M, ndi.subject.fromDocument(ds, sd{k}); end
add('fromDocument', toc(t0) * scale, N, '');
t0 = tic; s = ndi.subject.search(ds); add('find', toc(t0), numel(s), 'end to end (warm)');

T = cell2table(rows, 'VariableNames', {'layer', 'documents', 'seconds', 'ms_per_doc', 'note'});
T.share_of_find = T.seconds / T.seconds(end);
fprintf('\n== summary (share = seconds / warm find) ==\n');
disp(T(:, {'layer', 'documents', 'seconds', 'ms_per_doc', 'share_of_find'}));
end
