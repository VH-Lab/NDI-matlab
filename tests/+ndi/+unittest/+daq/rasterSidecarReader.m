classdef rasterSidecarReader < ndi.daq.reader.image.ndr
    % rasterSidecarReader - test double: an image.ndr reader that also supplies raster metadata
    %
    % A subclass of ndi.daq.reader.image.ndr (used with the 'tiffstack'
    % reader) that overrides metadata() to load a standardized
    % image-metadata struct from a 'raster.mat' sidecar (variable 'm') in the
    % epoch's directory. Everything else (frames, frametimes, geometry) comes
    % from the real tiffstack reader.
    %
    % This lets imageRasterTimingTest exercise ndi.probe.image/linetimes and
    % /pixeltimes end to end with controlled raster parameters, and it
    % survives the getprobes document round-trip because the metadata is read
    % from disk (not held in an object property) and the concrete class name
    % is recorded in the daqreader_ndr document.
    %
    % See also: ndi.daq.reader.image.ndr, ndi.probe.image/linetimes

    methods
        function obj = rasterSidecarReader(varargin)
            % rasterSidecarReader - construct the test reader (forwards to image.ndr)
            obj = obj@ndi.daq.reader.image.ndr(varargin{:});
        end % rasterSidecarReader()

        function m = metadata(obj, epochfiles)
            % METADATA - load the standardized metadata struct from raster.mat
            m = ndi.daq.reader.image.emptymetadata();
            if isempty(epochfiles), return; end
            d = fileparts(epochfiles{1});
            f = fullfile(d, 'raster.mat');
            if isfile(f)
                S = load(f, 'm');
                m = S.m;
            end
        end % metadata()
    end % methods
end % classdef
