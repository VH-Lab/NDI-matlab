% NDI_DAQREADER_MFDAQ - Multifunction DAQ reader class
%
% The ndi.daq.reader.mfdaq object class.
%
% This object allows one to address multifunction data acquisition systems that
% sample a variety of data types potentially simultaneously. 
%
% The channel types that are supported are the following:
% Channel type (string):      | Description
% -------------------------------------------------------------
% 'analog_in'   or 'ai'       | Analog input
% 'analog_out'  or 'ao'       | Analog output
% 'digital_in'  or 'di'       | Digital input
% 'digital_out' or 'do'       | Digital output
% 'time'        or 't'        | Time
% 'auxiliary_in','aux' or 'ax'| Auxiliary channels
% 'event', or 'e'             | Event trigger (returns times of event trigger activation)
% 'mark', or 'mk'             | Mark channel (contains value at specified times)
% 
%
% See also: ndi.daq.reader.mfdaq/ndi.daq.reader.mfdaq
%

classdef mfdaq < ndi.daq.reader
	properties (GetAccess=public,SetAccess=protected)

	end
	properties (Access=private) % potential private variables
	end

	methods
		function obj = mfdaq(varargin)
			% ndi.daq.reader.mfdaq - Create a new multifunction DAQ object
			%
			%  D = ndi.daq.reader.mfdaq()
			%
			%  Creates a new ndi.daq.reader.mfdaq object.
			%  This is an abstract class that is overridden by specific devices.
				obj = obj@ndi.daq.reader(varargin{:});
		end; % ndi.daq.reader.mfdaq

		% functions that override ndi.epoch.epochset

                function ec = epochclock(ndi_daqreader_mfdaq_obj, epoch_number)
                        % EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
                        %
                        % EC = EPOCHCLOCK(NDI_DAQREADER_MFDAQ_OBJ, EPOCH_NUMBER)
                        %
                        % Return the clock types available for this epoch as a cell array
                        % of ndi.time.clocktype objects (or sub-class members).
			% 
			% For the generic ndi.daq.reader.mfdaq, this returns a single clock
			% type 'dev_local'time';
			%
			% See also: ndi.time.clocktype
                        %
                                ec = {ndi.time.clocktype('dev_local_time')};
                end % epochclock

		function t0t1 = t0_t1(ndi_epochset_obj, epochfiles)
			% EPOCHCLOCK - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCHFILES)
			%
			% Return the beginning (t0) and end (t1) times of the epoch defined by EPOCHFILES.
			%
			% The abstract class always returns {[NaN NaN]}.
			%
			% See also: ndi.time.clocktype, EPOCHCLOCK
			%
				t0t1 = {[NaN NaN]};
		end % t0t1

		function channels = getchannelsepoch(ndi_daqreader_mfdaq_obj, epochfiles)
			% GETCHANNELSEPOCH - List the channels that were sampled for this epoch
			%
			%  CHANNELS = GETCHANNELSEPOCH(NDI_DAQREADER_MFDAQ_OBJ, EPOCHFILES)
			%
			%  Returns the channel list of acquired channels in these EPOCHFILES
			%
			%  The channels are of different types. In the below, 
			%  'n' is replaced with the channel number.
			%  Type       | Description
			%  ------------------------------------------------------
			%  ain        | Analog input (e.g., ai1 is the first input channel)
			%  din        | Digital input (e.g., di1 is the first input channel)
			%  t          | Time - a time channel
			%  axn        | Auxillary inputs
			%
			% CHANNELS is a structure list of all channels with fields:
			% -------------------------------------------------------
			% 'name'             | The name of the channel (e.g., 'ai1')
			% 'type'             | The type of data stored in the channel
			%                    |    (e.g., 'analog_input', 'digital_input', 'image', 'timestamp')
			%
				channels = struct('name',[],'type',[]);  
				channels = channels([]);
		end; % getchannelsepoch

		function data = readchannels_epochsamples(ndi_daqreader_mfdaq_obj, channeltype, channel, epochfiles, s0, s1)
			%  FUNCTION READ_CHANNELS - read the data based on specified channels
			%
			%  DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCH ,S0, S1)
			%
			%  CHANNELTYPE is the type of channel to read
			%
			%  CHANNEL is a vector of the channel numbers to read, beginning from 1
			%
			%  EPOCH is the epoch number to read from.
			%
			%  DATA will have one column per channel.
			%
				data = []; % abstract class 
		end % readchannels_epochsamples()

		function [timestamps, data] = readevents_epochsamples(ndi_daqreader_mfdaq_obj, channeltype, channel, epochfiles, t0, t1)
                        %  READEVENTS_EPOCHSAMPLES - read events, markers, and digital events of specified channels for a specified epoch
                        %
                        %  [TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES(NDR_READER_OBJ, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, T0, T1)
                        %
                        %  Returns TIMESTAMPS and DATA corresponding to event or marker channels. If the number of CHANNEL entries is 1, then TIMESTAMPS
                        %  is a column vector of type double, and DATA is also a column of a type that depends on the type of event that is read.
                        %  If the number of CHANNEL entries is more than 1, then TIMESTAMPS and DATA are both columns of cell arrays, with 1 column
                        %  per channel.
                        % 
                        %  CHANNELTYPE is a cell array of strings, describing the type of each channel to read, such as
                        %      'event'  - TIMESTAMPS mark the occurrence of each event; DATA is a logical 1 for each timestamp
                        %      'marker' - TIMESTAMPS mark the occurence of each event; each row of DATA is the data associated with the marker (type double)
                        %      'text' - TIMESTAMPS mark the occurence of each event; DATA is a cell array of character arrays, 1 per event
                        %      'dep' - Create events from a digital channel with positive transitions. TIMESTAMPS mark the occurence of each event and
                        %              DATA entries will be a 1
                        %      'dimp' - Create events from a digital channel by finding impulses that exhibit positive then negative transitions. TIMESTAMPS
                        %               mark the occurrence of each event, and DATA indicates whether the event is a positive transition (1) or negative (-1)
                        %               transition.
                        %      'den' - Create events from a digital channel with negative transitions. TIMESTAMPS mark the occurrence of each event and
                        %              DATA entries will be a -1.
                        %      'dimn' - Create events from a digital channel by finding impulses that exhibit negative then positive transitions. TIMESTAMPS
                        %               mark the occurence of each event, and DATA indicates whether the event is a negative transition (1) or a positive
                        %               transition (-1).
                        %
                        %  CHANNEL is a vector with the identity(ies) of the channel(s) to be read.
                        %
                        %  EPOCHSFILES is a cell array of full path file names
			%  
				if ~isempty(intersect(channeltype,{'dep','den','dimp','dimn'})),
					timestamps = {};
					data = {};
					for i=1:numel(channel),
						% optimization speed opportunity
						srd = ndi_daqreader_mfdaq_obj.samplerate(epochfiles,{'di'}, channel(i));
						s0d = 1+round(srd*t0);
						s1d = 1+round(srd*t1);
						data_here = ndi_daqreader_mfdaq_obj.readchannels_epochsamples(repmat({'di'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
						time_here = ndi_daqreader_mfdaq_obj.readchannels_epochsamples(repmat({'time'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
						if any(strcmp(channeltype{i},{'dep','dimp'})), % look for 0 to 1 transitions
							transitions_on_samples = find( (data_here(1:end-1)==0) & (data_here(2:end) == 1));
							if strcmp(channeltype{i},'dimp'),
								transitions_off_samples = 1+ find( (data_here(1:end-1)==1) & (data_here(2:end) == 0));
							else,
								transitions_off_samples = [];
							end;
						elseif any(strcmp(channeltype{i},{'den','dimn'})), % look for 1 to 0 transitions
							transitions_on_samples = find( (data_here(1:end-1)==1) & (data_here(2:end) == 0));
							if strcmp(channeltype{i},'dimp'),
								transitions_off_samples = 1+ find( (data_here(1:end-1)==0) & (data_here(2:end) == 1));
							else,
								transitions_off_samples = [];
							end;
						end;
						timestamps{i} = [ndr.data.colvec(time_here(transitions_on_samples)); ndr.data.colvec(time_here(transitions_off_samples)) ];
						data{i} = [ones(numel(transitions_on_samples),1); -ones(numel(transitions_off_samples),1) ];
						if ~isempty(transitions_off_samples),
							[dummy,order] = sort(timestamps{i}(:,1));
							timestamps{i} = timestamps{i}(order,:);
							data{i} = data{i}(order,:); % sort by on/off
						end;
					end;

					if numel(channel)==1,
						timestamps = timestamps{1};
						data = data{1};
					end;
				else,
					% if the user doesn't want a derived channel, we need to read it from the file natively (using the class's reader function)
					[timestamps, data] = ndr_reader_obj.readevents_epochsamples_native(channeltype, ...
						channel, epochstreams, epoch_select, t0, t1); % abstract class
				end;

		end; % readevents_epochsamples

		function [timestamps, data] = readevents_epochsamples_native(ndi_daqreader_mfdaq_obj, channeltype, channel, epochfiles, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events or markers of specified channels for a specified epoch
			%
			%  [TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES_NATIVE(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
			%
			%  CHANNELTYPE is the type of channel to read
			%  ('event','marker', etc). It must be a string (not a cell array of strings).
			%  
			%  CHANNEL is a vector with the identity of the channel(s) to be read.
			%  
			%  EPOCH is the epoch number or epochID
			%
			%  DATA is a two-column vector; the first column has the time of the event. The second
			%  column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
			%  is requested, DATA is returned as a cell array, one entry per channel.
			%
			%  TIMEREF is an ndi.time.timereference with the NDI_CLOCK of the device, referring to epoch N at time 0 as the reference.
			%  
				timestamps = {};
				data = {}; % abstract class
		end; % readevents_epochsamples

                function sr = samplerate(ndi_daqreader_mfdaq_obj, epochfiles, channeltype, channel)
			% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
			%
			% SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
			%
			% SR is an array of sample rates from the specified channels
			%
			% CHANNELTYPE can be either a string or a cell array of
			% strings the same length as the vector CHANNEL.
			% If CHANNELTYPE is a single string, then it is assumed that
			% that CHANNELTYPE applies to every entry of CHANNEL.
				sr = []; % abstract class;
		end;

	end; % methods
end % classdef

