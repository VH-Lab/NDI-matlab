function [plan, report] = sliceTetanus(v1Bodies, structs, epochIndex)
%SLICETETANUS Dabrowska slice electrophysiology: one entity per brain slice,
%   one optogenetic-tetanus manipulation per recording run, its time as a
%   relative time reference, and the before/after approach labels dropped.
%
%   [PLAN, REPORT] = SLICETETANUS(V1BODIES, STRUCTS, EPOCHINDEX)
%
%   V1BODIES   - cell of decoded did_v1 document structs (the migration input).
%   STRUCTS    - cell of migrated V_eta document structs (did2.document.toStruct).
%   EPOCHINDEX - did2.convert.epochMint's `epoch_index` (session_id,
%                local_identifier, epoch_document_id), the map from a v1 epoch
%                string to the minted `epoch` document.
%
%   PLAN is a struct:
%     minted      cell of new V_eta bodies (schema_version 'V_eta'): animals,
%                 copied strain assertions, slices, part_of relations, tetanus
%                 manipulations and their relative references
%     replaced    cell of migrated structs with an edge moved, base.id KEPT
%     removed     cellstr of migrated base.ids to drop
%   REPORT carries every count, each with its denominator.
%
%   PURE: reads structs, returns structs. No converter, no schema, no database.
%   ndi.migrate.local's resolveSliceTetanus does the fold.
%
%   ---------------------------------------------------------------------
%   DECIDED BY JESS HALEY, 2026-10-21 (NDI-matlab
%   src/ndi/+ndi/+setup/+conv/+dabrowska/V2_decisions.md, the Dab section)
%   ---------------------------------------------------------------------
%   1. A SLICE IS AN ENTITY, `part_of` ITS ANIMAL. The importer names every
%      probe of a slice with one postfix, `_<yymmdd>_BNST<type>[_<opto>]_<slice
%      label>` (doImport.m, `ProbePostfix`; the label is the `SliceLabel` the
%      file manifest reads from the folder, default 'a'), so a stimulator named
%      `bath_<postfix>` whose animal's local identifier ends in the postfix
%      without its label IS that slice's bath. The baths on it, the per-epoch
%      stimulator and recording statements in its epochs, and the probes that
%      share its postfix are re-attributed from the animal to the slice.
%   2. ONE TETANUS MANIPULATION PER RECORDING RUN (per slice): entity = the
%      slice, instrument = the bath stimulator, method = optogenetic tetanus
%      stimulation, and the animal's `treatment` target location (EMPTY:0000074,
%      an UBERON node) as a CONDITION. The per-animal treatment manipulation it
%      supersedes is removed, with the Path-S part-subject that existed only to
%      carry its site.
%   3. ITS TIME IS A RELATIVE REFERENCE on the exp_global_time clock: relative
%      to the run's last "before" epoch, starting when that recording ended
%      (start = its length) and lasting until the first "after" recording
%      started (duration = the gap).
%   4. THE 635 BEFORE/AFTER APPROACH LABELS ARE DROPPED (T6: derivable from
%      the times). They are dropped only after the rebuild below reproduces
%      every one of them from the emitted window; a run whose labels do not
%      rebuild keeps them.
%   5. A RECORDING DAY NESTED INSIDE ANOTHER IS ANOTHER ANIMAL. Where an
%      epoch's file path holds two date folders (`.../Dec 02 2022/Nov 28
%      2022/...`), the importer's RecordingDate regex took the first, so the
%      run was filed under the outer animal. The inner date names a separate
%      animal (its local identifier is the outer one with the date replaced),
%      with its own slice and run; it copies only the animal's STRAIN
%      assertions, which come from the genotype folder the two share. Species
%      and sex are lab-wide constants in doImport.m, not folder facts, and are
%      not copied.
%   6. THE TETANUS PROTOCOL FROM THE FOLDER. The post-tetanus recordings sit in
%      a folder named `TLS` or `TLS <f> Hz <d> s`; where the folder states the
%      protocol (every "after" epoch of the run agrees), the manipulation's
%      `method_parameters` carry frequency and duration as written. Plain
%      `TLS` records nothing.
%
%   WHAT THE PINNED SCHEMA (did-schema v_eta-pre73) CANNOT SAY, AND SO IS NOT
%   SAID: a slice's entity TYPE. pre73 `subject` has no `type` field (V2's
%   `entity.type`, bound to {'', 'tissue'}, came later), so a slice is a plain
%   `subject` + `part_of`, the shape Path-S part-subjects already use, and its
%   description says what it is. The method term and the hertz unit have no
%   registered identifier in scope, so their nodes are left empty, the line's
%   convention for a term with no identifier.

arguments
    v1Bodies cell
    structs  cell
    epochIndex = struct('session_id', {}, 'local_identifier', {}, ...
        'epoch_document_id', {})
end

plan = struct('minted', {{}}, 'replaced', {{}}, 'removed', {{}});
report = newReport();
report.v1_documents_read = numel(v1Bodies);
report.migrated_documents_read = numel(structs);

ACT = struct('node', '', 'name', 'optogenetic tetanus stimulation');
SITE_VAR_NODE = 'EMPTY:0000074';
SITE_VAR = struct('node', SITE_VAR_NODE, ...
    'name', 'Optogenetic Tetanus Stimulation Target Location');

% ======================= v1 indices =====================================
elName = containers.Map(); elType = containers.Map(); elSubj = containers.Map();
elSession = containers.Map();
subjLid = containers.Map(); subjSession = containers.Map(); subjDs = containers.Map();
times = containers.Map();      % session|epoch -> [t0 t1] (exp_global_time)
timesN = containers.Map();     % session|epoch -> count of epochtables with the clock
matFiles = containers.Map();   % session|epoch -> cellstr of .mat paths
bathOfEpoch = containers.Map();% session|epoch -> stimulator id
bathIds = {}; bathStim = {}; bathKey = {};
labelIds = {}; labelStim = {}; labelKey = {}; labelVal = {};
treatRegion = containers.Map();% animal id -> UBERON node ('' = conflicting)

for k = 1:numel(v1Bodies)
    b = v1Bodies{k};
    c = className(b);
    id = baseField(b, 'id'); sid = baseField(b, 'session_id');
    switch c
        case 'element'
            e = blockOf(b, 'element');
            elName(id) = charField(e, 'name');
            elType(id) = charField(e, 'type');
            elSubj(id) = depValue(b, 'subject_id');
            elSession(id) = sid;
        case 'subject'
            subjLid(id) = charField(blockOf(b, 'subject'), 'local_identifier');
            subjSession(id) = sid;
            subjDs(id) = baseField(b, 'datestamp');
        case 'daqreader_mfdaq_epochdata_ingested'
            ep = charField(blockOf(b, 'epochid'), 'epochid');
            et = blockOf(blockOf(b, 'daqreader_epochdata_ingested'), 'epochtable');
            [t, ok] = clockTimes(et, 'exp_global_time');
            if ok && ~isempty(ep)
                key = [sid '|' ep];
                n = 0; if isKey(timesN, key); n = timesN(key); end
                timesN(key) = n + 1;
                times(key) = t;
            end
        case 'epochfiles_ingested'
            blk = blockOf(b, 'epochfiles_ingested');
            ep = charField(blk, 'epoch_id');
            f = {};
            if isfield(blk, 'files'); f = cellstrOf(blk.files); end
            matFiles([sid '|' ep]) = f(endsWith(f, '.mat'));
        case 'stimulus_bath'
            ep = charField(blockOf(b, 'epochid'), 'epochid');
            st = depValue(b, 'stimulus_element_id');
            bathIds{end+1} = id; bathStim{end+1} = st; %#ok<AGROW>
            bathKey{end+1} = [sid '|' ep]; %#ok<AGROW>
            bathOfEpoch([sid '|' ep]) = st;
        case 'openminds_stimulus'
            om = blockOf(b, 'openminds');
            flds = blockOf(om, 'fields');
            nm = charField(flds, 'name'); on = charField(flds, 'preferredOntologyIdentifier');
            lab = '';
            if strcmp(on, 'EMPTY:0000221') || endsWith(nm, 'after optogenetic tetanus')
                lab = 'after';
            elseif strcmp(on, 'EMPTY:0000220') || endsWith(nm, 'before optogenetic tetanus')
                lab = 'before';
            end
            if isempty(lab); continue; end
            ep = charField(blockOf(b, 'epochid'), 'epochid');
            labelIds{end+1} = id; labelStim{end+1} = depValue(b, 'stimulus_element_id'); %#ok<AGROW>
            labelKey{end+1} = [sid '|' ep]; labelVal{end+1} = lab; %#ok<AGROW>
        case 'treatment'
            tb = blockOf(b, 'treatment');
            nm = lower(strtrim(charField(tb, 'name')));
            if strcmp(charField(tb, 'ontologyName'), SITE_VAR_NODE) ...
                    || endsWith(nm, 'tetanus stimulation target location')
                a = depValue(b, 'subject_id');
                v = charField(tb, 'string_value');
                if isKey(treatRegion, a) && ~strcmp(treatRegion(a), v)
                    treatRegion(a) = '';
                    report.treatment_animals_conflicting = report.treatment_animals_conflicting + 1;
                else
                    treatRegion(a) = v;
                end
            end
    end
end
report.treatment_target_locations = double(treatRegion.Count);
report.approach_labels = numel(labelIds);
report.stimulus_bath_documents = numel(bathIds);

% ======================= slices ========================================
% slice key = <stimulator id>|<inner yymmdd or ''>
sliceStim = containers.Map(); sliceAnimalKey = containers.Map(); sliceLabel = containers.Map();
stimSlices = containers.Map();       % stimulator id -> cellstr of slice keys
stimSuffix = containers.Map();       % stimulator id -> postfix (without 'bath_')
newAnimalLid = containers.Map();     % animal key -> local identifier
newAnimalOf = containers.Map();      % animal key -> original animal id
epochSlice = containers.Map();       % session|epoch -> slice key

cnt = containers.Map({'epochs_on_a_nested_date', 'nested_dates_not_in_animal_id'}, {0, 0});
ctx = struct('matFiles', matFiles, 'elSubj', elSubj, 'subjLid', subjLid, ...
    'newAnimalLid', newAnimalLid, 'newAnimalOf', newAnimalOf, 'cnt', cnt);
stimIds = elName.keys;
for i = 1:numel(stimIds)
    s = stimIds{i};
    if ~strcmp(elType(s), 'stimulator'); continue; end
    report.stimulators = report.stimulators + 1;
    tok = regexp(elName(s), '^bath_(.+)_([a-z])$', 'tokens', 'once');
    if isempty(tok)
        report.stimulators_not_a_slice_bath = report.stimulators_not_a_slice_bath + 1;
        continue;
    end
    a = elSubj(s);
    if ~isKey(subjLid, a) || ~endsWith(lidBase(subjLid(a)), ['_' tok{1}])
        report.stimulators_animal_mismatch = report.stimulators_animal_mismatch + 1;
        continue;
    end
    report.slice_bath_stimulators = report.slice_bath_stimulators + 1;
    stimSuffix(s) = [tok{1} '_' tok{2}];
end

for j = 1:numel(bathIds)
    s = bathStim{j};
    if ~isKey(stimSuffix, s); continue; end
    key = bathKey{j};
    ak = animalKeyOfEpoch(s, key, ctx);
    sk = [s '|' ak];
    if ~isKey(sliceStim, sk)
        sliceStim(sk) = s;
        sliceAnimalKey(sk) = ak;
        lt = regexp(elName(s), '_([a-z])$', 'tokens', 'once');
        sliceLabel(sk) = lt{1};
        if isKey(stimSlices, s); stimSlices(s) = [stimSlices(s) {sk}];
        else; stimSlices(s) = {sk}; end
    end
    epochSlice(key) = sk;
end
report.slices = double(sliceStim.Count);
report.epochs_on_a_nested_date = cnt('epochs_on_a_nested_date');
report.nested_dates_not_in_animal_id = cnt('nested_dates_not_in_animal_id');
report.new_animals = double(newAnimalLid.Count);

% ======================= migrated indices ==============================
n = numel(structs);
idOf = cell(1, n); classOf = cell(1, n);
for k = 1:n
    idOf{k} = baseField(structs{k}, 'id');
    classOf{k} = className(structs{k});
end
posOf = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    if ~isempty(idOf{k}); posOf(idOf{k}) = k; end
end
relTo = containers.Map();            % relative_reference id -> relative_to
for k = 1:n
    if strcmp(classOf{k}, 'relative_reference')
        relTo(idOf{k}) = depValue(structs{k}, 'relative_to');
    end
end
epochKeyOfDoc = containers.Map(); epochDocOfKey = containers.Map();
for k = 1:numel(epochIndex)
    ek = [char(epochIndex(k).session_id) '|' char(epochIndex(k).local_identifier)];
    epochKeyOfDoc(char(epochIndex(k).epoch_document_id)) = ek;
    epochDocOfKey(ek) = char(epochIndex(k).epoch_document_id);
end
report.epoch_index_entries = numel(epochIndex);

% ======================= mint animals, slices ==========================
mintedAnimalId = containers.Map();   % animal key -> id ('' key = original)
aks = newAnimalLid.keys;
for i = 1:numel(aks)
    ak = aks{i};
    a = newAnimalOf(ak);
    newId = did.ido.unique_id();
    mintedAnimalId(ak) = newId;
    body = struct();
    body.document_class = classBlock('subject', {'base'});
    body.depends_on = struct('name', {}, 'value', {});
    body.base = struct('id', newId, 'session_id', subjSession(a), ...
        'name', 'migrated_nested_date_animal', 'creation_timestamp', dsOr(subjDs(a)));
    body.subject = struct('local_identifier', newAnimalLid(ak), 'description', ...
        sprintf(['an animal recorded on 20%s that did_v1 filed under %s: its ' ...
        'epoch files sit in a %s folder nested inside the other animal''s ' ...
        'date folder'], ak(end-5:end), subjLid(a), ak(end-5:end)));
    body = ndi.migrate.internal.withSessionId(body, subjSession(a));
    plan.minted{end+1} = body;
    % the strain assertions come from the genotype folder the two animals share
    for k = 1:n
        if strcmp(classOf{k}, 'term_assertion') ...
                && strcmp(depValue(structs{k}, 'subject_id'), a) ...
                && ~isempty(depValue(structs{k}, 'strain_id'))
            cp = structs{k};
            cp.base.id = did.ido.unique_id();
            cp = setDep(cp, 'subject_id', newId);
            cp.document_class.schema_version = 'V_eta';
            plan.minted{end+1} = cp; %#ok<AGROW>
            report.new_animal_strain_assertions_copied = ...
                report.new_animal_strain_assertions_copied + 1;
        end
    end
end

sliceId = containers.Map();          % slice key -> minted id
sliceKeyById = containers.Map();     % minted id -> slice key
sks = sliceStim.keys;
for i = 1:numel(sks)
    sk = sks{i};
    s = sliceStim(sk); ak = sliceAnimalKey(sk);
    if isempty(ak)
        animalId = elSubj(s); lid = subjLid(animalId);
    else
        animalId = mintedAnimalId(ak); lid = newAnimalLid(ak);
    end
    origAnimal = elSubj(s);
    sid = subjSession(origAnimal); ds = dsOr(subjDs(origAnimal));
    newId = did.ido.unique_id();
    sliceId(sk) = newId;
    sliceKeyById(newId) = sk;
    [b0, dom] = lidBase(lid);
    sl = struct();
    sl.document_class = classBlock('subject', {'base'});
    sl.depends_on = struct('name', {}, 'value', {});
    sl.base = struct('id', newId, 'session_id', sid, ...
        'name', 'migrated_slice', 'creation_timestamp', ds);
    sl.subject = struct('local_identifier', [b0 '_' sliceLabel(sk) dom], ...
        'description', sprintf(['brain slice %s of %s (tissue); its bath ' ...
        'stimulator is %s'], sliceLabel(sk), lid, elName(s)));
    sl = ndi.migrate.internal.withSessionId(sl, sid);
    rel = struct();
    rel.document_class = classBlock('directed_relation', {'relation'});
    rel.depends_on = [struct('name', 'child', 'value', newId), ...
        struct('name', 'parent', 'value', animalId)];
    rel.base = struct('id', did.ido.unique_id(), 'session_id', sid, ...
        'name', 'migrated_slice_part_of', 'creation_timestamp', ds);
    rel.directed_relation = struct('relation', ...
        struct('node', 'BFO:0000050', 'name', 'part_of'));
    rel = ndi.migrate.internal.withSessionId(rel, sid);
    plan.minted = [plan.minted, {sl, rel}];
end

% ======================= re-attribute ==================================
% Each element that belongs to a slice: the stimulator itself, and any element
% of the same session and animal whose name ends in the stimulator's postfix.
elementSlices = containers.Map();
ss = stimSuffix.keys;
for i = 1:numel(ss)
    s = ss{i};
    if ~isKey(stimSlices, s); continue; end
    for e = 1:numel(stimIds)
        x = stimIds{e};
        if strcmp(x, s) || (strcmp(elSession(x), elSession(s)) ...
                && strcmp(elSubj(x), elSubj(s)) && ~strcmp(elType(x), 'stimulator') ...
                && endsWith(elName(x), ['_' stimSuffix(s)]))
            elementSlices(x) = stimSlices(s);
        end
    end
end
report.slice_elements = double(elementSlices.Count);

replacedPos = [];
for k = 1:n
    c = classOf{k};
    s = structs{k};
    isStatement = endsWith(c, '_manipulation') || endsWith(c, '_observation');
    if isStatement
        subj = depValue(s, 'subject_id');
        instr = depValue(s, 'instrument_id');
        ek = epochOfStatement(s, relTo, epochKeyOfDoc);
        if ~isempty(ek) && isKey(epochSlice, ek)
            sk = epochSlice(ek);
            st = sliceStim(sk);
            if ~strcmp(subj, elSubj(st)); continue; end
            report.epoch_statements_examined = report.epoch_statements_examined + 1;
            if isempty(instr)
                report.epoch_statements_unmatched = report.epoch_statements_unmatched + 1;
                continue;
            end
            if strcmp(instr, st) || (isKey(elementSlices, instr) ...
                    && any(strcmp(elementSlices(instr), sk)))
                structs{k} = setDep(s, 'subject_id', sliceId(sk));
                replacedPos(end+1) = k; %#ok<AGROW>
                report.epoch_statements_matched = report.epoch_statements_matched + 1;
                report = bumpClass(report, 'reattributed_by_class', c);
            else
                report.epoch_statements_unmatched = report.epoch_statements_unmatched + 1;
            end
        elseif ~isempty(instr) && isKey(elementSlices, instr) ...
                && strcmp(subj, elSubj(instr))
            % not anchored to a slice epoch: unambiguous only if the element
            % belongs to exactly one slice
            report.unanchored_statements_examined = report.unanchored_statements_examined + 1;
            sl = elementSlices(instr);
            if isscalar(sl)
                structs{k} = setDep(s, 'subject_id', sliceId(sl{1}));
                replacedPos(end+1) = k; %#ok<AGROW>
                report.unanchored_statements_matched = report.unanchored_statements_matched + 1;
                report = bumpClass(report, 'reattributed_by_class', c);
            else
                report.unanchored_statements_ambiguous = report.unanchored_statements_ambiguous + 1;
            end
        end
    elseif strcmp(c, 'directed_relation')
        child = depValue(s, 'child'); parent = depValue(s, 'parent');
        if isKey(elementSlices, child) && strcmp(parent, elSubj(child)) ...
                && strcmp(relationName(s), 'observes')
            report.element_relations_examined = report.element_relations_examined + 1;
            sl = elementSlices(child);
            if isscalar(sl)
                structs{k} = setDep(s, 'parent', sliceId(sl{1}));
                replacedPos(end+1) = k; %#ok<AGROW>
                report.element_relations_matched = report.element_relations_matched + 1;
            else
                report.element_relations_ambiguous = report.element_relations_ambiguous + 1;
            end
        end
    end
end

% ======================= tetanus runs ==================================
runKeys = {}; runRows = {};
for j = 1:numel(labelIds)
    s = labelStim{j}; key = labelKey{j};
    if ~isKey(epochSlice, key)
        report.labels_not_on_a_slice_epoch = report.labels_not_on_a_slice_epoch + 1;
        continue;
    end
    if ~isKey(times, key) || timesN(key) ~= 1
        report.labels_without_one_epoch_time = report.labels_without_one_epoch_time + 1;
        continue;
    end
    sk = epochSlice(key);
    if ~strcmp(sliceStim(sk), s)
        report.labels_stimulator_mismatch = report.labels_stimulator_mismatch + 1;
        continue;
    end
    t = times(key);
    r = find(strcmp(runKeys, sk), 1);
    if isempty(r); runKeys{end+1} = sk; runRows{end+1} = {}; r = numel(runKeys); end %#ok<AGROW>
    runRows{r}{end+1} = struct('t0', t(1), 't1', t(2), 'label', labelVal{j}, ...
        'key', key, 'id', labelIds{j}, 'folder', tlsFolder(matFiles, key));
end
report.runs_examined = numel(runKeys);

TOL_DAYS = 1e-3 / 86400;   % 1 ms, against datenum round-off; gaps are minutes
for r = 1:numel(runKeys)
    sk = runKeys{r};
    rows = [runRows{r}{:}];
    [~, o] = sort([rows.t0]); rows = rows(o);
    isB = strcmp({rows.label}, 'before');
    nb = sum(isB);
    if nb == 0 || nb == numel(rows) || ~all(isB(1:nb)) || any(isB(nb+1:end))
        report.runs_refused_not_a_clean_switch = report.runs_refused_not_a_clean_switch + 1;
        continue;
    end
    lb = rows(nb); fa = rows(nb+1);
    if ~isKey(epochDocOfKey, lb.key)
        report.runs_refused_no_epoch_document = report.runs_refused_no_epoch_document + 1;
        continue;
    end
    s = sliceStim(sk);
    sid = elSession(s);
    ds = dsOr(subjDs(elSubj(s)));
    startS = (lb.t1 - lb.t0) * 86400;
    durS = (fa.t0 - lb.t1) * 86400;
    if ~(durS > 0)
        report.runs_refused_no_gap = report.runs_refused_no_gap + 1;
        continue;
    end

    ref = struct();
    ref.document_class = struct('class_name', 'relative_reference', ...
        'class_version', '2.0.0', 'superclasses', struct('class_name', ...
        'time_reference', 'class_version', '4.0.0'), 'schema_version', 'V_eta');
    ref.depends_on = struct('name', 'relative_to', 'value', epochDocOfKey(lb.key));
    ref.base = struct('id', did.ido.unique_id(), 'session_id', sid, ...
        'name', 'migrated_tetanus_window', 'creation_timestamp', ds);
    ref = ndi.migrate.internal.withSessionId(ref, sid);
    ref.relative_reference = struct('value', struct( ...
        'clock', struct('node', '', 'name', 'exp_global_time'), ...
        'start', struct('seconds', startS), ...
        'duration', struct('seconds', durS)));

    m = struct();
    m.document_class = classBlock('term_manipulation', {'subject_manipulation'});
    m.depends_on = [struct('name', 'subject_id', 'value', sliceId(sk)), ...
        struct('name', 'instrument_id', 'value', s), ...
        struct('name', 'time_reference_1', 'value', ref.base.id)];
    m.base = struct('id', did.ido.unique_id(), 'session_id', sid, ...
        'name', 'migrated_tetanus_manipulation', 'creation_timestamp', ds);
    m = ndi.migrate.internal.withSessionId(m, sid);
    m.subject_statement = struct('variable', ACT, 'storage_mode', 'inline');
    ak = sliceAnimalKey(sk);
    if isempty(ak) && isKey(treatRegion, elSubj(s)) && ~isempty(treatRegion(elSubj(s)))
        m.subject_statement.conditions = struct('variable', SITE_VAR, ...
            'term', struct('value', struct('node', treatRegion(elSubj(s)), 'name', '')));
        report.tetanus_with_target_region = report.tetanus_with_target_region + 1;
    else
        report.tetanus_without_target_region = report.tetanus_without_target_region + 1;
    end
    m.subject_interaction = struct('method', ACT, 'sample_time', struct('kind', 'point'));
    [params, pstate] = folderParameters(rows(nb+1:end));
    if ~isempty(params)
        m.subject_interaction.method_parameters = params;
        report.tetanus_with_parameters = report.tetanus_with_parameters + 1;
    else
        report.tetanus_without_parameters = report.tetanus_without_parameters + 1;
        if strcmp(pstate, 'mixed')
            report.tetanus_parameter_folders_disagree = ...
                report.tetanus_parameter_folders_disagree + 1;
        end
    end
    m.subject_manipulation = struct('notes', '');
    m.term = struct('value', ACT);

    % ---- the labels, rebuilt from what is EMITTED ------------------------
    % Read back from the bodies just built, not from lb/fa: the window start
    % is the referent epoch's t0 plus `start`, its end that plus `duration`.
    ws = lb.t0 + ref.relative_reference.value.start.seconds / 86400;
    we = ws + ref.relative_reference.value.duration.seconds / 86400;
    allOk = true;
    for q = 1:numel(rows)
        if rows(q).t1 <= ws + TOL_DAYS
            p = 'before';
        elseif rows(q).t0 >= we - TOL_DAYS
            p = 'after';
        else
            p = '';
        end
        if strcmp(p, rows(q).label)
            report.labels_rebuilt = report.labels_rebuilt + 1;
        else
            report.labels_not_rebuilt = report.labels_not_rebuilt + 1;
            allOk = false;
        end
    end

    plan.minted = [plan.minted, {ref, m}];
    report.tetanus_manipulations = report.tetanus_manipulations + 1;
    if ~isempty(ak)
        report.tetanus_on_new_animal = report.tetanus_on_new_animal + 1;
    end
    if allOk
        for q = 1:numel(rows)
            if isKey(posOf, rows(q).id) && strcmp(classOf{posOf(rows(q).id)}, 'openminds_stimulus')
                plan.removed{end+1} = rows(q).id; %#ok<AGROW>
                report.approach_labels_removed = report.approach_labels_removed + 1;
            end
        end
    end
end

% ======================= supersede the per-animal treatment ============
animalsWithRun = {};
for i = 1:numel(plan.minted)
    b = plan.minted{i};
    if strcmp(baseField(b, 'name'), 'migrated_tetanus_manipulation')
        sk = sliceKeyById(depValue(b, 'subject_id'));
        if isempty(sliceAnimalKey(sk))
            animalsWithRun{end+1} = elSubj(sliceStim(sk)); %#ok<AGROW>
        end
    end
end
animalsWithRun = unique(animalsWithRun);
partsOf = containers.Map();          % part-subject id -> animal id
for k = 1:n
    if strcmp(classOf{k}, 'directed_relation') && strcmp(relationName(structs{k}), 'part_of')
        ch = depValue(structs{k}, 'child');
        if isKey(posOf, ch) && startsWith(baseField(structs{posOf(ch)}, 'name'), 'migrated_part_')
            partsOf(ch) = depValue(structs{k}, 'parent');
        end
    end
end
dropAnchors = {}; dropParts = {};
for k = 1:n
    if ~strcmp(classOf{k}, 'term_manipulation'); continue; end
    s = structs{k};
    if ~(strcmp(termNode(s, 'variable'), SITE_VAR_NODE) || strcmp(termNode(s, 'term'), SITE_VAR_NODE))
        continue;
    end
    report.treatment_manipulations_found = report.treatment_manipulations_found + 1;
    subj = depValue(s, 'subject_id');
    animal = subj;
    if isKey(partsOf, subj); animal = partsOf(subj); end
    if ~any(strcmp(animalsWithRun, animal))
        report.treatment_manipulations_kept_no_run = report.treatment_manipulations_kept_no_run + 1;
        continue;
    end
    plan.removed{end+1} = idOf{k}; %#ok<AGROW>
    report.treatment_manipulations_superseded = report.treatment_manipulations_superseded + 1;
    a = depValue(s, 'time_reference_1');
    if ~isempty(a); dropAnchors{end+1} = a; end %#ok<AGROW>
    if isKey(partsOf, subj); dropParts{end+1} = subj; end %#ok<AGROW>
    % an un-promoted site observation sharing the anchor goes with it
    for q = 1:n
        if strcmp(classOf{q}, 'term_observation') && ~isempty(a) ...
                && strcmp(depValue(structs{q}, 'time_reference_1'), a) ...
                && strcmp(depValue(structs{q}, 'subject_id'), animal) ...
                && strcmp(variableName(structs{q}), 'anatomical location')
            plan.removed{end+1} = idOf{q}; %#ok<AGROW>
            report.treatment_site_observations_superseded = ...
                report.treatment_site_observations_superseded + 1;
        end
    end
end
dropParts = unique(dropParts);
for i = 1:numel(dropParts)
    p = dropParts{i};
    plan.removed{end+1} = p; %#ok<AGROW>
    for k = 1:n
        c = classOf{k};
        if (strcmp(c, 'term_assertion') && strcmp(depValue(structs{k}, 'subject_id'), p)) ...
                || (strcmp(c, 'directed_relation') && strcmp(depValue(structs{k}, 'child'), p))
            plan.removed{end+1} = idOf{k}; %#ok<AGROW>
        end
    end
    report.treatment_part_subjects_superseded = report.treatment_part_subjects_superseded + 1;
end

% ======================= nothing removed may still be referenced =======
plan.removed = unique(plan.removed);
replacedPos = unique(replacedPos);
removedSet = setOf(plan.removed);
referenced = containers.Map();
for k = 1:n
    if isKey(removedSet, idOf{k}); continue; end
    vals = allDepValues(structs{k});
    for v = 1:numel(vals); referenced(vals{v}) = true; end
end
for i = 1:numel(plan.minted)
    vals = allDepValues(plan.minted{i});
    for v = 1:numel(vals); referenced(vals{v}) = true; end
end
dropAnchors = unique(dropAnchors);
for i = 1:numel(dropAnchors)
    if ~isKey(referenced, dropAnchors{i})
        plan.removed{end+1} = dropAnchors{i}; %#ok<AGROW>
        report.treatment_anchors_removed = report.treatment_anchors_removed + 1;
    end
end
keep = true(1, numel(plan.removed));
for i = 1:numel(plan.removed)
    if isKey(referenced, plan.removed{i})
        keep(i) = false;
        report.removals_withheld_still_referenced = ...
            report.removals_withheld_still_referenced + 1;
    end
end
plan.removed = plan.removed(keep);
report.documents_removed = numel(plan.removed);
removedSet = setOf(plan.removed);
replacedPos = replacedPos(~cellfun(@(x) isKey(removedSet, x), idOf(replacedPos)));
plan.replaced = structs(replacedPos);
report.documents_reattributed = numel(replacedPos);
report.documents_minted = numel(plan.minted);
report.changed = ~isempty(plan.minted) || ~isempty(plan.removed) || ~isempty(plan.replaced);

end

function ak = animalKeyOfEpoch(s, key, ctx)
%ANIMALKEYOFEPOCH '' for the stimulator's own animal; '<animal>|<yymmdd>'
%   when the epoch's files sit in a date folder nested inside another.
ak = '';
if ~isKey(ctx.matFiles, key); return; end
fs = ctx.matFiles(key);
for f = 1:numel(fs)
    d = regexp(fs{f}, '/([A-Z][a-z]{2}) (\d{1,2}) (\d{4})(?=[ a-zA-Z]*/)', 'tokens');
    if numel(d) < 2; continue; end
    outer = yymmdd(d{1}); inner = yymmdd(d{end});
    if strcmp(outer, inner); continue; end
    animal = ctx.elSubj(s);
    [base, dom] = lidBase(ctx.subjLid(animal));
    if numel(strfind(base, outer)) ~= 1
        ctx.cnt('nested_dates_not_in_animal_id') = ctx.cnt('nested_dates_not_in_animal_id') + 1;
        return;
    end
    ak = [animal '|' inner];
    if ~isKey(ctx.newAnimalLid, ak)
        ctx.newAnimalLid(ak) = [strrep(base, outer, inner) dom];
        ctx.newAnimalOf(ak) = animal;
    end
    ctx.cnt('epochs_on_a_nested_date') = ctx.cnt('epochs_on_a_nested_date') + 1;
    return;
end
end

function ek = epochOfStatement(s, relTo, epochKeyOfDoc)
ek = '';
a = depValue(s, 'time_reference_1');
if isempty(a) || ~isKey(relTo, a); return; end
e = relTo(a);
if isKey(epochKeyOfDoc, e); ek = epochKeyOfDoc(e); end
end

function f = tlsFolder(matFiles, key)
%TLSFOLDER The `TLS...` folder an epoch's .mat file sits in, '' if none.
f = '';
if ~isKey(matFiles, key); return; end
fs = matFiles(key);
for q = 1:numel(fs)
    t = regexp(fs{q}, '/(TLS[^/]*)/[^/]*$', 'tokens', 'once');
    if ~isempty(t); f = t{1}; return; end
end
end

function m = setOf(c)
m = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for i = 1:numel(c); m(c{i}) = true; end
end

% ===================== helpers (file scope) ============================

function r = newReport()
r = struct( ...
    'v1_documents_read', 0, 'migrated_documents_read', 0, ...
    'epoch_index_entries', 0, ...
    'stimulators', 0, 'stimulators_not_a_slice_bath', 0, ...
    'stimulators_animal_mismatch', 0, 'slice_bath_stimulators', 0, ...
    'stimulus_bath_documents', 0, 'slices', 0, 'slice_elements', 0, ...
    'epochs_on_a_nested_date', 0, 'nested_dates_not_in_animal_id', 0, ...
    'new_animals', 0, 'new_animal_strain_assertions_copied', 0, ...
    'epoch_statements_examined', 0, 'epoch_statements_matched', 0, ...
    'epoch_statements_unmatched', 0, ...
    'unanchored_statements_examined', 0, 'unanchored_statements_matched', 0, ...
    'unanchored_statements_ambiguous', 0, ...
    'element_relations_examined', 0, 'element_relations_matched', 0, ...
    'element_relations_ambiguous', 0, ...
    'reattributed_by_class', struct(), ...
    'approach_labels', 0, 'labels_not_on_a_slice_epoch', 0, ...
    'labels_without_one_epoch_time', 0, 'labels_stimulator_mismatch', 0, ...
    'runs_examined', 0, 'runs_refused_not_a_clean_switch', 0, ...
    'runs_refused_no_epoch_document', 0, 'runs_refused_no_gap', 0, ...
    'tetanus_manipulations', 0, 'tetanus_on_new_animal', 0, ...
    'tetanus_with_target_region', 0, 'tetanus_without_target_region', 0, ...
    'tetanus_with_parameters', 0, 'tetanus_without_parameters', 0, ...
    'tetanus_parameter_folders_disagree', 0, ...
    'labels_rebuilt', 0, 'labels_not_rebuilt', 0, 'approach_labels_removed', 0, ...
    'treatment_target_locations', 0, 'treatment_animals_conflicting', 0, ...
    'treatment_manipulations_found', 0, 'treatment_manipulations_superseded', 0, ...
    'treatment_manipulations_kept_no_run', 0, ...
    'treatment_site_observations_superseded', 0, ...
    'treatment_part_subjects_superseded', 0, 'treatment_anchors_removed', 0, ...
    'removals_withheld_still_referenced', 0, ...
    'documents_minted', 0, 'documents_reattributed', 0, 'documents_removed', 0, ...
    'changed', false);
end

function r = bumpClass(r, field, c)
f = matlab.lang.makeValidName(c);
if isfield(r.(field), f); r.(field).(f) = r.(field).(f) + 1;
else; r.(field).(f) = 1; end
end

function [params, state] = folderParameters(afterRows)
%FOLDERPARAMETERS `TLS <f> Hz <d> s` -> method parameters, only when every
%   "after" epoch of the run sits in one such folder. Plain `TLS` -> none.
params = []; state = 'none';
names = {};
for q = 1:numel(afterRows)
    names{end+1} = afterRows(q).folder; %#ok<AGROW>
end
names = unique(names);
if numel(names) ~= 1 || isempty(names{1}); if numel(names) > 1; state = 'mixed'; end; return; end
tok = regexp(names{1}, '^TLS\s+(\d+(?:\.\d+)?)\s*Hz\s+(\d+(?:\.\d+)?)\s*s$', 'tokens', 'once');
if isempty(tok); return; end
state = 'stated';
params = [ ...
    struct('variable', struct('node', '', 'name', 'frequency'), ...
        'unit', struct('node', '', 'name', 'hertz'), 'source_unit', 'Hz', ...
        'quantity', struct('value', str2double(tok{1}), 'source_value', tok{1})), ...
    struct('variable', struct('node', '', 'name', 'duration'), ...
        'unit', struct('node', 'om:second-Time', 'name', 'second'), 'source_unit', 's', ...
        'quantity', struct('value', str2double(tok{2}), 'source_value', tok{2}))];
end

function [t, ok] = clockTimes(et, clockName)
t = [NaN NaN]; ok = false;
if ~isstruct(et) || ~isfield(et, 'epochclock') || ~isfield(et, 't0_t1'); return; end
clocks = cellstrOf(et.epochclock);
i = find(strcmp(clocks, clockName), 1);
if isempty(i); return; end
m = et.t0_t1;
if iscell(m)
    try m = cell2mat(cellfun(@(x) double(x(:))', m(:), 'UniformOutput', false)); catch; return; end
end
m = double(m);
if numel(clocks) == 1 && numel(m) == 2
    t = [m(1) m(2)];
elseif size(m, 1) == 2 && size(m, 2) == numel(clocks)
    t = [m(1, i) m(2, i)];
else
    return;
end
ok = all(isfinite(t));
end

function c = cellstrOf(x)
if ischar(x); c = {x};
elseif isstring(x); c = cellstr(x);
elseif iscell(x); c = cellfun(@char, x(:)', 'UniformOutput', false);
else; c = {};
end
end

function s = yymmdd(tok)
mon = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
m = find(strcmp(mon, tok{1}), 1);
s = sprintf('%02d%02d%02d', mod(str2double(tok{3}), 100), m, str2double(tok{2}));
end

function [base, dom] = lidBase(lid)
at = strfind(lid, '@');
if isempty(at); base = lid; dom = '';
else; base = lid(1:at(1)-1); dom = lid(at(1):end); end
end

function v = dsOr(v)
if isempty(v); v = '2024-01-01T00:00:00.000Z'; end
end

function c = className(s)
c = '';
if isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isfield(s.document_class, 'class_name')
    c = char(s.document_class.class_name);
end
end

function b = blockOf(s, name)
b = struct();
if isstruct(s) && isfield(s, name) && isstruct(s.(name)); b = s.(name); end
end

function v = charField(s, name)
v = '';
if isstruct(s) && isfield(s, name) && (ischar(s.(name)) || isstring(s.(name)))
    v = char(s.(name));
end
end

function v = baseField(s, name)
v = charField(blockOf(s, 'base'), name);
end

function v = depValue(s, name)
v = '';
d = depList(s);
for k = 1:numel(d)
    if isfield(d{k}, 'name') && strcmp(char(d{k}.name), name)
        v = oneValue(d{k});
        return;
    end
end
end

function d = depList(s)
%DEPLIST depends_on as a cell of scalar structs, whatever shape jsondecode or
%   toStruct gave it (a struct array, a scalar, or a cell of unlike structs).
d = {};
if ~isstruct(s) || ~isfield(s, 'depends_on') || isempty(s.depends_on); return; end
x = s.depends_on;
if iscell(x); d = x(:)';
elseif isstruct(x); d = num2cell(x(:)');
end
end

function v = oneValue(e)
v = '';
if isfield(e, 'value') && (ischar(e.value) || isstring(e.value)) && ~isempty(e.value)
    v = char(e.value);
elseif isfield(e, 'document_id') && (ischar(e.document_id) || isstring(e.document_id))
    v = char(e.document_id);
end
end

function vals = allDepValues(s)
vals = {};
d = depList(s);
for k = 1:numel(d)
    v = oneValue(d{k});
    if ~isempty(v); vals{end+1} = v; end %#ok<AGROW>
end
end

function s = setDep(s, name, value)
d = s.depends_on;
if iscell(d); d = [d{:}]; end
for k = 1:numel(d)
    if isfield(d(k), 'name') && strcmp(char(d(k).name), name)
        if isfield(d(k), 'value'); d(k).value = value;
        else; d(k).document_id = value; end
        s.depends_on = d;
        return;
    end
end
if isfield(d, 'document_id') && ~isfield(d, 'value')
    d(end+1) = struct('name', name, 'document_id', value);
else
    d(end+1) = struct('name', name, 'value', value);
end
s.depends_on = d;
end

function nm = relationName(s)
nm = '';
r = blockOf(blockOf(s, 'directed_relation'), 'relation');
nm = charField(r, 'name');
end

function nm = variableName(s)
nm = charField(blockOf(blockOf(s, 'subject_statement'), 'variable'), 'name');
end

function node = termNode(s, which)
if strcmp(which, 'variable')
    node = charField(blockOf(blockOf(s, 'subject_statement'), 'variable'), 'node');
else
    node = charField(blockOf(blockOf(s, 'term'), 'value'), 'node');
end
end

function dc = classBlock(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
dc = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'V_eta');
end
