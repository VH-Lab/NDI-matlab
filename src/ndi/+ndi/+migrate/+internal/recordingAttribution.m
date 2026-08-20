function [plan, report] = recordingAttribution(structs)
%RECORDINGATTRIBUTION Re-attribute a raw recording to the SPECIMEN it came from.
%
%   [PLAN, REPORT] = RECORDINGATTRIBUTION(STRUCTS) finds migrated
%   `<modality>_observation` documents that name a PROBE as their subject and no
%   instrument at all, and plans the signed attribution for each: `subject_id`
%   becomes the specimen, and the probe moves to `instrument_id` (T7).
%
%   ---------------------------------------------------------------------
%   THE GAP, AS A MEASUREMENT
%   ---------------------------------------------------------------------
%   TEAM-SIGN-OFF [raw recording observation], 2026-08-10: "a raw continuous
%   recording IS a typed `<modality>_observation` of the SPECIMEN: `subject_id`
%   = the specimen, `instrument_id` = the electrode/probe in the instrument role
%   (T7)".
%
%   That model is BUILT -- in `migrators_j/element.m`, via jRecordingObservation
%   -- and it is not built in `migrators_j/pyraview.m`, which emits a SECOND
%   observation of the same physical signal keyed the other way. PRED shows both
%   at once, and the difference is the instrument edge:
%
%       element    subject_id = the SPECIMEN, instrument_id = the electrode
%       pyraview   subject_id = element_id (the probe-as-subject), NO instrument
%
%   So "all voltage recorded from mouse #7" answers over element's document and
%   silently misses pyraview's, though they describe one recording.
%
%   ---------------------------------------------------------------------
%   WHY THIS CANNOT BE A MIGRATOR FIX, WHICH IS THE WHOLE REASON IT IS HERE
%   ---------------------------------------------------------------------
%   The specimen is NOT IN THE PYRAVIEW DOCUMENT. On NDI origin/main the v1
%   template declares exactly one dependency:
%
%       database_documents/data/pyraview.json    depends_on: ['element_id']
%
%   pyraview.m reads `firstNonEmpty(element_id, subject_id)`, and that second
%   branch is DEAD CODE for any real document -- there is no `subject_id` to
%   fall back to. The animal is two hops away and the second hop lives on
%   another document entirely:
%
%       pyraview.element_id -> element
%       element.subject_id  -> the specimen        (element.json, origin/main)
%
%   A single-document migrator cannot see the element document, so what pyraview
%   emits is the only thing it COULD emit. This is the same shape as
%   `distance_metadata` and `ontology_table_row`, and it is resolved the same
%   way: in the pass that can see the whole migrated graph.
%
%   ---------------------------------------------------------------------
%   THE DONOR MAP -- WHY THE ELEMENT DOCUMENT IS NEVER READ
%   ---------------------------------------------------------------------
%   The obvious implementation walks `pyraview -> element -> subject` over the
%   v1 bodies. This does not, and the reason is that the answer is ALREADY IN
%   THE MIGRATED SET: element's own observation states `(instrument = probe,
%   subject = specimen)` as a fact about the very same probe. So the map is
%   built from documents that already carry an instrument edge and applied to
%   documents that carry none.
%
%   That choice has a property worth the paragraph: it CANNOT invent an
%   attribution the signed emitter did not already make. If element.m never ran,
%   never resolved, or was itself unsure, there is no donor and this pass
%   refuses -- rather than re-deriving a specimen link from v1 and quietly
%   disagreeing with the emitter that owns the model. Two implementations of
%   "whose recording is this" that disagree is worse than one that is missing.
%
%   A probe mapping to TWO different specimens is AMBIGUOUS and is refused, not
%   resolved by picking one. It should be impossible (a probe records one
%   specimen) and if it ever happens the honest output is a refusal with a
%   count.
%
%   ---------------------------------------------------------------------
%   WHAT THIS DOES NOT DO
%   ---------------------------------------------------------------------
%   It does not FOLD the two observations together. After this pass PRED still
%   holds two `voltage_observation` documents; they now agree about the subject
%   and the instrument, and differ only in the data bodies hanging off them
%   (element's raw trace, pyraview's resolution pyramid). Whether the pyramid
%   should hang off element's observation instead of minting its own is a
%   MODELLING question the signature does not answer, and it is left open
%   deliberately -- see the caller's report and DID-schema `V_eta_OPEN_WORK.md`.
%   Making the two agree is what turns that question from an archaeology
%   exercise into a visible duplicate.
%
%   `variable` is carried from the donor ONLY when the candidate's own is
%   unresolved (empty node). pyraview sets `variable` to the signal LABEL with
%   an empty node; element sets it from the modality map. Overwriting a
%   populated term would be this pass deciding a vocabulary question it has no
%   standing to decide.
%
%   STATUS: WRITTEN 2026-08-13 IN A CONTAINER WITH NO MATLAB. NOT EXECUTED HERE.
%
%   See also NDI.MIGRATE.INTERNAL.EPOCHANCHORFOLD,
%   NDI.MIGRATE.INTERNAL.ONTOLOGYLABELSUBJECTS

arguments
    structs cell
end

plan = struct('source_id', {}, 'body', {}, 'specimen_id', {}, ...
              'instrument_id', {});

% RULE 5: every counter initialised BEFORE any early return, so a pass that
% refuses everything reports the same shape as one that resolves everything. A
% field that appears only on the success path is a counter that cannot report a
% zero -- and a zero is exactly what a reader needs to distinguish "nothing to
% do" from "this did not run".
report = struct( ...
    'documents_inspected',      numel(structs), ...
    'observations',             0, ...
    'donors',                   0, ...   % carry an instrument edge
    'candidates',               0, ...   % carry none
    'attributed',               0, ...
    'variable_carried',         0, ...
    'refused_no_donor',         0, ...
    'refused_no_subject',       0, ...
    'refused_self_reference',   0, ...
    'refused_ambiguous_probe',  0, ...
    'ambiguous_probes',         {{}}, ...
    'changed',                  false);

if isempty(structs)
    return;
end

% ---- pass 1: partition the observations, and build the donor map ------------
donorSpecimen = containers.Map('KeyType', 'char', 'ValueType', 'char');
donorVariable = containers.Map('KeyType', 'char', 'ValueType', 'any');
ambiguous     = containers.Map('KeyType', 'char', 'ValueType', 'logical');
candidates    = {};

for k = 1:numel(structs)
    body = structs{k};
    if ~isObservation(body)
        continue;
    end
    report.observations = report.observations + 1;
    instrumentId = depValue(body, 'instrument_id');
    subjectId    = depValue(body, 'subject_id');
    if ~isempty(instrumentId)
        report.donors = report.donors + 1;
        if isempty(subjectId)
            continue;   % a donor with no specimen states nothing; ignore it
        end
        if isKey(donorSpecimen, instrumentId) ...
                && ~strcmp(donorSpecimen(instrumentId), subjectId)
            % TWO specimens for one probe. Refuse the probe entirely rather
            % than letting declaration order pick a winner.
            ambiguous(instrumentId) = true;
        else
            donorSpecimen(instrumentId) = subjectId;
            donorVariable(instrumentId) = getVariable(body);
        end
        continue;
    end
    report.candidates = report.candidates + 1;
    candidates{end+1} = body; %#ok<AGROW>
end

report.ambiguous_probes = sort(keys(ambiguous));

% ---- pass 2: plan an attribution per candidate ------------------------------
for k = 1:numel(candidates)
    body     = candidates{k};
    probeId  = depValue(body, 'subject_id');
    if isempty(probeId)
        report.refused_no_subject = report.refused_no_subject + 1;
        continue;
    end
    if isKey(ambiguous, probeId)
        report.refused_ambiguous_probe = report.refused_ambiguous_probe + 1;
        continue;
    end
    if ~isKey(donorSpecimen, probeId)
        % The common, correct refusal: this observation's subject is not a probe
        % any signed emitter has attributed. Leaving it alone is right.
        report.refused_no_donor = report.refused_no_donor + 1;
        continue;
    end
    specimenId = donorSpecimen(probeId);
    if strcmp(specimenId, probeId)
        report.refused_self_reference = report.refused_self_reference + 1;
        continue;
    end

    out = body;
    out = setDep(out, 'subject_id',    specimenId);
    out = setDep(out, 'instrument_id', probeId);
    if isUnresolvedVariable(out)
        donorVar = donorVariable(probeId);
        if ~isempty(donorVar) && ~isempty(nodeOf(donorVar))
            out.subject_statement.variable = donorVar;
            report.variable_carried = report.variable_carried + 1;
        end
    end
    % Tag so did2.convert.v1_to_v2 SHORT-CIRCUITS (isAlreadyTarget) to
    % ensureClassBlocks + validate instead of trying to migrate an already
    % migrated body -- the footing ontologyLabelSubjects and pathSPromotion use.
    out.document_class.schema_version = 'V_eta';

    plan(end+1) = struct( ...
        'source_id',     baseField(body, 'id'), ...
        'body',          out, ...
        'specimen_id',   specimenId, ...
        'instrument_id', probeId); %#ok<AGROW>
    report.attributed = report.attributed + 1;
end

report.changed = ~isempty(plan);
end

% ===================== helpers =========================================

function tf = isObservation(body)
%ISOBSERVATION A migrated observation document, by class name.
%   The `_observation` suffix is the whole test, and it is deliberately broad:
%   the donor map is keyed by instrument id and a candidate only matches when
%   its subject IS a probe some donor named, so a `count_observation` or an
%   `image_observation` that happens through here simply finds no donor. A
%   narrower whitelist of modality classes would go stale the first time a
%   modality is added and would fail SILENTLY, which is the worse direction.
tf = false;
name = className(body);
if isempty(name)
    return;
end
tf = numel(name) > 12 && strcmp(name(end-11:end), '_observation');
end

function name = className(body)
name = '';
if isfield(body, 'document_class') && isstruct(body.document_class) ...
        && isfield(body.document_class, 'class_name')
    name = char(body.document_class.class_name);
end
end

function value = depValue(body, name)
value = '';
if ~isfield(body, 'depends_on') || ~isstruct(body.depends_on)
    return;
end
for k = 1:numel(body.depends_on)
    d = body.depends_on(k);
    if isfield(d, 'name') && strcmp(char(d.name), name) && isfield(d, 'value')
        value = char(d.value);
        return;
    end
end
end

function body = setDep(body, name, value)
%SETDEP Set a dependency, replacing it in place or appending it.
entry = struct('name', name, 'value', value);
if ~isfield(body, 'depends_on') || ~isstruct(body.depends_on) ...
        || isempty(body.depends_on)
    body.depends_on = entry;
    return;
end
for k = 1:numel(body.depends_on)
    if isfield(body.depends_on(k), 'name') ...
            && strcmp(char(body.depends_on(k).name), name)
        body.depends_on(k).value = value;
        return;
    end
end
body.depends_on(end+1) = entry;
end

function v = getVariable(body)
v = [];
if isfield(body, 'subject_statement') && isstruct(body.subject_statement) ...
        && isfield(body.subject_statement, 'variable')
    v = body.subject_statement.variable;
end
end

function node = nodeOf(v)
node = '';
if isstruct(v) && isfield(v, 'node')
    node = char(v.node);
end
end

function tf = isUnresolvedVariable(body)
%ISUNRESOLVEDVARIABLE An empty ontology node -- a label, not a term.
tf = isempty(nodeOf(getVariable(body)));
end

function value = baseField(body, name)
value = '';
if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, name)
    value = char(body.base.(name));
end
end
