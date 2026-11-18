function [retireIds, report] = observesRetirement(structs)
%OBSERVESRETIREMENT Which loose `observes` relations the stimulus presentations replace.
%
%   [RETIREIDS, REPORT] = ndi.migrate.internal.observesRetirement(STRUCTS)
%   reads the migrated batch STRUCTS (a cell of V_eta document structs) and
%   returns the ids of the `observes` directed_relations (child a device,
%   parent the animal it acts on) that a converted stimulus presentation
%   states again, and a REPORT that counts every `observes` relation read,
%   retired or kept, and why.
%
%   THE DECISIONS. did-schema docs/plans/did_v2_go_forward_class_audit.md:
%     Decided by Jess Haley, 2026-11-17 [stimulator link lives in the
%     presentations]: the link between a stimulator device and the animal
%     it acts on is carried by the stimulus presentation manipulations
%     NDI's second pass writes (instrument the stimulator device, entity the
%     animal); the loose `observes` relation retires where such a
%     presentation names the same device and animal.
%     Decided by Jess Haley, 2026-11-17 [observes retires in the second
%     pass]: NDI's second pass retires a stimulator's `observes` relation
%     after it has converted the stimulus presentations into manipulations,
%     where a presentation names the same device as instrument and the same
%     animal as entity; DID's first pass keeps `observes`.
%
%   A PRESENTATION MANIPULATION is a `manipulation` whose value kind is
%   `item` (ndi.migrate.internal.stimulusPresentationToItem: instrument_id
%   the v1 `stimulus_element_id`, entity_id the animal or the session's
%   cohort). Other manipulations a stimulator is the instrument of (a bath's
%   dose, a per-epoch Stimulator manipulation DID-matlab still writes for a
%   row its wiring cannot hold) are not presentations and retire nothing.
%
%   RETIRED, for an `observes` relation (child C, parent P), when
%     * a presentation manipulation has instrument_id C and entity_id P, and
%     * every presentation manipulation with instrument_id C names P (so
%       the reader, ndi.vintage.elementFields, reads P back from the first
%       one it finds), and
%     * C `observes` no other parent.
%   KEPT otherwise, each counted under one reason, in this order:
%     kept_incomplete          the relation names no child or no parent
%     kept_several_observes    C `observes` more than one parent (a v1
%                              element names one subject; which one is not
%                              this pass's to choose)
%     kept_no_presentation     no presentation manipulation names C as its
%                              instrument (a stimulator that presented
%                              nothing, or a recording device)
%     kept_other_entity        C's presentations name only entities other
%                              than P (a cohort group, another animal)
%     kept_several_entities    C's presentations name P and another entity:
%                              the reader could not tell which is the v1
%                              element's subject (Proposed, not decided: a
%                              guard so that retiring loses nothing; see the
%                              PR)
%
%   REPORT (every counter set before any early return; the denominators
%   first):
%     documents_inspected, observes_seen, presentation_manipulations,
%     presentation_instruments, observes_retired, kept_incomplete,
%     kept_several_observes, kept_no_presentation, kept_other_entity,
%     kept_several_entities, observes_kept (the sum of the kept_*).
%
%   Pure struct logic: no converter, no schema, no database.
%
%   See also ndi.migrate.local, ndi.vintage.elementFields,
%   ndi.migrate.internal.stimulusPresentationToItem.

arguments
    structs cell
end

report = struct( ...
    'documents_inspected',        numel(structs), ...
    'observes_seen',              0, ...
    'presentation_manipulations', 0, ...
    'presentation_instruments',   0, ...
    'observes_retired',           0, ...
    'kept_incomplete',            0, ...
    'kept_several_observes',      0, ...
    'kept_no_presentation',       0, ...
    'kept_other_entity',          0, ...
    'kept_several_entities',      0, ...
    'observes_kept',              0);
retireIds = {};
if isempty(structs)
    return;
end
S = ndi.migrate.internal.etaShape;

% ---- the presentation manipulations: instrument -> the entities it names --
entitiesOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(structs)
    s = structs{k};
    if ~S.isStatement(s, 'manipulation', 'item')
        continue;
    end
    report.presentation_manipulations = report.presentation_manipulations + 1;
    instrument = S.edge(s, 'instrument_id');
    entity = S.aboutId(s);
    if isempty(instrument)
        continue;
    end
    if isKey(entitiesOf, instrument)
        names = entitiesOf(instrument);
    else
        names = {};
    end
    if ~any(strcmp(names, entity))
        names{end+1} = entity; %#ok<AGROW>
    end
    entitiesOf(instrument) = names;
end
report.presentation_instruments = entitiesOf.Count;

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
    if isKey(parentsOf, child)
        p = parentsOf(child);
    else
        p = {};
    end
    if ~any(strcmp(p, parent))
        p{end+1} = parent; %#ok<AGROW>
    end
    parentsOf(child) = p;
end

% ---- each relation: retired, or kept with its reason -----------------------
for k = 1:numel(rels)
    r = rels(k);
    if isempty(r.child) || isempty(r.parent) || isempty(r.id)
        report.kept_incomplete = report.kept_incomplete + 1;
    elseif numel(parentsOf(r.child)) > 1
        report.kept_several_observes = report.kept_several_observes + 1;
    elseif ~isKey(entitiesOf, r.child)
        report.kept_no_presentation = report.kept_no_presentation + 1;
    elseif ~any(strcmp(entitiesOf(r.child), r.parent))
        report.kept_other_entity = report.kept_other_entity + 1;
    elseif numel(entitiesOf(r.child)) > 1
        report.kept_several_entities = report.kept_several_entities + 1;
    else
        retireIds{end+1} = r.id; %#ok<AGROW>
        report.observes_retired = report.observes_retired + 1;
    end
end
report.observes_kept = report.kept_incomplete + report.kept_several_observes + ...
    report.kept_no_presentation + report.kept_other_entity + report.kept_several_entities;
end
