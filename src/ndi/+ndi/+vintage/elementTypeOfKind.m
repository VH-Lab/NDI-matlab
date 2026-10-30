function [elementType, source] = elementTypeOfKind(kindNode, forceMirror)
%ELEMENTTYPEOFKIND The v1 element type a device kind alone rebuilds, or ''.
%
%   ELEMENTTYPE = ndi.vintage.elementTypeOfKind(KINDNODE) is the one v1 probe
%   type whose decided device kind has the node KINDNODE (a CURIE; the prefix
%   is compared ignoring case, the local part exactly), or '' when no type has
%   it or several do (patch electrode, sharp electrode, microscope: those
%   elements keep their "element type" assertion).
%
%   [ELEMENTTYPE, SOURCE] = ... also says which table answered: 'did2' when
%   DID-matlab's did2.convert.elementTypeOfKind is on the path (it is the
%   source), else 'mirror', the copy below. ELEMENTTYPEOFKIND(KINDNODE, true)
%   reads the mirror even when DID-matlab's function is there (for the test
%   that compares them).
%
%   WHY A MIRROR. DID-matlab PR #304 adds did2.convert.elementTypeOfKind and
%   stops writing the "element type" assertion where the device kind alone
%   rebuilds the v1 type (did-schema V_eta_go_forward_class_audit.md,
%   [element type is a device kind term], [element types batch 1] ..
%   [element types batch 4], Decided by Jess Haley). This reader lands first
%   (did-schema CLAUDE.md, "Changes the siblings must follow land in the
%   siblings first"), so NDI-matlab CI runs it against a DID-matlab V2 that
%   does not yet hold that function. The mirror is DID-matlab's
%   did2.convert.elementDeviceKind table as of #304;
%   ndi.unittest.vintage.TestElementTypeFromKind compares the two whenever
%   DID-matlab's function is reachable.
%
%   See also ndi.vintage.elementTypeOf, ndi.vintage.elementFields.

arguments
    kindNode = ''
    forceMirror (1,1) logical = false
end

if ~forceMirror && ~isempty(which('did2.convert.elementTypeOfKind'))
    elementType = did2.convert.elementTypeOfKind(kindNode);
    source = 'did2';
    return;
end
source = 'mirror';
elementType = '';
node = strtrim(char(kindNode));
if isempty(node)
    return;
end
types = mirrorTable();
hit = false(size(types, 1), 1);
for k = 1:size(types, 1)
    hit(k) = sameCurie(types{k, 2}, node);
end
if nnz(hit) == 1
    elementType = types{hit, 1};
end
end

function types = mirrorTable()
% DID-matlab did2.convert.elementDeviceKind, PR #304 (v1 type, kind node)
types = {
    'n-trode',             'wikidata:Q1952355'
    'patch',               'EMPTY:0000411'
    'patch-Vm',            'EMPTY:0000411'
    'patch-I',             'EMPTY:0000411'
    'patch-attached',      'EMPTY:0000411'
    'sharp',               'EMPTY:0000412'
    'sharp-Vm',            'EMPTY:0000412'
    'sharp-Im',            'EMPTY:0000412'
    'wide-field-imaging',  'OBI:0400169'
    'two-photon-imaging',  'OBI:0400169'
    'one-photon-imaging',  'OBI:0400169'
    'brightfield-imaging', 'OBI:0400169'
    'lick-spout',          'EMPTY:0000414'
    'reward-well',         'EMPTY:0000415'
    'intraoral-cannula',   'NCIT:C50343'
    'optogenetic-fiber',   'NCIT:C50358'
    'ecg',                 'OBI:0003806'
    'eeg',                 'wikidata:Q4531135'
    'accelerometer',       'NCIT:C88166'
    'thermometer',         'NCIT:C50059'
    'ppg',                 'NCIT:C224112'
    'electrode-$',         'NCIT:C49936'};
end

function tf = sameCurie(a, b)
% the prefix compared ignoring case (wikidata / Wikidata), the local part exactly
ia = strfind(a, ':');
ib = strfind(b, ':');
if isempty(ia) || isempty(ib)
    tf = strcmp(a, b);
    return;
end
tf = strcmpi(a(1:ia(1)-1), b(1:ib(1)-1)) && strcmp(a(ia(1)+1:end), b(ib(1)+1:end));
end
