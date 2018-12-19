function test_intan_flat_saved(dirname)
% TEST_INTAN_FLAT - Test the functionality of the Intan driver and a file tree with a flat organization
%
%  TEST_INTAN_FLAT_SAVED([DIRNAME])
%
%  Given an experiment directory with an associated Intan driver, 
%  this function loads the channel information and then plots some
%  data from channel 1, as an example of the Intan driver.
%
%  If DIRNAME is not provided, the default directory
%  [NSDPATH]/example_experiments/exp1_eg_saved is used.
%

if nargin<1,
	nsd_globals;
	dirname = [nsdexampleexperpath filesep 'exp1_eg_saved'];
end;

disp(['reading a new experiment object from directory ' dirname ' ... ' ]);
exp = nsd_experiment_dir(dirname);

disp(['Now looking for iodevice Intan1']);

dev1 = exp.iodevice_load('name','Intan1'),

  % Now let's print some statistics

disp(['The channels we have on this iodevice are the following:']);

disp ( struct2table(getchannels(dev1)) );

sr_d = samplerate(dev1,1,{'digital_in'},1);
sr_a = samplerate(dev1,1,{'analog_in'},1);

disp(['The sample rate of digital channel 1 in epoch 1 is ' num2str(sr_d) '.']);
disp(['The sample rate of analog channel 1 in epoch 1 is ' num2str(sr_a) '.']);

disp(['We will now plot the data for epoch 1 for analog_input channel 1.']);

data = readchannels_epochsamples(dev1,{'analog_in'},1,1,0,Inf);
time = readchannels_epochsamples(dev1,{'timestamp'},1,1,0,Inf);

figure;
plot(time,data);
ylabel('Data');
xlabel('Time (s)');
box off;

findmydir = load(exp.database,'name','Animal parameters'),

findmyvar = load(findmydir,'name','Animal age')

keyboard
