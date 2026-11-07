function ids = referenceDatasets(docs)
%REFERENCEDATASETS The Data Set entities in DOCS that are references, not the dataset.
%
%   IDS = ndi.v2.referenceDatasets(DOCS) reads a cell of documents (property
%   structs, ndi.document or did2.document objects) and returns, as a sorted
%   cellstr, the base.id of every REFERENCE dataset among them: an `entity` of
%   type dataset (NCIT:C47824 "Data Set"; or a pre-#88 `dataset` document)
%     - that some document in DOCS was derived from: it is the parent of a
%       `directed_relation` `derived_from` (prov:wasDerivedFrom), and
%     - that no document in DOCS names as its session (its `session_id` edge,
%       or a v1 base.session_id), and
%     - that nothing is `included_in` (it is no `included_in` relation's
%       parent).
%
%   Why: a gene list's genome annotation and assembly are minimal Data Set
%   entities the gene-list term is derived from (Decided by Jess Haley,
%   2026-11-07, did-schema did_v2_go_forward_class_audit.md [gene-list
%   history entities]; built in DID-matlab #420, 180bc8cc). They are reference
%   data, not the dataset the documents belong to; "ours" vs "reference" is
%   read off the graph (did_v2_spatial_transcriptomics_plan.md item 22). This
%   is the rule DID-matlab's did2.convert.migrationRecord applies (#420,
%   anchorsOf): reference = (datasets that are derived_from parents) minus
%   (ids any document names as its session_id, and parents of `included_in`).
%   A reference Data Set is still an ordinary document, stored with its own
%   session.
%
%   The rule reads only DOCS: a caller that holds part of a database passes
%   the documents that can anchor a candidate (see ndi.v2.datasetSessions).
%
%   See also ndi.v2.datasetDocuments, ndi.migrate.internal.datasetScope,
%   ndi.v2.datasetSessions, ndi.setup.V2.createDataset.

arguments
    docs cell
end

datasets = {};
derivedFrom = {};
anchored = {};
for k = 1:numel(docs)
    p = docs{k};
    if ~isstruct(p)
        try
            p = ndi.v2.props(p);
        catch
            continue;
        end
    end
    if ~isstruct(p) || ~isscalar(p) || ~isfield(p, 'document_class') ...
            || ~isstruct(p.document_class) || ~isfield(p.document_class, 'class_name')
        continue;
    end
    cls = char(p.document_class.class_name);
    id = '';
    if isfield(p, 'base') && isstruct(p.base) && isfield(p.base, 'id')
        id = char(p.base.id);
    end
    if ~isempty(id) && isDataset(p, cls)
        datasets{end+1} = id; %#ok<AGROW>
    end
    sid = ndi.v2.sessionIdOf(p);
    if ~isempty(sid)
        anchored{end+1} = sid; %#ok<AGROW>
    end
    if strcmp(cls, 'directed_relation') && isfield(p, 'directed_relation') ...
            && isstruct(p.directed_relation) && isfield(p.directed_relation, 'relation')
        r = p.directed_relation.relation;
        parent = ndi.v2.edgeIds(p, 'parent_id');
        if isempty(parent)
            continue;
        end
        if ndi.v2.vocabIs('relation', r, 'included_in')   % by node (L1)
            if ~isempty(ndi.v2.edgeIds(p, 'child_id'))
                anchored = [anchored, parent(1)]; %#ok<AGROW>
            end
        elseif ndi.v2.vocabIs('relation', r, 'derived_from')
            derivedFrom = [derivedFrom, parent(1)]; %#ok<AGROW>
        end
    end
end
ids = setdiff(intersect(unique(datasets), unique(derivedFrom)), unique(anchored));
ids = reshape(ids, 1, []);
end

function tf = isDataset(p, cls)
% an `entity` whose type is dataset (by node, L2), or a pre-#88 `dataset`
if strcmp(cls, 'dataset')
    tf = true;
    return;
end
tf = strcmp(cls, 'entity') && isfield(p, 'entity') && isstruct(p.entity) ...
    && isfield(p.entity, 'type') && ndi.v2.vocabIs('entity_type', p.entity.type, 'dataset');
end
