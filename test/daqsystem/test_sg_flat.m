function test_sg_flat(dirname)
% TEST_SG_FLAT - Test the functionality of the SpikeGadgets driver and a filenavigator with a flat organization
%
% TEST_SG_FLAT([DIRNAME])
%
% Given a directory with .rec data inside, this function loads the
% first tetrode and plots the first second of data in all four channels.
%
% If DIRNAME is not provided, the default directory
% [NDIPATH]/example_sessions/exp1_eg is used.
%
% Developer note: function can be expanded to take in a specific tetrode to plot
% from specific epoch n, along with sample0 and sample1. 

if nargin < 1,
	ndi_globals
	dirname = [ndiexampleexperpath filesep 'exp_sg'];
end;

disp(['creating a new session object...']);
E = ndi_session_dir('exp1',dirname);

disp(['Now adding our acquisition device (sg):']);

% Step 1: Prepare the data tree; we will just look for .rec
%         files in any organization within the directory

dt = ndi_filenavigator(E, '.*\.rec\>');  % look for .rec files

% Step 2: create the daqsystem object and add it to the session:

dev1 = E.daqsystem_load('name','sgtest');
if isempty(dev1),
	dev1 = ndi_daqsystem_mfdaq('sgtest', dt, ndi_daqreader_mfdaq_spikegadgets());
	E.daqsystem_add(dev1);
end

% Now let's print some statistics

disp(['The channels we have on this daqsystem are the following:']);

disp ( struct2table(getchannels(dev1)) );

sr_d = samplerate(dev1,1,'di',1);
sr_a = samplerate(dev1,1,'ai',1);

disp(['The sample rate of digital channel 1 in epoch 1 is ' num2str(sr_d) '.']);
disp(['The sample rate of analog channel 1 in epoch 1 is ' num2str(sr_a) '.']);

tetrodes = dev1.getepochprobemap(1);

disp(['We will now plot the data for ' tetrodes(1).devicestring()]);

[~,~,channels] = ndi_daqsystemstring2channel(ndi_daqsystemstring(tetrodes(1).devicestring));
data = readchannels_epochsamples(dev1, {'analog_in'}, channels, 1, 1, 30000); %(device,channeltype,channels,epoch,s0,s1)

%Applies Chebyshev Type I filter to channels
[b,a] = cheby1(4,0.8,300/(0.5 * 30000),'high');
data = filtfilt(b,a,data);

%Plots all samples read from all four channels
plot_multichan(data,1:30000,400); %(data, timeframe, height)

E.daqsystem_rm(dev1); % remove the device so the demo works again

