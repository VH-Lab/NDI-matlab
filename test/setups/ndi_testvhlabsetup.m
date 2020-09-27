function exp = ndi_testvhlabsetup(dirname)
% NDI_TESTVHLABSETUP - display a variety of information about an NDI session
%
% EXP = NDI_TESTVHLABSETUP(DIRNAME)
%
% Displays all devices, all epochs, all probes for an NDI_SESSION_DIRNAME in directory
% DIRNAME. The session variable is returned in EXP.


exp = ndi_session_dir(dirname);


 % now print all devices
devs = exp.daqsystem_load('name','(.*)');

for i=1:numel(devs),
	mydev = vlt.data.celloritem(devs,i),

	disp(['Number of epochs here: ' int2str(numepochs(mydev.filenavigator)) '.'])
end

probes = getprobes(exp),

sr = samplerate(probes{1},1);

disp(['The sample rate of probe 1 epoch 1 is ' num2str(sr) '.']);

disp(['We will now plot the data for epoch 1 for analog_input channel 1.']);

[data,time] = read_epochsamples(probes{1},1,1,10000);

figure;
plot(time,data(:,1));
ylabel('Data on channel 1 of probe 1');
xlabel('Time (s)');
box off;

