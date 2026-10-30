function f = elementFields(subjectDoc, ndi_session_obj)
%ELEMENTFIELDS Rebuild a v1 `element` block from its V_eta satellites.
%
%   F = ndi.vintage.elementFields(SUBJECTDOC, NDI_SESSION_OBJ) returns a
%   struct with the fields ndi.element's document constructor reads:
%       name, reference, type, direct, ndi_element_class,
%       underlying_element_id, subject_id
%
%   THIS IS THE 1 -> N READ, and it is where "the strategy is the same
%   regardless of how many documents" stops being a slogan. One v1
%   `element` became five documents; this puts the parts NDI needs back
%   together. Where each piece went:
%
%     name              -> `entity.name`, exactly (Decided by Jess Haley,
%                          2026-10-29 [element name and reference stored
%                          apart], 2026-10-30 [element name kept apart,
%                          base.name carried])
%     reference         -> what follows that name in
%                          `entity.local_identifier` '<name> | <reference>'
%                          ([element local identifier is name and
%                          reference], 2026-10-26): a number when it reads
%                          as one, else the text. Read by
%                          ndi.vintage.elementNameReferenceApart. An entity
%                          migrated before, with no `name` (or one that does
%                          not lead its local_identifier), is read from
%                          `local_identifier` alone, as before:
%                          ndi.vintage.elementNameReference ('<name> |
%                          <integer>', the old '<name> (ref <reference>)',
%                          or a bare name).
%     type              -> a `term_assertion` labelled `element type`
%     ndi_element_class -> a `term_assertion` labelled `ndi element class`
%     underlying_element_id -> a `directed_relation` `derived_from`
%     subject_id (the specimen) -> a `directed_relation` `observes`,
%                          OR -- and this is the case that was missing --
%                          the `subject_id` of the typed observation that
%                          names this element as its `instrument_id`.
%     direct            -> NOT STORED ANYWHERE. Recovered from which
%                          lineage the migrator emitted.
%
%   THE `observes` RELATION IS NOT ALWAYS THERE, AND THIS FUNCTION USED TO
%   ASSUME IT WAS. Found on a real session, 2026-08-14. `electrode16`
%   rebuilt as
%
%       [1] electrode16   type: n-trode   direct: 0   subject_id: <none>
%
%   while `rayostim` beside it rebuilt correctly -- and the migration was
%   right both times. #30's signed model RETIRES the loose
%   `probe observes specimen` relation exactly when the typed observation
%   replaces it (+migrators_j/element.m:130-134, guarded by
%   `retireObserves`, set at jRecordingObservation.m:245 -- "the
%   instrument_id edge is now present, so `observes` may go"). A
%   stimulator returns early (`:186-187`, "the other direction; `observes`
%   stays for now"), which is why the two probes differed.
%
%   So for a recording probe the specimen moved: it is the `subject_id` of
%   the `<modality>_observation` whose `instrument_id` is this element
%   (T7 -- subject = patient, instrument = agent). Looking only for
%   `observes` read that migration as "no specimen", and then inferred
%   `direct = 0` from the same absence. TWO facts destroyed by ONE missing
%   query, and neither failed loudly.
%
%   IT IS NOT COSMETIC. `ndi.element.epochtable` branches on `direct`
%   (element.m:342) and gives a non-direct element `epochprobemap = []`,
%   which is how a probe finds its channels in the raw files; `:400`
%   refuses external observations on a direct element. A recording probe
%   that reads back as `direct = 0` cannot resolve its own channels.
%
%   RESIDUAL AMBIGUITY, RECORDED NOT FIXED. The migrator writes
%   `derived_from` for two different things -- an underlying element
%   (element.m:130, which fires whether or not `direct` is set) and a
%   NON-direct element's specimen (`:135`). This function assigns both to
%   `underlying_element_id`. The two are distinguishable only by asking
%   whether the parent is itself an element, and no case is known where it
%   matters (`ndi.probe` sets `direct` = 1 and has no underlying element),
%   so it is named here rather than guessed at.
%
%   THE NAME SPLIT. The name is read from `entity.name`, and the reference
%   is the text after [name ' | '] in `local_identifier`, so every name
%   round-trips (' | ' and ' (ref ' included, and an empty name, whose
%   identifier is ' | <reference>'), and so does a non-integer or text
%   reference. Without `name` (migrated before [element name and reference
%   stored apart]) the display form is split at the LAST ' | ' before an
%   integer, as before; DID-matlab's migrator then carried every pair that
%   split could not read back.
%
%   See also: ndi.vintage.elementSubjectDocs, ndi.vintage.elementLabel,
%             ndi.element.

props = subjectDoc.document_properties;
docId = props.base.id;

f = struct('name', '', 'reference', [], 'type', '', 'direct', false, ...
    'ndi_element_class', '', 'underlying_element_id', '', 'subject_id', '');

% --- name + reference: `name` first, then local_identifier --------------
localId = '';
entityName = '';
% did-schema #88 (T1): the element is an `entity`; #73: a `subject`
for blk = {'entity', 'subject'}
    if isfield(props, blk{1}) && isstruct(props.(blk{1})) ...
            && isfield(props.(blk{1}), 'local_identifier')
        localId = props.(blk{1}).local_identifier;
        if isfield(props.(blk{1}), 'name')
            entityName = props.(blk{1}).name;
        end
        break;
    end
end
% [element name and reference stored apart]: the name is `name`, the
% reference what follows [name ' | ']; without `name`, today's split
[f.name, f.reference] = ndi.vintage.elementNameReferenceApart(entityName, localId);

% --- the two kind assertions -------------------------------------------
f.type = assertionValue(ndi_session_obj, docId, ndi.vintage.elementLabel('type'));
f.ndi_element_class = assertionValue(ndi_session_obj, docId, ...
    ndi.vintage.elementLabel('class'));

% --- the lineage relations ---------------------------------------------
f.underlying_element_id = relationTarget(ndi_session_obj, docId, 'derived_from');

% TWO PLACES, IN THIS ORDER, and the second is the one that was missing.
% The typed observation is asked about FIRST because it is the STRONGER
% signal: jRecordingObservation only runs on a direct element, so its
% existence settles `direct` outright, whereas an `observes` relation is
% what survives when no observation was assembled.
[specimen, viaObservation] = specimenViaInstrument(ndi_session_obj, docId);
if isempty(specimen)
    specimen = relationTarget(ndi_session_obj, docId, 'observes');
end
f.subject_id = specimen;

% `direct` is inferred from the lineage, and BOTH direct shapes count. This
% line read `~isempty(specimen)` against the `observes` relation alone,
% which made every recording probe -- the case #30 exists for -- report
% `direct = 0` with no specimen.
f.direct = viaObservation || ~isempty(specimen);
end

% ===================== helpers =============================================

function v = assertionValue(ndi_session_obj, docId, label)
%ASSERTIONVALUE The value of one kind assertion, or '' when absent.
%   ABSENCE IS NOT AN ERROR HERE: the migrator writes each assertion only
%   when the source field was non-empty, so a missing one means the v1
%   element had nothing to say. Returning '' reproduces exactly what the
%   v1 read would have produced from an empty field.
v = '';
q = ndi.v2.statementQuery('assertion', 'term') & ...
    ndi.v2.fieldQuery('statement.variable.name', 'exact_string', label) & ...
    ndi.v2.entityQuery(docId);
docs = ndi_session_obj.database_search(q);
if isempty(docs)
    return;
end
p = docs{1}.document_properties;
if isfield(p, 'term') && isstruct(p.term) && isfield(p.term, 'value') ...
        && isfield(p.term.value, 'name')
    v = p.term.value.name;
end
end

function [specimen, found] = specimenViaInstrument(ndi_session_obj, elementId)
%SPECIMENVIAINSTRUMENT The specimen named by the observation this element made.
%
%   T7 puts the two roles on different edges: `subject_id` is the PATIENT
%   (whose value was measured) and `instrument_id` is the AGENT (what
%   measured it). #30 migrates a raw recording as a
%   `<modality>_observation` with `subject_id` = the specimen and
%   `instrument_id` = the element -- so from the element, the specimen is
%   one hop out along the instrument edge, backwards.
%
%   FOUND is returned separately from SPECIMEN and is NOT `~isempty`:
%   an observation exists only for a DIRECT element (element.m guards the
%   call with `if isDirect`), so its presence settles `direct` even in the
%   pathological case where the specimen edge came back blank. Conflating
%   the two is the mistake this whole helper exists to undo.
%
%   `subject_observation` is queried rather than each `<modality>_observation`
%   name: the modality is chosen per element type by jRecordingModality, and
%   enumerating those here would put a second copy of that table in a second
%   repository.
specimen = '';
found = false;
q = ndi.v2.isaQuery('observation') & ...
    ndi.query('', 'depends_on', 'instrument_id', elementId);
docs = ndi_session_obj.database_search(q);
if isempty(docs)
    return;
end
found = true;
specimen = ndi.v2.edgeIds(ndi.v2.props(docs{1}), 'entity_id');
if isempty(specimen), specimen = ''; else, specimen = specimen{1}; end
end

function target = relationTarget(ndi_session_obj, childId, relationName)
%RELATIONTARGET The `parent` of a directed_relation whose child is CHILDID.
%   The relation name is `directed_relation.relation.name` -- an
%   ontology_term with an empty node, exactly like the kind assertions.
%   Read from the migrator rather than guessed:
%
%       +migrators_j/element.m, lineageRelation()
%           rel.directed_relation = struct('relation', jOntologyTerm('', relationName));
%           rel.depends_on = [struct('name','child', ...), struct('name','parent', ...)]
%
%   The name test runs IN THE QUERY, so a session with many relations does
%   not pull them all into MATLAB to filter.
target = '';
q = ndi.query('', 'isa', 'directed_relation', '') & ...
    ndi.v2.vocabQuery('directed_relation.relation', 'relation', relationName) & ...
    (ndi.query('', 'depends_on', 'child_id', childId) | ...   % did-schema #88
     ndi.query('', 'depends_on', 'child', childId));
docs = ndi_session_obj.database_search(q);
if isempty(docs)
    return;
end
target = docs{1}.dependency_value('parent', 'ErrorIfNotFound', 0);
end
