function [retireIds, report, carries] = observesRetirement(structs, options)
%OBSERVESRETIREMENT Which element subjects NDI's second pass carries, and which pass-1 `observes` relations it removes.
%
%   [RETIREIDS, REPORT, CARRIES] = ndi.migrate.internal.observesRetirement(STRUCTS, ...
%       'ElementSubjects', SUBJECTS)
%   reads the migrated batch STRUCTS (a cell of V_eta document structs) and
%   SUBJECTS (a containers.Map from a v1 element's id to its v1
%   `depends_on subject_id`, ndi.migrate.internal.v1ElementSubjects of the
%   migration input: the direct elements with a subject and no underlying
%   element) and returns
%     CARRIES    one {element_id, subject_id, reason} per converted element
%                whose v1 subject the statements made with it do not give
%                back (the caller records each with
%                did2.convert.carryElementSubject);
%     RETIREIDS  the ids of the `observes` directed_relations (child the
%                element, parent its v1 subject) the batch still holds, to
%                remove: DID-matlab's first pass wrote one per such element
%                until [no observes relation in v2];
%     REPORT     every count, the denominators first.
%
%   ... = observesRetirement(..., 'CanCarry', false): a DID-matlab without
%   did2.convert.carryElementSubject. An element whose subject would need a
%   carry is counted kept_no_carry_api, nothing is carried for it, and its
%   pass-1 `observes` relation (if any) is kept.
%
%   ... = observesRetirement(..., 'AttributedViaSubject', IDS): the
%   observations IDS (cellstr) were re-attributed to the element's v1
%   subject by ndi.migrate.internal.recordingAttribution because no
%   recording observation names that probe ([preview attribution without
%   epoch files]); they are not the probe's recording observations, so they
%   name no subject here (counted observations_attributed_via_subject).
%
%   THE DECISIONS (did-schema docs/plans/did_v2_standing_wiring_plan.md).
%     Decided by Jess Haley, 2026-11-26 [no observes relation in v2]: "v2 has
%     no `observes` relation: DID-matlab's first pass stops turning a v1
%     element's `subject_id` into one, and NDI's second pass reads the v1
%     `subject_id` directly; the animal is the `entity_id` of the
%     observations and manipulations made with the element, or, where none
%     names it, is carried as the element's subject". It supersedes the
%     `observes` parts of [observes retires in the second pass], [DID first
%     pass keeps observes] and [stimulator link lives in the presentations]
%     (did_v2_go_forward_class_audit.md).
%     Decided by Jess Haley, 2026-11-19 [stimulator subject carried as
%     needing information], [one-field carry in the migration report]
%     (carried when "no presentation, bath manipulation or Stimulator
%     manipulation names the v1 subject"; carry register row carry-172) and
%     [recording probe subject carried the same way].
%
%   THE STATEMENTS READ, each by its `instrument_id` (the element) and what
%   it is about (`entity_id`):
%     presentation    a `manipulation` of value kind `item`
%                     (ndi.migrate.internal.stimulusPresentationToItem)
%     bath            a `manipulation` of value kind `formulation`
%                     (ndi.migrate.internal.stimulusBathToBath)
%     other manipulation  any other `manipulation` (a per-epoch Stimulator
%                     manipulation DID-matlab writes for a row its wiring
%                     cannot hold: value kind `term`)
%     observation     any `observation` (a recording probe's), except those
%                     'AttributedViaSubject' names
%
%   EACH CONVERTED ELEMENT C WITH V1 SUBJECT P (SUBJECTS), in this order;
%   what ndi.vintage.elementFields reads back decides it (an observation
%   made with C first, then a carried subject, then the manipulations made
%   with C, ndi.vintage.subjectNamingManipulations):
%     named_by_observation      an observation made with C names P
%     named_by_presentation, named_by_bath, named_by_other_manipulation
%                               the manipulations made with C name P and
%                               nothing else (so the reader reads P from the
%                               first one): by a presentation if one names
%                               P, else a bath, else another manipulation
%     carried_several_entities  the manipulations made with C name P and
%                               another entity: the reader could not tell
%                               which is the v1 subject, so P is carried
%                               (read before the manipulations). Proposed
%                               (not decided): it replaces the counter-only
%                               guard of [observes kept on several entities]
%                               (1), which kept `observes`, now that v2 has
%                               none; 0 on B, 20211116 and Dab when that
%                               guard was built
%     carried_other_entity      the statements made with C name only other
%                               entities (a cohort, another animal, a sorted
%                               unit): P is carried
%     carried_no_statement      no statement names C as its instrument (a
%                               stimulator that presented nothing, a
%                               recording probe of a session never
%                               ingested): P is carried
%     kept_no_carry_api         a carry is needed and 'CanCarry' is false
%   An element of SUBJECTS that is not a converted entity of the batch is
%   carried whole as v1 with its `subject_id` (elements_not_converted).
%
%   EACH PASS-1 `observes` RELATION: removed (observes_removed) when its
%   child is an element of SUBJECTS, unless that element is
%   kept_no_carry_api; kept otherwise (observes_kept: kept_no_carry_api, or
%   observes_without_v1_subject, a relation whose child SUBJECTS does not
%   list, so removing it could lose its parent).
%
%   REPORT (every counter set before any early return; the denominators
%   first):
%     documents_inspected, elements_with_v1_subject, elements_converted,
%     elements_not_converted, observes_seen, presentation_manipulations,
%     presentation_instruments, bath_manipulations, bath_instruments,
%     other_manipulations, observations_with_instrument,
%     observations_attributed_via_subject, named_by_observation,
%     named_by_presentation, named_by_bath, named_by_other_manipulation,
%     carried (= carried_several_entities + carried_other_entity +
%     carried_no_statement), carried_several_entities, carried_other_entity,
%     carried_no_statement, kept_no_carry_api, observes_removed,
%     observes_kept (= kept relations of kept_no_carry_api elements +
%     observes_without_v1_subject), observes_without_v1_subject.
%     elements_converted = the named_by_* + carried + kept_no_carry_api.
%
%   Pure struct logic: no converter, no schema, no database, no migration
%   report (the caller writes the carries).
%
%   See also ndi.migrate.local, ndi.migrate.internal.v1ElementSubjects,
%   ndi.vintage.elementFields, ndi.vintage.carriedSubjects,
%   did2.convert.carryElementSubject.

arguments
    structs cell
    options.ElementSubjects = containers.Map('KeyType', 'char', 'ValueType', 'char')
    options.CanCarry (1,1) logical = true
    options.AttributedViaSubject cell = {}
end

subjects = options.ElementSubjects;
report = struct( ...
    'documents_inspected',          numel(structs), ...
    'elements_with_v1_subject',     double(subjects.Count), ...
    'elements_converted',           0, ...
    'elements_not_converted',       0, ...
    'observes_seen',                0, ...
    'presentation_manipulations',   0, ...
    'presentation_instruments',     0, ...
    'bath_manipulations',           0, ...
    'bath_instruments',             0, ...
    'other_manipulations',          0, ...
    'observations_with_instrument', 0, ...
    'observations_attributed_via_subject', 0, ...
    'named_by_observation',         0, ...
    'named_by_presentation',        0, ...
    'named_by_bath',                0, ...
    'named_by_other_manipulation',  0, ...
    'carried',                      0, ...
    'carried_several_entities',     0, ...
    'carried_other_entity',         0, ...
    'carried_no_statement',         0, ...
    'kept_no_carry_api',            0, ...
    'observes_removed',             0, ...
    'observes_kept',                0, ...
    'observes_without_v1_subject',  0);
retireIds = {};
carries = struct('element_id', {}, 'subject_id', {}, 'reason', {});
if isempty(structs)
    report.elements_not_converted = report.elements_with_v1_subject;
    return;
end
S = ndi.migrate.internal.etaShape;

% ---- the statements made with each element: instrument -> the entities ----
presentationsOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
bathsOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
otherOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
manipulatedOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
observedOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
entityIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(structs)
    s = structs{k};
    if S.isEntity(s)
        if isfield(s, 'base') && isfield(s.base, 'id') && ~isempty(s.base.id)
            entityIds(char(s.base.id)) = true;
        end
        continue;
    end
    d = S.direction(s);
    if strcmp(d, 'observation')
        instrument = S.edge(s, 'instrument_id');
        if ~isempty(instrument)
            report.observations_with_instrument = report.observations_with_instrument + 1;
            if isfield(s, 'base') && isfield(s.base, 'id') ...
                    && any(strcmp(options.AttributedViaSubject, char(s.base.id)))
                % its entity came from the element's v1 subject itself
                report.observations_attributed_via_subject = ...
                    report.observations_attributed_via_subject + 1;
            else
                observedOf = addEntity(observedOf, instrument, S.aboutId(s));
            end
        end
        continue;
    end
    if ~strcmp(d, 'manipulation')
        continue;
    end
    instrument = S.edge(s, 'instrument_id');
    switch S.valueKind(s)
        case 'item'
            report.presentation_manipulations = report.presentation_manipulations + 1;
            presentationsOf = addEntity(presentationsOf, instrument, S.aboutId(s));
        case 'formulation'
            report.bath_manipulations = report.bath_manipulations + 1;
            bathsOf = addEntity(bathsOf, instrument, S.aboutId(s));
        otherwise
            report.other_manipulations = report.other_manipulations + 1;
            otherOf = addEntity(otherOf, instrument, S.aboutId(s));
    end
    manipulatedOf = addEntity(manipulatedOf, instrument, S.aboutId(s));
end
report.presentation_instruments = double(presentationsOf.Count);   % Count is uint64
report.bath_instruments = double(bathsOf.Count);

% ---- each element with a v1 subject: named by a statement, or carried ------
noCarry = containers.Map('KeyType', 'char', 'ValueType', 'logical');
ids = keys(subjects);
for k = 1:numel(ids)
    c = ids{k};
    p = subjects(c);
    if ~isKey(entityIds, c)
        report.elements_not_converted = report.elements_not_converted + 1;
        continue;
    end
    report.elements_converted = report.elements_converted + 1;
    if any(strcmp(entitiesOf(observedOf, c), p))
        report.named_by_observation = report.named_by_observation + 1;
        continue;
    end
    manipulated = entitiesOf(manipulatedOf, c);
    if isequal(manipulated, {p})
        if any(strcmp(entitiesOf(presentationsOf, c), p))
            report.named_by_presentation = report.named_by_presentation + 1;
        elseif any(strcmp(entitiesOf(bathsOf, c), p))
            report.named_by_bath = report.named_by_bath + 1;
        else
            report.named_by_other_manipulation = report.named_by_other_manipulation + 1;
        end
        continue;
    end
    if ~options.CanCarry
        report.kept_no_carry_api = report.kept_no_carry_api + 1;
        noCarry(c) = true;
        continue;
    end
    observed = entitiesOf(observedOf, c);
    if any(strcmp(manipulated, p))
        report.carried_several_entities = report.carried_several_entities + 1;
        why = ['the manipulations made with the element name its v1 subject and ' ...
            'another entity, so the reader could not tell which is the subject ' ...
            '([no observes relation in v2]; carried in place of the guard of ' ...
            '[observes kept on several entities] (1): Proposed, not decided)'];
    elseif isempty(manipulated) && isempty(observed)
        report.carried_no_statement = report.carried_no_statement + 1;
        why = ['no statement names the element as its instrument (no stimulus ' ...
            'presentation, bath manipulation, Stimulator manipulation or recording ' ...
            'observation), so its v1 subject is carried ([no observes relation in ' ...
            'v2], [stimulator subject carried as needing information], [recording ' ...
            'probe subject carried the same way])'];
    else
        report.carried_other_entity = report.carried_other_entity + 1;
        why = ['the stimulus presentations, bath manipulations, Stimulator ' ...
            'manipulations and observations made with the element name only other ' ...
            'entities, so its v1 subject is carried ([no observes relation in v2], ' ...
            '[stimulator subject carried as needing information], [recording probe ' ...
            'subject carried the same way])'];
    end
    carries(end+1) = struct('element_id', c, 'subject_id', p, 'reason', why); %#ok<AGROW>
end
report.carried = report.carried_several_entities + report.carried_other_entity + ...
    report.carried_no_statement;

% ---- the `observes` relations pass 1 still wrote: removed -------------------
for k = 1:numel(structs)
    s = structs{k};
    if ~strcmp(S.className(s), 'directed_relation') || ~strcmp(S.relationName(s), 'observes')
        continue;
    end
    report.observes_seen = report.observes_seen + 1;
    child = S.relationEnds(s);
    id = '';
    if isfield(s, 'base') && isfield(s.base, 'id')
        id = char(s.base.id);
    end
    if isempty(id) || isempty(child) || ~isKey(subjects, char(child))
        report.observes_without_v1_subject = report.observes_without_v1_subject + 1;
        report.observes_kept = report.observes_kept + 1;
        continue;
    end
    if isKey(noCarry, char(child))
        report.observes_kept = report.observes_kept + 1;
        continue;
    end
    retireIds{end+1} = id; %#ok<AGROW>
    report.observes_removed = report.observes_removed + 1;
end
end

function m = addEntity(m, key, entity)
% m(key) gains ENTITY once (an empty key is not listed)
if isempty(key)
    return;
end
key = char(key);
entity = char(entity);
if isKey(m, key)
    names = m(key);
else
    names = {};
end
if ~any(strcmp(names, entity))
    names{end+1} = entity;
end
m(key) = names;
end

function names = entitiesOf(m, key)
% the entities listed for KEY ({} when none)
names = {};
if isKey(m, key)
    names = m(key);
end
end
