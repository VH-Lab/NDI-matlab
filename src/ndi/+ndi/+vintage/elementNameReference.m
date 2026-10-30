function [name, reference, form] = elementNameReference(localId)
%ELEMENTNAMEREFERENCE A migrated element's name and reference, out of its local_identifier.
%
%   [NAME, REFERENCE, FORM] = ndi.vintage.elementNameReference(LOCALID)
%
%   The inverse of ndi.vintage.elementLocalIdentifier. Read in this order:
%
%     'name | reference'   NDI's display form (Decided by Jess Haley,
%                          2026-10-26 [element local identifier is name and
%                          reference]): split at the LAST ' | ', when what
%                          follows it is an integer. REFERENCE is that
%                          integer (a double); NAME is everything before it,
%                          ' | ' and ' (ref ' included. FORM 'display'.
%     'name (ref X)'       the form migrated documents carried before it,
%                          still accepted: DID-matlab +migrators_j/element.m
%                          wrote sprintf('%s (ref %s)', name, reference).
%                          REFERENCE is X as a number when it is one, else
%                          the text. FORM 'ref'.
%     anything else        an element with no reference: NAME is LOCALID,
%                          REFERENCE []. FORM 'name'.
%
%   The display form is tried first and cannot be mistaken for the old one:
%   an old identifier ends in ')', never in ' | <integer>'.
%
%   SINCE [element name and reference stored apart] (Jess Haley, 2026-10-29)
%   a migrated element's name is the entity's `name`; ndi.vintage.elementFields
%   calls ndi.vintage.elementNameReferenceApart, which reads the reference
%   after that name and falls back to this split for an entity without one.
%
%   See also ndi.vintage.elementLocalIdentifier, ndi.vintage.elementFields,
%            ndi.vintage.elementNameReferenceApart.

arguments
    localId
end

if isstring(localId)
    localId = char(localId);
end
if ~ischar(localId)
    localId = '';
end
name = localId;
reference = [];
form = 'name';

% greedy (.*) leaves the LAST ' | ' to the separator
tok = regexp(localId, '^(.*) \| (-?\d+)$', 'tokens', 'once');
if ~isempty(tok)
    name = tok{1};
    reference = str2double(tok{2});
    form = 'display';
    return;
end

tok = regexp(localId, '^(.*) \(ref (.+)\)$', 'tokens', 'once');
if ~isempty(tok)
    name = tok{1};
    % v1 `reference` is numeric on every NDI-written element; the old form
    % stringified it. Restore the number when it is one, and keep the text
    % when it is not, rather than silently producing NaN.
    refNum = str2double(tok{2});
    if isnan(refNum)
        reference = tok{2};
    else
        reference = refNum;
    end
    form = 'ref';
end
end
