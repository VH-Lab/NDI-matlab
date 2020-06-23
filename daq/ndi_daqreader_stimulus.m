classdef ndi_daqreader_stimulus < ndi_daqreader
% NDI_DAQREADER_STIMULUS - an abstract NDI_DAQREADER class for stimulators

	properties (GetAcces=public,SetAccess=protected)

	end
	properties (Access=private) % potential private variables
	end

	methods
		function obj = ndi_daqreader_stimulus(varargin)
			% NDI_DAQREADER_STIMULUS - Create a new multifunction DAQ object
			%
			%  D = NDI_DAQREADER_STIMULUS()
			%
			%  Creates a new NDI_DAQREADER_STIMULUS object
			%  This is an abstract class that is overridden by specific devices.
				obj = obj@ndi_daqreader(varargin{:});
		end; % ndi_daqreader_stimulus

		function parameters = get_stimulus_parameters(ndi_daqsystem_stimulus_obj, epochfiles)
			%
			% PARAMETERS = NDI_GET_STIMULUS_PARAMETERS(NDI_DAQSYSTEM_STIMULUS_OBJ, EPOCHFILES)
			%
			% Returns the parameters (array, struct array, or cell array) associated with the
			% stimulus or stimuli that were prepared to be presented in epoch with file list EPOCHFILES.
			%
			% This abstract class returns empty always.
			%
				parameters = {};
                end; % get_stimulus_parameters()


	end; % methods
end % classdef
