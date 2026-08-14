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
%     subject_id (the specimen) -> a `directed_relation` `observes`
%     direct            -> NOT STORED ANYWHERE. It is recovered from WHICH
%                          relation the migrator emitted, because that is
%                          what it was used to decide: `direct` = 1 gives
%                          `observes` the specimen, a derived element gives
%                          `derived_from` its underlying element.
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
specimen = relationTarget(ndi_session_obj, docId, 'observes');
f.subject_id = specimen;

% `direct` is inferred, and only from the relation the migrator would have
% written for it. An element with an `observes` edge to a specimen is the
% direct case by construction.
f.direct = ~isempty(specimen);
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
