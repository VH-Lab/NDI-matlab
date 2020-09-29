% NDI_DAQSYSTEM_MFDAQ - Multifunction DAQ object class
%
% The ndi.daq.system.mfdaq.mfdaq object class.
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
% See also: ndi.daq.system.mfdaq.mfdaq/ndi.daq.system.mfdaq.mfdaq
%

classdef mfdaq < ndi.daq.system.system

	properties (GetAcces=public,SetAccess=protected)
	end
	properties (Access=private) % potential private variables
	end

	methods
		function obj = ndi.daq.system.mfdaq.mfdaq(varargin)
			% ndi.daq.system.mfdaq.mfdaq - Create a new multifunction DAQ object
			%
			%  D = ndi.daq.system.mfdaq.mfdaq(NAME, THEFILENAVIGATOR)
			%
			%  Creates a new ndi.daq.system.mfdaq.mfdaq object with NAME, and FILENAVIGATOR.
			%  This is an abstract class that is overridden by specific devices.
				obj = obj@ndi.daq.system(varargin{:});

				if ~isempty(obj.daqreader),
					if ~isa(obj.daqreader,'ndi.daq.reader.mfdaq.base'),
						error(['The DAQREADER for an ndi.daq.system.mfdaq.mfdaq object must be a type of ndi.daq.reader.mfdaq.base.']);
					end;
				end;
		end; % ndi.daq.system.mfdaq.mfdaq

		% functions that override ndi.epoch.epochset

                function ec = epochclock(ndi_daqsystem_mfdaq_obj, epoch)
                        % EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
                        %
                        % EC = EPOCHCLOCK(NDI_DAQSYSTEM_MFDAQ_OBJ, EPOCH)
                        %
                        % Return the clock types available for this epoch as a cell array
                        % of ndi.time.clocktype objects (or sub-class members).
			% 
			% For the generic ndi.daq.system.mfdaq.mfdaq, this returns a single clock
			% type 'dev_local'time';
			%
			% See also: ndi.time.clocktype
                        %
				epochfiles = ndi_daqsystem_mfdaq_obj.filenavigator.getepochfiles(epoch);
                                ec = ndi_daqsystem_mfdaq_obj.daqreader.epochclock(epochfiles);
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
				t0t1 = ndi_daqsystem_mfdaq_obj.daqreader.t0_t1(epochfiles);
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
			%
				channels = struct('name',[],'type',[]);  
				channels = channels([]);

				N = numepochs(ndi_daqsystem_mfdaq_obj);

				for n=1:N,
					epochfiles = getepochfiles(ndi_daqsystem_mfdaq_obj.filenavigator, n);
					channels_here = getchannelsepoch(ndi_daqsystem_mfdaq_obj.daqreader, epochfiles);
					channels = vlt.data.equnique( [channels(:); channels_here(:)] );
				end
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
				data = ndi_daqsystem_mfdaq_obj.daqreader.readchannels_epochsamples(channeltype, channel, epochfiles, s0, s1);
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

			error('this function presently does not work, needs to know how to get to session');

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
			[data] = readchannels_epochsamples(ndi_daqsystem_mfdaq_obj, epoch, channeltype, channel, s0, s1);
		end %readchannels()

		function data = readevents(ndi_daqsystem_mfdaq_obj, channeltype, channel, timeref_or_epoch, t0, t1)
			%  FUNCTION READEVENTS - read events or markers of specified channels
			%
			%  DATA = READEVENTS(MYDEV, CHANNELTYPE, CHANNEL, TIMEREF_OR_EPOCH, T0, T1)
			%
			%  CHANNELTYPE is the type of channel to read
			%  ('event','marker', etc)
			%  
			%  CHANNEL is a vector with the identity of the channel(s) to be read.
			%  
			%  TIMEREF_OR_EPOCH is either an ndi.time.timereference object indicating the clock for T0, T1, or
			%  it can be a single number, which will indicate the data are to be read from that epoch.
			%
			%  DATA is a two-column-per-channel vector; the first column has the time of the event. The second
			%  column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
			%  is requested, DATA is returned as a cell array, one entry per channel.
			%

			if isa(timeref_or_epoch,'ndi.time.timereference'),
				tref = timeref_or_epoch;
				error(['this function does not handle working with clocks yet.']);
			else,
				epoch = timeref_or_epoch;
				%disp('here, about to call readchannels_epochsamples')
				[data] = readevents_epochsamples(ndi_daqsystem_mfdaq_obj,channeltype,channel,epoch,t0,t1);
			end
		end % readevents

		function [data, timeref] = readevents_epochsamples(ndi_daqsystem_mfdaq_obj, channeltype, channel, epoch, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events or markers of specified channels for a specified epoch
			%
			%  [DATA, TIMEREF] = READEVENTS_EPOCHSAMPLES(MYDEV, CHANNELTYPE, CHANNEL, EPOCH, T0, T1)
			%
			%  CHANNELTYPE is the type of channel to read
			%  ('event','marker', etc)
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
				epochfiles = getepochfiles(ndi_daqsystem_mfdaq_obj.filenavigator, epoch);
				epochclocks  = ndi_daqsystem_mfdaq_obj.epochclock(epoch);
				timeref = ndi.time.timereference(ndi_daqsystem_mfdaq_obj, epochclocks{1}, epoch, 0);
				data = ndi_daqsystem_mfdaq_obj.daqreader.readevents_epochsamples(channeltype, channel, epochfiles, t0, t1);
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
				sr = ndi_daqsystem_mfdaq_obj.daqreader.samplerate(epochfiles, channeltype, channel); 
		end;

	end; % methods

	methods (Static), % functions that don't need the object
		function ct = mfdaq_channeltypes
			% MFDAQ_CHANNELTYPES - channel types for ndi.daq.system.mfdaq.mfdaq objects
			%
			%  CT = MFDAQ_CHANNELTYPES - channel types for ndi.daq.system.mfdaq.mfdaq objects
			%
			%  Returns a cell array of strings of supported channels of the
			%  ndi.daq.system.mfdaq.mfdaq class. These are the following:
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
			% See also: ndi.daq.system.mfdaq.mfdaq/MFDAQ_TYPE
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
			% See also: ndi.daq.system.mfdaq.mfdaq/MFDAQ_TYPE
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
			% See also: ndi.daq.system.mfdaq.mfdaq/MFDAQ_PREFIX
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

