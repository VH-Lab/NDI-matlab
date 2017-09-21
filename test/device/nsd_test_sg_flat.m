function nsd_test_sg_flat(dirname)
%NSD_TEST_SG_FLAT - Test the functionality of the SpikeGadgets driver and a filetree with a flat organization
%
% NSD_TEST_SG_FLAT([DIRNAME])
%
% Given a directory with .rec data inside, this function loads the
% first tetrode and plots the first second of data in all four channels.
%
% If DIRNAME is not provided, the default directory
% [NSDPATH]/example_experiments/exp1_eg is used.
%
% Developer note: function can be expanded to take in a specific tetrode to plot
% from specific epoch n, along with sample0 and sample1. 

	if nargin < 1,

		nsd_globals

		mydirectory = [nsdpath filesep 'example_experiments' ];
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

	%sr_d = samplerate(dev1,1,{'digital_in'},1);
	%sg has a global sample rate of 30000, if this changes functions in sg dev
	%need to be fixed

	sr_d = samplerate(dev1,1);
	sr_a = samplerate(dev1,1);

	disp(['The sample rate of digital channel 1 in epoch 1 is ' num2str(sr_d) '.']);
	disp(['The sample rate of analog channel 1 in epoch 1 is ' num2str(sr_a) '.']);

	tetrodes = dev1.getepochcontents(1);

    disp(['We will now plot the data for ' tetrodes(1).devicestring()]);

	[~,~,channels] = nsd_devicestring2channel(nsd_devicestring(tetrodes(1).devicestring));
    data = readchannels_epochsamples(dev1, {'analog_in'}, channels, 1, 1, 30000); %(device,channeltype,channels,epoch,s0,s1)
    %time = readchannels_epochsamples(dev1,{'timestamp'},1,1,0,Inf);

    %Applies Chebyshev Type I filter to channels
    [b,a] = cheby1(4,0.8,300/(0.5 * 30000),'high');
    data = filtfilt(b,a,data);

	%Plots all samples read from all four channels
    plot_multichan(data,1:30000,400); %(data, timeframe, height)

	exp.device_rm(dev1); % remove the device so the demo works again

end
