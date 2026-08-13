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
%   ONE DECLARATIVE MISMATCH, STATED RATHER THAN HIDDEN: `directed_relation`
%   declares `child` and `parent` as `must_refer_to_document_class: "entity"`,
%   and the cache carrier (`acquisition_epoch`, superclasses base + epochid) is
%   NOT an entity. It validates -- must_refer is existence-only, never
%   type-checked -- and the registry row for `derived_from` constrains neither
%   end (`child_types: []`, `parent_types: []`). It is recorded here because
%   the right long-term child is the `sampled_body` cache document of item 3,
%   which does not exist yet; when it does, this edge moves to it.
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
%   2. THE EDGES ARE NOT EPOCH-SCOPED AS WIRED TODAY -- and this item's OWN
%      account of why was STALE. Both blockers it named are gone; the reason
%      the edges are still unscoped is now PASS ORDER, which is a smaller and
%      different problem. Corrected here with positive evidence, because this
%      file's prose about itself is exactly the thing that goes stale in the
%      direction of "less is possible than really is".
%
%        (a) SAID: "`directed_relation` declares exactly three dependencies --
%            `child`, `parent`, `time_reference_#`. There is no `epoch_id`."
%            FALSE NOW. The slot is declared:
%
%              $ python3 -c "import json;print([x['name'] for x in json.load(
%                    open('schemas/V_eta/stable/directed_relation.json')
%                  )['depends_on']])"
%              ['child', 'parent', 'time_reference_#', 'epoch_id']
%
%        (b) SAID: "No `epoch` document exists to point at ... that mint is a
%            different family and is not built." FALSE NOW.
%            `did2.convert.epochMint` mints one `epoch` per distinct
%            (base.session_id, epoch-id string) and PUBLISHES the index this
%            hook needs -- `report.epoch_index` rows are
%            (session_id, local_identifier, epoch_document_id), where
%            `local_identifier` IS the epoch string (epochMint.m:196,317,526).
%            ndi.migrate.local already calls it and already feeds that index to
%            resolveEpochAnchorFold (local.m:675, 1447-1453).
%
%      WHAT ACTUALLY BLOCKED IT WAS PASS ORDER, AND THAT IS NOW FIXED (team
%      decision, 2026-08-11). `resolveEnsembleMembership` ran at local.m:638
%      while `epochMint` ran at local.m:675, so this pass ran BEFORE the
%      epochs it points at existed and could emit nothing but unscoped edges.
%      It is now ordered AFTER epochMint and receives a resolver built from
%      epochMint's own `epoch_index`, exactly as sub-pass (7e) valid intervals
%      is ordered ("ORDER: after (7) FOR A REAL REASON, not for symmetry. It
%      reads the `epoch` documents epochMint appends; run before them it
%      refuses every interval and changes nothing").
%
%      THE EDGE COUNTS MOVE, AND THE EXPECTED MOVEMENT IS A PREDICTION, NOT A
%      MEASUREMENT. Scoping separates the dedupe key, so an ensemble recorded
%      over N epochs with the same roster now yields N rosters of edges where
%      it previously yielded one -- which is the point (the per-epoch roster
%      is the fact the signed model exists to preserve). NO CORPUS HAS RUN
%      THIS. epochMint's own header still reads "WRITTEN 2026-08-10, NEVER
%      EXECUTED", so the next corpus run is the FIRST measurement of the two
%      passes together, and the numbers may move for reasons neither this
%      comment nor its author anticipated. Read any figure quoted for this
%      pass as a prediction until a corpus prints one.
%
%      Note the key must stay the PAIR (session_id, epoch string): epochMint
%      measured `epochid.epochid` strings REUSED ACROSS SESSIONS in 142 of
%      corpus B's 149 distinct ids, so grouping on the string alone would fuse
%      epochs from different animals. OPTIONS.EpochDocumentIdFor already takes
%      both arguments.
%
%      HOOK, unchanged and ready: pass OPTIONS.EpochDocumentIdFor, a function
%      handle `docId = f(epochidString, sessionId)` returning '' when unknown.
%      When it returns a non-empty id an `epoch_id` dependency is added to both
%      edge kinds and the dedupe key separates epochs. Nothing empty is ever
%      emitted (rule: never emit an empty edge).
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
%   ---------------------------------------------------------------------
%   THE VERIFY-BEFORE-DELETE GATE MEASURES TRAINS, NOT SUBJECTS
%   ---------------------------------------------------------------------
%   An earlier revision of this pass offered `neuron_edges_stranded` as the
%   verify-before-delete instrument. IT MEASURES THE WRONG THING, in the
%   reassuring direction. `neuron_edges_stranded` asks whether the neuron
%   SUBJECT is in the migrated set -- but `migrators_j.element` turns every
%   element into a bare `subject` carrying NO data:
%
%       DID-matlab +did2/+convert/+migrators_j/element.m:89-95
%           subjectDoc.document_class = struct('class_name','subject', ...
%           subjectDoc.subject = struct('local_identifier', localId, ...
%
%   The spike times live in a SEPARATE document. So every neuron-subject can
%   be present, `neuron_edges_stranded` can read 0, and the per-neuron trains
%   can be absent to the last byte -- and dropping the combined binary on that
%   zero would destroy the only surviving copy. That is this project's
%   standing failure mode (a counter that reads clean while inspecting
%   something other than the question) applied to a DATA-LOSS gate.
%
%   WHAT A PER-NEURON TRAIN ACTUALLY IS, taken from NDI's own READER rather
%   than from a template or a schema (origin/main
%   +ndi/+element/timeseries.m:56-70, the readtimeseries path):
%
%       sq = ndi.query('depends_on','depends_on','element_id',element_doc.id()) & ...
%            ndi.query('','isa','element_epoch','') & ...
%            ndi.query('epochid.epochid','exact_string',epoch_timeref.epoch,'');
%       epochdoc = E.database_search(sq);
%       f = E.database_openbinarydoc(epochdoc,'epoch_binary_data.vhsb');
%
%   i.e. a train is an `element_epoch` whose `element_id` is the neuron, whose
%   `epochid.epochid` is the epoch, carrying the binary. `element_epoch` is
%   RENAMED to `acquisition_epoch` in V_eta (base.id preserved), and
%   `universalRenames.m` skips the structural keys `file`/`files`, so the file
%   block survives verbatim. The writer agrees with the reader:
%   +ndi/element.m:382-393 mints `element_epoch` and sets `element_id`, and
%   +ndi/+element/timeseries.m:114-116 attaches `epoch_binary_data.vhsb`.
%
%   DO NOT RE-SIMPLIFY THE THREE BUCKETS BELOW INTO ONE. The whole failure
%   this guards against is a gate that reads a clean zero on a corpus where
%   every spike train is missing, and then AUTHORISES DROPPING THE ONLY COPY
%   of the combined binary. Any collapse of these buckets -- into a single
%   "trains_missing", into a boolean, into "stranded" -- reintroduces exactly
%   that, because it makes "the data is not there" indistinguishable from
%   "the data is there and I looked in the wrong place". The buckets are the
%   instrument; their separation IS the safety property, not presentation.
%
%   TRAIN PRESENCE IS THEREFORE REPORTED IN THREE BUCKETS, because "no train
%   anywhere" and "trains exist but not under this epoch id" are different
%   findings and must not be summed:
%     neuron_trains_present_this_epoch   train for THIS map's epochid
%     neuron_trains_other_epoch_only     neuron has train(s), none this epochid
%     neuron_trains_missing_entirely     neuron has no train document at all
%   The middle bucket is expected to be non-zero in principle: the reader
%   reaches its epoch through `syncgraph.time_convert`, so an ensemble's
%   epochid and a constituent neuron's epochid need not be the same string.
%   It is reported, never silently folded into either neighbour.
%
%   THE INSTRUMENT REPORTS ITS OWN DENOMINATOR TOO -- `train_documents_seen`
%   and `train_documents_with_binary`. If the second is 0 while the first is
%   large, this pass is looking at the wrong field and every "missing train"
%   is an artefact of the instrument, not a fact about the corpus. That
%   distinction is visible from the report alone.
%
%   NOTHING IS DELETED HERE AND NO SWITCH ENABLES DELETION. The gate is
%   MEASURED and reported (`verify_before_delete_clear`); acting on it is a
%   separate, team-gated build.
%
%   5. RESOLVED, NOT OPEN -- this item said the registry row for `member_of`
%      declares `"timed": false, "ordered": false` and disagreed with the
%      signed model. IT NOW AGREES, and the disagreement is closed:
%
%        $ python3 -c "import json;[print(r) for r in json.load(open(
%              'schemas/V_eta/stable/binding_registry_meta.json'))
%              ['relation_bindings'] if r['relation']['name']=='member_of']"
%        {'relation': {'node': 'RO:0002350', 'name': 'member_of'},
%         'class': 'directed_relation', 'child_role': 'the member',
%         'parent_role': 'the group', 'child_types': ['subject'],
%         'parent_types': ['subject'], 'timed': True, 'ordered': True}
%
%      (DENOMINATOR: 26 relation_bindings rows read.) So `ordered: true`
%      licenses the `sequence` this pass emits, and `timed: true` licenses the
%      epoch scoping item 2 describes. Nothing here needs a team call.
%
%   STATUS: authored without local MATLAB -- CI is the first execution of
%   every line here. The membership/cache half first ran GREEN in
%   test-eta-migrate.yml run 31463051482 (13/13). The train-verification half
%   added afterwards has its own tests in the same class; read a green run as
%   proving the pair is self-consistent, not as proving either matches NDI
%   ground truth -- the corpus gate remains the real check.
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
report.ensemble_maps_no_neurons = 0;   % map carries no usable neuron_id_# edge
report.distinct_ensembles_seen  = 0;   % distinct group ids (a map is PER EPOCH)
report.distinct_epochs_seen     = 0;   % distinct epochid.epochid strings
report.neuron_edges_seen        = 0;
report.neuron_edges_resolved    = 0;
report.neuron_edges_stranded    = 0;
report.stranded_neuron_ids      = {};
% --- verify-before-delete: TRAINS, not subjects (see header) --------------
report.train_documents_seen         = 0;  % acquisition_epoch docs in the batch
report.train_documents_with_binary  = 0;  % ... carrying epoch_binary_data.vhsb
report.neuron_trains_present_this_epoch = 0;
report.neuron_trains_other_epoch_only   = 0;
report.neuron_trains_missing_entirely   = 0;
report.neurons_missing_train_ids        = {};
report.verify_before_delete_clear       = false;
report.cache_carriers_seen      = 0;   % distinct element_epoch_id values
report.cache_carriers_resolved  = 0;   % ... that are present in the migrated set
report.member_of_minted         = 0;
report.derived_from_minted      = 0;
report.epoch_scoped_edges       = 0;
report.unscoped_edges           = 0;   % emitted, but NOT epoch-scoped
% Why a map could not be scoped -- three distinct facts, never summed.
report.maps_epoch_scoped              = 0;
report.maps_unscoped_no_resolver      = 0;  % caller wired no resolver
report.maps_unscoped_no_epoch_string  = 0;  % document carries no epochid
report.maps_unscoped_epoch_unresolved = 0;  % epochid named no minted epoch
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

