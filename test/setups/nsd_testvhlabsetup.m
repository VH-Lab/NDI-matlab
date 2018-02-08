function nsd_testvhlabsetup(dirname)
% NSD_TESTVHLABSETUP - display a variety of information about an NSD experiment
%
% EXP = NSD_TESTVHLABSETUP(DIRNAME)
%
% Displays all devices, all epochs, all probes for an NSD_EXPERIMENT_DIRNAME in directory
% DIRNAME. The experiment variable is returned in EXP.


exp = nsd_experiment_dir(dirname);


 % now print all devices
devs = exp.device_load('name','(.*)');

for i=1:numel(devs),
	mydev = celloritem(devs,i),

	disp(['Number of epochs here: ' int2str(numepochs(mydev.filetree)) '.'])
end

probes = getprobes(exp),

