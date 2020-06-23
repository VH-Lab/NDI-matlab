classdef ndi_daqsystem_mfdaq_stimulus < ndi_daqsystem_mfdaq & ndi_daqsystem_stimulus
% NDI_DAQSYSTEM_MFDAQ_STIMULUS - Create a new NDI_DEVICE_MFDAQ STIMULUS class object
%
%  D = NDI_DAQSYSTEM_MFDAQ_STIMULUS(NAME, THEFILENAVIGATOR, THEDAQREADER)
%
%  Creates a new NDI_DAQSYSTEM_MFDAQ, STIMULUS object with name and specific file tree object.
%  This is an abstract class that is overridden by specific devices.


	properties (GetAccess=public, SetAccess=protected)
	end

	methods
		function obj = ndi_daqsystem_mfdaq_stimulus(varargin)
			% NDI_DAQSYSTEM_MFDAQ_STIMULUS - create a new NDI_DEVICE_MFDAQ_STIMULUS object
			%
			%  OBJ = NDI_DAQSYSTEM_MFDAQ_STIMULUS(NAME, THEFILENAVIGATOR, THEDAQREADER)
			%
			%  Creates an NDI_DAQSYSTEM_MFSAQ STIMULUS with name NAME and NDI_FILENAVIGATOR
			%  THEFILENAVIGATOR. THEFILENAVIGATOR is an interface object to the raw data files
			%  on disk that are read by the NDI_DAQSYSTEM_STIMULUS. THEDAQREADER is an NDI_DAQREADER
			%  object for reading from the stimulator's data acqusition system.
			%
			%  NDI_DAQSYSTEM_MFDAQ_STIMULUS is a merger of the NDI_DAQSYSTEM_MFDAQ and NDI_DAQSYSTEM_STIMULUS
			%  classes.
				obj = obj@ndi_daqsystem_mfdaq(varargin{:});
		end % ndi_daqsystem_mfdaq_stimulus
	end % methods
end


