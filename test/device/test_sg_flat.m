function test_sg_flat( dirname )
%TEST_SG_FLAT Summary of this function goes here
%   Detailed explanation goes here

if nargin<1,

	mydirectory = [userpath filesep 'tools' filesep 'NSD' ...
                filesep 'example_experiments' ];
	dirname = [mydirectory filesep 'exp_sg'];

end;

disp(['creating a new experiment object...']);
exp = nsd_experiment_dir('exp1',dirname);

disp(['Now adding our acquisition device (sg):']);


  % Step 1: Prepare the data tree; we will just look for .rec
  %         files in any organization within the directory

dt = nsd_filetree(exp, '.*\.rec\>');  % look for .rec files

  % Step 2: create the device object and add it to the experiment:

dev1 = nsd_device_mfdaq_sg('sgtest',dt);
exp.device_add(dev1);

  % Now let's print some statistics

disp(['The channels we have on this device are the following:']);

disp ( struct2table(getchannels(dev1)) );

%sr_d = samplerate(dev1,1,'digital_in',1);
%sg has a global sample rate of 30000, if this changes functions in sg dev
%need to be fixed

sr_d = samplerate(dev1,1);
sr_a = samplerate(dev1,1);

disp(['The sample rate of digital channel 1 in epoch 1 is ' num2str(sr_d) '.']);
disp(['The sample rate of analog channel 1 in epoch 1 is ' num2str(sr_a) '.']);

disp(['We will now plot the data for epoch 1 for analog_in at channel 2 and 4.']);

data = readchannels_epochsamples(dev1,'analog_in',[2 4],1,1,30000);
%time = readchannels_epochsamples(dev1,'timestamp',1,1,0,Inf);

%disp(getepochcontents(dev1,1));

figure;
time = (1:30000);
time = time /sr_a;
plot(time,data);
ylabel('Data');
xlabel('Time (s)');
box off;


exp.device_rm(dev1); % remove the device so the demo works again

end