% index every per-neuron TRAIN in the batch: elementId -> the epochid strings
% it carries data for. Mirrors NDI's own readtimeseries triple (header) --
% an acquisition_epoch, its `element_id`, and a binary payload.
trainEpochs = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:numel(structs)
    if ~isTrainCarrier(structs{i})
        continue;
    end
    report.train_documents_seen = report.train_documents_seen + 1;
    if ~hasBinaryPayload(structs{i})
        continue;   % an epoch document with no bytes is not a train
    end
    report.train_documents_with_binary = report.train_documents_with_binary + 1;
    ownerId = depVal(structs{i}, 'element_id');
    if isempty(ownerId)
        continue;
    end
    ep = epochIdString(structs{i});
    if isKey(trainEpochs, ownerId)
        trainEpochs(ownerId) = [trainEpochs(ownerId), {ep}];
    else
        trainEpochs(ownerId) = {ep};
    end
end

seenEdge      = containers.Map('KeyType', 'char', 'ValueType', 'logical');
seenCarrier   = containers.Map('KeyType', 'char', 'ValueType', 'logical');
seenStranded  = containers.Map('KeyType', 'char', 'ValueType', 'logical');
seenGroup     = containers.Map('KeyType', 'char', 'ValueType', 'logical');
seenEpoch     = containers.Map('KeyType', 'char', 'ValueType', 'logical');
seenNoTrain   = containers.Map('KeyType', 'char', 'ValueType', 'logical');

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

    % A map document is PER EPOCH, so ensemble_maps_seen over-counts ensembles.
    % Both denominators are reported rather than one standing in for the other.
    if ~isKey(seenGroup, groupId)
        seenGroup(groupId) = true;
        report.distinct_ensembles_seen = report.distinct_ensembles_seen + 1;
    end
    mapEpochStr = epochIdString(s);
    if ~isempty(mapEpochStr) && ~isKey(seenEpoch, mapEpochStr)
        seenEpoch(mapEpochStr) = true;
        report.distinct_epochs_seen = report.distinct_epochs_seen + 1;
    end

    sessionId = baseField(s, 'session_id', '');
    ds        = baseField(s, 'datestamp', '2024-01-01T00:00:00.000Z');
    [epochKey, epochStatus] = epochScope(s, sessionId, options.EpochDocumentIdFor);
    switch epochStatus
        case 'scoped'
            report.maps_epoch_scoped = report.maps_epoch_scoped + 1;
        case 'no_resolver'
            report.maps_unscoped_no_resolver = ...
                report.maps_unscoped_no_resolver + 1;
        case 'no_epoch_string'
            report.maps_unscoped_no_epoch_string = ...
                report.maps_unscoped_no_epoch_string + 1;
        case 'unresolved'
            report.maps_unscoped_epoch_unresolved = ...
                report.maps_unscoped_epoch_unresolved + 1;
    end

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
        % counted rather than silently skipped: this map contributes no
        % membership at all, and "fell through" must never be inferable only
        % by subtracting two other counters.
        report.ensemble_maps_no_neurons = report.ensemble_maps_no_neurons + 1;
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

        % VERIFY-BEFORE-DELETE. The subject exists; does its TRAIN? Three
        % buckets, never summed -- see the header.
        if ~isKey(trainEpochs, neuronId)
            report.neuron_trains_missing_entirely = ...
                report.neuron_trains_missing_entirely + 1;
            if ~isKey(seenNoTrain, neuronId)
                seenNoTrain(neuronId) = true;
                report.neurons_missing_train_ids{end+1} = neuronId; %#ok<AGROW>
            end
        elseif ~isempty(mapEpochStr) && any(strcmp(trainEpochs(neuronId), mapEpochStr))
            report.neuron_trains_present_this_epoch = ...
                report.neuron_trains_present_this_epoch + 1;
        else
            % the neuron has data, but not filed under this map's epochid.
            % NDI reaches a neuron's epoch through syncgraph.time_convert, so
            % the two strings need not agree; this is reported, not folded in.
            report.neuron_trains_other_epoch_only = ...
                report.neuron_trains_other_epoch_only + 1;
        end

        mKey = ['m|' groupId '|' neuronId '|' int2str(column) '|' epochKey];
        if ~isKey(seenEdge, mKey)
            seenEdge(mKey) = true;
            minted{end+1} = relationBody(neuronId, groupId, MEMBER_OF, ...
                column, epochKey, sessionId, ds, 'migrated_ensemble_member'); %#ok<AGROW>
            report.member_of_minted = report.member_of_minted + 1;
            if ~isempty(epochKey)
                report.epoch_scoped_edges = report.epoch_scoped_edges + 1;
            else
                % Emitted, but carrying no epoch: membership is preserved
                % (dropping it would lose the roster outright) while the
                % per-epoch fact is NOT. Counted, never silent.
                report.unscoped_edges = report.unscoped_edges + 1;
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
                else
                    report.unscoped_edges = report.unscoped_edges + 1;
                end
            end
        end
    end
