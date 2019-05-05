function test_blackrock_flat(dirname)
% TEST_BLACKROCK_FLAT - Test the functionality of the Blackrock driver and a file tree with a flat organization
%
%  TEST_BLACKROCK_FLAT([DIRNAME])
%
%  Given a directory with Blackrock data inside, this function loads the
%  channel information and then plots some data from channel 1,
%  as an example of the Intan driver.
%
%  If DIRNAME is not provided, the default directory
%  [NDIPATH]/example_experiments/exp_blackrock is used.
%
%

if nargin<1,
	ndi_globals;
	dirname = [ndiexampleexperpath filesep 'exp_blackrock'];
end;

disp(['creating a new experiment object...']);
exp = ndi_experiment_dir('exp1',dirname);

disp(['Now adding our acquisition device (blackrock):']);

  % Step 1: Prepare the data tree; we will just look for .rhd
  %         files in any organization within the directory

dt = ndi_filetree(exp, '.*\.ns2\>');  % look for .ns2 files - not exactly right yet, need to modify to find epochs correctly

  % Step 2: create the iodevice object and add it to the experiment:

dev1 = ndi_iodevice_mfdaq_blackrock('blackrock1',dt);
exp.iodevice_add(dev1);

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

exp.iodevice_rm(dev1); % remove the iodevice so the demo can run again

