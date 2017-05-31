% NSD_DEVICE_MFDAQ - Multifunction DAQ object class
%
% The NSD_DEVICE_MFDAQ object class.
%
% This object allows one to address multifunction data acquisition systems that
% sample a variety of data types potentially simultaneously. 
%
% The channel types that are supported are the following:
% Channel type (string):   | Description
% -------------------------------------------------------------
% 'analog_in'   or 'ai'    | Analog input
% 'analog_out'  or 'ao'    | Analog output
% 'digital_in'  or 'di'    | Digital input
% 'digital_out' or 'do'    | Digital output
% 'time'        or 't'     | Time
% 'auxiliary'  or 'ax'     | Auxiliary channels
% 
%
% See also: NSD_DEVICE_MFDAQ/NSD_DEVICE_MFDAQ
%
% 

classdef nsd_device_mfdaq < handle & nsd_device
	properties (SetAccess=protected)
		name;
		datatree;
	end
	properties (Access=private) % potential private variables
	end

	methods
		function d = nsd_device_mfdaq(name, thedatatree)
		% NSD_DEVICE_MFDAQ - Create a new multifunction DAQ object
		%
		%  D = NSD_DEVICE_MFDAQ(NAME, THEDATATREE)
		%
		%  Creates a new NSD_DEVICE_MFDAQ object with NAME, DATATREE and associated EXP.
		%  This is an abstract class that is overridden by specific devices.
			if nargin==1,
				error(['Not enough input arguments.']);
			elseif nargin==2,
				obj.name = name;
				obj.datatree = thedatatree;
			else,
				error(['Too many input arguments.']);
			end;

		end; % nsd_device_mfdaq

		function channels = getchannels(thedev)
		% FUNCTION GETCHANNELS - List the channels that are available on this device
		%
		%  CHANNELS = GETCHANNELS(THEDEV)
		%
		%  Returns the channel list of acquired channels in this experiment
		%
		%  The channels are of different types:
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
			   % because this is an abstract class, only empty records are returned
			channels = struct('name',[],'type',[]);  
			channels = channels([]);

		end; % getchannels

		function data = readchannels_epochsamples(self, channeltype, channel, epoch, s0, s1)
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
			data = [];

		end; % readchannels_epochsamples

		function data = readchannels(self, channeltype, channel, clock_or_epoch, t0, t1)
		%  FUNCTION READCHANNELS - read the data based on specified channels
		%
		%  DATA = READCHANNELS(MYDEV, CHANNELTYPE, CHANNEL, CLOCK_OR_EPOCH, T0, T1)
		%
		%  CHANNELTYPE is the type of channel to read
		%  ('analog','digitalin','digitalout', etc)
		%  
		%  CHANNEL is a vector with the identity of the channels to be read.
		%  
		%  CLOCK_OR_EPOCH is either an NSD_CLOCK object indicating the clock for T0, T1, or
		%  it can be a single number, which will indicate the data are to be read from that epoch.
		%
		%  DATA is the data collection for specific channels

			if isa(clock_or_epoch,'nsd_clock'),
				clock = clock_or_epoch;
				error(['this function does not handle working with clocks yet.']);
			else,
				epoch = clock_or_epoch;
				sr = samplerate(self, epoch, channeltype, channel);
				if numel(unique(sr))~=1,
					error(['Do not know how to handle multiple sampling rates across channels.']);
				end;
				sr = unique(sr);
				s0 = 1+round(sr*t0);
				s1 = 1+round(sr*t1);
			end;

			[data] = readchannels_epochsamples(self, epoch, channeltype, channel);

		end %read_channel()

                function sr = samplerate(self, epoch, channeltype, channel)
                %
                % SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
                %
                % SR = SAMPLERATE(DEV, EPOCH, CHANNELTYPE, CHANNEL)
                %
                % SR is an array of sample rates from the specified channels
		%
		% Note: in the abstract class NSD_DEVICE_MFDAQ, this returns empty.
			sr = [];  % this is an abstract class
		end

	end; % methods

	methods (Static), % functions that don't need the object
		function ct = mfdaq_channeltypes
		% MFDAQ_CHANNELTYPES - channel types for NSD_DEVICE_MFDAQ objects
		%
		%  CT = MFDAQ_CHANNELTYPES - channel types for NSD_DEVICE_MFDAQ objects
		%
		%  Returns a cell array of strings of supported channels of the
		%  NSD_DEVICE_MFDAQ class. These are the following:
		%
		%  Channel type:       | Description: 
		%  -------------------------------------------------------------
		%  analog_in           | Analog input channel
		%  aux_in              | Auxiliary input
		%  diagnostic          | Diagnostic channel
		%  analog_out          | Analog output channel
		%  digital_in          | Digital input channel
		%  digital_out         | Digital output channel
		%
			ct = { 'analog_in', 'aux_in', 'diagnostic', 'analog_out', 'digital_in', 'digital_out' };
		end;

	end; % methods (Static)
end;



