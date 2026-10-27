function [localId, reversible] = elementLocalIdentifier(name, reference)
%ELEMENTLOCALIDENTIFIER A migrated element's local_identifier: its name and reference, as NDI shows them.
%
%   [LOCALID, REVERSIBLE] = ndi.vintage.elementLocalIdentifier(NAME, REFERENCE)
%
%   Decided by Jess Haley, 2026-10-26 [element local identifier is name and
%   reference] (did-schema V_eta_go_forward_class_audit.md): a migrated
%   element's `local_identifier` is NDI's own display form
%
%       <name> | <reference>          e.g.  'leftcortex | 2'
%
%   the string ndi.element/elementstring writes
%   ([name ' | ' int2str(reference)]). The name alone is not unique (Soph
%   holds `leftcortex` n-trodes with references 1, 2 and 3). It replaces the
%   unescaped '%s (ref %s)' packing (did-schema OPEN_WORK #142).
%
%   It is read back by ndi.vintage.elementNameReference, which splits at the
%   LAST ' | ': the reference is an integer, so it holds no ' | ' of its own,
%   and a name may hold any text, ' | ' and ' (ref ' included.
%
%   REFERENCE is an integer (numeric, or text that is one, e.g. '2'), or
%   empty for an element with no reference, whose LOCALID is NAME alone.
%   REVERSIBLE is false, and LOCALID '', when the pair cannot be read back
%   exactly: a REFERENCE that is not an integer, an empty NAME, or no
%   REFERENCE and a NAME that itself ends in ' | <integer>' or reads as the
%   old ' (ref X)' form. A caller then keeps the element as it was (the
%   migration's "carried as v1") rather than writing a form that reads back
%   as something else.
%
%   See also ndi.vintage.elementNameReference, ndi.vintage.elementFields,
%            ndi.element/elementstring.

arguments
    name {mustBeText}
    reference = []
end

name = char(name);
localId = '';
reversible = false;
if isempty(name)
    return;
end
if isempty(reference) || (isstring(reference) && strlength(reference) == 0)
    % no reference: the name alone, if it cannot be mistaken for a pair
    [n, r] = ndi.vintage.elementNameReference(name);
    if strcmp(n, name) && isempty(r)
        localId = name;
        reversible = true;
    end
    return;
end
ref = integerOf(reference);
if isempty(ref)
    return;
end
localId = [name ' | ' int2str(ref)];
reversible = true;
end

function r = integerOf(x)
% the integer X is, or [] when it is not one
r = [];
if ischar(x) || isstring(x)
    x = strtrim(char(x));
    if isempty(regexp(x, '^-?\d+$', 'once'))
        return;
    end
    x = str2double(x);
end
if (isnumeric(x) || islogical(x)) && isscalar(x) && isfinite(double(x)) ...
        && double(x) == round(double(x))
    r = double(x);
end
end
