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
%     name / reference  -> `subject.local_identifier`, COMBINED. The
%                          migrator writes `sprintf('%s (ref %s)', name,
%                          reference)` and plain `name` when there is no
%                          reference (+migrators_j/element.m:84-85), so
%                          the split below is the exact inverse of that
%                          one format string.
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
%   THE NAME SPLIT IS THE LOSSY PART, AND IT IS NAMED RATHER THAN HIDDEN.
%   An element whose NAME genuinely ends in " (ref something)" is
%   indistinguishable from a name+reference pair after the fold. That is a
%   property of the stored format, not of this function: the two facts
%   were concatenated into one required field and the separator is not
%   escaped. PRED is unaffected ("electrode16 (ref 1)", "rayostim (ref
%   1)"), and any element with no reference round-trips exactly.
%
%   See also: ndi.vintage.elementSubjectDocs, ndi.vintage.elementLabel,
%             ndi.element.

props = subjectDoc.document_properties;
docId = props.base.id;

f = struct('name', '', 'reference', [], 'type', '', 'direct', false, ...
    'ndi_element_class', '', 'underlying_element_id', '', 'subject_id', '');

% --- name + reference, out of the one combined field -------------------
localId = '';
if isfield(props, 'subject') && isstruct(props.subject) ...
        && isfield(props.subject, 'local_identifier')
    localId = props.subject.local_identifier;
end
tok = regexp(localId, '^(.*) \(ref (.+)\)$', 'tokens', 'once');
if isempty(tok)
    f.name = localId;
    f.reference = [];
else
    f.name = tok{1};
    % v1 `reference` is numeric on every NDI-written element; the migrator
    % stringified it. Restore the number when it is one, and keep the text
    % when it is not, rather than silently producing NaN.
    refNum = str2double(tok{2});
    if isnan(refNum)
        f.reference = tok{2};
    else
        f.reference = refNum;
    end
end

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
q = ndi.query('', 'isa', 'term_assertion', '') & ...
    ndi.query('subject_statement.variable.name', 'exact_string', label, '') & ...
    ndi.query('', 'depends_on', 'subject_id', docId);
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
q = ndi.query('', 'isa', 'subject_observation', '') & ...
    ndi.query('', 'depends_on', 'instrument_id', elementId);
docs = ndi_session_obj.database_search(q);
if isempty(docs)
    return;
end
found = true;
specimen = docs{1}.dependency_value('subject_id', 'ErrorIfNotFound', 0);
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
    ndi.query('directed_relation.relation.name', 'exact_string', relationName, '') & ...
    ndi.query('', 'depends_on', 'child', childId);
docs = ndi_session_obj.database_search(q);
if isempty(docs)
    return;
end
target = docs{1}.dependency_value('parent', 'ErrorIfNotFound', 0);
end
