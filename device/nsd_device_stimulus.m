classdef nsd_device_stimulus < nsd_device
% NSD_DEVICE_STIMULUS - Create a new NSD_DEVICE_STIMULUS class handle object
%
%  D = NSD_DEVICE_STIMULUS(NAME, THEFILETREE)
%
%  Creates a new NSD_DEVICE_STIMULUS object with name and specific file tree object.
%  This is an abstract class that is overridden by specific devices.


	properties (GetAccess=public, SetAccess=protected)
	end

	methods
		function obj = nsd_device_stimulus(varargin)
			% NSD_DEVICE_STIMULUS - create a new NSD_DEVICE_STIMULUS object
			%
			%  OBJ = NSD_DEVICE_STIMULUS(NAME, THEFILETREE)
			%
			%  Creates an NSD_DEVICE_STIMULUS with name NAME and NSD_FILETREE
			%  THEFILETREE. THEFILETREE is an interface object to the raw data files
			%  on disk that are read by the NSD_DEVICE_STIMULUS.
			%
			%  NSD_DEVICE_STIMULUS is an abstract class, and a specific implementation must be called.
			%
			obj = obj@nsd_device(varargin{:});
			obj.clock = nsd_clock('dev_local_time');
		end % nsd_device_stimulus

		function parameters = get_stimulus_parameters(nsd_device_stimulus_obj, epoch_number)
			% 
			% PARAMETERS = NSD_GET_STIMULUS_PARAMETERS(NSD_DEVICE_STIMULUS_OBJ, EPOCH_NUMBER)
			%
			% Returns the parameters (array, struct array, or cell array) associated with the
			% stimulus or stimuli that were prepared to be presented in epoch EPOCH_NUMBER.
			%
			parameters = []; % abstract
		end
	end % methods
end
