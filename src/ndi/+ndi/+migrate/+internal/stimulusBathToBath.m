function [bathBody, timeRefBody, extraBodies, anchorInfo] = stimulusBathToBath(v1Body, resolver, targetVersion)
%STIMULUSBATHTOBATH Assemble a `bath` (+ epoch time reference) from a legacy
%   stimulus_bath, using session/element context.
%
%   ---------------------------------------------------------------------
%   ON did-schema #88 (the V_eta target since 2026-10-21) -- READ THIS FIRST
%   ---------------------------------------------------------------------
%   The V_eta branch emits #88's shape, mirroring DID-matlab's
%   did2.convert.resolveDeferredBaths/makeBathVEta (the DID-side assembler of
%   the same class on #88):
%
%     bathBody     a `manipulation` with the `formulation` value kind, its
%                  value the formulation document below through a `value_id`
%                  edge and its own `value` empty -- NOT a dose: "A bath is a
%                  manipulation whose value is the formulation (pointed at
%                  through `value_id`), not a dose; a dose always has an
%                  amount" (Jess Haley, 2026-10-21). Source id PRESERVED, about
%                  the stimulator element's subject (`entity_id`), the
%                  stimulator as `instrument_id` (T7).
%     timeRefBody  a `relative_time_reference` (#88: the placeholder class
%                  `epoch_bounded_reference` is GONE, so it cannot be emitted
%                  even transiently -- it would quarantine on validation) that
%                  says "during the session": `referent_id` is the session id,
%                  which IS the session entity's base.id on #88
%                  (V_eta_relation_inheritance_plan.md item 4). The epoch is
%                  not lost: ANCHORINFO carries the stimulator's epoch string
%                  and clock, and ndi.migrate.internal.epochAnchorFold
%                  re-points the anchor at the epoch entity did2.convert.
%                  epochMint mints (id PRESERVED), which is the two-phase shape
%                  the placeholder used to give. If the fold cannot resolve the
%                  epoch, the bath stays anchored to its session -- valid, and
%                  exactly what the DID-side assembler writes.
%     extraBodies  one `chemical` per mixture row and the `formulation` naming
%                  them (`ingredient_id`, ordered; each ingredient entry holds
%                  the row's amount as a concentration with its source unit as
%                  a term). A pH or osmolarity row is a property of the whole
%                  mixture and lands on the formulation's `ph` / `osmolarity`,
%                  as DID-side does.
%     anchorInfo   struct {anchor_id, session_id, epoch_string, epoch_clock}
%                  for epochAnchorFold; [] when no anchor was minted.
%
%   The mixture table is read with DID-side's parser (quoted names that hold
%   commas; the header row is not a chemical) -- the pre-#88 reader split on
%   every comma and read the header as a chemical named "ontologyName".
%   The bath's LOCATION (Jess Haley, 2026-10-21, replacing D3's located-by-
%   default): "Any statement about an anatomical region of a subject targets
%   that region's part entity ... A statement about the whole subject (a
%   whole-prep or whole-slice bath, i.e. the generic 'bath' location
%   NCIm:C0179246) targets the subject." So a bath at an ANATOMICAL location
%   (a Marder compartment: 'upper' UBERON:8910017-22, 'lower' UBERON:8910010)
%   gets an `anatomical location` term observation CO-ANCHORED with the bath
%   (it shares the bath's time reference), which
%   ndi.migrate.internal.pathSPromotion turns into the compartment's part
%   entity and moves the bath onto; a GENERIC bath location (node
%   NCIm:C0179246, or a name 'bath') gets none, so the bath stays on the
%   subject -- every Dabrowska bath, and Marder's 'bath', which is what
%   sliceTetanus matches. The test is the one did2.convert.migrators_j's
%   jTreatmentRoute uses. A bath with NO anchor (no epoch, or a no_time clock)
%   has nothing to co-anchor on and gets no site observation: it stays on the
%   subject (a gap, not a decision).
%
%   ---------------------------------------------------------------------
%   STATUS: the V_eta changes below (the time-anchor guard, the `instrument_id`
%   edge and the two-phase note) were WRITTEN 2026-08-11 IN A CONTAINER WITH NO
%   MATLAB. THEY HAVE NOT BEEN EXECUTED. test-eta-migrate.yml is the first
%   thing that will have an opinion about them.
%   ---------------------------------------------------------------------
%
%   The per-document converter (did2.convert.migrators_i.stimulus_bath /
%   migrators_e.stimulus_bath) defers stimulus_bath with
%   did2:convert:needsSessionContext, because a `bath`
%   (pharmacological_manipulation) must be emitted complete and two of its
%   required parts can only be obtained by following the stimulator element:
%
%     - subject_id      : the stimulator element's subject, and
%     - time_reference  : an epoch_bounded_reference on the stimulator's epoch.
%
%   THE TIME REFERENCE IS A PASS-1 PLACEHOLDER UNDER V_eta, NOT THE FINAL MODEL.
%   ---------------------------------------------------------------------
%   The signed time-reference decision (DID-schema
%   schemas/V_eta_time_reference_model_plan.md, TEAM-SIGN-OFF [time_reference],
%   2026-08-08) collapses eight reference classes to TWO --
%   `absolute_reference` + `relative_reference` -- and its migration table
%   (line 195) retires `epoch_bounded_reference` into `relative_reference`.
%
%   This function STILL mints an `epoch_bounded_reference`, deliberately, for
%   the reason the plan itself gives:
%
%       "A pass-1 migrator knows the epoch STRING ... but not the
%        `acquisition_epoch` DOCUMENT id, so it cannot populate `relative_to`.
%        ... the string is the pass-1 handle; the edge is the pass-2
%        resolution."
%
%   `relative_reference.relative_to` is REQUIRED and the RequiredDependencies
%   strict check is ARMED, so emitting a `relative_reference` here -- where no
%   `epoch` document exists yet, because did2.convert.epochMint is step (5) of
%   the second pass and this assembler is step (1) -- would emit a blank
%   required edge and QUARANTINE the document. The placeholder carries the
%   epoch STRING and `ndi.migrate.internal.epochAnchorFold` upgrades it to a
%   `relative_reference` anchored to the minted `epoch`, base.id PRESERVED.
%   This is the same two-phase shape jSessionAnchor + resolveSessionAnchors
%   use one referent over. UNTIL THAT FOLD WAS WRITTEN, NOTHING ANYWHERE
%   CONSUMED THIS CLASS -- it was minted, fully populated, and carried straight
%   into migrated output. (Written, not yet run: see STATUS above.)
%
%   THE FOLD IS NOT UNCONDITIONAL, SO THE RETIREMENT IS NOT UNCONDITIONAL.
%   ---------------------------------------------------------------------
%   Recorded here so the next person does not re-derive it. What this function
%   mints CAN reach a database as the retired class, and the path is short:
%
%       epochMint refuses to mint an `epoch` for a session id with no `session`
%       DOCUMENT in the batch (DID-matlab +did2/+convert/epochMint.m:349-353,
%       counted as `skipped_no_session_document`)
%         -> epochAnchorFold cannot resolve the (session, epoch-string) pair,
%            refuses (`refused_no_epoch_document`) and LEAVES THE BODY ALONE
%         -> ndi.migrate.local writes it to <target>.sqlite with every other
%            migrated document (local.m, `db.add(convertResult.migrated, ...)`).
%
%   That refusal is CORRECT -- DISCOVERY MODE: a subset batch need not carry the
%   `session` document, absence is not evidence, and a guessed `relative_to`
%   would be a blank required edge and therefore a quarantine. Production is the
%   resolving case: `ndi.session.dir` creates and PERSISTS a `session` document
%   on first open, so a real session directory has one.
%
%   BOTH BRANCHES ARE PINNED FROM THIS EMITTER, THROUGH THE REAL PIPELINE, in
%   tests/+ndi/+unittest/+migrate/TestMigrateLocalEta.m --
%   `testEpochAnchorFoldsToRelativeReferenceWithItsIdPreserved` (folds; base.id
%   preserved; 0 orphans) and
%   `testWithoutASessionDocumentTheRetiredAnchorReachesTheDatabase` (refuses;
%   the retired class is in the database and its id still resolves). Those are
%   the tests to read before changing anything in the `if mintReference` block
%   below: TestEpochAnchorFold's 27 methods all run on a HAND-BUILT
%   transcription of that block and cannot see it move.
%
%   The stimulator is used ONLY as the time referent and the subject source; no
%   other connection is kept (the result is a plain `bath`, not a
%   `stimulus_bath`). This function does that session-aware assembly; it is
%   called by ndi.migrate.local on each body that v1_to_v2 deferred with reason
%   did2:convert:needsSessionContext.
%
%   Inputs:
%     v1Body        - the legacy stimulus_bath document body (struct), carrying:
%                       depends_on            : stimulus_element_id (stimulator)
%                       epochid.epochid       : the stimulator's epoch id
%                       stimulus_bath.location, stimulus_bath.mixture_table
%                       base.{id, session_id, datestamp}
%     resolver      - struct of session-aware lookups (from ndi.migrate.local):
%                       .subjectOfElement(elementId)            -> subject_id
%                       .epochClockOfElement(elementId, epochId)-> clocktype
%     targetVersion - 'V_zeta' (default, Brainstorm I) or 'V_epsilon'
%                     (Brainstorm E). Selects the wire shape: under V_zeta the
%                     bath is a `subject_interaction`, so the assembled body
%                     also carries the spine block (method / variable /
%                     target_structure) and the manipulation `notes` block, and
%                     `variable` is set to the primary mixture chemical (the
%                     queryable "what"). Under V_epsilon the older block layout
%                     (no spine block) is emitted.
%
%   Outputs:
%     bathBody     - the manipulation document body (schema_version =
%                    targetVersion): a `bath` under V_zeta/V_epsilon, or a
%                    `manipulation` valued by its `formulation` under V_eta.
%     timeRefBody  - the epoch_bounded_reference document the manipulation
%                    depends_on, or [] when V_eta declines to anchor (see
%                    NO TIMES => NO REFERENCE below). A caller must drop an
%                    empty body rather than pass it on; ndi.migrate.local's
%                    assembleDeferred does.
%
%   The bath preserves the source stimulus_bath's base.id, so inbound
%   references to the legacy document resolve to the migrated bath.
%
%   See also: ndi.migrate.local, ndi.migrate.internal.bodyResolver,
%   ndi.migrate.internal.epochAnchorFold, did2.convert.epochMint,
%   did2.convert.migrators_i.stimulus_bath.

arguments
    v1Body   (1,1) struct
    resolver (1,1) struct
    targetVersion (1,:) char = 'V_zeta'
end

stimulatorId = dependencyValue(v1Body, 'stimulus_element_id');
epochId      = epochIdOf(v1Body);
sessionId    = ndi.v2.sessionIdOf(v1Body);
datestamp    = baseField(v1Body, 'datestamp', '');
bathId       = baseField(v1Body, 'id', did.ido.unique_id());

% --- resolve the session/element context (the reason this is NDI-layer) -----
subjectId  = resolver.subjectOfElement(stimulatorId);
epochClock = resolver.epochClockOfElement(stimulatorId, epochId);

% --- time reference: epoch_bounded_reference on the stimulator's epoch ------
% Under V_eta this is the PASS-1 PLACEHOLDER described in the header; under the
% older targets it is the final shape and nothing here changes for them.
%
% NO TIMES => NO REFERENCE (V_eta only). The signed plan's rule: a reference
% that cannot name a time is a hollow document -- it validates, it is counted,
% and it says nothing, which is precisely what did2.validate.silentLoss and the
% FRAGMENT detector exist to catch. Two cases here, and both are real:
%
%   * NO EPOCH STRING. `epochid.epochid` is mustBeNonEmpty on the V_eta schema,
%     so an empty one is a QUARANTINE today; declining to mint turns a
%     quarantined document into an honest absence.
%   * epoch_clock == 'no_time'. bodyResolver.epochClockOfElement reads this
%     straight off an `element_epoch` / `epochclocktimes` document, and
%     'no_time' is NDI's way of saying the thing keeps no time at all
%     (+file/navigator.m:185 "filenavigator does not keep time"). It is an
%     epoch_clock assertion, never a timeline a time is expressed on.
%
% In both cases `time_reference_1` is simply OMITTED from the manipulation --
% it is an OPTIONAL dependency (subject_interaction declares time_reference_#
% with mustBeNonEmpty false), so the absence costs nothing and asserts nothing.
extraBodies = {};
anchorInfo  = [];

if strcmp(targetVersion, 'V_eta')
    [bathBody, timeRefBody, extraBodies, anchorInfo] = vetaBath(v1Body, ...
        stimulatorId, epochId, sessionId, datestamp, bathId, subjectId, epochClock);
    return;
end

% --- the older targets (no V_eta) -----------------------------------------
timeRefId = did.ido.unique_id();
timeRefBody = struct();
timeRefBody.document_class = struct( ...
    'class_name', 'epoch_bounded_reference', 'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
        struct('class_name', 'epochid',        'class_version', '1.0.0')], ...
    'schema_version', targetVersion);
