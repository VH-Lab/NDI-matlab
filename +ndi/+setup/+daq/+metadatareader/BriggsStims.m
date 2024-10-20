classdef BriggsStims < ndi.daq.metadatareader
% NDI_DAQMETADATAREADER_BRIGGSSTIMS - a class for reading stims from Angelucci lab example data
%
% 

	properties (GetAccess=public, SetAccess=protected)
	end;
	properties (Access=private)
	end;

	methods

		function obj = BriggsStims(varargin)
			% NDI_DAQMETADATAREADER_BRIGGS_STIMS - Create a new multifunction DAQ object
			%
			%  D = NDI_DAQMETADATAREADER_BRIGGS_STIMS()
			%  or
			%  D = ndi.daq.metadatareader(STIMDATA_MAT_FILE)
			%
			%  Creates a new ndi.daq.metadatareader object. If TSVFILE_REGEXPRESSION
			%  is given, it indicates a regular expression to use to search EPOCHFILES
			%  for a tab-separated-value text file that describes stimulus parameters.
			%
				obj = obj@ndi.daq.metadatareader(varargin{:});
		end; % ndi.daq.metadatareader.BriggsStims

		function [parameters,stimorder,stimtimes] = readmetadatafromfile(ndi_daqmetadatareader_angelucci_stims_obj, file)
			% PARAMETERS = READMETADATAFROMFILE - read in metadata from the file that is identified
			%
			% PARAMETERS = READMETADATAFROMFILE(NDI_DAQMETADATAREADER_BRIGGS_STIMS_OBJ, FILE)
			%
			% Given a file that matches the metadata search criteria for an NDI_DAQMETADATAREADER_BRIGGS_STIMS
			% document, this function loads in the metadata.
				z = load(file,'-mat');
				
				base_parameters = z.stimData;
				base_parameters.stimParams = rmfield(base_parameters.stimParams,{'stimOrder','Value'});
				parameters = {};
				stimorder = z.stimData.stimParams.stimOrder(:);
				stimtimes = z.stimData.stimTimes(:);
				for i=1:numel(z.stimData.stimParams.Value), % if stimIDs change, this will use last value
					stimid = z.stimData.stimParams.stimOrder(i);
					params_here = base_parameters;
					params_here.Value = z.stimData.stimParams.Value(i);
					parameters{stimid} = params_here;
				end;
		end; % readmetadatafromfile()

	end; % methods

end % classdef
