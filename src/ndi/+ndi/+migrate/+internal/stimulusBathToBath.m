function [bathBody, timeRefBody] = stimulusBathToBath(v1Body, resolver, targetVersion)
%STIMULUSBATHTOBATH Assemble a `bath` (+ epoch time reference) from a legacy
%   stimulus_bath, using session/element context.
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
%                    `dose_manipulation` under V_eta (D8 retired the bath family).
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
sessionId    = baseField(v1Body, 'session_id', '');
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
timeRefId   = '';
timeRefBody = [];
mintReference = true;
if strcmp(targetVersion, 'V_eta')
    mintReference = ~isempty(epochId) && ~strcmp(epochClock, 'no_time');
end
if mintReference
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
        'name', 'migrated_stimulator_epoch_anchor', 'datestamp', datestamp);
    timeRefBody.time_reference = struct('is_approximate', false);
    timeRefBody.epochid = struct('epochid', epochId);
    timeRefBody.epoch_bounded_reference = struct('epoch_clock', epochClock);
end

% --- the bath --------------------------------------------------------------
mixture = parseMixture(v1Body);

if strcmp(targetVersion, 'V_eta')
    % Strict J (D8) retired the bath / pharmacological_manipulation family: a
    % bath is a delivered substance -> a `dose_manipulation` on the resolved
    % subject over the stimulator's epoch. This is the LIVE-session counterpart
    % of the coarse did2.convert.resolveDeferredBaths.makeBathVeta (and shares
    % migrators_j.treatment's dose shape): the primary chemical is the spine
    % identity (subject_statement.variable), the whole mixture becomes the dose
    % formulation's chemicals. Unlike the coarse path it keeps the epoch-precise
    % time anchor built above, not a session-relative one -- as a pass-1
    % `epoch_bounded_reference` placeholder that
    % ndi.migrate.internal.epochAnchorFold folds into the signed
    % `relative_reference`, id preserved, once epochMint has created the `epoch`
    % it points at. The bath `location` (the chamber, not a subject site) has no
    % strict-J home on the subject and is dropped.
    chemicals = struct('substance', {}, 'amount', {});
    for i = 1:numel(mixture)
        chem = mixture(i).chemical;
        if isempty(chem.node) && isempty(chem.name)
            continue;   % skip parseMixture's blank fallback (invalid chemical)
        end
        chemicals(end+1) = struct('substance', chem, ...
            'amount', mixture(i).amount); %#ok<AGROW>
    end
    bathBody = struct();
    bathBody.document_class = struct('class_name', 'dose_manipulation', ...
        'class_version', '1.0.0', 'superclasses', [ ...
            struct('class_name', 'subject_manipulation', 'class_version', '1.0.0'), ...
            struct('class_name', 'dose',                 'class_version', '1.0.0')], ...
        'schema_version', targetVersion);
    % `instrument_id` = the STIMULATOR (T7: the instrument of an interaction is
    % an edge on the interaction). This is NOT decoration. The retired
    % `epoch_bounded_reference` was the only document recording WHICH element's
    % epoch this bath sat in, on its `element_id` edge -- and
    % `relative_reference` declares exactly one dependency, `relative_to`, so
    % epochAnchorFold must drop that edge when it folds. Carrying the stimulator
    % here keeps the fact on a class that declares a slot for it
    % (subject_interaction.instrument_id, must_refer subject, optional), and
    % keeps it whether or not the fold ever runs. The stimulator is an element,
    % and did2.convert.migrators_j.element promotes an element to a `subject`
    % with its id PRESERVED, so the edge resolves.
    %
    % NOT A NEW PATTERN, and that matters because a new edge that dangles is a
    % GATING orphan failure (the reverted distance_metadata endpoint relation
    % cost 4,156 of them). An element id in `instrument_id` is what the shipped
    % J migrators already write, on the DID path the corpus is green on:
    %
    %   $ grep -rn "'instrument_id'" DID-matlab/src/did/+did2/+convert/
    %   DENOMINATOR: 175 .m files under +did2/+convert; 2 emit the edge.
    %   +migrators_j/stimulus_response_scalar.m:292
    %       setDep(..., 'instrument_id', depValue(preBody, 'stimulator_id'))
    %                                             ^^ the SAME referent kind
    %   +migrators_j/private/jRecordingObservation.m:212
    %       struct('name','instrument_id','value', elementId)  % the electrode (T7)
    %
    % Guarded anyway: an empty stimulator id emits NO edge rather than a blank
    % one. (subjectOfElement above errors before we reach here in that case, so
    % this is belt-and-braces, not a live branch.)
    bathDeps = struct('name', 'subject_id', 'value', subjectId);
    if ~isempty(stimulatorId)
        bathDeps(end+1) = struct('name', 'instrument_id', 'value', stimulatorId);
    end
    if ~isempty(timeRefId)
        bathDeps(end+1) = struct('name', 'time_reference_1', 'value', timeRefId);
    end
    bathBody.depends_on = bathDeps;
    bathBody.base = struct('id', bathId, 'session_id', sessionId, ...
        'name', 'migrated_bath', 'datestamp', datestamp);
    bathBody.subject_statement = struct('variable', primaryChemical(mixture), ...
        'storage_mode', 'inline');
    bathBody.subject_interaction = struct('method', struct('node', '', 'name', ''), ...
        'sample_time', struct('kind', 'point'));
    bathBody.subject_manipulation = struct('notes', '');
    bathBody.dose = struct('value', struct('formulation', ...
        struct('chemicals', chemicals), ...
        'volume', struct('source_unit', '', 'source_value', 0.0, 'approximate', false), ...
        'route', struct('node', '', 'name', '')));
    return;
end

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
    'name', 'migrated_bath', 'datestamp', datestamp);

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