timeRefBody.depends_on = struct('name', 'element_id', 'value', stimulatorId);
timeRefBody.base = struct('id', timeRefId, 'session_id', sessionId, ...
    'name', 'migrated_stimulator_epoch_anchor', 'creation_timestamp', datestamp);
timeRefBody.time_reference = struct('is_approximate', false);
timeRefBody.epochid = struct('epochid', epochId);
timeRefBody.epoch_bounded_reference = struct('epoch_clock', epochClock);

mixture = parseMixture(v1Body);

bathBody = struct();
bathBody.document_class = struct( ...
    'class_name', 'bath', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'pharmacological_manipulation', ...
        'class_version', '1.0.0'), ...
    'schema_version', targetVersion);
bathBody.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', timeRefId)];
bathBody.base = struct('id', bathId, 'session_id', sessionId, ...
    'name', 'migrated_bath', 'creation_timestamp', datestamp);

if strcmp(targetVersion, 'V_zeta')
    % Brainstorm I: a bath is a subject_interaction. Identity is OFF the class
    % on the spine -- the primary chemical is the `variable`; the verb (method)
    % and locus (target_structure) are left blank/empty (the bath location
    % lives in the bath block); `notes` prose on the manipulation base.
    bathBody.subject_interaction = struct( ...
        'method', struct('node', '', 'name', ''), ...
        'variable', primaryChemical(mixture), ...
        'target_structure', {struct('node', {}, 'name', {})});
    bathBody.manipulation = struct('notes', '');
