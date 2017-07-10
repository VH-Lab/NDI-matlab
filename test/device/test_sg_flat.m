function test_sg_flat( dirname )
%TEST_SG_FLAT Summary of this function goes here
%   Detailed explanation goes here

	if nargin < 1,

		nsd_globals

		mydirectory = [nsdpath filesep 'example_experiments' ];
		dirname = [mydirectory filesep 'exp_sg'];
	end;

	%Temporary s0 - s1 to read from
    samples = [1 60000];
    %Samples for refractory period
    refractory_period_samples = 10;
    %Spike samples
    spike_samples = [-10 20];

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

	tetrodes = dev1.getepochcontents(1);

    %for every tetrode i
    %for i=1:length(tetrodes)
        %for all samples loop inf 30000
		%get channels in tetrode
		[~,~,channels] = nsd_devicestring(tetrodes(1).devicestring)
        data = readchannels_epochsamples(dev1,'analog_in',channels,1,1,30000); %str2intseq(tetrodes(1).devicestring)
        %time = readchannels_epochsamples(dev1,'timestamp',1,1,0,Inf);

        %Applies Chebyshev Type I filter to channels
        [b,a] = cheby1(4,0.8,300/(0.5 * 30000),'high');
        data = filtfilt(b,a,data);
        %Transpose to channels in rows, data in columns
        data = data';

        locations = [];

        for j=1:size(data,1) %channel
            %Calculate stdev for same j sample in all channels
            stddev = std(data(j,:));
            %Dot discriminator to find thresholds
            locations{j} = dotdisc(double(data(j,:)),[4 * stddev 1 0]);
            locations{j} = refractory(locations{j}, refractory_period_samples);
            locations{j} = locations{j}(find(locations{j} > -spike_samples(1) & locations{j} <= length(data(j,:))-spike_samples(2)));
        end

		%Makes an array [samples(1):samples(2)] for number of nTrode channels times
		sample_offsets = repmat([samples(1):samples(2)],1,size(data,1));

		keyboard
		%Makes an array with rows (channels in tetrode)(diff(samples of spike))
		%channel_offsets = repmat(my_chan_list(:)',diff(samples)+1,1);
		%
		%single_spike_selection = sample_offsets + (channel_offsets(:)'-1)*size(data,1);
		%
		%spike_selections = repmat(single_spike_selection, length(my_locations), 1) + repmat(my_locations, 1, size(single_spike_selection,2));
		%
		%my_waveforms = single(data(spike_selections));
		%
		%my_waveforms = reshape(my_waveforms,length(my_locations), diff(samples)+1, length(channelgrouping(k).channel_list));
        %keyboard

        figure;
        time = (1:30000);
        time = time /sr_a;
        plot(time,data);
        ylabel('Data');
        xlabel('Time (s)');
        box off;


	exp.device_rm(dev1); % remove the device so the demo works again

end
