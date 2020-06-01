function test_ndi_probe(dirname)
% TEST_NDI_PROBE - Test the functionality of NDI_PROBE
%
%  TEST_NDI_PROBE([DIRNAME])
%
%  Given an session directory with probes, this function
%  plots some data from the first probe channel 1.
%
%  If DIRNAME is not provided, the default directory
%  [NDIPATH/example_sessions/exp1_eg_saved] is used.
%
%

if nargin<1,
	ndi_globals;
	dirname = [ndi.path.exampleexperpath filesep 'exp1_eg_saved'];
end;

disp(['reading session from directory ' dirname ' ...']);
E = ndi_session_dir(dirname),

%dev1 = load(E.daqsystem,'name','intan1')

probes = E.getprobes();
if numel(probes)==0, % build_intan_flat_exp hasn't been run yet
	disp(['Need to run build_intan_flat_exp first, doing that now...']);
	build_intan_flat_exp(dirname);
        probes = E.getprobes(); % should return 1 probe
end;

% now let's play with the first probe

sr = probes{1}.samplerate(1);

disp(['The sample rate of probe 1 epoch 1 is ' num2str(sr) '.']);

disp(['We will now plot the data for epoch 1 for analog_input channel 1.']);

[data,time] = probes{1}.read_epochsamples(1,0,10000);

figure;
plot(time,data(:,1));
ylabel('Data on channel 1 of probe 1');
xlabel('Time (s)');
box off;

