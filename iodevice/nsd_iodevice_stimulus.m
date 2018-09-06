classdef nsd_iodevice_stimulus < nsd_iodevice
% NSD_IODEVICE_STIMULUS - Create a new NSD_DEVICE_STIMULUS class handle object
%
%  D = NSD_IODEVICE_STIMULUS(NAME, THEFILETREE)
%
%  Creates a new NSD_IODEVICE_STIMULUS object with name and specific file tree object.
%  This is an abstract class that is overridden by specific devices.


	properties (GetAccess=public, SetAccess=protected)
	end

	methods
		function obj = nsd_iodevice_stimulus(varargin)
			% NSD_IODEVICE_STIMULUS - create a new NSD_DEVICE_STIMULUS object
			%
			%  OBJ = NSD_IODEVICE_STIMULUS(NAME, THEFILETREE)
			%
			%  Creates an NSD_IODEVICE_STIMULUS with name NAME and NSD_FILETREE
			%  THEFILETREE. THEFILETREE is an interface object to the raw data files
			%  on disk that are read by the NSD_IODEVICE_STIMULUS.
			%
			%  NSD_IODEVICE_STIMULUS is an abstract class, and a specific implementation must be called.
			%
			obj = obj@nsd_iodevice(varargin{:});
		end % nsd_iodevice_stimulus

		function ec = epochclock(nsd_iodevice_stimulus_obj, epoch_number)
			% EPOCHCLOCK - return the NSD_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NSD_IODEVICE_STIMULUS_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch as a cell array
			% of NSD_CLOCKTYPE objects (or sub-class members).
			%
			% For the generic NSD_IODEVICE_STIMULUS, this returns a single clock
			% type 'dev_local'time';
			%
			% See also: NSD_CLOCKTYPE
			%
				ec = {nsd_clocktype('dev_local_time')};
		end % epochclock


		function parameters = get_stimulus_parameters(nsd_iodevice_stimulus_obj, epoch_number)
			% 
			% PARAMETERS = NSD_GET_STIMULUS_PARAMETERS(NSD_IODEVICE_STIMULUS_OBJ, EPOCH_NUMBER)
			%
			% Returns the parameters (array, struct array, or cell array) associated with the
			% stimulus or stimuli that were prepared to be presented in epoch EPOCH_NUMBER.
			%
			parameters = []; % abstract
		end
	end % methods
end