end

% mixture is declared on pharmacological_manipulation -> its block.
bathBody.pharmacological_manipulation = struct();
bathBody.pharmacological_manipulation.mixture = mixture;
% location/kind are declared on bath -> the bath block.
bathBody.bath = struct('kind', 'drug', 'location', locationTerm(v1Body));
end

function [dose, anchor, extra, anchorInfo] = vetaBath(v1Body, stimulatorId, ...
        epochId, sessionId, datestamp, bathId, subjectId, epochClock)
%VETABATH The did-schema #88 bath: manipulation valued by a formulation + chemicals,
%   anchored "during the session" until epochAnchorFold re-points the anchor at
%   the stimulator's epoch (see the header).
S = ndi.migrate.internal.etaShape;
common = {'SessionId', sessionId, 'Datestamp', datestamp};

% NO TIMES => NO REFERENCE. The signed plan's rule: a reference that cannot
% name a time is a hollow document. A `no_time` clock, or no epoch string at
% all, mints none (the dose then has no time reference; `time_reference_id` is
% min_count 1 on interactions, so validation reports it rather than this
% function hiding it).
anchor = [];
anchorInfo = [];
trIds = {};
if ~isempty(epochId) && ~strcmp(epochClock, 'no_time')
    anchor = S.relativeTimeReference(sessionId, struct('relation', ...
        S.term('time:intervalDuring', 'intervalDuring')), common{:});
    trIds = {anchor.base.id};
    anchorInfo = struct('anchor_id', anchor.base.id, 'session_id', sessionId, ...
        'epoch_string', epochId, 'epoch_clock', epochClock);
