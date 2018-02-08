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

sr = samplerate(probes{1},1);

disp(['The sample rate of probe 1 epoch 1 is ' num2str(sr) '.']);

disp(['We will now plot the data for epoch 1 for analog_input channel 1.']);

[data,time] = read_epochsamples(probes{1},1,0,10000);

figure;
plot(time,data(:,1));
ylabel('Data on channel 1 of probe 1');
xlabel('Time (s)');
box off;

