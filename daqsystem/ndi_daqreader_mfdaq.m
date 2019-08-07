% NDI_DAQREADER_MFDAQ - Multifunction DAQ reader class
%
% The NDI_DAQREADER_MFDAQ object class.
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
% See also: NDI_DAQREADER_MFDAQ/NDI_DAQREADER_MFDAQ
%

classdef ndi_daqreader_mfdaq < ndi_daqreader
	properties (GetAcces=public,SetAccess=protected)

	end
	properties (Access=private) % potential private variables
	end

	methods
		function obj = ndi_daqreader_mfdaq(varargin)
			% NDI_DAQREADER_MFDAQ - Create a new multifunction DAQ object
			%
			%  D = NDI_DAQREADER_MFDAQ(NAME, THEFILENAVIGATOR)
			%
			%  Creates a new NDI_DAQREADER_MFDAQ object with NAME, and FILENAVIGATOR.
			%  This is an abstract class that is overridden by specific devices.
			obj = obj@ndi_daqreader(varargin{:});
		end; % ndi_daqreader_mfdaq

		% functions that override ndi_epochset

                function ec = epochclock(ndi_daqreader_mfdaq_obj, epoch_number)
                        % EPOCHCLOCK - return the NDI_CLOCKTYPE objects for an epoch
                        %
                        % EC = EPOCHCLOCK(NDI_DAQREADER_MFDAQ_OBJ, EPOCH_NUMBER)
                        %
                        % Return the clock types available for this epoch as a cell array
                        % of NDI_CLOCKTYPE objects (or sub-class members).
			% 
			% For the generic NDI_DAQREADER_MFDAQ, this returns a single clock
			% type 'dev_local'time';
			%
			% See also: NDI_CLOCKTYPE
                        %
                                ec = {ndi_clocktype('dev_local_time')};
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
			% See also: NDI_CLOCKTYPE, EPOCHCLOCK
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

		function [data] = readevents_epochsamples(ndi_daqreader_mfdaq_obj, channeltype, channel, epochfiles, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events or markers of specified channels for a specified epoch
			%
			%  [DATA] = READEVENTS_EPOCHSAMPLES(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
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
			%  TIMEREF is an NDI_TIMEREFERENCE with the NDI_CLOCK of the device, referring to epoch N at time 0 as the reference.
			%  
				data = []; % abstract class
		end; % readevents_epochsamples

                function sr = samplerate(ndi_daqreader_mfdaq_obj, epoch, channeltype, channel)
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
				sr = []; % abstract class;
		end;

	end; % methods
end % classdef