end

mixture = parseMixture88(v1Body);
extra = {};
ids = {};
entries = {};
props = struct();
for i = 1:numel(mixture)
    chem = mixture(i).chemical;
    if isempty(chem.node) && isempty(chem.name)
        continue;
    end
    a = mixture(i).amount;
    if strcmpi(chem.name, 'pH') && isfinite(a.source_value)
        props.ph = struct('ph', a.source_value, 'source_value', a.source_value, ...
            'source_unit', a.source_unit, 'approximate', false);
        continue;
    end
    if any(strcmpi(chem.name, {'osm', 'osmolarity'})) && isfinite(a.source_value)
        props.osmolarity = struct('source_value', a.source_value, ...
            'source_unit', a.source_unit, 'approximate', false);
        continue;
    end
    c = struct();
    c.document_class = S.docClass('chemical');
    c.depends_on = S.noEdges();
    c.base = S.baseBlock('', datestamp);
    c.chemical = struct('value', struct('substance', chem));
    c = ndi.migrate.internal.withSessionId(c, sessionId);
    extra{end+1} = c; %#ok<AGROW>
    ids{end+1} = c.base.id; %#ok<AGROW>
    e = struct();
    if isfinite(a.source_value)
        conc = struct('source_value', a.source_value, 'approximate', false);
        if ~isempty(a.source_unit.node) || ~isempty(a.source_unit.name)
            conc.source_unit = a.source_unit;
        end
        if strcmpi(a.source_unit.name, 'Molar')
            conc.molar = a.source_value;
        end
        e.concentration = conc;
    end
    entries{end+1} = e; %#ok<AGROW>
