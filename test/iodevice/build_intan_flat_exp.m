function build_intan_flat_exp(dirname)
% BUILD_INTAN_FLAT_EXP - Create an Intan driver and save it to an experiment
%
%  BUILD_INTAN_FLAT_EXP([DIRNAME])
%
%  Given a directory with RHD data inside, this function loads the
%  channel information and then plots some data from channel 1,
%  as an example of the Intan driver. It also leaves the driver saved
%  in the experiment record.
%
%  If DIRNAME is not provided, the default directory
%  [NSDPATH]/example_experiments/exp1_eg_saved is used.
%

if nargin<1,
	nsd_globals;

	mydirectory = [nsdpath filesep 'example_experiments' ];
	dirname = [mydirectory filesep 'exp1_eg_saved'];
end;

disp(['creating a new experiment object...']);
exp = nsd_experiment_dir('exp1',dirname);

disp(['Now adding our acquisition iodevice (intan):']);

  % Step 1: Prepare the data tree; we will just look for .rhd
  %         files in any organization within the directory

dt = nsd_filetree(exp, '.*\.rhd\>');  % look for .rhd files

  % Step 2: create the device object and add it to the experiment:

dev1 = nsd_iodevice_mfdaq_intan('intan1',dt);
exp.iodevice_add(dev1);
 
  % Step 3: let's add a variable

myvardir = nsd_variable_branch(exp.variable,'Animal parameters',{'nsd_variable'});
myvar = nsd_variable('Animal age','double',30,'The age of the animal at the time of the experiment (days)','');
myvardir.add(myvar);

  % Now let's print some statistics

disp(['The channels we have on this device are the following:']);

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



