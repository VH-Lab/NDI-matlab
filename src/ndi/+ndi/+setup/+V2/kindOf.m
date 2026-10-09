function [kind, block] = kindOf(doc)
%KINDOF What a built V2 document is: its class, or an entity's type.
%
%   [KIND, BLOCK] = ndi.setup.V2.kindOf(DOC) is ndi.v2.kindOf(DOC).
%
%   See also ndi.v2.kindOf.

[kind, block] = ndi.v2.kindOf(doc);
end