end
fv = props;
f = struct();
f.document_class = S.docClass('formulation');
f.depends_on = S.noEdges();
for k = 1:numel(ids)
    f = S.addEdge(f, 'ingredient_id', ids{k});
end
f.base = S.baseBlock('', datestamp);
% `ingredients` is a STRUCT ARRAY, as the schema declares it and as did2.build
% writes it. Left a cell of per-row structs, the value rule
% (value_inline_or_body) reads it as blank and quarantines the formulation, so
% the bath's `value_id` names nothing (e2e run 39668356516).
fv.ingredients = rowsToStructArray(entries);
f.formulation = struct('value', fv);
f = ndi.migrate.internal.withSessionId(f, sessionId);
extra{end+1} = f;

% A bath is NOT a dose: "A bath is a manipulation whose value is the
% formulation (pointed at through `value_id`), not a dose; a dose always has an
% amount" (Jess Haley, 2026-10-21; did-schema V_eta_go_forward_class_audit.md).
% So the manipulation's value kind is `formulation`, its own `value` stays
% empty, and the formulation document above is its value through `value_id`
% (DID-matlab resolveDeferredBaths, ff6d542, builds the same shape).
dose = S.statement('manipulation', 'formulation', subjectId, primaryChemical(mixture), [], ...
    'Id', bathId, 'InstrumentId', stimulatorId, 'TimeReferenceIds', trIds, ...
    'Edges', {'value_id', f.base.id}, common{:});

