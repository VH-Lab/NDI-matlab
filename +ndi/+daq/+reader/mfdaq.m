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
% 'mark', or 'mk'             | Mark channel (contains int16 value at specified times)
% 'text', or 'tx'             | Text mark channel (contains character string at specified time)
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

		function ec = epochclock(ndi_daqreader_mfdaq_obj, epochfiles)
			% EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
			%
			% EC = EPOCHCLOCK(NDI_DAQREADER_MFDAQ_OBJ, EPOCHFILES)
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

			%012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789 - 80 characters for documentation

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
			% 'time_channel'     | The number of the time channel that contains the time information
			%                    |    for the channel. Can be NaN when not applicable.
			%
				channels = struct('name',[],'type',[],'time_channel',[]);  
				channels = channels([]);
		end; % getchannelsepoch

			%012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789 - 80 characters for documentation

		function [channels,fullchannelinfo] = getchannelsepoch_ingested(ndi_daqreader_mfdaq_obj, epochfiles, S)
			% GETCHANNELSEPOCH_INGESTED - List the channels that were sampled for this epoch
			%
			%  CHANNELS = GETCHANNELSEPOCH_INGESTED(NDI_DAQREADER_MFDAQ_OBJ, EPOCHFILES, S)
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
			% 'time_channel'     | The number of the time channel that contains the time information
			%                    |    for the channel. Can be NaN when not applicable.
			%
				d = ndi_daqreader_mfdaq_obj.getingesteddocument(epochfiles,S);
				tname = ndi.database.fun.copydocfile2temp(d,S,'channel_list.bin','');
				mfdaq_epoch_channel_obj = ndi.file.type.mfdaq_epoch_channel(tname);
				delete(tname);
				fullchannelinfo = mfdaq_epoch_channel_obj.channel_information;
				to_remove = setdiff(fieldnames(fullchannelinfo),{'name','type','time_channel'});
				channels = rmfield(fullchannelinfo,to_remove);
		end; % getchannelsepoch_ingested

		function data = readchannels_epochsamples(ndi_daqreader_mfdaq_obj, channeltype, channel, epochfiles, s0, s1)
			%  READ_CHANNELS_EPOCHSAMPLES - read the data based on specified channels
			%
			%  DATA = READ_CHANNELS_EPOCHSAMPLES(NDI_DAQREADER_MFDAQ_OBJ, CHANNELTYPE, CHANNEL, ...
			%    EPOCHFILES, S0, S1)
			%
			%  CHANNELTYPE is the type of channel to read. It can either be a single string or a cell
			%    array with one entry per channel.
			%
			%  CHANNEL is a vector of the channel numbers to read, beginning from 1
			%
			%  EPOCHFILES is the set of epochfiles to read from
			%
			%  S0 is the sample where reading should start, and S1 is sample where reading should end.
			%
			%  DATA will have one column per channel.
			%
				data = []; % abstract class 
		end % readchannels_epochsamples()

		function data = readchannels_epochsamples_ingested(ndi_daqreader_mfdaq_obj, channeltype, channel, epochfiles, s0, s1, S)
			%  READ_CHANNELS_EPOCHSAMPLES_INGESTED - read the data based on specified channels
			%
			%  DATA = READ_CHANNELS_EPOCHSAMPLES_INGESTED(NDI_DAQREADER_MFDAQ_OBJ, CHANNELTYPE, ...
			%    CHANNEL, EPOCHFILES, S0, S1, S)
			%
			%  CHANNELTYPE is the type of channel to read
			%
			%  CHANNEL is a vector of the channel numbers to read, beginning from 1
			%
			%  EPOCHFILES is the set of epochfiles to read from
			%
			%  S0 is the sample where reading should start, and S1 is sample where reading should end.
			%
			%  DATA will have one column per channel.
			%

				mylog = ndi.common.getLogger();
				d = ndi_daqreader_mfdaq_obj.getingesteddocument(epochfiles,S);

				if ~iscell(channeltype),
					channeltype = repmat({channeltype},numel(channel),1);
				end;
				channeltype = ndi.daq.reader.mfdaq.standardize_channel_types(channeltype);

				ch_unique = unique(channeltype);

				if numel(ch_unique)~=1,
					error(['Only one type of channel may be read per function call at present.']);
				end;

				[sr,offset,scale] = ndi_daqreader_mfdaq_obj.samplerate_ingested(epochfiles, channeltype, channel, S);

				sr_unique = unique(sr);
				if numel(sr_unique)~=1,
					error(['Do not know how to handle different sampling rates across channels in one function call.']);
				end;

				sr = sr_unique;

				t0_t1 = ndi_daqreader_mfdaq_obj.t0_t1_ingested(epochfiles,S);
				absolute_beginning = ndi.time.fun.times2samples(t0_t1{1}(1),t0_t1{1},sr);
				absolute_end = ndi.time.fun.times2samples(t0_t1{1}(2),t0_t1{1},sr);

				if isinf(s0) | isinf(s1), % need to figure out actual values if user gave -inf/inf for either value
					if isinf(s0),
						s0 = absolute_beginning;
					end;
					if isinf(s1),
						s1 = absolute_end;
					end;
				end;

				using_absolute_end = 0;
				if s1==absolute_end,
					using_absolute_end = 1;
				end;                    

				if s0>s1,
					error(['sample number s0 must be less than or equal to s1.']);
				end;

				% we have two issues here:
				%   1) identify the groups to which the requested channels belong
				[dummy,fullchannelinfo] = ndi_daqreader_mfdaq_obj.getchannelsepoch_ingested(epochfiles,S);

				[groups,channel_indexes_in_groups,channel_indexes_in_output] = ...
					ndi.file.type.mfdaq_epoch_channel.channelgroupdecoding(fullchannelinfo,ch_unique{1},channel);


				%   2) identify the segments in which the requested samples belong
				data = NaN(s1-s0+1,numel(channel));

				switch(ch_unique{1}),
					case {'analog_in','analog_out','auxiliary_in','auxiliary_out'},
						samples_segment = d.document_properties.daqreader_mfdaq_epochdata_ingested.parameters.sample_analog_segment;
						use_ephys = 1;
						use_time = 0;
					case {'digital_in','digital_out'},
						samples_segment = d.document_properties.daqreader_mfdaq_epochdata_ingested.parameters.sample_digital_segment;
						use_ephys = 0;
						use_time = 0;
					case {'time'},
						samples_segment = d.document_properties.daqreader_mfdaq_epochdata_ingested.parameters.sample_analog_segment;                        
						use_time = 1;
						use_ephys = 0;
					otherwise,
						error(['Unknown channel type ' ch_unique{1} '. Use readevents for events, markers, text markers, etc.']);
				end;
				[mytypes,myabbrev] = ndi.daq.reader.mfdaq.channel_types();
				ind = find(strcmp(ch_unique{1},mytypes));
				prefix = myabbrev{ind};
				if strcmp(ch_unique{1},'time'),
					prefix = 'ti';
				end;

				SEG_start = ceil(s0/samples_segment);
				SEG_stop = ceil(s1/samples_segment);

				count = 0;
				for seg = SEG_start : SEG_stop,
					s0_ = 1;
					if seg==SEG_start,
						s0_ = mod(s0,samples_segment);
						if s0_ == 0 % it's the last sample),
							s0_ = samples_segment;
						end;
					end;
					s1_ = samples_segment;
					if seg==SEG_stop,
						s1_ = mod(s1,samples_segment);
						if s1_ == 0 % it's the last sample),
							s1_ = samples_segment;
						end;
					end;

					samples_here = s0_:s1_;

					for g = 1:numel(groups),
						fname = [prefix '_group' int2str(groups(g)) '_seg.nbf_' int2str(seg)];
						[tname,tname_without_extension] = ndi.database.fun.copydocfile2temp(d,S,fname,'.nbf.tgz');
						if use_ephys,
							data_here = ndi.compress.expand_ephys(tname_without_extension);
						elseif ~use_time,
							data_here = ndi.compress.expand_digital(tname_without_extension);
						else,
							data_here = ndi.compress.expand_time(tname_without_extension);
						end;
						delete(tname);

						if using_absolute_end&seg==SEG_stop,
							% we should read from 1 ... s1_ and get at least s1_ samples.
							if size(data_here,1)==s1_-1, % if we are short 1 sample at the bitter end, it's okay
								s1_ = s1_ - 1; % drop the last sample
								samples_here(end) = []; % drop the last sample
								data(end,:) = []; % drop the last sample
								mylog.msg('debug',5,['ndi.daq.reader.mfdaq.readchannels_epochsamples_ingested dropping a sample; can happen if reading from a channel that is sampled at a different rate than the rate that determines the time...']);
							elseif size(data_here,1)<s1_-1, % if we are more than 1 sample short, complain
								error(['I''m confused; data does not have the size I expect']);
							end;
						end;
						data((1+count):(count+numel(samples_here)),channel_indexes_in_output{g}) = ...
							data_here(s0_:s1_,channel_indexes_in_groups{g});
					end;
					count = count + numel(samples_here);
				end;
				data = ndi.compress.underlying2scaled(data,[offset scale]);

		end % readchannels_epochsamples_ingested()

		function [timestamps, data] = readevents_epochsamples(ndi_daqreader_mfdaq_obj, channeltype, channel, epochfiles, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events, markers, and digital events of specified channels for a specified epoch
			%
			%  [TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES(NDR_READER_OBJ, CHANNELTYPE, CHANNEL, ...
			%     EPOCHFILES, T0, T1)
			%
			%  Returns TIMESTAMPS and DATA corresponding to event or marker channels. If the number
			%  of CHANNEL entries is 1, then TIMESTAMPS is a column vector of type double, and DATA is
			%  also a column of a type that depends on the type of event that is read.  If the number
			%  of CHANNEL entries is more than 1, then TIMESTAMPS and DATA are both columns of cell
			%  arrays, with 1 column per channel.
			% 
			%  CHANNELTYPE is a cell array of strings, describing the type of each channel to read:
			%      'event'  - TIMESTAMPS mark the occurrence of each event; DATA is a logical 1 for
			%                    each timestamp
			%      'marker' - TIMESTAMPS mark the occurence of each event; each row of DATA is the
			%                    data associated with the marker (type double)
			%      'text'   - TIMESTAMPS mark the occurence of each event; DATA is a cell array of
			%                    character arrays, 1 per event
			%      'dep'    - Create events from a digital channel with positive transitions.
			%                    TIMESTAMPS mark the occurence of each event and DATA entries are 1
			%      'dimp'   - Create events from a digital channel by finding impulses that exhibit
			%                    positive then negative transitions. TIMESTAMPS mark the occurrence
			%                    of each event, and DATA indicates whether the event is a positive
			%                    transition (1) or negative (-1) transition.
			%      'den'    - Create events from a digital channel with negative transitions.
			%                    TIMESTAMPS mark the occurrence of each event and DATA entries are -1.
			%      'dimn'   - Create events from a digital channel by finding impulses that exhibit
			%                    negative then positive transitions. TIMESTAMPS mark the occurence of
			%                    each event, and DATA indicates whether the event is a negative
			%                    transition (1) or a positive transition (-1).
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
					[timestamps, data] = ndi_daqreader_mfdaq_obj.readevents_epochsamples_native(channeltype, ...
						channel, epochfiles, t0, t1); % abstract class
				end;

		end; % readevents_epochsamples

		function [timestamps, data] = readevents_epochsamples_ingested(ndi_daqreader_mfdaq_obj, channeltype, channel, epochfiles, t0, t1, S)
			%  READEVENTS_EPOCHSAMPLES_INGESTED - read events, markers, and digital events of specified channels for a specified epoch
			%
			%  [TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES_INGESTED(NDR_READER_OBJ, CHANNELTYPE, ...
			%     CHANNEL, EPOCHFILES, T0, T1)
			%
			%  Returns TIMESTAMPS and DATA corresponding to event or marker channels. If the number
			%  of CHANNEL entries is 1, then TIMESTAMPS is a column vector of type double, and DATA is
			%  also a column of a type that depends on the type of event that is read.  If the number
			%  of CHANNEL entries is more than 1, then TIMESTAMPS and DATA are both columns of cell
			%  arrays, with 1 column per channel.
			% 
			%  CHANNELTYPE is a cell array of strings, describing the type of each channel to read:
			%      'event'  - TIMESTAMPS mark the occurrence of each event; DATA is a logical 1 for
			%                    each timestamp
			%      'marker' - TIMESTAMPS mark the occurence of each event; each row of DATA is the
			%                    data associated with the marker (type double)
			%      'text'   - TIMESTAMPS mark the occurence of each event; DATA is a cell array of
			%                    character arrays, 1 per event
			%      'dep'    - Create events from a digital channel with positive transitions.
			%                    TIMESTAMPS mark the occurence of each event and DATA entries are 1
			%      'dimp'   - Create events from a digital channel by finding impulses that exhibit
			%                    positive then negative transitions. TIMESTAMPS mark the occurrence
			%                    of each event, and DATA indicates whether the event is a positive
			%                    transition (1) or negative (-1) transition.
			%      'den'    - Create events from a digital channel with negative transitions.
			%                    TIMESTAMPS mark the occurrence of each event and DATA entries are -1.
			%      'dimn'   - Create events from a digital channel by finding impulses that exhibit
			%                    negative then positive transitions. TIMESTAMPS mark the occurence of
			%                    each event, and DATA indicates whether the event is a negative
			%                    transition (1) or a positive transition (-1).
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
						srd = ndi_daqreader_mfdaq_obj.samplerate_ingested(epochfiles,{'di'}, channel(i),S);
						s0d = 1+round(srd*t0);
						s1d = 1+round(srd*t1);
						data_here = ndi_daqreader_mfdaq_obj.readchannels_epochsamples_ingested(repmat({'di'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d,S);
						time_here = ndi_daqreader_mfdaq_obj.readchannels_epochsamples_ingested(repmat({'time'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d,S);
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
					% if the user doesn't want a derived channel, we need to read it from the file from ingested epochfiles
					
					d = ndi_daqreader_mfdaq_obj.getingesteddocument(epochfiles,S);
					% need to fix this so it works with mixed channeltypes
					%[groups,channel_indexes_in_groups,channel_indexes_in_output] = ...
					%	ndi.file.type.mfdaq_epoch_channel.channelgroupdecoding(fullchannelinfo,ch_unique{1},channel);

					if ~iscell(channeltype),
						channeltype = repmat({channeltype},numel(channel),1);
					end;
					channeltype = ndi.daq.reader.mfdaq.standardize_channel_types(channeltype);

					groups = 1; g = 1;
					prefix = 'evmktx';
					fname = [prefix '_group' int2str(groups(g)) '_seg.nbf_1'];
					try,
						[tname,tname_without_extension] = ndi.database.fun.copydocfile2temp(d,S,fname,'.nbf.tgz');
					catch,
						error(['No event data found for this epoch.']);
					end;
					[channeltype_out,channel_out,T,D] = ndi.compress.expand_eventmarktext(tname_without_extension);
					delete(tname);

					order = [];
					for i=1:numel(channel),
						order_here = find(strcmp(channeltype{i},channeltype_out) & channel_out==channel(i));
						if isempty(order_here),
							error(['Channel type ' channeltype{i} ' and channel ' int2str(channel(i)) ' not found.']);
						end;
						order(i) = order_here;
					end;

					timestamps = T(order);
					data = D(order);

					for i=1:numel(timestamps),
						included = find(timestamps{i} >=t0 & timestamps{i} <= t1);
						timestamps{i} = timestamps{i}(included,:);
                        data{i} = data{i}(:); % make sure we are column
						data{i} = data{i}(included,:);
					end;

					if numel(timestamps)==1, % only one entry,
						timestamps = timestamps{1};
						data = data{1};
					end;
				end;

		end; % readevents_epochsamples_ingested


		function [timestamps, data] = readevents_epochsamples_native(ndi_daqreader_mfdaq_obj, channeltype, channel, epochfiles, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events or markers of specified channels for a specified epoch
			%
			%  [TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES_NATIVE(MYDEV, CHANNELTYPE, CHANNEL, ...
			%     EPOCHFILES, T0, T1)
			%
			%  CHANNELTYPE is the type of channel to read
			%  ('event','marker', etc). It must be a string (not a cell array of strings).
			%  
			%  CHANNEL is a vector with the identity of the channel(s) to be read.
			%  
			%  EPOCH is the epoch number or epochID
			%
			%  T is a two-column vector; the first column has the time of the event. The second
			%  column indicates the marker code. In the case of 'events', this is just 1. If more
			%  than one channel is requested, DATA is returned as a cell array, one entry per channel.
			%
			%  TIMEREF is an ndi.time.timereference with the NDI_CLOCK of the device, referring to
			%  epoch N at time 0 as the reference.
			%  
				timestamps = {};
				data = {}; % abstract class
		end; % readevents_epochsamples_native ()

			%012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789 - 80 characters for documentation
                function sr = samplerate(ndi_daqreader_mfdaq_obj, epochfiles, channeltype, channel)
			% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
			%
			% SR = SAMPLERATE(NDI_DAQREADER_MFDAQ_OBJ, EPOCHFILES, CHANNELTYPE, CHANNEL)
			%
			% SR is an array of sample rates from the specified channels
			%
			% CHANNELTYPE can be either a string or a cell array of
			% strings the same length as the vector CHANNEL.
			% If CHANNELTYPE is a single string, then it is assumed that
			% that CHANNELTYPE applies to every entry of CHANNEL.
				sr = []; % abstract class;
		end; % samplerate()

			%012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789 - 80 characters for documentation
                function [sr,offset,scale] = samplerate_ingested(ndi_daqreader_mfdaq_obj, epochfiles, channeltype, channel, S)
			% SAMPLERATE_INGESTED - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
			%
			% SR = SAMPLERATE_INGESTED(NDI_DAQREADER_MFDAQ_OBJ, EPOCHFILES, CHANNELTYPE, CHANNEL, S)
			%
			% SR is an array of sample rates from the specified channels
			%
			% CHANNELTYPE can be either a string or a cell array of
			% strings the same length as the vector CHANNEL.
			% If CHANNELTYPE is a single string, then it is assumed that
			% that CHANNELTYPE applies to every entry of CHANNEL.

				d = ndi_daqreader_mfdaq_obj.getingesteddocument(epochfiles,S);
				tname = ndi.database.fun.copydocfile2temp(d,S,'channel_list.bin','');
				mfdaq_epoch_channel_obj = ndi.file.type.mfdaq_epoch_channel(tname);
				delete(tname);
				fullchannelinfo = mfdaq_epoch_channel_obj.channel_information;

				if ~iscell(channeltype),
					channeltype = repmat({channeltype},numel(channel),1);
				end;
				channeltype = ndi.daq.reader.mfdaq.standardize_channel_types(channeltype);

				sr = [];
                offset = [];
                scale = [];
				for i=1:numel(channel),
					index_here = find( strcmp(channeltype{i},{fullchannelinfo.type}) & ...
						([fullchannelinfo.number]==channel(i)) );
					if isempty(index_here), 
						error(['No such channel: ' channeltype{i} ' : ' int2str(channel(i)) '.']);
					end;
					sr(i) = fullchannelinfo(index_here).sample_rate;
                    offset(i) = fullchannelinfo(index_here).offset;
                    scale(i) = fullchannelinfo(index_here).scale;
				end;
				sr = sr(:);
                offset = offset(:);
                scale = scale(:);

		end; % samplerate_ingested

                function [datatype,p,datasize] = underlying_datatype(ndi_daqreader_mfdaq_obj, epochfiles, channeltype, channel)
			% UNDERLYING_DATATYPE - get the underlying data type for a channel in an epoch
			%
			% [DATATYPE,P,DATASIZE] = UNDERLYING_DATATYPE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
			%
			% Return the underlying datatype for the requested channel.
			%
			% DATATYPE is a type that is suitable for passing to FREAD or FWRITE
			%  (e.g., 'float64', 'uint16', etc. See help fread.)
			%
			% P is a ,atrix of polynomials that converts between the double data that is returned by
			% READCHANNEL. RETURNED_DATA = (RAW_DATA+P(i,1))*P(i,2)+(RAW_DATA+P(i,1))*P(i,3) ...
            % There is one row of P for each entry of CHANNEL.
			%
			% DATASIZE is the sample size in bits.
			%
			% CHANNELTYPE must be a string. It is assumed that
			% that CHANNELTYPE applies to every entry of CHANNEL.
			%
				switch(channeltype),
					case {'analog_in','analog_out','auxiliary_in','time'},
						% For the abstract class, keep the data in doubles. This will always work but may not
						% allow for optimal compression if not overridden
						datatype = 'float64';
						datasize = 64;
						p = repmat([0 1],numel(channel),1);
					case {'digital_in','digital_out'},
						datatype = 'char';
						datasize = 8;
						p = repmat([0 1],numel(channel),1);
					case {'eventmarktext','event','marker','text'},
						datatype = 'float64';
						datasize = 64;
						p = repmat([0 1],numel(channel),1);
					otherwise,
						error(['Unknown channel type ' channeltype '.']);
				end; % 
		end;

			%012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789 - 80 characters for documentation

		function d = ingest_epochfiles(ndi_daqreader_mfdaq_obj, epochfiles, epoch_id)
			% INGEST_EPOCHFILES - create an document that describes the data read by an ndi.daq.reader
			%
			% D = INGEST_EPOCHFILES(NDI_DAQREADER_OBJ, EPOCHFILES, EPOCH_ID)
			%
			% Creates an ndi.document of type 'daqreader_epochdata_ingested' that contains the data
			% for an ndi.daq.reader object. The document D is not added to any database.
			%
			% Example:
			%    D = mydaqreader.ingest_epochfiles(epochfiles,epoch_id);

				sample_analog_segment = 1e6; %(1M)  
				sample_digital_segment = 1e7; % 10M

				mylog = ndi.common.getLogger;

				daqreader_mfdaq_epochdata_ingested.parameters.sample_analog_segment = sample_analog_segment; 
				daqreader_mfdaq_epochdata_ingested.parameters.sample_digital_segment = sample_digital_segment; 

				ec = ndi_daqreader_mfdaq_obj.epochclock(epochfiles);
				ec_ = {};
				for i=1:numel(ec),
					ec_{i} = ec{i}.ndi_clocktype2char();
				end;
				daqreader_epochdata_ingested.epochtable.epochclock = ec_;
				daqreader_epochdata_ingested.epochtable.t0_t1 = ndi_daqreader_mfdaq_obj.t0_t1(epochfiles);

				epochid_struct.epochid = epoch_id;

				d = ndi.document('daqreader_mfdaq_epochdata_ingested', ...
					'daqreader_mfdaq_epochdata_ingested', daqreader_mfdaq_epochdata_ingested,...
					'daqreader_epochdata_ingested',daqreader_epochdata_ingested,...
					'epochid',epochid_struct);
				d = d.set_dependency_value('daqreader_id',ndi_daqreader_mfdaq_obj.id());

				filenames_we_made = {};

				% Step 1: add channel list
				ch = ndi_daqreader_mfdaq_obj.getchannelsepoch(epochfiles);
				% get sampling rate for each channel
				sample_rates = repmat({NaN},numel(ch),1);
				samplerate_types = {'analog_in','analog_out','auxiliary_in','digital_in','digital_out','time'};
				for i=1:numel(samplerate_types),
					indexes_here = find(strcmp(samplerate_types{i},{ch.type}));
					numbers_here = 0 * indexes_here;
					for j=1:numel(indexes_here),
						[dummy,numbers_here(j)] = ndi.fun.channelname2prefixnumber(ch(indexes_here(j)).name);
					end;
					if ~isempty(indexes_here),
						sr = ndi_daqreader_mfdaq_obj.samplerate(epochfiles,samplerate_types{i},numbers_here);
						for j=1:numel(indexes_here),
							sample_rates{indexes_here(j)} = sr(j);
						end;
					end;
				end;
				[ch.sample_rate] = sample_rates{:};
                thepoly1 = {}; thepoly2 = {};
                for i=1:numel(ch),
                    [dummy,chan_number] = ndi.fun.channelname2prefixnumber(ch(i).name);
                    [ut,thepoly,~]=ndi_daqreader_mfdaq_obj.underlying_datatype(epochfiles,ch(i).type,chan_number);
                    thepoly1{i} = thepoly(1);
                    thepoly2{i} = thepoly(2);
                end;
                [ch.offset] = thepoly1{:};
                [ch.scale] = thepoly2{:};

				mfdaq_epoch_channel_obj = ndi.file.type.mfdaq_epoch_channel(ch);
				channel_file_name = ndi.file.temp_name();
				[b,errmsg] = mfdaq_epoch_channel_obj.writeToFile(channel_file_name);
				if ~b,
					error(errmsg);
				end;
				filenames_we_made{end+1} = channel_file_name;
				d = d.add_file('channel_list.bin',channel_file_name);

				ci = mfdaq_epoch_channel_obj.channel_information;  %% need to update to combine eventmarktext
				% Step 2: loop over channels with rigid samples
				types = ndi.daq.reader.mfdaq.channel_types();
				% we will treat event,mark,text with the same file
				index_emt = find( strcmp('event',types) | strcmp('marker',types) | strcmp('text',types) );
				types(index_emt) = [];
				types{end+1} = 'eventmarktext';
				 

				for i = 1:numel(types),
					if strcmp(types{i},'eventmarktext'),
						chan_entries_indexes = find(strcmp('event',{ci.type}) | strcmp('marker',{ci.type}) | strcmp('text',{ci.type}) ); 
					else,
						chan_entries_indexes = find(strcmp(types{i},{ci.type})); 
					end;

					fileprefix = 'ai';
					switch(types{i}),
						case 'analog_in',
							fileprefix = 'ai';
						case 'analog_out',
							fileprefix = 'ao';
						case 'auxiliary_in',
							fileprefix = 'ax';
						case 'digital_in',
							fileprefix = 'di';
						case 'digital_out',
							fileprefix = 'di';
						case 'eventmarktext',
							fileprefix = 'evmktx';
						case 'time',
							fileprefix = 'ti';
					end;

					% now find the groups
					groups = unique([ci(chan_entries_indexes).group]); 
					for g = 1:numel(groups),
						group_indexes = find([ci(chan_entries_indexes).group]==groups(g));
						% Step 2b: check to make sure all channels have the same sampling rate
							% will this work for all channel types? Probably not
						[underlying_format,mypoly,datasize] = ndi_daqreader_mfdaq_obj.underlying_datatype(epochfiles,...
							types{i},[ci(chan_entries_indexes(group_indexes)).number]);
						sample_rates_here = [];
						for k=1:numel(group_indexes),
							sample_rates_here(k) = ndi_daqreader_mfdaq_obj.samplerate(epochfiles, ...
								ci(chan_entries_indexes(group_indexes(k))).type,...
								ci(chan_entries_indexes(group_indexes(k))).number);
						end;

						sample_rates_here_unique = unique(sample_rates_here);
						indexes_nan = find(isnan(sample_rates_here_unique));
						if numel(indexes_nan)>1,
							sample_rates_here_unique(indexes_nan(2:end)) = [];
						end;
						if numel(unique(sample_rates_here_unique))~=1,
							error(['Sample rates are not all identical for ' types{i} ' group ' int2str(groups(g)) '.']);
						end;

						% now, do different things depending upon the underlying data types

						switch ci(chan_entries_indexes(group_indexes(1))).dataclass,
							case 'ephys',
								% read in the data and convert it to its underlying data type 
								%   (e.g., convert from double to uint16 if that's the underlying form)
					
								if isnan(sample_rates_here_unique),
									error(['Analog records have a NaN sample rate.']);
								end;

								channels_here = [ci(chan_entries_indexes(group_indexes)).number];
								t0t1 = ndi_daqreader_mfdaq_obj.t0_t1(epochfiles);
								S0 = 1;
								S1 = 1+ (t0t1{1}(end) - t0t1{1}(1)) * unique(sample_rates_here_unique);

								s_starts = [S0:sample_analog_segment:S1];
								for s=1:numel(s_starts),
									mylog.msg('system',1,['Working on ephys/analog ingestion segment ' int2str(s) ' of ' int2str(numel(s_starts)) '.']);
									s0 = s_starts(s);
									s1 = min(s0+sample_analog_segment-1,S1);
									data = ndi_daqreader_mfdaq_obj.readchannels_epochsamples(repmat({types{i}},1,numel(channels_here)), ...
										channels_here, epochfiles, s0, s1);
									data = ndi.compress.scaled2underlying(data, mypoly);
									output_bit_size = datasize;
									filename_here = ndi.file.temp_name();
									[ratio] = ndi.compress.compress_ephys(data,output_bit_size,filename_here,'data_is_unsigned','u'==lower(underlying_format(1)));
									d = d.add_file([fileprefix '_group' int2str(groups(g)) '_seg.nbf_' int2str(s) ],...
										[filename_here '.nbf.tgz']);
									filenames_we_made{end+1} = [filename_here '.nbf.tgz'];
								end;
							case 'digital',
								% do prep
								if isnan(sample_rates_here_unique),
									error(['Analog records have a NaN sample rate.']);
								end;

								channels_here = [ci(chan_entries_indexes(group_indexes)).number];
								t0t1 = ndi_daqreader_mfdaq_obj.t0_t1(epochfiles);
								S0 = 1;
								S1 = 1+(t0t1{1}(end) - t0t1{1}(1)) * unique(sample_rates_here_unique);
								s_starts = [S0:sample_digital_segment:S1];
								for s=1:numel(s_starts),
									mylog.msg('system',1,['Working on digital ingestion segment ' int2str(s) ' of ' int2str(numel(s_starts)) '.']);
									s0 = s_starts(s);
									s1 = min(s0+sample_digital_segment-1,S1);
									data = ndi_daqreader_mfdaq_obj.readchannels_epochsamples(repmat({types{i}},1,numel(channels_here)), ...
										channels_here, epochfiles, s0, s1);
									data = ndi.compress.scaled2underlying(data, mypoly);
									output_bit_size = datasize;
									filename_here = ndi.file.temp_name();
									[ratio] = ndi.compress.compress_digital(data,filename_here);
									d = d.add_file([fileprefix '_group' int2str(groups(g)) '_seg.nbf_' int2str(s) ],...
										[filename_here '.nbf.tgz']);
									filenames_we_made{end+1} = [filename_here '.nbf.tgz'];
								end;
							case 'eventmarktext',
								mylog.msg('system',1,['Working on event/marker/text ingestion segment 1 of 1.']);
								channels_here = [ci(chan_entries_indexes(group_indexes)).number];
								channeltype = {};
								for ii=1:numel(channels_here),
									channeltype{end+1} = ci(chan_entries_indexes(group_indexes(ii))).type;
								end;
								[T,D] = ndi_daqreader_mfdaq_obj.readevents_epochsamples_native(channeltype,channels_here,epochfiles,-Inf,Inf); 
								filename_here = ndi.file.temp_name();
								ratio = ndi.compress.compress_eventmarktext(channeltype,channels_here,T,D,filename_here);
								d = d.add_file(['evmktx_group' int2str(groups(g)) '_seg.nbf_1'],[filename_here '.nbf.tgz']);
								filenames_we_made{end+1} = [filename_here '.nbf.tgz'];
							case 'time',
								s_starts = [S0:sample_analog_segment:S1];
								for s=1:numel(s_starts),
									mylog.msg('system',1,['Working on time ingestion segment ' int2str(s) ' of ' int2str(numel(s_starts)) '.']);
									s0 = s_starts(s);
									s1 = min(s0+sample_analog_segment-1,S1);
									data = ndi_daqreader_mfdaq_obj.readchannels_epochsamples(types{i}, channels_here, epochfiles, s0, s1);
									filename_here = ndi.file.temp_name();
									[ratio] = ndi.compress.compress_time(data,filename_here);
									d = d.add_file([fileprefix '_group' int2str(groups(g)) '_seg.nbf_' int2str(s) ],...
										[filename_here '.nbf.tgz']);
									filenames_we_made{end+1} = [filename_here '.nbf.tgz'];
								end;

							otherwise,
								error(['Unknown channel type ' types{i} '.']);
						end;
					end;
				end;
		end; % ingest_epochfiles()
	end; % methods

	methods(Static)
		function [types,abbrev] = channel_types()
			% CHANNEL_TYPES - what channel types are possible in an ndi.daq.reader.mfdaq ? 
			%
			% [TYPES, ABBREV] = ndi.daq.reader.mfdaq.channel_types()
			%
			%  Returns a cell array of possible channel types in TYPES, and a corresponding
			%  short abbreviation in the cell array ABBREV.
			%
			% ----------------------------------------------------------------------------
			% | CHANNEL TYPE       | ABBREV  | Description                               |
			% |--------------------|---------|-------------------------------------------|
			% | 'analog_in'        | 'ai'    | Analog input                              |
			% | 'analog_out'       | 'ao'    | Analog output                             | 
			% | 'auxiliary_in'     | 'ax'    | Auxiliary channels                        |
			% | 'digital_in'       | 'di'    | Digital input                             | 
			% | 'digital_out'      | 'do'    | Digital output                            | 
			% | 'event'            | 'e'     | Event trigger (returns times, codes of    |
			% |                    |         |    event trigger activation)              |
			% | 'marker'           | 'mk'    | Mark channel (contains value at specified |
			% |                    |         |    times)                                 |
			% | 'text'             | 'tx'    | Text channel (contains text at specified  |
			% |                    |         |    times)
			% | 'time'             | 't'     | Time samples                              |
			% |--------------------|---------|-------------------------------------------|
			%
				types =  {'analog_in','analog_out','auxiliary_in','digital_in','digital_out','event','marker','text','time'}; 
				abbrev = {'ai'      , 'ao',        'ax',          'di',        'do',         'e',    'mk',  'tx',  't'   };

		end; % channelTypes

		function [stdchanneltypes] = standardize_channel_types(channeltypes)
			% STANDARDIZE_CHANNEL_TYPES - return standard channel type names
			% 
			% STDCHANNELTYPES = STANDARDIZE_CHANNEL_TYPES(CHANNELTYPES)
			%
			% Given a cell array of strings of CHANNELTYPES, replace any abbreviations with
			% with the standard channel type name in ndi.daq.reader.mfdaq.channel_types()
			%
			%
				stdchanneltypes = channeltypes;
				[types,abbrev] = ndi.daq.reader.mfdaq.channel_types();
				for i=1:numel(channeltypes),
				index = find(strcmp(channeltypes{i},abbrev));
					if ~isempty(index),
						stdchanneltypes{i}=types{index};
					end;
				end;
		end; % standardize_channel_types

		function tc = channelsepoch2timechannelinfo(channelsepoch, channeltype, channelnumber)
			% CHANNELSEPCH2TIMECHANNELINFO - look up time channel info
			%
			% TC = CHANNELSEPOCH2TIMECHANNELINFO(CHANNELSEPOCH, CHANNELTYPE, CHANNELNUMBER)
			% 
			% Given a CHANNELSEPOCH struct returned from GETCHANNELSEPOCH, find the time
			% channel number that corresponds to the channel specified by CHANNELTYPE and
			% CHANNELNUMBER.
			%
				if ~iscell(channeltype),
					channeltype = repmat({channeltype},numel(channelnumber),1);
				end;
                channeltype = ndi.daq.reader.mfdaq.standardize_channel_types(channeltype);
                tc = NaN(size(channeltype));
                [types,abbrev] = ndi.daq.reader.mfdaq.channel_types;

                for i=1:numel(channelnumber),
                    index = find(strcmp(channeltype{i},types));
                    chname = [abbrev{index} int2str(channelnumber(i))];
                    otherindex = find(strcmp(chname,{channelsepoch.name}));
                    if ~isempty(otherindex),
                        tc(i) = channelsepoch(otherindex).time_channel;
                    end;
				end;

		end; % channelsepoch2timechannelinfo
	end % methods(Static)
end % classdef