end

% The verify-before-delete verdict. It is a MEASUREMENT -- nothing in this
% file deletes anything, and no option enables deletion. `false` when nothing
% was inspected, so an empty batch can never read as a clearance.
report.verify_before_delete_clear = ...
    report.ensemble_maps_used > 0 && ...
    report.neuron_edges_resolved > 0 && ...
    report.neuron_edges_stranded == 0 && ...
    report.neuron_trains_missing_entirely == 0 && ...
    report.neuron_trains_other_epoch_only == 0;

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
    % item 2 of the header. THIS COMMENT SAID "directed_relation does not
    % declare the slot yet -- that is the DID-schema change this hook waits
    % on", contradicting item 2(a) of this file's own header. STALE: the slot
    % is declared, and OPTIONAL, so an unscoped edge cannot quarantine under
    % #37 RequiredDependencies.
    %
    %   $ python3 -c "import json;print([(x['name'],x['mustBeNonEmpty']) for x
    %         in json.load(open('schemas/V_eta/stable/directed_relation.json')
    %       )['depends_on']])"
    %   [('child', True), ('parent', True), ('time_reference_#', False),
    %    ('epoch_id', False)]
    deps(end+1) = struct('name', 'epoch_id', 'value', epochDocId);
end
body.depends_on = deps;
body.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', name, 'creation_timestamp', ds);
block = struct('relation', relTerm);
if ~isempty(sequence)
    % `sequence` is directed_relation's declared "ordinal for ordered
    % relations" -- the column index of this neuron in the epoch's combined
    % binary. THIS COMMENT SAID "NOTE the registry row for member_of
    % currently says 'ordered': false", contradicting item 5 of this file's
    % own header, which records the disagreement as CLOSED. STALE: the row
    % reads `'timed': True, 'ordered': True` (DENOMINATOR: 26
    % relation_bindings rows read from
    % schemas/V_eta/stable/binding_registry_meta.json), so `ordered: true`
    % licenses this ordinal and `timed: true` licenses the epoch scoping.
    block.sequence = sequence;
