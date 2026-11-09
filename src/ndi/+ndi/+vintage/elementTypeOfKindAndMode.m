function elementType = elementTypeOfKindAndMode(kindNode, modeNode)
%ELEMENTTYPEOFKINDANDMODE The v1 element type a shared device kind and a recording mode rebuild, or ''.
%
%   ELEMENTTYPE = ndi.vintage.elementTypeOfKindAndMode(KINDNODE, MODENODE) is
%   the one registered v1 probe type whose decided device kind has the node
%   KINDNODE and whose decided recording or imaging mode has the node
%   MODENODE (CURIEs; the prefix is compared ignoring case, the local part
%   exactly), or '' when no registered type has both.
%
%   The kinds here are the ones several v1 types share (patch electrode,
%   sharp electrode, microscope), which ndi.vintage.elementTypeOfKind
%   cannot read back alone. The mode is the `method.term` of the element's
%   recording observation, where DID-matlab's resolveEpochProbemap
%   (recordingModeMethod) writes it:
%
%     [element type is a device kind term] (Decided by Jess Haley,
%     2026-10-27, did-schema did_v2_go_forward_class_audit.md): "recording
%     mode suffixes (-Vm, -I, -Im, -attached) go on the recording
%     observation; the round trip rebuilds the v1 word from kind plus mode".
%     [recording mode terms] (2026-11-01): OBI:0002185 "current clamp assay"
%     (v1 `-Vm`), OBI:0002182 "voltage clamp assay" (v1 `-I`, `-Im`); its
%     build line: "`ndi.vintage.elementTypeOf` reads kind plus mode".
%     [cell-attached is OBI]: OBI:0002179 "cell-attached patch clamp assay".
%     [imaging mode is a method term], [imaging mode terms], [one-photon is
%     NCIT fluorescence microscopy], [element types batch 2]: the imaging
%     modes below.
%
%   Each (kind, mode) pair names exactly one type of NDI's
%   probetype2object.json: a sharp electrode in voltage clamp is `sharp-Im`,
%   the one registered sharp voltage-clamp type (DID-matlab also writes
%   voltage clamp for an unregistered `sharp-I`, which NDI's
%   probestruct2probe cannot build; that element keeps its "element type"
%   assertion for as long as DID-matlab writes one, and
%   ndi.vintage.elementTypeOf reads the assertion first).
%
%   See also ndi.vintage.elementTypeOf, ndi.vintage.elementTypeOfKind,
%   ndi.vintage.elementGeneralTypeOfKind.

arguments
    kindNode = ''
    modeNode = ''
end

elementType = '';
kind = strtrim(char(kindNode));
mode = strtrim(char(modeNode));
if isempty(kind) || isempty(mode)
    return;
end
types = {
    % v1 type              kind node         mode node
    'patch-Vm',            'EMPTY:0000411',  'OBI:0002185'    % current clamp assay
    'patch-I',             'EMPTY:0000411',  'OBI:0002182'    % voltage clamp assay
    'patch-attached',      'EMPTY:0000411',  'OBI:0002179'    % cell-attached patch clamp assay
    'sharp-Vm',            'EMPTY:0000412',  'OBI:0002185'
    'sharp-Im',            'EMPTY:0000412',  'OBI:0002182'
    'wide-field-imaging',  'OBI:0400169',    'OBI:0002437'    % widefield microscopy assay
    'two-photon-imaging',  'OBI:0400169',    'FBbi:00000254'  % two-photon laser scanning microscopy
    'one-photon-imaging',  'OBI:0400169',    'NCIT:C16856'    % Fluorescence Microscopy
    'brightfield-imaging', 'OBI:0400169',    'EMPTY:0000300'};% brightfield imaging
hit = false(size(types, 1), 1);
for k = 1:size(types, 1)
    hit(k) = sameCurie(types{k, 2}, kind) && sameCurie(types{k, 3}, mode);
end
if nnz(hit) == 1
    elementType = types{hit, 1};
end
end

function tf = sameCurie(a, b)
ia = strfind(a, ':');
ib = strfind(b, ':');
if isempty(ia) || isempty(ib)
    tf = strcmp(a, b);
    return;
end
tf = strcmpi(a(1:ia(1)-1), b(1:ib(1)-1)) && strcmp(a(ia(1)+1:end), b(ib(1)+1:end));
end
