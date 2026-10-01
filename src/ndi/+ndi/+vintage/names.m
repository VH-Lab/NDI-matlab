function c = names(x)
%NAMES The candidate V_eta names held in one ndi.vintage.map cell, as a list.
%
%   C = ndi.vintage.names(X) returns X as a row cellstr: {X} for a char,
%   X itself for a cellstr. A map entry's `eta_class`, and the V_eta side of
%   an `edges` or `fields` row, is either one name or a list of candidates
%   (current name first, then older ones -- see ndi.vintage.map), and every
%   reader iterates the list the same way.
%
%   See also: ndi.vintage.map, ndi.vintage.entryFor.

if ischar(x) || (isstring(x) && isscalar(x))
    c = {char(x)};
elseif iscell(x)
    c = reshape(cellfun(@char, x, 'UniformOutput', false), 1, []);
else
    c = {};
end
end
