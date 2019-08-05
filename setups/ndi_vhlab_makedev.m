function exp = ndi_vhlab_makedev(exp, devname)
% NDI_VHLAB_MAKEDEV - initialize devices used by VHLAB
%
% EXP = NDI_VHLAB_MAKEDEV(EXP, DEVNAME)
%
% Creates devices that look for files in the VHLAB standard recording
% scheme, where data from different epochs are organized into
% subdirectories (using NDI_FILENAVIGATOR_EPOCHDIR). DEVNAME should be the 
% name a device in the table below. These devices are added to the NDI_EXPERIMENT
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
% vhintan            |  ndi_iodevice_multichannel_mfdaq_intan that looks for
%                    |    files 'vhintan_channelgrouping.txt' and '*.rhd'
% vhspike2           |  ndi_iodevice_multichannel_mfdaq_cedspike2 that looks for
%                    |    files 'vhspike2_channelgrouping.txt' and '*.smr'
% vhvis_spike2       |  ndi_iodevice_multichannel_mfdaq_stimulus_vhlabvisspike2 that
%                    |    looks for files 'stimtimes.txt', 'verticalblanking.txt',
%                    |    'stims.mat', and 'spike2data.smr'.
%
% See also: NDI_FILENAVIGATOR_EPOCHDIR

if nargin == 0,
	exp = {'vhintan', 'vhspike2', 'vhvis_spike2'};
	return;
end;

if iscell(devname),
	for i=1:length(devname),
		exp = ndi_vhlab_makedev(exp, devname{i});
	end
	return;
end

fileparameters = {'reference.txt'};
objectclass = 'ndi_iodevice_mfdaq';
epochcontentsclass = 'ndi_epochcontents_iodevice_vhlab';

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
		epochcontentsfileparameters = {'stimtimes.txt'}; 

	otherwise,
		error(['Unknown device requested ' devname '.']);

end

ft = ndi_filenavigator_epochdir(exp, fileparameters, epochcontentsclass, epochcontentsfileparameters);

eval(['mydev = ' objectclass '(devname, ft);']);

exp = exp.iodevice_add(mydev);


