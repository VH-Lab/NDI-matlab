classdef NielsenLabStims < ndi.daq.metadatareader
    % NDI_DAQMETADATAREADER_NIELSENLABSTIMS - a class for reading NielsenLabStim metadata
    %
    %

    properties (GetAccess=public, SetAccess=protected)
    end
    properties (Access=private)
    end

    methods

        function obj = NielsenLabStims(varargin)
            % ndi.daq.metadatareader.NielsenLabStims - Create a new multifunction DAQ object
            %
            %  D = ndi.daq.metadatareader.NielsenLabStims()
            %  or
            %  D = ndi.daq.metadatareader(TSVFILE_REGEXPRESSION)
            %
            %  Creates a new ndi.daq.metadatareader object. If TSVFILE_REGEXPRESSION
            %  is given, it indicates a regular expression to use to search EPOCHFILES
            %  for a tab-separated-value text file that describes stimulus parameters.
            %
            obj = obj@ndi.daq.metadatareader(varargin{:});
        end % ndi_daqmetadatareader_NielsenLabStims

        function parameters = readmetadatafromfile(ndi_daqmetadatareader_nielsenlabstims_obj, file)
            % READMETADATAFROMFILE - read in metadata from the file that is identified
            %
            % PARAMETERS = READMETADATAFROMFILE(NDI_DAQMETADATAREADER_NIELSENLABSTIMS_OBJ, FILE)
            %
            % Given a file that matches the metadata search criteria for an ndi.daq.metadatareader.NielsenLabStims
            % document, this function loads in the metadata.

            z = load(file,'-mat');
            parameters = ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(z.Analyzer);

        end % readmetadatafromfile()

    end % methods

end % classdef

