function [kept, minted, report] = ensembleMembership(structs, options)
%ENSEMBLEMEMBERSHIP V_eta second pass: turn each did_v1 `ensemble` MAP document
%   into graph-native membership -- `member_of` edges from every constituent
%   neuron-subject to the ensemble group-subject -- and record the combined
%   marked-point-process binary as an explicitly DERIVED cache (`derived_from`
%   edges to those same neurons).
%
%   SIGNED MODEL (DID-schema `V_eta_ensemble_plan.md`, TEAM-SIGN-OFF jess
%   2026-08-06): per-neuron spike times are the PRIMARY archival data; the
%   ensemble is a GROUP SUBJECT with its id preserved and NO data body of its
%   own; members are EPOCH-SCOPED `member_of` edges carrying their epoch and
%   column order; the combined (times, ids) array is kept as an explicitly
%   DERIVED, REBUILDABLE CACHE (`derived_from` the neurons, T10); the per-epoch
%   MAP document dissolves; and a verify-before-delete (0 stranded per-neuron
%   trains) gates dropping the combined bytes.
%
%   STRUCTS is a cell of V_eta document body structs (from
%   did2.document.toStruct), i.e. the pass-1 output -- the same contract
%   ndi.migrate.internal.pathSPromotion takes. Returns KEPT (the surviving
%   bodies -- see "WHAT THIS DOES NOT DO"), MINTED (the new `directed_relation`
%   bodies, tagged schema_version 'V_eta' so they fold back through v1_to_v2),
%   and REPORT (denominator first; REPORT.changed is false when nothing was
%   minted, so the caller can skip the rebuild).
%
%   ---------------------------------------------------------------------
%   WHERE THE NEURON IDS COME FROM -- edges, NOT `neuron_names.txt`
%   ---------------------------------------------------------------------
%   The plan originally said the roster lived only inside the map document's
%   `neuron_names.txt` and therefore needed file-byte access. That premise is
%   WRONG. The ids are `depends_on` EDGES on the map document, written in
%   column order:
%
%     git show origin/main:src/ndi/+ndi/+element/ensemble.m   (buildMapDoc)
%         mapdoc = mapdoc.set_dependency_value('element_id', obj.id());
%         mapdoc = mapdoc.set_dependency_value('element_epoch_id', epochdoc.id());
%         for i = 1:numel(neuron_ids)
%             mapdoc = mapdoc.add_dependency_value_n('neuron_id', neuron_ids{i});
%         end
%         mapdoc = mapdoc.add_file('neuron_names.txt', names_tempfile);
%
%     git show origin/main:src/ndi/ndi_common/schema_documents/ensemble/ensemble_schema.json
%         "depends_on": [
%             { "name": "element_id",       "mustbenotempty": 1},
%             { "name": "element_epoch_id", "mustbenotempty": 1},
%             { "name": "neuron_id",        "mustbenotempty": 0}   <- declared
%         ]
%
%   `did.document.add_dependency_value_n` (DID-matlab +did/document.m:349)
%   appends `neuron_id_1`, `neuron_id_2`, ... so the SUFFIX INDEX *is* the
%   column index -- the same loop writes the names in the same order. Column
%   order therefore needs no file read either.
%
%   The names in `neuron_names.txt` add nothing: they are
%   `e.elementstring()` of the very elements the ids point at
%   (origin/main:+ndi/+fun/+ensemble/load.m:167), so they are recoverable from
%   the neuron-subjects.
%
%   WHY THE WRONG PREMISE SURVIVED: the TEMPLATE
%   (database_documents/ensemble/ensemble.json) declares only `element_id` and
%   `element_epoch_id`. Only the SCHEMA and the WRITER carry `neuron_id`. This
%   is the ground-truth rule -- *where template and WRITER disagree, the WRITER
%   wins* -- firing on a divergence inside NDI's own pair.
%
%   ---------------------------------------------------------------------
%   WHAT IS MINTED
%   ---------------------------------------------------------------------
%   Per (map document, neuron_id_i), deduplicated on
%   (parent, child, sequence, epoch):
%
%     member_of    directed_relation   child  = the neuron-subject
%                                      parent = the ensemble group-subject
%                                      relation {RO:0002350, member_of}
%                                      sequence = i (the column index)
%
%     derived_from directed_relation   child  = the cache carrier (the migrated
%                                               `acquisition_epoch` that holds
%                                               the combined .vhsb binary --
%                                               the map's `element_epoch_id`)
%                                      parent = the neuron-subject
%                                      relation {RO:0001000, derived_from}
%
%   The `derived_from` set IS the verify-before-delete manifest: for a given
%   cache carrier its parents name exactly the per-neuron trains that must
%   exist before those bytes may be dropped.
%
%   The relation terms are taken from the built registry, not invented:
%       schemas/V_eta/stable/binding_registry_meta.json  relation_bindings
%         { "relation": {"node":"RO:0002350","name":"member_of"},
%           "class":"directed_relation", "child_role":"the member",
%           "parent_role":"the group", "child_types":["subject"],
%           "parent_types":["subject"], "timed":false, "ordered":false }
%         { "relation": {"node":"RO:0001000","name":"derived_from"},
%           "class":"directed_relation", "child_role":"the derivative",
%           "parent_role":"the source", "child_types":[], "parent_types":[],
%           "timed":true, "ordered":false }
%
%   ---------------------------------------------------------------------
%   WHAT THIS DOES NOT DO, AND WHY -- read before "finishing" it
%   ---------------------------------------------------------------------
%   1. IT DROPS NOTHING. KEPT == STRUCTS. The map document is NOT consumed, the
%      `acquisition_epoch` is NOT touched, and no bytes are removed. The map
%      document may only dissolve once the edges can carry the epoch (item 2)
%      AND the verify-before-delete gate has run on a real corpus (0 stranded
%      per-neuron trains). This pass MEASURES that gate (REPORT.stranded_*); it
%      does not act on it. `V_eta_ensemble_plan.md` deferred task 5 says the
%      same: "until then it stays a green passthrough -- do NOT phase-8-delete
%      early."
%
%   2. THE EDGES ARE NOT EPOCH-SCOPED BY DEFAULT, because there is nowhere
%      declared to put the epoch and nothing to point at:
%
%        (a) `directed_relation` declares exactly three dependencies --
%            `child`, `parent`, `time_reference_#`
%            (schemas/V_eta/stable/directed_relation.json). There is no
%            `epoch_id`. V_eta's declared epoch edge exists elsewhere
%            (`acquisition_metadata_file.epoch_id -> epoch`, REQUIRED), so the
%            NAME is established; the SLOT on directed_relation is not.
%        (b) No `epoch` document exists to point at. From
%            did2.convert.migrators_j.private.jEpochDocId: "NO MIGRATOR MINTS
%            AN `epoch` DOCUMENT ... Open item #60 records the correct shape --
%            mint one `epoch` per distinct `epochid.epochid` by GROUPING (a
%            second pass)". That mint is a different family and is not built.
%
%      Emitting an undeclared `epoch_id` dependency would validate silently
%      (did2/+schema/cache.m:598 allows `depends_on` wholesale and never checks
%      individual dependency names), which is precisely the standing defect
%      this project already tracks as "the `openminds_#` deps are declared by
%      nobody". So it is not done here.
%
%      HOOK, so this is a one-line change when #60 lands: pass
%      OPTIONS.EpochDocumentIdFor, a function handle
%      `docId = f(epochidString, sessionId)` returning '' when unknown. When it
%      returns a non-empty id an `epoch_id` dependency is added to both edge
%      kinds and the dedupe key separates epochs. Nothing empty is ever emitted
%      (rule: never emit an empty edge).
%
%   3. NO `sampled_body` CACHE DOCUMENT IS MATERIALISED. The signed model marks
%      the cache with the T6 `is_cache` marker on a `sampled_body`; neither
%      exists in the built schema set today:
%        - `is_cache` appears in NO schema (only in three prose documents:
%          V_eta_tenets.md, V_eta_tenet_audit.md, V_eta_ensemble_plan.md);
%        - `sampled_body` is still DRAFT (schemas/V_eta/draft/sampled_body.json)
%          with a REQUIRED `statement -> subject_statement` edge, and the whole
%          data_body tier is under redesign (V_eta_data_body_model_plan.md,
%          #45, blocked on #32).
%      So the cache is recorded here as PROVENANCE (the `derived_from` edges)
%      over the carrier that already holds the bytes, which is the half that
%      can be built correctly today.
%
%   4. A STRANDED NEURON GETS NO EDGE. An edge to an id that is not in the
%      migrated set is an ORPHAN, and orphans are the corpus gate (the
%      11,448-orphan dissolution failure). Stranded ids are COUNTED and
%      RETURNED instead.
%
%   See also: ndi.migrate.local, ndi.migrate.internal.pathSPromotion,
%     ndi.migrate.internal.strainAssembly,
%     DID-schema schemas/V_eta_ensemble_plan.md.

arguments
    structs cell
    options.EpochDocumentIdFor = []      % f(epochidString, sessionId) -> docId | ''
end

MEMBER_OF   = struct('node', 'RO:0002350', 'name', 'member_of');
DERIVED_FROM = struct('node', 'RO:0001000', 'name', 'derived_from');

kept   = structs;
minted = {};

report = struct();
report.documents_inspected      = numel(structs);
report.ensemble_maps_seen       = 0;
report.ensemble_maps_used       = 0;
report.ensemble_maps_no_group   = 0;   % element_id missing or not a migrated subject
report.neuron_edges_seen        = 0;
report.neuron_edges_resolved    = 0;
report.neuron_edges_stranded    = 0;
report.stranded_neuron_ids      = {};
report.cache_carriers_seen      = 0;   % distinct element_epoch_id values
report.cache_carriers_resolved  = 0;   % ... that are present in the migrated set
report.member_of_minted         = 0;
report.derived_from_minted      = 0;
report.epoch_scoped_edges       = 0;
report.epoch_scope_available    = ~isempty(options.EpochDocumentIdFor);
report.changed                  = false;

if isempty(structs)
    return;
end

% index the whole migrated set once: id -> class name
idClass = containers.Map('KeyType', 'char', 'ValueType', 'char');
for i = 1:numel(structs)
    bid = baseField(structs{i}, 'id', '');
    if ~isempty(bid)
        idClass(bid) = classNameOf(structs{i});
    end
end

seenEdge     = containers.Map('KeyType', 'char', 'ValueType', 'logical');
seenCarrier  = containers.Map('KeyType', 'char', 'ValueType', 'logical');
seenStranded = containers.Map('KeyType', 'char', 'ValueType', 'logical');

for i = 1:numel(structs)
    s = structs{i};
    if ~strcmp(classNameOf(s), 'ensemble')
        continue;
    end
    report.ensemble_maps_seen = report.ensemble_maps_seen + 1;

    groupId = depVal(s, 'element_id');
    % The ensemble ELEMENT became a group-SUBJECT with its id preserved
    % (did2.convert.migrators_j.element: `subjectDoc.base = preBody.base`), so
    % element_id resolves to a `subject` in the migrated set.
    if isempty(groupId) || ~isSubject(idClass, groupId)
        report.ensemble_maps_no_group = report.ensemble_maps_no_group + 1;
        continue;
    end

    sessionId = baseField(s, 'session_id', '');
    ds        = baseField(s, 'datestamp', '2024-01-01T00:00:00.000Z');
    epochKey  = epochScope(s, sessionId, options.EpochDocumentIdFor);

    % the cache carrier: the migrated acquisition_epoch that holds the combined
    % marked-point-process binary (element_epoch -> acquisition_epoch is a
    % RENAME, base.id preserved, so this edge still resolves).
    carrierId = depVal(s, 'element_epoch_id');
    carrierOk = false;
    if ~isempty(carrierId)
        if ~isKey(seenCarrier, carrierId)
            seenCarrier(carrierId) = true;
            report.cache_carriers_seen = report.cache_carriers_seen + 1;
            if isKey(idClass, carrierId)
                report.cache_carriers_resolved = report.cache_carriers_resolved + 1;
            end
        end
        carrierOk = isKey(idClass, carrierId);
    end

    neurons = neuronEdges(s);
    if isempty(neurons)
        continue;
    end
    report.ensemble_maps_used = report.ensemble_maps_used + 1;

    for k = 1:numel(neurons)
        report.neuron_edges_seen = report.neuron_edges_seen + 1;
        neuronId = neurons(k).id;
        column   = neurons(k).column;

        % A neuron element became a subject with its id preserved, so an
        % unresolvable id means the train is NOT in this corpus. Emitting an
        % edge to it would be an orphan; count it for the verify-before-delete
        % gate instead.
        if ~isSubject(idClass, neuronId)
            report.neuron_edges_stranded = report.neuron_edges_stranded + 1;
            if ~isKey(seenStranded, neuronId)
                seenStranded(neuronId) = true;
                report.stranded_neuron_ids{end+1} = neuronId; %#ok<AGROW>
            end
            continue;
        end
        report.neuron_edges_resolved = report.neuron_edges_resolved + 1;

        mKey = ['m|' groupId '|' neuronId '|' int2str(column) '|' epochKey];
        if ~isKey(seenEdge, mKey)
            seenEdge(mKey) = true;
            minted{end+1} = relationBody(neuronId, groupId, MEMBER_OF, ...
                column, epochKey, sessionId, ds, 'migrated_ensemble_member'); %#ok<AGROW>
            report.member_of_minted = report.member_of_minted + 1;
            if ~isempty(epochKey)
                report.epoch_scoped_edges = report.epoch_scoped_edges + 1;
            end
        end

        if carrierOk
            dKey = ['d|' carrierId '|' neuronId '|' epochKey];
            if ~isKey(seenEdge, dKey)
                seenEdge(dKey) = true;
                minted{end+1} = relationBody(carrierId, neuronId, DERIVED_FROM, ...
                    [], epochKey, sessionId, ds, 'migrated_ensemble_cache_source'); %#ok<AGROW>
                report.derived_from_minted = report.derived_from_minted + 1;
                if ~isempty(epochKey)
                    report.epoch_scoped_edges = report.epoch_scoped_edges + 1;
                end
            end
        end
    end
end

report.changed = ~isempty(minted);
end

% ===================== builders ========================================

function body = relationBody(childId, parentId, relTerm, sequence, epochDocId, ...
        sessionId, ds, name)
%RELATIONBODY One `directed_relation`. Emits only NON-EMPTY edges.
body = struct();
% `subject_relation` was renamed to `relation` (abstract) in V_eta; emit the
% current superclass and NO stale block -- an undeclared top-level block
% quarantines (the JH 163k-orphan regression). ensureClassBlocks rebuilds the
% chain and any needed empty blocks. Mirrors pathSPromotion exactly.
body.document_class = struct('class_name', 'directed_relation', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'relation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
deps = [struct('name', 'child',  'value', childId), ...
        struct('name', 'parent', 'value', parentId)];
if ~isempty(epochDocId)
    % Only reachable when OPTIONS.EpochDocumentIdFor supplied a real id; see
    % item 2 of the header. `epoch_id` is V_eta's declared name for this edge
    % (acquisition_metadata_file), but directed_relation does not declare the
    % slot yet -- that is the DID-schema change this hook waits on.
    deps(end+1) = struct('name', 'epoch_id', 'value', epochDocId);
end
body.depends_on = deps;
body.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', name, 'datestamp', ds);
block = struct('relation', relTerm);
if ~isempty(sequence)
    % `sequence` is directed_relation's declared "ordinal for ordered
    % relations" -- the column index of this neuron in the epoch's combined
    % binary. NOTE the registry row for member_of currently says
    % "ordered": false; see the report returned to the caller.
    block.sequence = sequence;
end
body.directed_relation = block;
end

% ===================== struct accessors ================================

function key = epochScope(s, sessionId, resolverFcn)
%EPOCHSCOPE The epoch DOCUMENT id for this map, or '' when unavailable.
key = '';
if isempty(resolverFcn)
    return;
end
epochStr = '';
if isfield(s, 'epochid') && isstruct(s.epochid) && isfield(s.epochid, 'epochid')
    epochStr = char(s.epochid.epochid);
end
if isempty(epochStr)
    return;
end
try
    key = char(resolverFcn(epochStr, sessionId));
catch
    key = '';
end
end

function out = neuronEdges(s)
%NEURONEDGES The `neuron_id_#` edges, with their 1-based column index.
%   add_dependency_value_n appends `neuron_id_1`, `neuron_id_2`, ... in the
%   loop order that also writes neuron_names.txt, so the suffix IS the column.
out = struct('id', {}, 'column', {});
if ~isfield(s, 'depends_on') || ~isstruct(s.depends_on)
    return;
end
for k = 1:numel(s.depends_on)
    d = s.depends_on(k);
    if ~isfield(d, 'name'); continue; end
    tok = regexp(char(d.name), '^neuron_id_(\d+)$', 'tokens', 'once');
    if isempty(tok); continue; end
    v = depEntryValue(d);
    if isempty(v); continue; end     % never mint an edge for an empty value
    out(end+1) = struct('id', v, 'column', str2double(tok{1})); %#ok<AGROW>
end
if ~isempty(out)
    [~, order] = sort([out.column]);
    out = out(order);
end
end

function tf = isSubject(idClass, id)
tf = ~isempty(id) && isKey(idClass, id) && strcmp(idClass(id), 'subject');
end

function c = classNameOf(s)
c = '';
if isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isfield(s.document_class, 'class_name')
    c = char(s.document_class.class_name);
end
end

function v = depEntryValue(d)
v = '';
if isfield(d, 'value') && ~isempty(d.value)
    v = char(d.value);
elseif isfield(d, 'document_id') && ~isempty(d.document_id)
    v = char(d.document_id);
end
end

function v = depVal(s, name)
v = '';
if isfield(s, 'depends_on') && isstruct(s.depends_on)
    for k = 1:numel(s.depends_on)
        d = s.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            v = depEntryValue(d);
            return;
        end
    end
end
end

function v = baseField(s, name, default)
v = default;
if isfield(s, 'base') && isstruct(s.base) && isfield(s.base, name) ...
        && ~isempty(s.base.(name))
    v = s.base.(name);
end
end
