function [name, ref, daqsysstr,subjectlist] = channelnames2daqsystemstrings(chNames, daqname, subjects)
%
% DAQSYSSTR = CHANNELNAMES2DAQSYSTEMSTRINGS(CHNAMES, DAQNAME, SUBJECTS)
% 
% 

name = {};
ref = [];
subjectlist = {};

hasPhysio = 0;

for i=1:numel(chNames),
	if i==1,
		daqsysstr = ndi.daq.daqsystemstring(daqname, {'ai'}, i);
	else,
		daqsysstr(end+1) = ndi.daq.daqsystemstring(daqname, {'ai'}, i);
	end;
	[name{i},ref(i),subjectlist{i}] = ndi.setup.conv.marder.channelname2probename(chNames{i},subjects);
	if strcmp(name{i},'PhysiTemp_1'),
		hasPhysio = i;
	end;
end;

if hasPhysio & numel(subjects)>1, % add it to any second prep
	daqsysstr(end+1) = ndi.daq.daqsystemstring(daqname, {'ai'}, hasPhysio);
	name{end+1} = 'PhysiTemp_2';
	ref(i+1) = 1;
	subjectlist{end+1} = subjects{2};
end;



