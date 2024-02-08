% NDI_DAQSYSTEM_MFDAQ - Multifunction DAQ object class
%
% The ndi.daq.system.mfdaq object class.
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
% See also: ndi.daq.system.mfdaq/ndi.daq.system.mfdaq
%

classdef mfdaq < ndi.daq.system

	properties (GetAcces=public,SetAccess=protected)
	end
	properties (Access=private) % potential private variables
	end

	methods
		function obj = mfdaq(varargin)
			% ndi.daq.system.mfdaq - Create a new multifunction DAQ object
			%
			%  D = ndi.daq.system.mfdaq(NAME, THEFILENAVIGATOR)
			%
			%  Creates a new ndi.daq.system.mfdaq object with NAME, and FILENAVIGATOR.
			%  This is an abstract class that is overridden by specific devices.
				obj = obj@ndi.daq.system(varargin{:});

				if ~isempty(obj.daqreader),
					if ~isa(obj.daqreader,'ndi.daq.reader.mfdaq'),
						error(['The DAQREADER for an ndi.daq.system.mfdaq object must be a type of ndi.daq.reader.mfdaq.']);
					end;
				end;
		end; % ndi.daq.system.mfdaq

		% functions that override ndi.epoch.epochset

                function ec = epochclock(ndi_daqsystem_mfdaq_obj, epoch)
                        % EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
                        %
                        % EC = EPOCHCLOCK(NDI_DAQSYSTEM_MFDAQ_OBJ, EPOCH)
                        %
                        % Return the clock types available for this epoch as a cell array
                        % of ndi.time.clocktype objects (or sub-class members).
			% 
			% For the generic ndi.daq.system.mfdaq, this returns a single clock
			% type 'dev_local'time';
			%
			% See also: ndi.time.clocktype
                        %
				epochfiles = ndi_daqsystem_mfdaq_obj.filenavigator.getepochfiles(epoch);
				if ~ndi.file.navigator.isingested(epochfiles),
                                	ec = ndi_daqsystem_mfdaq_obj.daqreader.epochclock(epochfiles);
				else,
                                	ec = ndi_daqsystem_mfdaq_obj.daqreader.epochclock_ingested(epochfiles ,...
						ndi_daqsystem_mfdaq_obj.session());
				end;
                end % epochclock()

		function t0t1 = t0_t1(ndi_daqsystem_mfdaq_obj, epoch)
			% T0_T1 - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
			%
			% Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
			% in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
			%
				epochfiles = ndi_daqsystem_mfdaq_obj.filenavigator.getepochfiles(epoch);
				if ~ndi.file.navigator.isingested(epochfiles),
					t0t1 = ndi_daqsystem_mfdaq_obj.daqreader.t0_t1(epochfiles);
				else,
					t0t1 = ndi_daqsystem_mfdaq_obj.daqreader.t0_t1_ingested(epochfiles,...
						ndi_daqsystem_mfdaq_obj.session());
				end;
		end % t0_t1()

		function channels = getchannels(ndi_daqsystem_mfdaq_obj)
			% FUNCTION GETCHANNELS - List the channels that are available on this device
			%
			%  CHANNELS = GETCHANNELS(NDI_DAQSYSTEM_MFDAQ_OBJ)
			%
			%  Returns the channel list of acquired channels in this session
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
			% 'time_channel'     | The time channel that has timing information for that channel
				channels = struct('name',[],'type',[],'time_channel',[]);  
				channels = channels([]);

				N = numepochs(ndi_daqsystem_mfdaq_obj);

				for n=1:N,
					epochfiles = getepochfiles(ndi_daqsystem_mfdaq_obj.filenavigator, n);
					if ~ndi.file.navigator.isingested(epochfiles),
						channels_here = getchannelsepoch(ndi_daqsystem_mfdaq_obj.daqreader, epochfiles);
					else,
						channels_here = getchannelsepoch_ingested(ndi_daqsystem_mfdaq_obj.daqreader, ...
							epochfiles, ndi_daqsystem_mfdaq_obj.session());
					end;
					channels = vlt.data.equnique( [channels(:); channels_here(:)] );
				end
		end; % getchannels

		function channels = getchannelsepoch(ndi_daqsystem_mfdaq_obj, epoch)
			% FUNCTION GETCHANNELSEPOCH - List the channels that are available on this device for an epoch
			%
			%  CHANNELS = GETCHANNELSEPOCH(NDI_DAQSYSTEM_MFDAQ_OBJ, EPOCH)
			%
			%  Returns the channel list of acquired channels in this session
			%  for a given EPOCH (can be epochid or number)
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
			% 'time_channel'     | The time channel that has timing information for that channel
			%
				channels = struct('name',[],'type',[],'time_channel',[]);  
				channels = channels([]);

				epochfiles = getepochfiles(ndi_daqsystem_mfdaq_obj.filenavigator, epoch);
				if ~ndi.file.navigator.isingested(epochfiles),
					channels_here = getchannelsepoch(ndi_daqsystem_mfdaq_obj.daqreader, epochfiles);
				else,
					channels_here = getchannelsepoch_ingested(ndi_daqsystem_mfdaq_obj.daqreader, ...
						epochfiles, ndi_daqsystem_mfdaq_obj.session());
				end;
				channels = vlt.data.equnique( [channels(:); channels_here(:)] );
		end; % getchannels

		function data = readchannels_epochsamples(ndi_daqsystem_mfdaq_obj, channeltype, channel, epoch, s0, s1)
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
				epochfiles = getepochfiles(ndi_daqsystem_mfdaq_obj.filenavigator, epoch);
				if ~ndi.file.navigator.isingested(epochfiles),
					data = ndi_daqsystem_mfdaq_obj.daqreader.readchannels_epochsamples(channeltype, channel, epochfiles, s0, s1);
				else,
					data = ndi_daqsystem_mfdaq_obj.daqreader.readchannels_epochsamples_ingested(channeltype,...
						channel,epochfiles,s0,s1,ndi_daqsystem_mfdaq_obj.session());
				end;
		end % readchannels_epochsamples()

		function data = readchannels(ndi_daqsystem_mfdaq_obj, channeltype, channel, timeref_or_epoch, t0, t1)
			   % because this is an abstract class, only empty records are returned

			%  FUNCTION READCHANNELS - read the data based on specified channels
			%
			%  DATA = READCHANNELS(MYDEV, CHANNELTYPE, CHANNEL, TIMEREF_OR_EPOCH, T0, T1)
			%
			%  CHANNELTYPE is the type of channel to read
			%  ('analog','digitalin','digitalout', etc)
			%  
			%  CHANNEL is a vector with the identity of the channels to be read.
			%  
			%  TIMEREF_OR_EPOCH is either an NDI_CLOCK object indicating the clock for T0, T1, or
			%  it can be a single number, which will indicate the data are to be read from that epoch.
			%
			%  DATA is the data collection for specific channels

				%error('this function presently does not work, needs to know how to get to session');

				if t1<t0,
					error(['t0 must be <= t1']);
				end;

				if isa(timeref_or_epoch,'ndi.time.timereference'),
					exp = ndi_daqsystem_mfdaq_obj.session;
					[t0,epoch0_timeref] = exp.syncgraph.timeconvert(timeref_or_epoch,t0,...
						ndi_daqsystem_mfdaq_obj,ndi.time.clocktype('devlocal'));
					[t1,epoch1_timeref] = exp.syncgraph.timeconvert(timeref_or_epoch,t1,...
						ndi_daqsystem_mfdaq_obj,ndi.time.clocktype('dev_local_time'));
					if epoch0_timeref.epoch~=epoch1_timeref.epoch,
						error(['Do not know how to read across epochs yet; request spanned ' ...
							 ndi_daqsystem_mfdaq_obj.filenavigator.epoch2str(epoch0_timeref.epoch) ...
							' and ' ndi_daqsystem_mfdaq_obj.filenavigator.epoch2str(epoch1_timeref.epoch) '.']);
					end
					epoch = epoch0;
				else,
					epoch = timeref_or_epoch;
				end
				sr = samplerate(ndi_daqsystem_mfdaq_obj, epoch, channeltype, channel);
				if numel(unique(sr))~=1,
					error(['Do not know how to handle multiple sampling rates across channels.']);
				end;
				sr = unique(sr);
				s0 = 1+round(sr*t0);
				s1 = 1+round(sr*t1);
				[data] = readchannels_epochsamples(ndi_daqsystem_mfdaq_obj, channeltype, channel, epoch, s0, s1);
		end %readchannels()

		function [timestamps,data] = readevents(ndi_daqsystem_mfdaq_obj, channeltype, channel, timeref_or_epoch, t0, t1)
			%  FUNCTION READEVENTS - read events or markers of specified channels
			%
			%  [TIMESTAMPS,DATA] = READEVENTS(MYDEV, CHANNELTYPE, CHANNEL, TIMEREF_OR_EPOCH, T0, T1)
			%
			%  CHANNELTYPE is the type of channel to read
			%  ('event','marker', etc)
			%  
			%  CHANNEL is a vector with the identity of the channel(s) to be read.
			%  
			%  TIMEREF_OR_EPOCH is either an ndi.time.timereference object indicating the clock for T0, T1, or
			%  it can be a single number, which will indicate the data are to be read from that epoch.
			%
			%  TIMESTAMPS is an array of the timestamps read. If more than one channel is requested, then TIMESTAMPS
			%  will be a cell array of timestamp arrays, one per channel.
			%
			%  DATA is an array of the event data. If more than one channel is requested, then DATA will be a cell array of
			%  data arrays, one per channel.
			%
				if isa(timeref_or_epoch,'ndi.time.timereference'),
					tref = timeref_or_epoch;
					error(['this function does not handle working with clocks yet.']);
				else,
					epoch = timeref_or_epoch;
					%disp('here, about to call readchannels_epochsamples')
					[timestamps,data] = readevents_epochsamples(ndi_daqsystem_mfdaq_obj,channeltype,channel,epoch,t0,t1);
				end
		end % readevents

		function [timestamps,data,timeref] = readevents_epochsamples(ndi_daqsystem_mfdaq_obj, channeltype, channel, epoch, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events or markers of specified channels for a specified epoch
			%
			%  [TIMESTAMPS, DATA, TIMEREF] = READEVENTS_EPOCHSAMPLES(MYDEV, CHANNELTYPE, CHANNEL, EPOCH, T0, T1)
			%
			%  CHANNELTYPE is the type of channel to read
			%  ('event','marker', etc)
			%  
			%  CHANNEL is a vector with the identity of the channel(s) to be read.
			%  
			%  EPOCH is the epoch number or epochID
			%
			%  TIMESTAMPS is an array of the timestamps read. If more than one channel is requested, then TIMESTAMPS
			%  will be a cell array of timestamp arrays, one per channel.
			%
			%  DATA is an is an array of the event data. For events, values are always 1. If more than one channel
			%  is requested, then DATA will be a cell array of data arrays, one per channel.
			%
			%  TIMEREF is an ndi.time.timereference with the NDI_CLOCK of the device, referring to epoch N at time 0 as the reference.
			%  
				epochfiles = getepochfiles(ndi_daqsystem_mfdaq_obj.filenavigator, epoch);
				epochclocks  = ndi_daqsystem_mfdaq_obj.epochclock(epoch);
				timeref = ndi.time.timereference(ndi_daqsystem_mfdaq_obj, epochclocks{1}, epoch, 0);
				if ~ndi.file.navigator.isingested(epochfiles),
					[timestamps,data]=ndi_daqsystem_mfdaq_obj.daqreader.readevents_epochsamples(channeltype,channel,epochfiles,t0,t1);
				else,
					[timestamps,data]=ndi_daqsystem_mfdaq_obj.daqreader.readevents_epochsamples_ingested(...
						channeltype,channel,epochfiles,t0,t1,ndi_daqsystem_mfdaq_obj.session());
				end;
		end; % readevents_epochsamples

                function sr = samplerate(ndi_daqsystem_mfdaq_obj, epoch, channeltype, channel)
			% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
			%
			% SR = SAMPLERATE(DEV, EPOCH, CHANNELTYPE, CHANNEL)
			%
			% SR is an array of sample rates from the specified channels
			%
			% CHANNELTYPE can be either a string or a cell array of
			% strings the same length as the vector CHANNEL.
			% If CHANNELTYPE is a single string, then it is assumed that
			% that CHANNELTYPE applies to every entry of CHANNEL.

				epochfiles = getepochfiles(ndi_daqsystem_mfdaq_obj.filenavigator, epoch);
				if ~ndi.file.navigator.isingested(epochfiles),
					sr = ndi_daqsystem_mfdaq_obj.daqreader.samplerate(epochfiles, channeltype, channel); 
				else,
					sr = ndi_daqsystem_mfdaq_obj.daqreader.samplerate_ingested(epochfiles, ...
						channeltype, channel, ndi_daqsystem_mfdaq_obj.session()); 
				end;
		end;

	end; % methods

	methods (Static), % functions that don't need the object
		function ct = mfdaq_channeltypes
			% MFDAQ_CHANNELTYPES - channel types for ndi.daq.system.mfdaq objects
			%
			%  CT = MFDAQ_CHANNELTYPES - channel types for ndi.daq.system.mfdaq objects
			%
			%  Returns a cell array of strings of supported channels of the
			%  ndi.daq.system.mfdaq class. These are the following:
			%
			%  Channel type:       | Description: 
			%  -------------------------------------------------------------
			%  analog_in           | Analog input channel
			%  aux_in              | Auxiliary input
			%  analog_out          | Analog output channel
			%  digital_in          | Digital input channel
			%  digital_out         | Digital output channel
			%  marker              | 
			%
			% See also: ndi.daq.system.mfdaq/MFDAQ_TYPE
			ct = { 'analog_in', 'aux_in', 'analog_out', 'digital_in', 'digital_out', 'marker', 'event', 'time' };
		end;

		function prefix = mfdaq_prefix(channeltype)
			% MFDAQ_PREFIX - Give the channel prefix for a channel type
			%
			%  PREFIX = MFDAQ_PREFIX(CHANNELTYPE)
			%
			%  Produces the channel name prefix for a given CHANNELTYPE.
			% 
			% Channel type:               | MFDAQ_PREFIX:
			% ---------------------------------------------------------
			% 'analog_in',       'ai'     | 'ai' 
			% 'analog_out',      'ao'     | 'ao'
			% 'digital_in',      'di'     | 'di'
			% 'digital_out',     'do'     | 'do'
			% 'time','timestamp','t'      | 't'
			% 'auxiliary','aux','ax',     | 'ax'
			%    'auxiliary_in'           | 
			% 'mark', 'marker', or 'mk'   | 'mk'
			% 'event' or 'e'              | 'e'
			% 'metadata' or 'md'          | 'md'
			% 'digital_in_event', 'de',   | 'dep'
			% 'digital_in_event_pos','dep'| 
			% 'digital_in_event_neg','den'| 'den'
			% 'digital_in_mark','dimp',   | 'dimp'
			% 'digital_in_mark_pos','dim' |
			% 'digital_in_mark_neg','dimn'| 'dimn'
			%
			% See also: ndi.daq.system.mfdaq/MFDAQ_TYPE
			%
				switch channeltype,
					case {'analog_in','ai'},
						prefix = 'ai';
					case {'analog_out','ao'},
						prefix = 'ao';
					case {'digital_in','di'},
						prefix = 'di';
					case {'digital_out','do'},
						prefix = 'do';
					case {'digital_in_event','digital_in_event_pos','de','dep'},
						prefix = 'dep';
					case {'digital_in_event_neg','den'},
						prefix = 'den';
					case {'digital_in_mark', 'digital_in_mark_pos','dim','dimp'},
						prefix = 'dimp';
					case {'digital_in_mark_neg','dimn'},
						prefix = 'dimn';
					case {'time','timestamp','t'},
						prefix = 't';
					case {'auxiliary','aux','ax','auxiliary_in'},
						prefix = 'ax';
					case {'marker','mark','mk'},
						prefix = 'mk';
					case {'event','e'},
						prefix = 'e';
					case {'metadata','md'},
						prefix = 'md';
				end;
		end % mfdaq_prefix()

		function type = mfdaq_type(channeltype)
			% MFDAQ_TYPE - Give the preferred long channel type for a channel type
			%
			%  TYPE = MFDAQ_TYPE(CHANNELTYPE)
			%
			%  Produces the preferred long channel type name for a given CHANNELTYPE.
			% 
			% Channel type:               | MFDAQ_TYPE:
			% ---------------------------------------------------------
			% 'analog_in',       'ai'     | 'analog_in' 
			% 'analog_out',      'ao'     | 'analog_out'
			% 'digital_in',      'di'     | 'digital_in'
			% 'digital_out',     'do'     | 'digital_out'
			% 'time','timestamp','t'      | 'time'
			% 'auxiliary','aux','ax',     | 'auxiliary'
			%    'auxiliary_in'           | 
			% 'mark', 'marker', or 'mk'   | 'mark'
			% 'event' or 'e'              | 'event'
			%
			% See also: ndi.daq.system.mfdaq/MFDAQ_PREFIX
			%
				switch channeltype,
					case {'analog_in','ai'},
						type = 'analog_in';
					case {'analog_out','ao'},
						type = 'analog_out';
					case {'digital_in','di'},
						type = 'digital_in';
					case {'digital_out','do'},
						type = 'digital_out';
					case {'time','timestamp','t'},
						type = 'time';
					case {'auxiliary','aux','ax','auxiliary_in'},
						type = 'ax';
					case {'marker','mark','mk'},
						type = 'mark';
					case {'event','e'},
						type = 'event';
				end;
		end 
	
	end % methods (Static)
end

