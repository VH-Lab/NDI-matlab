% NSD_IODEVICE_MFDAQ_STIMULUS_VHLABVISSPIKE2 - Device object for vhlab visual stimulus computer
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

classdef nsd_iodevice_mfdaq_stimulus_vhlabvisspike2 < nsd_iodevice_mfdaq & nsd_iodevice_stimulus
	properties (GetAcces=public,SetAccess=protected)

	end
	properties (Access=private) % potential private variables
	end

	methods
		function obj = nsd_iodevice_mfdaq_stimulus_vhlabvisspike2(varargin)
			% NSD_IODEVICE_MFDAQ_STIMULUS_VHLABVISSPIKE2 - Create a new multifunction DAQ object
			%
			%  D = NSD_IODEVICE_MFDAQ_STIMULUS_VHLABVISSPIKE2(NAME, THEFILETREE)
			%
			%  Creates a new NSD_IODEVICE_MFDAQ object with NAME, and FILETREE.
			%  This is an abstract class that is overridden by specific devices.
			obj = obj@nsd_iodevice_mfdaq(varargin{:});
		end; % nsd_iodevice_mfdaq_stimulus_vhlabvisspike2()

		function ec = epochclock(nsd_iodevice_mfdaq_stimulus_vhlabvisspike2_obj, epoch_number)
			% EPOCHCLOCK - return the NSD_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NSD_IODEVICE_MFDAQ_STIMULUS_VHLABVISSPIKE2_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch as a cell array
			% of NSD_CLOCKTYPE objects (or sub-class members).
			%
			% This returns a single clock type 'dev_local'time';
			%
			% See also: NSD_CLOCKTYPE
			%
				ec = {nsd_clocktype('dev_local_time')};
		end % epochclock

		function channels = getchannels(thedev)
			% FUNCTION GETCHANNELS - List the channels that are available on this device
			%
			%  CHANNELS = GETCHANNELS(THEDEV)
			%
			% This device produces the following channels in each epoch:
			% Channel name:   | Signal description:
			% ----------------|------------------------------------------
			% mk1             | stimulus on/off
			% mk2             | stimid 
			% mk3             | stimulus open/close
			% e1              | frame trigger
			% e2              | vertical refresh trigger
			% e3              | pretime trigger
			%

			channels        = struct('name','mk1','type','marker');  
			channels(end+1) = struct('name','mk2','type','marker');  
			channels(end+1) = struct('name','mk3','type','marker');  
			channels(end+1) = struct('name','e1','type','event');  
			channels(end+1) = struct('name','e2','type','event');  
			channels(end+1) = struct('name','e3','type','event');  
		end; % getchannels()

		function data = readevents_epochsamples(nsd_iodevice_mfdaq_stimulus_vhlabvisspike2_obj, channeltype, channel, epoch, t0, t1)
			%  FUNCTION READEVENTS - read events or markers of specified channels for a specified epoch
			%
			%  DATA = READEVENTS(SELF, CHANNELTYPE, CHANNEL, EPOCH, T0, T1)
			%
			%  SELF is the NSD_IODEVICE_MFDAQ_STIMULUS_VHVISSPIKE2 object.
			%
			%  CHANNELTYPE is a cell array of strings describing the the type(s) of channel(s) to read
			%  ('event','marker', etc)
			%  
			%  CHANNEL is a vector with the identity of the channel(s) to be read.
			%  
			%  EPOCH is the epoch number or ID string
			%
			%  DATA is a two-column vector; the first column has the time of the event. The second
			%  column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
			%  is requested, DATA is returned as a cell array, one entry per channel.
			%  
				data = {};

				eid = nsd_iodevice_mfdaq_stimulus_vhlabvisspike2_obj.epochid(epoch);
				et = epochtable(nsd_iodevice_mfdaq_stimulus_vhlabvisspike2_obj);
				epoch_number = find(strcmp(eid,{et.epoch_id}));
				if isempty(epoch_number),
					error(['No such epoch ' eid '.']);
				end

				filelist = et(epoch_number).underlying_epochs.underlying;

				pathname = {};
				fname = {};
				ext = {};
				for i=1:numel(filelist),
					[pathname{i},fname{i},ext{i}] = fileparts(filelist{i});
				end

				% do the decoding
				[stimid,stimtimes,frametimes] = read_stimtimes_txt(pathname{1});
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

				for i=1:numel(channel),
					%nsd_iodevice_mfdaq_stimulus_vhlabvisspike2_obj.mfdaq_prefix(channeltype{i}),
					switch (nsd_iodevice_mfdaq_stimulus_vhlabvisspike2_obj.mfdaq_prefix(channeltype{i})),
						case 'mk',
							% put them together, alternating stimtimes and stimofftimes in the final product
							time1 = [stimtimes(:)' ; stimofftimes(:)'];
							data1 = [ones(size(stimtimes(:)')) ; -1*ones(size(stimofftimes(:)'))];
							time1 = reshape(time1,numel(time1),1);
							data1 = reshape(data1,numel(data1),1);
							ch{1} = [time1 data1];
							
							time2 = [stimtimes(:)];
							data2 = [stimid(:)];
							ch{2} = [time2 data2];

							time3 = [stimsetuptimes(:)' ; stimcleartimes(:)'];
							data3 = [ones(size(stimsetuptimes(:)')) ; -1*ones(size(stimcleartimes(:)'))];
							time3 = reshape(time3,numel(time3),1);
							data3 = reshape(data3,numel(data3),1);
							ch{3} = [time3 data3];

							data{i} = ch{channel(i)};
						case 'e',
							if channel(i)==1, % frametimes
								allframetimes = cat(1,frametimes{:});
								data{end+1} = [allframetimes(:) ones(size(allframetimes(:)))];
							elseif channel(i)==2, % vertical refresh
								vr = load(filelist{find(strcmp('verticalblanking',fname))},'-ascii');
								data{end+1} = [vr(:) ones(size(vr(:)))];
							elseif channel(i)==3, % background trigger, simulated
								data{end+1} = [stimsetuptimes(:) ones(size(stimsetuptimes(:)))];
							end
						otherwise,
							error(['Unknown channel.']);
					end
				end

				if numel(data)==1,% if only 1 channel entry to return, make it non-cell
					data = data{1};
				end; 

		end % readevents_epochsamples()

		function t0t1 = t0_t1(nsd_iodevice_mfdaq_stimulus_vhlabvisspike2_obj, epoch_number)
			% EPOCHCLOCK - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NSD_IODEVICE_MFDAQ_STIMULUS_VHLABVISSPIKE2_OBJ, EPOCH_NUMBER)
			%
			% Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
			% in the same units as the NSD_CLOCKTYPE objects returned by EPOCHCLOCK.
			%
			%
			% See also: NSD_CLOCKTYPE, EPOCHCLOCK
			%
				filelist = getepochfiles(nsd_iodevice_mfdaq_stimulus_vhlabvisspike2_obj.filetree, epoch_number);
				filename = nsd_iodevice_mfdaq_stimulus_vhlabvisspike2_obj.cedspike2filelist2smrfile(filelist);
				header = read_CED_SOMSMR_header(filename);

				t0 = 0;  % developer note: the time of the first sample in spike2 is not 0 but 0 + 1/4 * sample interval; might be more correct to use this
				t1 = header.fileinfo.dTimeBase * header.fileinfo.maxFTime * header.fileinfo.usPerTime;
				t0t1 = {[t0 t1]};
		end % t0t1

		function sr = samplerate(nsd_iodevice_mfdaq_stimulus_vhlabvisspike2_obj, epoch, channeltype, channel)
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

		function parameters = get_stimulus_parameters(nsd_iodevice_stimulus_obj, epoch_number)
			%
			% PARAMETERS = NSD_GET_STIMULUS_PARAMETERS(NSD_IODEVICE_STIMULUS_OBJ, EPOCH_NUMBER)
			%
			% Returns the parameters (array, struct array, or cell array) associated with the
			% stimulus or stimuli that were prepared to be presented in epoch EPOCH_NUMBER.
			%
			% In this case, it is the parameters of NEWSTIM stimuli from the VHLab visual stimulus system.
			%

				filelist = nsd_iodevice_stimulus_obj.filetree.getepochfiles(epoch_number);
				pathname = {};
				fname = {};
				ext = {};
				for i=1:numel(filelist),
					[pathname{i},fname{i},ext{i}] = fileparts(filelist{i});
				end

				index = find(strcmp('stims',fname));
				[ss,mti]=getstimscript(pathname{index});

				parameters = {};
				for i=1:numStims(ss),
					parameters{i} = getparameters(get(ss,i));
				end;
		end

	end; % methods

	methods (Static)  % helper functions
		function smrfile = cedspike2filelist2smrfile(filelist)
			% CEDSPIKE2SPIKELIST2SMRFILE - Identify the .SMR file out of a file list
			%
			% FILENAME = CEDSPIKE2FILELIST2SMRFILE(FILELIST)
			%
			% Given a cell array of strings FILELIST with full-path file names,
			% this function identifies the first file with an extension '.smr' (case insensitive)
			% and returns the result in FILENAME (full-path file name).
				for k=1:numel(filelist),
					[pathpart,filenamepart,extpart] = fileparts(filelist{k});
					if strcmpi(extpart,'.smr'),
						smrfile = filelist{k}; % assume only 1 file
						return;
					end; % got the .smr file
				end
				error(['Could not find any .smr file in the file list.']);
		end

	end % static methods
end

