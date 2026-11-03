function r5probe(outDir)
% TEMPORARY (remove before merge): dump the v1 and migrated documents of
% TestReadTimeseriesEquivalence's ingested session.
if ~isfolder(outDir); mkdir(outDir); end
P = ndi.unittest.migrate.TestReadTimeseriesEquivalence;
root = tempname; mkdir(root);
P.buildIntanSession(root);
S = ndi.session.dir(root);
[b, msg] = S.ingest(); assert(logical(b), msg);
delete(fullfile(root, P.IntanFile));
S.cache.clear();
probe = P.theProbe(S);
et = probe.epochtable();
disp(jsonencode(P.normalizeEpochTable(et), 'PrettyPrint', true));
dev = S.daqsystem_load('name', 'intan1'); if iscell(dev); dev = dev{1}; end
etd = dev.epochtable();
for i=1:numel(etd)
    fprintf('DEV EPOCH %d id=%s\n', i, etd(i).epoch_id);
    disp(etd(i).underlying_epochs.underlying);
    ef = getepochfiles(dev.filenavigator, etd(i).epoch_id);
    disp(ef);
end
ch = dev.getchannelsepoch(1);
disp(struct2table(ch));
ef = getepochfiles(dev.filenavigator, etd(1).epoch_id);
[c2, full] = dev.daqreader.getchannelsepoch_ingested(ef, S);
disp(jsonencode(full, 'PrettyPrint', true));
[sr,off,sc] = dev.daqreader.samplerate_ingested(ef, {'ai'}, 1, S); disp([sr off sc]);
t = dev.readchannels_epochsamples('time', 1, 1, 1, 10); disp(t');
t0t1 = dev.t0_t1(1); disp(t0t1);
[d, tt] = probe.readtimeseries(1, -Inf, Inf); fprintf('probe read %s, t(1)=%.12g t(end)=%.12g\n', mat2str(size(d)), tt(1), tt(end));
docs = S.database_search(ndi.query.all());
dumpDocs(docs, fullfile(outDir, 'v1'));
clear S probe dev
res = ndi.migrate.local(root, 'Validate', true, 'Backup', false);
fprintf('MIGRATED %d, quarantine %d\n', res.summary.total, numel(res.quarantine));
disp(res.summary);
S2 = ndi.session.dir(root);
docs = S2.database_search(ndi.query.all());
dumpDocs(docs, fullfile(outDir, 'v2'));
d = dir(fullfile(root, '.ndi', 'files')); fprintf('files in store: %d\n', numel(d)-2);
end

function dumpDocs(docs, d)
mkdir(d);
fprintf('=== %s: %d documents\n', d, numel(docs));
for k = 1:numel(docs)
    p = docs{k}.document_properties;
    cls = p.document_class.class_name;
    j = jsonencode(p, 'PrettyPrint', true);
    fid = fopen(fullfile(d, sprintf('%03d_%s_%s.json', k, cls, p.base.id)), 'w'); fwrite(fid, j); fclose(fid);
    fprintf('--- %s %s\n', cls, p.base.id);
    if numel(j) < 6000; disp(j); else; disp(j(1:6000)); disp('...TRUNCATED'); end
end
end
