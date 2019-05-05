classdef ndi_iodevice_stimulus < ndi_iodevice
% NDI_IODEVICE_STIMULUS - Create a new NDI_DEVICE_STIMULUS class handle object
%
%  D = NDI_IODEVICE_STIMULUS(NAME, THEFILETREE)
%
%  Creates a new NDI_IODEVICE_STIMULUS object with name and specific file tree object.
%  This is an abstract class that is overridden by specific devices.


	properties (GetAccess=public, SetAccess=protected)
	end

	methods
		function obj = ndi_iodevice_stimulus(varargin)
			% NDI_IODEVICE_STIMULUS - create a new NDI_DEVICE_STIMULUS object
			%
			%  OBJ = NDI_IODEVICE_STIMULUS(NAME, THEFILETREE)
			%
			%  Creates an NDI_IODEVICE_STIMULUS with name NAME and NDI_FILETREE
			%  THEFILETREE. THEFILETREE is an interface object to the raw data files
			%  on disk that are read by the NDI_IODEVICE_STIMULUS.
			%
			%  NDI_IODEVICE_STIMULUS is an abstract class, and a specific implementation must be called.
			%
			obj = obj@ndi_iodevice(varargin{:});
		end % ndi_iodevice_stimulus

		function ec = epochclock(ndi_iodevice_stimulus_obj, epoch_number)
			% EPOCHCLOCK - return the NDI_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NDI_IODEVICE_STIMULUS_OBJ, EPOCH_NUMBER)
			%
			% Return the clock types available for this epoch as a cell array
			% of NDI_CLOCKTYPE objects (or sub-class members).
			%
			% For the generic NDI_IODEVICE_STIMULUS, this returns a single clock
			% type 'dev_local'time';
			%
			% See also: NDI_CLOCKTYPE
			%
				ec = {ndi_clocktype('dev_local_time')};
		end % epochclock


		function parameters = get_stimulus_parameters(ndi_iodevice_stimulus_obj, epoch_number)
			% 
			% PARAMETERS = NDI_GET_STIMULUS_PARAMETERS(NDI_IODEVICE_STIMULUS_OBJ, EPOCH_NUMBER)
			%
			% Returns the parameters (array, struct array, or cell array) associated with the
			% stimulus or stimuli that were prepared to be presented in epoch EPOCH_NUMBER.
			%
			parameters = []; % abstract
		end
	end % methods
end