end
body.directed_relation = block;
end

% ===================== struct accessors ================================

function [key, status] = epochScope(s, sessionId, resolverFcn)
%EPOCHSCOPE The epoch DOCUMENT id for this map, and WHY when there is none.
%   An unscoped edge is not one fact but three, and they have different
%   remedies: no resolver wired (a caller/order problem), no epoch string on
%   the document (a source-data fact), or a string that named no minted epoch
%   (an epochMint coverage gap). Collapsing them into one empty string is how
%   "it did not resolve" becomes indistinguishable from "there was nothing to
%   resolve".
key = '';
epochStr = epochIdString(s);
if isempty(resolverFcn)
    status = 'no_resolver';
    return;
end
if isempty(epochStr)
    status = 'no_epoch_string';
    return;
end
try
    key = char(resolverFcn(epochStr, sessionId));
catch
    key = '';   % a resolver that throws is a resolver that did not resolve
end
if isempty(key)
    status = 'unresolved';
else
    status = 'scoped';
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

function tf = isTrainCarrier(s)
%ISTRAINCARRIER True for a document that can hold an element's epoch data.
%   `element_epoch` is RENAMED to `acquisition_epoch` in V_eta with base.id
%   preserved. Pass-1 output carries the V_eta name; the did_v1 name is
%   accepted too so this instrument cannot silently read zero if it is ever
%   pointed at an unmigrated batch -- a false "no trains" would block a
%   deletion, never permit one.
c = classNameOf(s);
tf = strcmp(c, 'acquisition_epoch') || strcmp(c, 'element_epoch');
end

function tf = hasBinaryPayload(s)
%HASBINARYPAYLOAD True when the epoch document actually carries bytes.
%   NDI attaches `epoch_binary_data.vhsb`
%   (+ndi/+element/timeseries.m:114-116) and the template declares it under
%   `files.file_list`. `universalRenames.m` skips the structural keys
%   `file`/`files`, so the block survives migration verbatim -- both
%   spellings are accepted because the restated-tombstone defect showed the
%   two are not reliably distinguished across the tree.
tf = false;
for blk = {'files', 'file'}
    name = blk{1};
    if isfield(s, name) && isstruct(s.(name)) && isfield(s.(name), 'file_list')
        fl = s.(name).file_list;
        if ~isempty(fl)
            tf = true; return;
        end
    end
end
end

function e = epochIdString(s)
%EPOCHIDSTRING The `epochid.epochid` join key, or '' when absent.
e = '';
if isfield(s, 'epochid') && isstruct(s.epochid) && isfield(s.epochid, 'epochid') ...
        && ~isempty(s.epochid.epochid)
    e = char(s.epochid.epochid);
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
