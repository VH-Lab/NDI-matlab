function scope = datasetScope(structs)
%DATASETSCOPE Is this batch a dataset, and if so where do shared entities live?
%   SCOPE = ndi.migrate.internal.datasetScope(STRUCTS) reads a cell of V_eta
%   document body structs (the second pass's working set) and answers the one
%   question the shared-entity passes need:
%
%     Decided by Jess Haley, 2026-10-21: "When a dataset is migrated, shared
%     entities (strains, software, people, organizations, instruments,
%     products) move to the dataset level as in native V2 imports (Haley
%     import_V2_decisions.md #20): one entity per distinct thing in the
%     dataset's database, with session documents pointing at it and
%     merged-away ids remapped so every link still resolves; a lone session
%     with no dataset keeps them in the session."
%
%   ndi.migrate.local reads ONE v1 database, PATH/.ndi; for a dataset that is
%   the dataset's database, holding every ingested session's documents (Soph:
%   33 sessions in one database, TestMigrateLocalEtaSoph). So "the dataset's
%   database" is exactly this batch.
%
%   The dataset level is the `dataset` ENTITY: did-schema #88 records a
%   document's session as a `session_id` edge "to the session or dataset
%   entity whose base.id IS the session id" (ndi.migrate.internal.
%   withSessionId), and the native Haley V2 import writes its dataset-level
%   documents with that id (import_V2.m: "the dataset entity's id IS the
%   dataset's session id").
%
%   SCOPE fields:
%     dataset_entities   number of distinct `dataset` entity ids seen
%     is_dataset         true when exactly ONE distinct dataset entity is seen
%     dataset_id         that entity's base.id ('' otherwise)
%     reason             'dataset' | 'no dataset entity' |
%                        'more than one dataset entity'
%   Two or more distinct dataset ids is not resolved by guessing: the batch is
%   treated as session-scoped and the reason says why.
%
%   See also ndi.migrate.internal.remapIds, ndi.migrate.internal.withSessionId.

S = ndi.migrate.internal.etaShape;
ids = {};
for i = 1:numel(structs)
    s = structs{i};
    if ~isstruct(s)
        continue;
    end
    isDs = S.isEntity(s, {'dataset'}) || strcmp(S.className(s), 'dataset');
    if ~isDs
        continue;
    end
    id = '';
    if isfield(s, 'base') && isstruct(s.base) && isfield(s.base, 'id')
        id = char(s.base.id);
    end
    if ~isempty(id) && ~any(strcmp(ids, id))
        ids{end+1} = id; %#ok<AGROW>
    end
end
scope = struct('dataset_entities', numel(ids), 'is_dataset', false, ...
    'dataset_id', '', 'reason', 'no dataset entity');
if numel(ids) == 1
    scope.is_dataset = true;
    scope.dataset_id = ids{1};
    scope.reason = 'dataset';
elseif numel(ids) > 1
    scope.reason = 'more than one dataset entity';
end
end
