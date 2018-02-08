function exp = nsd_vhlab_makedev(exp, devname)
% NSD_VHLAB_MAKEDEV - initialize devices used by VHLAB
%
% EXP = NSD_VHLAB_MAKEDEV(EXP, DEVNAME)
%
% Creates devices that look for files in the VHLAB standard recording
% scheme, where data from different epochs are organized into
% subdirectories (using NSD_FILETREE_EPOCHDIR). DEVNAME should be the 
% name a device in the table below. These devices are added to the NSD_EXPERIMENT
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
% vhintan            |  nsd_device_multichannel_mfdaq_intan that looks for
%                    |    files 'vhintan_channelgrouping.txt' and '*.rhd'
% vhspike2           |  nsd_device_multichannel_mfdaq_cedspike2 that looks for
%                    |    files 'vhspike2_channelgrouping.txt' and '*.smr'
% vhvis_spike2       |  nsd_device_multichannel_mfdaq_stimulus_vhlabvisspike2 that
%                    |    looks for files 'stimtimes.txt', 'verticalblanking.txt',
%                    |    'stims.mat', and 'spike2data.smr'.
%
% See also: NSD_FILETREE_EPOCHDIR

if nargin == 0,
	exp = {'vhintan', 'vhspike2', 'vhvis_spike2'};
	return;
end;

if iscell(devname),
	for i=1:length(devname),
		exp = nsd_vhlab_makedev(exp, devname{i});
	end
	return;
end

fileparameters = {'reference.txt'};
objectclass = 'nsd_device_mfdaq';
epochcontentsclass = 'nsd_epochcontents_vhlab';

switch devname,
	case 'vhintan',
		fileparameters{end+1} = '.*\.rhd\>';
		fileparameters{end+1} = 'vhintan_channelgrouping.txt'; 
		objectclass = [objectclass '_intan'];
		epochcontentsfileparameters = {'vhintan_channelgrouping.txt'};
	case 'vhspike2',
		fileparameters{end+1} = '.*\.smr\>';
		fileparameters{end+1} = 'vhspike2_channelgrouping.txt'; 
		objectclass = [objectclass '_cedspike2'];
		epochcontentsfileparameters = {'vhspike2_channelgrouping.txt'};

	case 'vhvis_spike2'
		fileparameters{end+1} = 'stimtimes.txt';
		fileparameters{end+1} = 'verticalblanking.txt';
		fileparameters{end+1} = 'stims.mat';
		fileparameters{end+1} = 'spike2data.smr'; 
		objectclass = [objectclass '_stimulus_vhlabvisspike2'];
		epochcontentsfileparameters = {'.txt'}; % really need a method that always returns 1 stim machine

	otherwise,
		error(['Unknown device requested ' devname '.']);

end

ft = nsd_filetree_epochdir(exp, fileparameters, epochcontentsclass, epochcontentsfileparameters);

eval(['mydev = ' objectclass '(devname, ft);']);

exp = exp.device_add(mydev);


