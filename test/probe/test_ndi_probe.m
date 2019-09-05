function test_ndi_probe(dirname)
% TEST_NDI_PROBE - Test the functionality of NDI_PROBE
%
%  TEST_NDI_PROBE([DIRNAME])
%
%  Given an experiment directory with probes, this function
%  plots some data from the first probe channel 1.
%
%  If DIRNAME is not provided, the default directory
%  [NDIPATH/example_experiments/exp1_eg_saved] is used.
%
%

if nargin<1,
	ndi_globals;
	dirname = [ndiexampleexperpath filesep 'exp1_eg_saved'];
end;

disp(['reading experiment from directory ' dirname ' ...']);
exp = ndi_experiment_dir(dirname);

%dev1 = load(exp.daqsystem,'name','Intan1');

probes = getprobes(exp);

% now let's play with the first probe

sr = samplerate(probes{1},1);

disp(['The sample rate of probe 1 epoch 1 is ' num2str(sr) '.']);

disp(['We will now plot the data for epoch 1 for analog_input channel 1.']);

[data,time] = read_epochsamples(probes{1},1,0,10000);

figure;
plot(time,data(:,1));
ylabel('Data on channel 1 of probe 1');
xlabel('Time (s)');
box off;
