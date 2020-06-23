classdef ndi_daqsystem_stimulus < ndi_daqsystem
% NDI_DAQSYSTEM_STIMULUS - Create a new NDI_DEVICE_STIMULUS class handle object
%
%  D = NDI_DAQSYSTEM_STIMULUS(NAME, THEFILENAVIGATOR)
%
%  Creates a new NDI_DAQSYSTEM_STIMULUS object with name and specific file tree object.
%  This is an abstract class that is overridden by specific devices.


	properties (GetAccess=public, SetAccess=protected)
	end

	methods
		function obj = ndi_daqsystem_stimulus(varargin)
			% NDI_DAQSYSTEM_STIMULUS - create a new NDI_DEVICE_STIMULUS object
			%
			%  OBJ = NDI_DAQSYSTEM_STIMULUS(NAME, THEFILENAVIGATOR, THEDAQREADER)
			%
			%  Creates an NDI_DAQSYSTEM_STIMULUS with name NAME and NDI_FILENAVIGATOR
			%  THEFILENAVIGATOR. THEFILENAVIGATOR is an interface object to the raw data files
			%  on disk that are read by the NDI_DAQSYSTEM_STIMULUS. THEDAQREADER is an NDI_DAQREADER
			%  object for reading from the stimulator's data acqusition system.
			%
			%  NDI_DAQSYSTEM_STIMULUS is an abstract class, and a specific implementation must be called.
			%
				obj = obj@ndi_daqsystem(varargin{:});
		end % ndi_daqsystem_stimulus

		function parameters = get_stimulus_parameters(ndi_daqsystem_stimulus_obj, epoch_number)
			% 
			% PARAMETERS = NDI_GET_STIMULUS_PARAMETERS(NDI_DAQSYSTEM_STIMULUS_OBJ, EPOCH_NUMBER)
			%
			% Returns the parameters (array, struct array, or cell array) associated with the
			% stimulus or stimuli that were prepared to be presented in epoch EPOCH_NUMBER.
			%
                                epochfiles = ndi_daqsystem_stimulus_obj.filenavigator.getepochfiles(epoch_number);
				parameters = ndi_daqsystem_stimulus_obj.daqreader.get_stimulus_parameters(epochfiles);
		end
	end % methods
end


