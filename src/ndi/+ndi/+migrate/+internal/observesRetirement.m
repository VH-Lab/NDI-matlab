function [retireIds, report, carries] = observesRetirement(structs, options)
%OBSERVESRETIREMENT Which loose `observes` relations NDI's second pass retires, and which subjects it carries.
%
%   [RETIREIDS, REPORT, CARRIES] = ndi.migrate.internal.observesRetirement(STRUCTS)
%   reads the migrated batch STRUCTS (a cell of V_eta document structs) and
%   returns the ids of the `observes` directed_relations (child a device,
%   parent the subject the v1 element named, `depends_on subject_id`) that
%   retire, a REPORT that counts every `observes` relation read, retired or
%   kept, and why, and CARRIES, one {element_id, subject_id, reason} per
%   relation that retires with its subject carried in the migration report
%   (the caller records each with did2.convert.carryElementSubject).
%
%   ... = observesRetirement(STRUCTS, 'CanCarry', false) retires nothing that
%   would need a carry (DID-matlab without did2.convert.carryElementSubject):
%   those relations are kept, counted under kept_no_carry_api.
%
%   ... = observesRetirement(STRUCTS, 'AttributedViaObserves', IDS): the
%   observations IDS (cellstr) were re-attributed to the probe's specimen
%   through the probe's own `observes` relation (ndi.migrate.local
%   resolveRecordingAttribution, [preview attribution without epoch files]);
%   they are not the probe's recording observations, so they keep no
%   relation (counted observations_attributed_via_observes).
%
%   THE DECISIONS.
%   did-schema docs/plans/did_v2_go_forward_class_audit.md:
%     Decided by Jess Haley, 2026-11-17 [stimulator link lives in the
%     presentations] and [observes retires in the second pass]: NDI's second
%     pass retires a stimulator's `observes` relation where a converted
%     stimulus presentation names the same device as instrument and the same
%     animal as entity; DID's first pass keeps `observes`.
%     Decided by Jess Haley, 2026-11-19 [bath manipulation retires observes]:
%     a bath manipulation that names the stimulator as its instrument and the
%     stimulator's subject as its entity retires that `observes` relation by
%     the same rule as a stimulus presentation.
%   did-schema docs/plans/did_v2_standing_wiring_plan.md:
%     Decided by Jess Haley, 2026-11-19 [stimulator subject carried as
%     needing information]: a migrated stimulator whose v1 `subject_id` no
%     statement names gets no `observes`; its v1 subject is recorded as
%     needing information.
%     Decided by Jess Haley, 2026-11-19 [one-field carry in the migration
%     report]: it is held in the run's migration report's carried fields
%     (carry register row carry-172), written by NDI's second pass when no
%     presentation, bath manipulation or Stimulator manipulation names the
%     v1 subject.
%     Decided by Jess Haley, 2026-11-19 [recording probe subject carried the
%     same way]: a migrated recording probe with no recording observation
%     gets no `observes`; its v1 subject is carried the same way.
%
%   THE STATEMENTS READ, each by its `instrument_id` (the device) and what it
%   is about (`entity_id`):
%     presentation    a `manipulation` of value kind `item`
%                     (ndi.migrate.internal.stimulusPresentationToItem)
%     bath            a `manipulation` of value kind `formulation`
%                     (ndi.migrate.internal.stimulusBathToBath: instrument the
%                     stimulator, entity the stimulator's subject)
%     other manipulation  any other `manipulation` (the per-epoch Stimulator
%                     manipulation DID-matlab still writes for a row its
%                     wiring cannot hold: value kind `term`)
%     observation     any `observation` (a recording probe's)
%
%   EACH `observes` RELATION (child C, parent P), in this order:
%     kept_incomplete          the relation names no child, no parent or has
%                              no id
%     kept_several_observes    C `observes` more than one parent (a v1
%                              element names one subject; which one is not
%                              this pass's to choose)
%     RETIRED, by presentation or by bath, when the presentations and bath
%                              manipulations by C name P and nothing else (so
%                              ndi.vintage.elementFields reads P back from the
%                              first one it finds): retired_by_presentation
%                              when a presentation names P, else
%                              retired_by_bath
%     kept_several_entities    C's presentations and baths name P and another
%                              entity: the reader could not tell which is the
%                              v1 element's subject (Proposed, not decided: a
%                              guard so that retiring loses nothing; NDI-matlab
%                              #1260)
%     kept_other_manipulation  another manipulation by C (a Stimulator
%                              manipulation) names P: a statement names the
%                              v1 subject, so nothing is carried, and no
%                              decision retires `observes` on it in NDI's pass
%     kept_observation         an observation (other than those
%                              'AttributedViaObserves' names) has C as its
%                              instrument: C is a
%                              recording probe that has recording
%                              observations, which DID-matlab's
%                              resolveEpochProbemap retires `observes` on
%                              where they name P; this pass does not
%     kept_child_not_converted C is not a converted entity of the batch (the
%                              carried field is collected only for a v2
%                              document)
%     kept_no_carry_api        'CanCarry' false
%     RETIRED WITH A CARRIED SUBJECT (retired_carried), otherwise: no
%                              presentation, bath manipulation or other
%                              manipulation by C names P, and no observation
%                              is made with C. CARRIES gets {C, P, reason}.
%                              Split, for the report, by what C did:
%                              carried_other_entity (C's manipulations name
%                              only other entities: a cohort, another animal)
%                              and carried_no_statement (no statement names C
%                              as its instrument: a stimulator that presented
%                              nothing, or a recording probe of a session
%                              never ingested)
%
%   REPORT (every counter set before any early return; the denominators
%   first):
%     documents_inspected, observes_seen, presentation_manipulations,
%     presentation_instruments, bath_manipulations, bath_instruments,
%     other_manipulations, observations_with_instrument,
%     observations_attributed_via_observes,
%     observes_retired (= retired_by_presentation + retired_by_bath +
%     retired_carried), retired_by_presentation, retired_by_bath,
%     retired_carried, carried_other_entity, carried_no_statement,
%     kept_incomplete, kept_several_observes, kept_several_entities,
%     kept_other_manipulation, kept_observation, kept_child_not_converted,
%     kept_no_carry_api, observes_kept (the sum of the kept_*).
%
%   Pure struct logic: no converter, no schema, no database, no migration
%   report (the caller writes the carries).
%
%   See also ndi.migrate.local, ndi.vintage.elementFields,
%   ndi.vintage.carriedSubjects, did2.convert.carryElementSubject,
%   ndi.migrate.internal.stimulusPresentationToItem,
%   ndi.migrate.internal.stimulusBathToBath.

arguments
    structs cell
    options.CanCarry (1,1) logical = true
    options.AttributedViaObserves cell = {}
end

report = struct( ...
    'documents_inspected',          numel(structs), ...
    'observes_seen',                0, ...
    'presentation_manipulations',   0, ...
    'presentation_instruments',     0, ...
    'bath_manipulations',           0, ...
    'bath_instruments',             0, ...
    'other_manipulations',          0, ...
    'observations_with_instrument', 0, ...
    'observations_attributed_via_observes', 0, ...
    'observes_retired',             0, ...
    'retired_by_presentation',      0, ...
    'retired_by_bath',              0, ...
    'retired_carried',              0, ...
    'carried_other_entity',         0, ...
    'carried_no_statement',         0, ...
    'kept_incomplete',              0, ...
    'kept_several_observes',        0, ...
    'kept_several_entities',        0, ...
    'kept_other_manipulation',      0, ...
    'kept_observation',             0, ...
    'kept_child_not_converted',     0, ...
    'kept_no_carry_api',            0, ...
    'observes_kept',                0);
retireIds = {};
carries = struct('element_id', {}, 'subject_id', {}, 'reason', {});
if isempty(structs)
    return;
end
S = ndi.migrate.internal.etaShape;

% ---- the statements made with each device: instrument -> the entities -----
presentationsOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
bathsOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
otherOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
observed = containers.Map('KeyType', 'char', 'ValueType', 'logical');
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
                    && any(strcmp(options.AttributedViaObserves, char(s.base.id)))
                % its specimen came from this very `observes` relation
                report.observations_attributed_via_observes = ...
                    report.observations_attributed_via_observes + 1;
            else
                observed(instrument) = true;
            end
        end
        continue;
    end
    if ~strcmp(d, 'manipulation')
        continue;
    end
    switch S.valueKind(s)
        case 'item'
            report.presentation_manipulations = report.presentation_manipulations + 1;
            presentationsOf = addEntity(presentationsOf, S.edge(s, 'instrument_id'), S.aboutId(s));
        case 'formulation'
            report.bath_manipulations = report.bath_manipulations + 1;
            bathsOf = addEntity(bathsOf, S.edge(s, 'instrument_id'), S.aboutId(s));
        otherwise
            report.other_manipulations = report.other_manipulations + 1;
            otherOf = addEntity(otherOf, S.edge(s, 'instrument_id'), S.aboutId(s));
    end
end
report.presentation_instruments = double(presentationsOf.Count);   % Count is uint64
report.bath_instruments = double(bathsOf.Count);

% ---- the `observes` relations, and each child's parents -------------------
rels = struct('id', {}, 'child', {}, 'parent', {});
parentsOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(structs)
    s = structs{k};
    if ~strcmp(S.className(s), 'directed_relation') || ~strcmp(S.relationName(s), 'observes')
        continue;
    end
    report.observes_seen = report.observes_seen + 1;
    [child, parent] = S.relationEnds(s);
    id = '';
    if isfield(s, 'base') && isfield(s.base, 'id')
        id = char(s.base.id);
    end
    rels(end+1) = struct('id', id, 'child', char(child), 'parent', char(parent)); %#ok<AGROW>
    if isempty(child) || isempty(parent)
        continue;
    end
    parentsOf = addEntity(parentsOf, char(child), char(parent));
end

% ---- each relation: retired, retired with its subject carried, or kept ------
for k = 1:numel(rels)
    r = rels(k);
    if isempty(r.child) || isempty(r.parent) || isempty(r.id)
        report.kept_incomplete = report.kept_incomplete + 1;
        continue;
    end
    if numel(parentsOf(r.child)) > 1
        report.kept_several_observes = report.kept_several_observes + 1;
        continue;
    end
    pres = entitiesOf(presentationsOf, r.child);
    baths = entitiesOf(bathsOf, r.child);
    naming = unique([pres, baths], 'stable');   % what the reader reads back
    if any(strcmp(naming, r.parent))
        if numel(naming) > 1
            report.kept_several_entities = report.kept_several_entities + 1;
            continue;
        end
        retireIds{end+1} = r.id; %#ok<AGROW>
        if any(strcmp(pres, r.parent))
            report.retired_by_presentation = report.retired_by_presentation + 1;
        else
            report.retired_by_bath = report.retired_by_bath + 1;
        end
        continue;
    end
    other = entitiesOf(otherOf, r.child);
    if any(strcmp(other, r.parent))
        report.kept_other_manipulation = report.kept_other_manipulation + 1;
        continue;
    end
    if isKey(observed, r.child)
        report.kept_observation = report.kept_observation + 1;
        continue;
    end
    if ~isKey(entityIds, r.child)
        report.kept_child_not_converted = report.kept_child_not_converted + 1;
        continue;
    end
    if ~options.CanCarry
        report.kept_no_carry_api = report.kept_no_carry_api + 1;
        continue;
    end
    retireIds{end+1} = r.id; %#ok<AGROW>
    report.retired_carried = report.retired_carried + 1;
    if isempty(naming) && isempty(other)
        report.carried_no_statement = report.carried_no_statement + 1;
        why = ['no statement names the element as its instrument (no stimulus ' ...
            'presentation, bath manipulation, Stimulator manipulation or recording ' ...
            'observation), so its `observes` relation retires ([stimulator subject ' ...
            'carried as needing information], [recording probe subject carried the ' ...
            'same way])'];
    else
        report.carried_other_entity = report.carried_other_entity + 1;
        why = ['the stimulus presentations, bath manipulations and Stimulator ' ...
            'manipulations made with the element name only other entities, so its ' ...
            '`observes` relation retires ([stimulator subject carried as needing ' ...
            'information])'];
    end
    carries(end+1) = struct('element_id', r.child, 'subject_id', r.parent, ...
        'reason', why); %#ok<AGROW>
end
report.observes_retired = report.retired_by_presentation + report.retired_by_bath + ...
    report.retired_carried;
report.observes_kept = report.kept_incomplete + report.kept_several_observes + ...
    report.kept_several_entities + report.kept_other_manipulation + ...
    report.kept_observation + report.kept_child_not_converted + report.kept_no_carry_api;
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
