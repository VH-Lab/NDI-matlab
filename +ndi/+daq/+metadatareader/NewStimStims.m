classdef ndi_daqmetadatareader_NewStimStims < ndi_daqmetadatareader
% NDI_DAQMETADATAREADER_NEWSTIMSTIMS - a class for reading NewStim metadata 
%
% 

	properties (GetAccess=public, SetAccess=protected)
	end;
	properties (Access=private)
	end;

	methods

		function obj = ndi.daq.metadatareader.NewStimStims(varargin)
			% ndi.daq.metadatareader.NewStimStims - Create a new multifunction DAQ object
			%
			%  D = ndi.daq.metadatareader.NewStimStims()
			%  or
			%  D = ndi.daq.metadatareader.base(TSVFILE_REGEXPRESSION)
			%
			%  Creates a new ndi.daq.metadatareader.base object. If TSVFILE_REGEXPRESSION
			%  is given, it indicates a regular expression to use to search EPOCHFILES
			%  for a tab-separated-value text file that describes stimulus parameters.
			%
				obj = obj@ndi.daq.metadatareader.base(varargin{:});
		end; % ndi_daqmetadatareader_NewStimStim

		function parameters = readmetadatafromfile(ndi_daqmetadatareader_newstimstims_obj, file)
			% PARAMETERS = READMETADATAFROMFILE - read in metadata from the file that is identified
			%
			% PARAMETERS = READMETADATAFROMFILE(NDI_DAQMETADATAREADER_NEWSTIMSTIMS_OBJ, FILE)
			%
			% Given a file that matches the metadata search criteria for an ndi.daq.metadatareader.NewStimStims
			% document, this function loads in the metadata.
				[parentdir,filename,ext] = fileparts(file);
				[ss,mti]=getstimscript(parentdir);
				for i=1:numStims(ss),
					parameters{i} = getparameters(get(ss,i));
				end;
		end; % readmetadatafromfile()

	end; % methods

end % classdef
