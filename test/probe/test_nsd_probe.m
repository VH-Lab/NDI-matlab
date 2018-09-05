function test_nsd_probe(dirname)
% TEST_NSD_PROBE - Test the functionality of NSD_PROBE
%
%  TEST_NSD_PROBE([DIRNAME])
%
%  Given an experiment directory with probes, this function
%  plots some data from the first probe channel 1.
%
%  If DIRNAME is not provided, the default directory
%  [NSDPATH/example_experiments/exp1_eg_saved] is used.
%
%

if nargin<1,
	nsd_globals;

	mydirectory = [nsdpath filesep 'example_experiments' ];
	dirname = [mydirectory filesep 'exp1_eg_saved'];
end;

disp(['reading experiment from directory ' dirname ' ...']);
exp = nsd_experiment_dir(dirname);

%dev1 = load(exp.iodevice,'name','Intan1');

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
