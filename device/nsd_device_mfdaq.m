% NSD_DEVICE_MFDAQ - Multifunction DAQ object class
%
% The NSD_DEVICE_MFDAQ object class.
%
% See also: NSD_DEVICE_MFDAQ/NSD_DEVICE/MFDAQ
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
			elseif nargin==5,
				obj.exp = exp;
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
		%  time       | Time - a time channel
		%  aux        | Auxillary inputs
		%
		% CHANNELS is a structure list of all channels with fields:
		% -------------------------------------------------------
		% 'name'             | The name of the channel (e.g., 'ai0')
		% 'type'             | The type of data stored in the channel
		%                    |    (e.g., 'analog', 'digital', 'image', 'timestamp')
		%

			   % because this is an abstract class, only empty records are returned
			channels = struct('name',[],'type',[]);  
			channels = channels([]);

		end; % getchannels
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
		%  aux_in              | Auxilliary input
		%  diagnostic          | Diagnostic channel
		%  analog_out          | Analog output channel
		%  digital_in          | Digital input channel
		%  digital_out         | Digital output channel
		%
			ct = { 'analog_in', 'aux_in', 'diagnostic', 'analog_in', 'digital_in', 'digital_out' };
		end;

	end; % methods (Static)
end;



