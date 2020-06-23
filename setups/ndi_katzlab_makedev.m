function exp = ndi_katzlab_makedev(exp, devname)
% NDI_KATZLAB_MAKEDEV - initialize devices used by KATZLAB
%
% EXP = NDI_KATZLAB_MAKEDEV(EXP, DEVNAME)
%
% Creates devices that look for files in the KATZLAB standard recording
% scheme, where data from different epochs are organized into
% subdirectories (using NDI_FILENAVIGATOR_EPOCHDIR). DEVNAME should be the 
% name a device in the table below. These devices are added to the NDI_SESSION
% object EXP. If DEVNAME is a cell list of strings, then multiple items are added.
%
% If the function is called with no input arguments, then it returns a list
% of all valid device names.
% 
% Each epoch is defined by the presence specific files that are needed by each
% device as described below.
%
% Devices created    | Description
% ----------------------------------------------------------------
% narendra_intan     |  ndi_daqsystem_multichannel_mfdaq that looks for
%                    |    files 'time.dat, 'info.rhd', and 'epochprobemap.txt'
%
% See also: NDI_FILENAVIGATOR_EPOCHDIR

if nargin == 0,
	exp = {'narendra_intan'};
	return;
end;

if iscell(devname),
	for i=1:length(devname),
		exp = ndi_katzlab_makedev(exp, devname{i});
	end
	return;
end

fileparameters = {};
objectclass = 'ndi_daqsystem_mfdaq';
readerobjectclass = 'ndi_daqreader_mfdaq';
epochprobemapclass = 'ndi_epochprobemap_daqsystem';

switch devname,
	case 'narendra_intan',
		fileparameters{end+1} = 'time.dat';
		fileparameters{end+1} = 'info.rhd'; 
		fileparameters{end+1} = 'epochprobemap.txt';
		fileparameters{end+1} = 'intraoral_canulae.tsv'; 
		fileparameters{end+1} = 'optical_fiber1.tsv'; 
		fileparameters{end+1} = 'optical_fiber2.tsv'; 
		readerobjectclass = [readerobjectclass '_intan'];
		mdr = {ndi_daqmetadatareader('stimulus_metadata_intraoral_canulae.tsv') ...
			ndi_daqmetadatareader('stimulus_metadata_optical_fiber1.tsv') ...
			ndi_daqmetadatareader('stimulus_metadata_optical_fiber2.tsv')};
		epochprobemapfileparameters = {'epochprobemap.txt'};
	otherwise,
		error(['Unknown device requested ' devname '.']);

end

ft = ndi_filenavigator_epochdir(exp, fileparameters, epochprobemapclass, epochprobemapfileparameters);

eval(['dr = ' readerobjectclass '();']);

eval(['mydev = ' objectclass '(devname, ft, dr );']);

exp = exp.daqsystem_add(mydev);


