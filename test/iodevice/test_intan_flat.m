function test_intan_flat(dirname)
% TEST_INTAN_FLAT - Test the functionality of the Intan driver and a file tree with a flat organization
%
%  TEST_INTAN_FLAT([DIRNAME])
%
%  Given a directory with RHD data inside, this function loads the
%  channel information and then plots some data from channel 1,
%  as an example of the Intan driver.
%
%  If DIRNAME is not provided, the default directory
%  [NSDPATH]/example_experiments/exp1_eg is used.
%
%

if nargin<1,
	nsd_globals;
	dirname = [nsdexampleexperpath filesep 'exp1_eg'];
end;

disp(['creating a new experiment object...']);
exp = nsd_experiment_dir('exp1',dirname);

disp(['Now adding our acquisition device (intan):']);

  % Step 1: Prepare the data tree; we will just look for .rhd
  %         files in any organization within the directory

dt = nsd_filetree(exp, '.*\.rhd\>');  % look for .rhd files

  % Step 2: create the iodevice object and add it to the experiment:

dev1 = nsd_iodevice_mfdaq_intan('intan1',dt);
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

