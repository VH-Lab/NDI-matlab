function exp = angeluccilab_makedev(exp, devname)
% ANGELUCCILAB_MAKEDEV - initialize devices used by ANGELUCCILAB
%
% EXP = ndi.setups.angeluccilab_makedev(EXP, DEVNAME)
%
% Creates devices that look for files in the ANGELUCCILAB standard recording
% scheme, where data from different epochs are organized into
% subdirectories (using ndi.file.navigator_epochdir). DEVNAME should be the 
% name a device in the table below. These devices are added to the ndi.session
% object EXP. If DEVNAME is a cell list of strings, then multiple items are added.
%
% If the function is called with no input arguments, then it returns a list
% of all valid device names.
% 
% Each epoch is defined by the presence of a 'reference.txt' file, as well
% as specific files that are needed by each device as described below.
%
% Devices created    | Description
% ----------------------------------------------------------------
% angelucci_blackrock5  |  ndi.daq.system.mfdaq that looks for
%                       |    files '#.nev', '#.ns5', and 'stimData.mat'
% angelucci_visstim     |  ndi.daq.system.mfdaq that looks for
%                       |    files '#.nev', '#.ns4', and 'stimData.mat'
%
% See also: ndi.file.navigator_epochdir

if nargin == 0,
	exp = {'angelucci_blackrock5', 'angelucci_visstim'};
	return;
end;

if iscell(devname),
	for i=1:length(devname),
		exp = ndi.setups.angeluccilab_makedev(exp, devname{i});
	end
	return;
end

fileparameters = {'#.nev'};
fileparameters{end+1} = '^stimData.mat$';
fileparameters{end+1} = '^epochprobemap.txt$'; 
epochprobemapfileparameters = {'^epochprobemap.txt$'};
objectclass = 'ndi.daq.system.mfdaq';
readerobjectclass = 'ndi.daq.reader.mfdaq';
epochprobemapclass = 'ndi.daq.metadata.epochprobemap_daqsystem';

switch devname,
	case 'angelucci_blackrock5',
		fileparameters{end+1} = '#.ns5'; 
		readerobjectclass = [readerobjectclass '_blackrock'];
		mdr = {};
	case 'angelucci_visstim',
		fileparameters{end+1} = '#.nev';
		fileparameters{end+1} = '#.ns4'; 
		readerobjectclass = [readerobjectclass '_stimulus_angelucci_visstim'];
		mdr = {ndi.daq.metadatareader.AngelucciStims('stimData.mat')};
	otherwise,
		error(['Unknown device requested ' devname '.']);

end

ft = ndi.file.navigator(exp, fileparameters, epochprobemapclass, epochprobemapfileparameters);

eval(['dr = ' readerobjectclass '();']);


eval(['mydev = ' objectclass '(devname, ft, dr, mdr );']);

exp = exp.daqsystem_add(mydev);


