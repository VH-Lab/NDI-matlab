function q = ingestedQuery(navigatorId, sessionId)
%INGESTEDQUERY The query that finds a file navigator's ingested epochs, in every vintage.
%
%   Q = ndi.vintage.ingestedQuery(NAVIGATORID, SESSIONID) finds
%
%     v1     `epochfiles_ingested` documents whose `filenavigator_id` is
%            NAVIGATORID (what ndi.file.navigator writes on ingest)
%     V_eta  `ingestion_manifest` documents whose `epoch_file_pattern_id` is
%            NAVIGATORID -- the same id: the migrator keeps the navigator's
%            id on its `epoch_file_pattern` and points the manifest at it
%            (DID-matlab did2.convert.resolveEpochProbemap, mkIngestionManifest)
%
%   in session SESSIONID.
%
%   did-schema #88, Decided by Jess Haley, 2026-10-22 [ingested epochs found]
%   (V_eta_epoch_plan.md, "B1a"): an NDI vintage rule, so the classic
%   navigator's `isa epochfiles_ingested & depends_on filenavigator_id` query
%   (ndi.file.navigator/selectfilegroups) finds migrated ingested epochs.
%   Before it, a migrated session's 2,484 (B), 4,088 (Dab) and 349 (Soph)
%   ingested epochs read as "nothing ingested" -- no error, and the epochs
%   then looked for on a disk that holds none of their files.
%
%   ndi.vintage.ingestedEpochs reads what Q returns, in either vintage.
%
%   See also ndi.vintage.ingestedEpochs, ndi.vintage.map, ndi.vintage.edge.

arguments
    navigatorId (1,:) char
    sessionId (1,:) char
end

entry = ndi.vintage.entryFor('epochfiles_ingested');
edges = {'filenavigator_id'};
if ~isempty(entry)
    row = strcmp(entry.edges(:, 1), 'filenavigator_id');
    if any(row)
        edges = [edges, ndi.vintage.names(entry.edges{find(row, 1), 2})];
    end
end
byEdge = ndi.query('', 'depends_on', edges{1}, navigatorId);
for k = 2:numel(edges)
    byEdge = byEdge | ndi.query('', 'depends_on', edges{k}, navigatorId);
end
q = ndi.vintage.isaQuery('epochfiles_ingested') & byEdge & ...
    ndi.query('base.session_id', 'exact_string', sessionId);
end
