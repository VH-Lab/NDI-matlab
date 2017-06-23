function nsd_probe_obj = nsd_probestruct2probe(probestruct, exp)
% NSD_PROBESTRUCT2PROBE - Convert probe structures to NSD_PROBE objects
%
% NSD_PROBE_OBJ = NSD_PROBESTRUCT2PROBE(PROBESTRUCT, EXP)
%
% Given an array of structures PROBESTRUCT with field 
% 'name', 'reference', and 'type', and an NSD_EXPERIMENT EXP,
% this function generates the appropriate subclass of NSD_PROBE for
% dealing with the PROBE and returns the objects in a cell array NSD_PROBE_OBJ.
%
% This function uses the NSD_GLOBALS variable 'nsd_probetype2object' to
% make the conversion.
%
% See also: NSD_GLOBALS and NSD_PROBETYPE2OBJECT
%

nsd_globals;

if ~exist('nsd_probetype2object','var'),
	nsd_probetype2objectinit;
end

nsd_probe_obj = {};

for i=1:numel(probestruct),
	ind = find(strcmpi(probestruct(i).type,{nsd_probetype2object.type}));
	if isempty(ind),
		warning(['Could not find exact match for ' probestruct(i).type ', using general NSD_PROBE.']);
	end
	eval(['nsd_probe_obj{i} = ' nsd_probetype2object(ind).classname '(exp, probestruct(i).name, probestruct(i).reference, probestruct(i).type);']);
end
