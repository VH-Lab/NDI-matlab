classdef RayoLabStims < ndi.daq.metadatareader
    %NDI.DAQ.METADATAREADER.RAYOLABSTIMS Trivial metadata reader for the RayoLab stimulator.
    %
    %   The RayoLab stimulator emits a single stimulus type whose
    %   only parameter is its stimulus id, which is always 1. This
    %   metadata reader does not read any per-stimulus content from disk;
    %   it returns one parameter set:
    %
    %       parameters{1} = struct('stimid', 1);
    %
    %   The single entry is keyed at index 1 to match the stimulus id
    %   reported on the mk2 marker channel by
    %   ndi.setup.daq.reader.mfdaq.stimulus.rayolab_intanseries.
    %
    %   The constructor accepts the same arguments as
    %   ndi.daq.metadatareader (typically a filename regular expression
    %   identifying the metadata file inside an epoch's file list); the
    %   pattern is stored but not consulted, since the parameters are
    %   constant.

    methods
        function obj = RayoLabStims(varargin)
            obj = obj@ndi.daq.metadatareader(varargin{:});
        end

        function parameters = readmetadatafromfile(~, ~)
            %READMETADATAFROMFILE Return the constant RayoLab parameter set.
            %
            %   PARAMETERS = READMETADATAFROMFILE(OBJ, FILE) ignores FILE
            %   and returns {struct('stimid', 1)}.
            parameters = {struct('stimid', 1)};
        end
    end
end
