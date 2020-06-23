function exp = ndi_vhlab_makedev(exp, devname)
% NDI_VHLAB_MAKEDEV - initialize devices used by VHLAB
%
% EXP = NDI_VHLAB_MAKEDEV(EXP, DEVNAME)
%
% Creates devices that look for files in the VHLAB standard recording
% scheme, where data from different epochs are organized into
% subdirectories (using NDI_FILENAVIGATOR_EPOCHDIR). DEVNAME should be the 
% name a device in the table below. These devices are added to the NDI_SESSION
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
% vhintan            |  ndi_daqsystem_multichannel_mfdaq that looks for
%                    |    files 'vhintan_channelgrouping.txt' and '*.rhd'
% vhspike2           |  ndi_daqsystem_multichannel_mfdaq that looks for
%                    |    files 'vhspike2_channelgrouping.txt' and '*.smr'
% vhvis_spike2       |  ndi_daqsystem_multichannel_mfdaq_stimulus that
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
objectclass = 'ndi_daqsystem_mfdaq';
readerobjectclass = 'ndi_daqreader_mfdaq';
epochprobemapclass = 'ndi_epochprobemap_daqsystem_vhlab';

switch devname,
	case 'vhintan',
		fileparameters{end+1} = '.*\.rhd\>';
		fileparameters{end+1} = 'vhintan_channelgrouping.txt'; 
		readerobjectclass = [readerobjectclass '_intan'];
		epochprobemapfileparameters = {'vhintan_channelgrouping.txt'};
		mdr = {};
	case 'vhspike2',
		fileparameters{end+1} = '.*\.smr\>';
		fileparameters{end+1} = 'vhspike2_channelgrouping.txt'; 
		readerobjectclass = [readerobjectclass '_cedspike2'];
		epochprobemapfileparameters = {'vhspike2_channelgrouping.txt'};
		mdr = {};
	case 'vhvis_spike2'
		fileparameters{end+1} = 'stimtimes.txt';
		fileparameters{end+1} = 'verticalblanking.txt';
		fileparameters{end+1} = 'stims.mat';
		fileparameters{end+1} = 'spike2data.smr'; 
		readerobjectclass = [readerobjectclass '_stimulus_vhlabvisspike2'];
		epochprobemapfileparameters = {'stimtimes.txt'}; 
		mdr = {ndi_daqmetadatareader_NewStimStims('stims.mat')};
	otherwise,
		error(['Unknown device requested ' devname '.']);

end

ft = ndi_filenavigator_epochdir(exp, fileparameters, epochprobemapclass, epochprobemapfileparameters);

eval(['dr = ' readerobjectclass '();']);


eval(['mydev = ' objectclass '(devname, ft, dr, mdr );']);

exp = exp.daqsystem_add(mydev);


