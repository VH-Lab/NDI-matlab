function [name, ref, daqsysstr,subjectlist, probetype] = channelnames2daqsystemstrings(chNames, daqname, subjects, options)
%
% DAQSYSSTR = CHANNELNAMES2DAQSYSTEMSTRINGS(CHNAMES, DAQNAME, SUBJECTS)
% 
% 

arguments
	chNames
	daqname
	subjects
	options.channelnumbers = []
end

name = {};
ref = [];
subjectlist = {};
probetype = {};

if isempty(options.channelnumbers),
	options.channelnumbers = 1:numel(chNames);
end;

accelStruct = did.datastructures.emptystruct('key','value');

good = [];

for i=1:numel(chNames),
	if ~isempty(findstr(lower(chNames{i}),'acc')),
		accelStruct(end+1) = struct('key',chNames{i}(4),'value',i);
	end;
	if i==1,
		daqsysstr = ndi.daq.daqsystemstring(daqname, {'ai'}, options.channelnumbers(i));
	else,
		daqsysstr(end+1) = ndi.daq.daqsystemstring(daqname, {'ai'}, options.channelnumbers(i));
	end;
	[name{i},ref(i),subjectlist{i},probetype{i}] = ndi.setup.conv.gluckman.channelname2probename(chNames{i},subjects);
	good(i) = ~isempty(probetype{i});
end;

good = find(good);

name = name(good);
ref = ref(good);
daqsysstr = daqsysstr(good);
subjectlist = subjectlist(good);
probetype = probetype(good);

if ~(numel(accelStruct)==3 | numel(accelStruct)==0),
	error(['new case for accelerometer.']);
end;

[dummy,theorder] = sort({accelStruct.key});

if numel(accelStruct)==3,
	name{end+1} = 'accel';
	ref(end+1) = 1;
	probetype{end+1} = 'accelerometer';
	subjectlist{end+1} = subjects{1};
	daqsysstr(end+1) = ndi.daq.daqsystemstring(daqname,{'ai','ai','ai'},[accelStruct(theorder).value]);
end;