% an anatomical bath location: the site observation pathSPromotion promotes
loc = locationTerm(v1Body);
if ~isempty(trIds) && ~isempty([char(loc.node) char(loc.name)]) && ~isGenericBath(loc)
    extra{end+1} = S.statement('observation', 'term', subjectId, ...
        S.anatomicalLocationVariable(), loc, ...
        'TimeReferenceIds', trIds, common{:});
end
end

function tf = isGenericBath(loc)
%ISGENERICBATH The whole-prep / whole-slice bath location: node NCIm:C0179246
%   (compared as a CURIE key, so the prefix's spelling does not matter) or a
%   name 'bath' -- did2.convert.migrators_j's jTreatmentRoute test, the
%   registry-label half left out (a pure assembler loads no registry).
node = strtrim(char(loc.node));
tf = strcmpi(strtrim(char(loc.name)), 'bath');
if ~tf && ~isempty(node)
    tf = strcmpi(curieKeyOf(node), curieKeyOf('NCIm:C0179246'));
end
end

function k = curieKeyOf(node)
try
    k = char(did2.schema.curieKey(node));
catch
    k = lower(node);
end
end

function mixture = parseMixture88(body)
%PARSEMIXTURE88 The bath's mixture_table rows as NDI's writer serialises them:
%   a CSV with a HEADER row (ontologyName,name,value,ontologyUnit,unitName) and
%   double-quoted names that may hold commas. Each row is {chemical {node,name},
%   amount {source_value, source_unit {node,name}}}; the header is not a row.
%   The same reader as DID-matlab did2.convert.resolveDeferredBaths.
mixture = struct('chemical', {}, 'amount', {});
if ~(isfield(body, 'stimulus_bath') && isstruct(body.stimulus_bath) ...
        && isfield(body.stimulus_bath, 'mixture_table'))
    return;
end
raw = body.stimulus_bath.mixture_table;
if ~(ischar(raw) || (isstring(raw) && isscalar(raw)))
    return;
end
lines = regexp(char(raw), '\r?\n', 'split');
for i = 1:numel(lines)
    line = strtrim(lines{i});
    if isempty(line); continue; end
    cols = csvFields(line);
    if numel(cols) < 5 || isempty(cols{1}); continue; end
    if strcmpi(cols{1}, 'ontologyName'); continue; end      % the header row
    chemical = struct('node', cols{1}, 'name', cols{2});
    amount = struct('source_value', str2double(cols{3}), ...
        'source_unit', struct('node', cols{4}, 'name', cols{5}), 'approximate', false);
    mixture(end+1) = struct('chemical', chemical, 'amount', amount); %#ok<AGROW>
end
end

function cols = csvFields(line)
%CSVFIELDS Split one CSV line on commas outside double quotes; a quoted field
%   loses its quotes and "" inside it is one ". Empty fields (",,", a trailing
%   ",") are kept, so a row's column count is its comma count + 1.
cols = {};
cur = '';
inQuote = false;
k = 1;
while k <= numel(line)
    ch = line(k);
    if inQuote
        if ch == '"'
            if k < numel(line) && line(k + 1) == '"'
                cur(end+1) = '"'; %#ok<AGROW>
                k = k + 1;
            else
                inQuote = false;
            end
        else
            cur(end+1) = ch; %#ok<AGROW>
        end
    elseif ch == '"'
        inQuote = true;
    elseif ch == ','
        cols{end+1} = strtrim(cur); %#ok<AGROW>
        cur = '';
    else
        cur(end+1) = ch; %#ok<AGROW>
    end
    k = k + 1;
end
cols{end+1} = strtrim(cur);
end

