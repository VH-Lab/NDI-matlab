function [elementType, how] = elementTypeOf(assertions, entityType)
%ELEMENTTYPEOF The v1 element type of a migrated element, from its term assertions.
%
%   [ELEMENTTYPE, HOW] = ndi.vintage.elementTypeOf(ASSERTIONS) reads the v1
%   `element.type` back from the term assertions about one migrated element
%   (a cell of ndi.document, did2.document or body structs; documents of any
%   other kind, or about nothing recognisable, are ignored).
%   [ELEMENTTYPE, HOW] = ndi.vintage.elementTypeOf(ASSERTIONS, ENTITYTYPE)
%   also reads the element's own `entity.type` (an ontology_term {node, name}
%   or a name) when no assertion names the type (step 3):
%
%     1. the "element type" assertion (ndi.vintage.elementLabel('type')), when
%        there is one: its value's name, exactly. HOW = 'element type'.
%        Every element migrated before DID-matlab PR #304 has it, and so do,
%        after #304, a kind several v1 types share (patch*, sharp*, the
%        imaging types), a sorted unit and an ensemble.
%     2. else the device-kind assertion (variable NCIT:C178920 "Equipment
%        Type"): the one v1 type that kind rebuilds
%        (ndi.vintage.elementTypeOfKind). HOW = 'device kind'.
%     3. else, when ENTITYTYPE is `cell` or `group` (read by node,
%        ndi.v2.vocabHandle): 'spikes'. HOW = 'entity type'. A sorted unit
%        is the one element that becomes a cell or a group with no "element
%        type" assertion (an ensemble, also a group, keeps its assertion, so
%        step 1 reads it). Decided by Jess Haley, did-schema
%        did_v2_go_forward_class_audit.md, [cell spellings are one meaning]
%        and [cell spellings amended] (2026-10-27): the v1 types `spikes`,
%        `neuron` and `cell` are "not kept as a statement or a note", each
%        becomes the entity type [sorted units are cells or groups] gives
%        it, and the three are equivalent spellings. 'spikes' is the
%        spelling NDI's own writers use (ndi.element.spikesForProbe,
%        ndi.app.spikesorter) and the one ndi.neuron readers query.
%     4. else ''. HOW = ''. A shared kind with no "element type" assertion
%        reads '' here, as an element with no assertion read before.
%
%   Decided by Jess Haley, did-schema V_eta_go_forward_class_audit.md,
%   [element type is a device kind term] and [element types batch 1] ..
%   [element types batch 4]: the "element type" assertion is dropped where
%   the device kind alone rebuilds the v1 word.
%
%   See also ndi.vintage.elementFields, ndi.vintage.elementTypeOfKind,
%   ndi.vintage.isEquipmentTypeVariable.

arguments
    assertions = {}
    entityType = ''
end

elementType = '';
how = '';
if ~iscell(assertions)
    assertions = num2cell(assertions);
end
typeLabel = ndi.vintage.elementLabel('type');
kindType = '';
for k = 1:numel(assertions)
    p = propsOf(assertions{k});
    if isempty(p)
        continue;
    end
    v = variableOf(p);
    val = termValueOf(p);
    if strcmp(v.name, typeLabel)
        elementType = val.name;
        how = 'element type';
        return;
    end
    if isempty(kindType) && ndi.vintage.isEquipmentTypeVariable(v)
        kindType = ndi.vintage.elementTypeOfKind(val.node);
    end
end
if ~isempty(kindType)
    elementType = kindType;
    how = 'device kind';
    return;
end
if isUnitEntityType(entityType)
    elementType = 'spikes';
    how = 'entity type';
end
end

function tf = isUnitEntityType(entityType)
% a sorted unit's entity type: `cell` (CL:0000000) or `group` (NCIT:C43359),
% by node (ndi.v2.vocabHandle), so the stored name ('cell', 'Group') is notation
tf = false;
if isempty(entityType)
    return;
end
if isstruct(entityType)
    entityType = entityType(1);
end
h = ndi.v2.vocabHandle('entity_type', entityType);
tf = any(strcmp(char(h), {'cell', 'group'}));
end

function p = propsOf(doc)
p = [];
if isa(doc, 'ndi.document')
    p = doc.document_properties;
elseif isa(doc, 'did2.document')
    p = doc.documentProperties;
elseif isstruct(doc) && isscalar(doc)
    if isfield(doc, 'document_properties')
        p = doc.document_properties;
    else
        p = doc;
    end
end
end

function v = variableOf(p)
v = struct('node', '', 'name', '');
for blk = {'statement', 'subject_statement'}
    if isfield(p, blk{1}) && isstruct(p.(blk{1})) && isfield(p.(blk{1}), 'variable')
        v = asTerm(p.(blk{1}).variable);
        return;
    end
end
end

function t = termValueOf(p)
t = struct('node', '', 'name', '');
blk = [];
if isfield(p, 'term') && isstruct(p.term)
    blk = p.term;
elseif isfield(p, 'term_assertion') && isstruct(p.term_assertion)
    blk = p.term_assertion;
end
if isempty(blk) || ~isfield(blk, 'value') || ~isstruct(blk.value) || isempty(blk.value)
    return;
end
t = asTerm(blk.value(1));
end

function t = asTerm(v)
t = struct('node', '', 'name', '');
if isstruct(v) && ~isempty(v)
    v = v(1);
    if isfield(v, 'node'); t.node = strtrim(char(v.node)); end
    if isfield(v, 'name'); t.name = char(v.name); end
elseif ischar(v) || isstring(v)
    t.name = char(v);
end
end
