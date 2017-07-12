% NSD_DEVICE_MFDAQ_STIMULUS_VHLABVISSPIKE2 - Device object for vhlab visual stimulus computer
%
% This device reads the 'stimtimes.txt', 'verticalblanking.txt', 'stims.mat', and 'spike2data.smr' files
% that are present in directories where a VHLAB stimulus computer (running NewStim/RunExperiment)
% has produced triggers that have been acquired on a CED Spike2 system running the VHLAB Spike2 script.
%
% This device produces the following channels in each epoch:
% Channel name:   | Signal description:
% ----------------|------------------------------------------
% m1              | stimulus on/off
% m2              | stimid 
% e1              | frame trigger
% e2              | vertical refresh trigger
% e3              | pretime trigger
%

classdef nsd_device_mfdaq_stimulus_vhlabvisspike2 < nsd_device_mfdaq & nsd_device_stimulus
	properties (GetAcces=public,SetAccess=protected)

	end
	properties (Access=private) % potential private variables
	end

	methods
		function obj = nsd_device_mfdaq_stimulus_vhlabvisspike2(varargin)
			% NSD_DEVICE_MFDAQ_STIMULUS_VHLABVISSPIKE2 - Create a new multifunction DAQ object
			%
			%  D = NSD_DEVICE_MFDAQ_STIMULUS_VHLABVISSPIKE2(NAME, THEFILETREE)
			%
			%  Creates a new NSD_DEVICE_MFDAQ object with NAME, and FILETREE.
			%  This is an abstract class that is overridden by specific devices.
			obj = obj@nsd_device_mfdaq(varargin{:});
		end; % nsd_device_mfdaq_stimulus_vhlabvisspike2()

		function channels = getchannels(thedev)
			% FUNCTION GETCHANNELS - List the channels that are available on this device
			%
			%  CHANNELS = GETCHANNELS(THEDEV)
			%
			% This device produces the following channels in each epoch:
			% Channel name:   | Signal description:
			% ----------------|------------------------------------------
			% m1              | stimulus on/off
			% m2              | stimid 
			% e1              | frame trigger
			% e2              | vertical refresh trigger
			% e3              | pretime trigger
			%

			channels        = struct('name','m1','type','marker');  
			channels(end+1) = struct('name','m2','type','marker');  
			channels(end+1) = struct('name','e1','type','event');  
			channels(end+1) = struct('name','e2','type','event');  
			channels(end+1) = struct('name','e3','type','event');  
		end; % getchannels

		function data = readevents_epoch(self, channeltype, channel, n, t0, t1)
			%  FUNCTION READEVENTS - read events or markers of specified channels for a specified epoch
			%
			%  DATA = READEVENTS(MYDEV, CHANNELTYPE, CHANNEL, EPOCH, T0, T1)
			%
			%  CHANNELTYPE is the type of channel to read
			%  ('event','marker', etc)
			%  
			%  CHANNEL is a vector with the identity of the channel(s) to be read.
			%  
			%  EPOCH is the epoch number 
			%
			%  DATA is a two-column vector; the first column has the time of the event. The second
			%  column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
			%  is requested, DATA is returned as a cell array, one entry per channel.
			%  
			data = [];

			filelist = self.filetree.getepochfiles(n);
			pathname = {};
			fname = {};
			ext = {};
			for i=1:numel(filelist),
				[pathname{i},fname{i},ext{i}] = fileparts(filelist{i});
			end

			channeltype = self.mfdaq_prefix(channeltype);

			% do the decoding
			[stimids,stimtimes,frametimes] = read_stimtimes_txt(pathname{1});
			[ss,mti]=getstimscript(pathname{1});
			stimofftimes = [];
			stimsetuptimes = [];
			stimcleartimes = [];
			if numel(mti)~=numel(stimtimes),
				error(['Error: The number of stim triggers present in the stimtimes.txt file (' int2str(numel(stimtimes)) ') as compared to what is expected from the content of stims.mat file (' int2str(length(mti)) ').']);
			end

			for i=1:numel(mti),
				% spike2time = mactime + timeshift
				timeshift = stimtimes(i) - mti{i}.startStopTimes(2);
				stimofftimes(i) = mti{i}.startStopTimes(3) + timeshift;
				stimsetuptimes(i) = mti{i}.startStopTimes(1) + timeshift;
				stimcleartimes(i) = mti{i}.startStopTimes(4) + timeshift;
			end;

			switch (channeltype),
				case 'm',
					% put them together, alternating stimtimes and stimofftimes in the final product
					time1 = [stimtimes(:)' ; stimofftimes(:)'];
					data1 = [ones(size(stimtimes(:)')) ; -1*ones(size(stimofftimes(:)'))];
					time1 = reshape(time1,numel(time1),1);
					data1 = reshape(data1,numel(data1),1);
					ch{1} = [time1 data1];
					
					time2 = [stimtimes(:)];
					data2 = [stimid(:)];
					ch{2} = [time2 data2];
					
					for i=1:numel(channel),
						data = [data ch{channel(i)}];
					end
				case 'e',
					for i=1:numel(channel),
						if channel(i)==1, % frametimes
							allframetimes = cat(2,frametimes{:});
							data = [data allframetimes(:)];
						elseif channel(i)==2, % vertical refresh
							vr = load(filelist{find(strcmp('verticalblanking',fname))},'-ascii');
							data = [data vr(:)];
						elseif channel(i)==3, % background trigger, simulated
							data = [data stimsetuptimes(:)];
						end
					end
				otherwise,
					error(['Unknown channel.']);
			end

		end % readevents_epoch()

                function sr = samplerate(self, epoch, channeltype, channel)
			%
			% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
			%
			% SR = SAMPLERATE(DEV, EPOCH, CHANNELTYPE, CHANNEL)
			%
			% SR is an array of sample rates from the specified channels
			%

			   %so, these are all events, and it doesn't much matter, so
			   % let's make a guess that should apply well in all cases

			sr = 1e-4 * ones(size(channel));
		end
	end; % methods
end

