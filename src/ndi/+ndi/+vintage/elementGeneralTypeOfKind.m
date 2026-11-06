function elementType = elementGeneralTypeOfKind(kindNode)
%ELEMENTGENERALTYPEOFKIND The general v1 element type of a shared device kind, or ''.
%
%   ELEMENTTYPE = ndi.vintage.elementGeneralTypeOfKind(KINDNODE) is the
%   general v1 probe type of a device kind several v1 types share, for an
%   element whose mode is not known: 'patch' for EMPTY:0000411 "patch
%   electrode", 'sharp' for EMPTY:0000412 "sharp electrode", and '' for any
%   other node (the prefix is compared ignoring case, the local part
%   exactly).
%
%   Decided by Jess Haley, 2026-11-06 ("Read back patch"), to Claude's "for a
%   patch probe that never recorded (no recording observation, so no clamp
%   mode; [clamp mode of unrecorded probe dropped], 2026-11-03), NDI reads
%   back an empty element type. Should it read back the general word `patch`
%   instead (and likewise `sharp` and the imaging types)?".
%
%   Both words are registered v1 probe types (ndi_common/probe/
%   probetype2object.json, at NDI-matlab main: `patch` and `sharp`, each
%   ndi.probe.timeseries.mfdaq). The imaging types (wide-field-imaging,
%   two-photon-imaging, one-photon-imaging, brightfield-imaging; kind
%   OBI:0400169 "microscope") have no general registered type, so a
%   microscope with no mode still reads ''.
%
%   See also ndi.vintage.elementTypeOf, ndi.vintage.elementTypeOfKind.

arguments
    kindNode = ''
end

elementType = '';
node = strtrim(char(kindNode));
if isempty(node)
    return;
end
general = {
    'EMPTY:0000411', 'patch'
    'EMPTY:0000412', 'sharp'};
for k = 1:size(general, 1)
    if sameCurie(general{k, 1}, node)
        elementType = general{k, 2};
        return;
    end
end
end

function tf = sameCurie(a, b)
% the prefix compared ignoring case, the local part exactly
ia = strfind(a, ':');
ib = strfind(b, ':');
if isempty(ia) || isempty(ib)
    tf = strcmp(a, b);
    return;
end
tf = strcmpi(a(1:ia(1)-1), b(1:ib(1)-1)) && strcmp(a(ia(1)+1:end), b(ib(1)+1:end));
end