function variable = primaryChemical(mixture)
%PRIMARYCHEMICAL The spine identity is the first (primary) mixture chemical;
%   blank if the mixture parsed to nothing.
variable = struct('node', '', 'name', '');
if ~isempty(mixture) && isfield(mixture, 'chemical')
    variable = mixture(1).chemical;
end
end

% ===================== helpers =============================================

function v = dependencyValue(body, name)
v = '';
if isfield(body, 'depends_on') && isstruct(body.depends_on)
    for k = 1:numel(body.depends_on)
        d = body.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value');       v = d.value;
            elseif isfield(d, 'document_id'); v = d.document_id; end
        end
    end
end
end

function e = epochIdOf(body)
e = '';
if isfield(body, 'epochid') && isstruct(body.epochid) ...
        && isfield(body.epochid, 'epochid')
    e = body.epochid.epochid;
end
end

function v = baseField(body, name, default)
v = default;
if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, name)
    v = body.base.(name);
end
end

function term = locationTerm(body)
term = struct('node', '', 'name', '');
if isfield(body, 'stimulus_bath') && isstruct(body.stimulus_bath) ...
        && isfield(body.stimulus_bath, 'location') ...
        && isstruct(body.stimulus_bath.location)
    loc = body.stimulus_bath.location;
    if isfield(loc, 'node');             term.node = loc.node;
    elseif isfield(loc, 'ontologyNode'); term.node = loc.ontologyNode; end
    if isfield(loc, 'name');             term.name = loc.name; end
end
end

function mixture = parseMixture(body)
%PARSEMIXTURE Build the array-of-records mixture from the legacy fields.
%   Mirrors the per-chemical record shape pharmacological_manipulation.mixture
%   wants: { chemical: ontology_term, amount: concentration }. Handles the
%   CSV mixture_table form; the V_gamma solution_name/concentration form is a
%   TODO extension. pharmacological_manipulation.mixture is mustBeNonEmpty,
%   so this always returns >= 1 record -- a blank one when nothing parses,
%   which is the curator's signal rather than a validation failure.
mixture = struct('chemical', {}, 'amount', {});
if isfield(body, 'stimulus_bath') && isstruct(body.stimulus_bath) ...
        && isfield(body.stimulus_bath, 'mixture_table')
    raw = body.stimulus_bath.mixture_table;
    if ischar(raw) || (isstring(raw) && isscalar(raw))
        lines = strsplit(char(raw), newline);
        for i = 1:numel(lines)
            cols = strsplit(strtrim(lines{i}), ',', 'CollapseDelimiters', false);
            if numel(cols) < 5 || isempty(strtrim(cols{1}))
                continue;   % header / blank / malformed row
            end
            chemical = struct('node', strtrim(cols{1}), 'name', strtrim(cols{2}));
            amount = struct('source_value', str2double(cols{3}), ...
                'source_unit', strtrim(cols{5}), 'approximate', false);
            mixture(end+1) = struct('chemical', chemical, 'amount', amount); %#ok<AGROW>
        end
    end
end
if isempty(mixture)
    mixture(1) = struct( ...
        'chemical', struct('node', '', 'name', ''), ...
        'amount', struct('source_value', 0.0, 'source_unit', '', ...
            'approximate', false));
end
end

function out = rowsToStructArray(rows)
%ROWSTOSTRUCTARRAY A cell of per-row structs as one struct array. A row that
%   lacks a field another row has (an ingredient with no amount beside one
%   with a concentration) gets that field empty, so no row is dropped.
out = struct([]);
if isempty(rows)
    return;
end
names = {};
for k = 1:numel(rows)
    names = union(names, fieldnames(rows{k}), 'stable');
end
for k = 1:numel(rows)
    r = rows{k};
    for j = 1:numel(names)
        if ~isfield(r, names{j})
            r.(names{j}) = [];
        end
    end
    r = orderfields(r, names);
    if isempty(out)
        out = r;
    else
        out(end+1) = r; %#ok<AGROW>
    end
end
end
