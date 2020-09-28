function ndi_probe_obj = ndi_probestruct2probe(probestruct, exp)
% NDI_PROBESTRUCT2PROBE - Convert probe structures to NDI_PROBE objects
%
% NDI_PROBE_OBJ = NDI_PROBESTRUCT2PROBE(PROBESTRUCT, EXP)
%
% Given an array of structures PROBESTRUCT with field 
% 'name', 'reference', and 'type', and an NDI_SESSION EXP,
% this function generates the appropriate subclass of NDI_PROBE for
% dealing with the PROBE and returns the objects in a cell array NDI_PROBE_OBJ.
%
% This function uses the NDI_GLOBALS variable 'ndi_globals.probetype2object' to
% make the conversion.
%
% See also: NDI_GLOBALS and NDI_PROBETYPE2OBJECT
%

ndi_globals;

init_probetypes = 0;
if ~isfield(ndi,'probetype2object'),
	init_probetypes = 1;
elseif isempty(ndi_globals.probetype2object),
	init_probetypes = 1;
end

if init_probetypes==1,
	ndi_globals.probetype2objectinit;
end

ndi_probe_obj = {};

for i=1:numel(probestruct),
	ind = find(strcmpi(probestruct(i).type,{ndi_globals.probetype2object.type}));
	if isempty(ind),
		error(['Could not find exact match for ' probestruct(i).type ', bailing out.']);
	end
	eval(['ndi_probe_obj{i} = ' ndi_globals.probetype2object(ind).classname '(exp, probestruct(i).name, probestruct(i).reference, probestruct(i).type, probestruct(i).subject_id);']);
end
