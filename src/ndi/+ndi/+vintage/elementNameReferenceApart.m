function [name, reference, apart] = elementNameReferenceApart(entityName, localId)
%ELEMENTNAMEREFERENCEAPART A migrated element's name and reference, read from its `name` first.
%
%   [NAME, REFERENCE, APART] = ndi.vintage.elementNameReferenceApart(ENTITYNAME, LOCALID)
%
%   Decided by Jess Haley, 2026-10-29 [element name and reference stored
%   apart] and 2026-10-30 [element name kept apart, base.name carried]
%   (did-schema V_eta_go_forward_class_audit.md): a migrated element writes
%   its v1 element.name, exactly, to the entity's `name`; `local_identifier`
%   stays '<name> | <reference>'; the reference is what follows the KNOWN
%   name, so a name holding ' | ' or ' (ref ' reads back exactly, and so do
%   an empty name and a non-integer or text reference. ENTITYNAME is the
%   entity's `name` ('' or [] when it has none).
%
%   APART is true when the pair was read this way:
%     LOCALID equal to ENTITYNAME                  NAME, REFERENCE []
%     LOCALID = [ENTITYNAME ' | ' X]               NAME, REFERENCE X
%     LOCALID = [ENTITYNAME ' (ref ' X ')']        NAME, REFERENCE X (the form
%                                                  migrated documents carried
%                                                  before 2026-10-26)
%     no ENTITYNAME and LOCALID = [' | ' X]        NAME '', REFERENCE X (an
%                                                  element with an empty name)
%   X is a number when str2double reads it as one (v1 `reference` is numeric
%   on every NDI-written element), else the text.
%
%   APART is false otherwise: an entity migrated before the decision, with no
%   `name`, or whose `name` was its v1 base.name and does not lead LOCALID.
%   NAME and REFERENCE are then today's split of LOCALID alone,
%   ndi.vintage.elementNameReference.
%
%   The mirror of DID-matlab's did2.convert.elementNameReferenceApart (the
%   reader beside its writer did2.convert.elementHandle): the same rules.
%
%   See also ndi.vintage.elementNameReference, ndi.vintage.elementFields.

arguments
    entityName = ''
    localId = ''
end

entityName = textOf(entityName);
localId = textOf(localId);
apart = true;
if ~isempty(entityName)
    name = entityName;
    n = numel(name);
    if strcmp(localId, name)
        reference = [];
        return;
    end
    if startsWith(localId, [name ' | ']) && numel(localId) > n + 3
        reference = referenceValue(localId(n + 4:end));
        return;
    end
    if startsWith(localId, [name ' (ref ']) && endsWith(localId, ')') ...
            && numel(localId) > n + 7
        reference = referenceValue(localId(n + 7:end - 1));
        return;
    end
elseif startsWith(localId, ' | ') && numel(localId) > 3
    name = '';
    reference = referenceValue(localId(4:end));
    return;
end
apart = false;
[name, reference] = ndi.vintage.elementNameReference(localId);
end

function v = referenceValue(s)
% a number when the text is one, else the text
d = str2double(s);
if (~isnan(d) || strcmpi(strtrim(s), 'nan')) && isreal(d)
    v = d;
else
    v = s;
end
end

function s = textOf(v)
s = '';
if isstring(v) && isscalar(v)
    s = char(v);
elseif ischar(v)
    s = v;
end
end
