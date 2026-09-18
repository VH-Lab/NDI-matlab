classdef image < ndi.daq.reader
    % ndi.daq.reader.image - abstract reader for image-series (frame) data
    %
    % ndi.daq.reader.image is the imaging counterpart of ndi.daq.reader.mfdaq.
    % It extends ndi.daq.reader DIRECTLY, as a sibling of mfdaq, NOT a subclass:
    % images are frames on a pixel grid, not (sample x channel) columns, and do
    % not fit the mfdaq 1-D sampled API. This class declares the frame API
    % surface (numframes, readframes, framesize, dimensionorder, datatype,
    % frametimes) and provides a generic ingest/read-ingested implementation.
    %
    % Concrete readers (e.g. ndi.daq.reader.image.ndr, the thin bridge to
    % NDR-matlab) implement the live frame methods. Format reading lives in
    % NDR-matlab; NDI never hand-rolls per-format image readers.
    %
    % Clock model (the imageseries timestamp question):
    %   - The base epochclock is 'no_time' (inherited from ndi.daq.reader):
    %     a clockless slide scan / z-stack is one ordered epoch with no real
    %     time axis; frames are addressed by index.
    %   - A movie overrides epochclock to a real clock ('dev_local_time') and
    %     returns per-frame times from FRAMETIMES, in that clock's units. The
    %     element/probe then surface those times through the NDI epoch clock /
    %     syncgraph system, exactly as ndi.element.timeseries does for ephys.
    %
    % The frame API design is adapted from nansen.stack.ImageStack (VervaekeLab,
    % https://github.com/VervaekeLab/NANSEN); see ndr.reader.tiffstack.
    %
    % See also: ndi.daq.reader, ndi.daq.reader.mfdaq, ndi.daq.reader.image.ndr,
    %   ndi.daq.system.image

    properties (GetAccess=public, SetAccess=protected)
    end

    methods

        function obj = image(varargin)
            % ndi.daq.reader.image - create a new ndi.daq.reader.image object
            %
            %  OBJ = ndi.daq.reader.image()
            %
            %  ndi.daq.reader.image has abstract frame methods; it is meant to
            %  be overridden (see ndi.daq.reader.image.ndr).
            %
            obj = obj@ndi.daq.reader(varargin{:});
        end % ndi.daq.reader.image

        %% live frame API (abstract; concrete readers must override)

        function n = numframes(ndi_daqreader_image_obj, epochfiles)
            % NUMFRAMES - number of frames in an image epoch
            %
            % N = NUMFRAMES(NDI_DAQREADER_IMAGE_OBJ, EPOCHFILES)
            %
            % Abstract: concrete subclasses must override. Adapted from
            % nansen.stack.ImageStack NumTimepoints/NumPlanes.
            error('ndi:daq:reader:image:abstract','numframes must be overridden by a concrete ndi.daq.reader.image subclass.');
        end % numframes()

        function sz = framesize(ndi_daqreader_image_obj, epochfiles)
            % FRAMESIZE - [Y X C Z T] extent of an image epoch, without reading pixels
            %
            % SZ = FRAMESIZE(NDI_DAQREADER_IMAGE_OBJ, EPOCHFILES)
            %
            % Abstract. Adapted from nansen.stack.ImageStack/getFrameSetSize.
            error('ndi:daq:reader:image:abstract','framesize must be overridden by a concrete ndi.daq.reader.image subclass.');
        end % framesize()

        function order = dimensionorder(ndi_daqreader_image_obj, epochfiles)
            % DIMENSIONORDER - dimension order of the returned frames (default 'YXCZT')
            %
            % ORDER = DIMENSIONORDER(NDI_DAQREADER_IMAGE_OBJ, EPOCHFILES)
            %
            % Adapted from nansen.stack.ImageStack DataDimensionOrder.
            order = 'YXCZT';
        end % dimensionorder()

        function dt = datatype(ndi_daqreader_image_obj, epochfiles)
            % DATATYPE - underlying numeric class of the image data
            %
            % DT = DATATYPE(NDI_DAQREADER_IMAGE_OBJ, EPOCHFILES)
            %
            % Abstract. Adapted from nansen.stack.ImageStack DataType.
            error('ndi:daq:reader:image:abstract','datatype must be overridden by a concrete ndi.daq.reader.image subclass.');
        end % datatype()

        function t = frametimes(ndi_daqreader_image_obj, epochfiles, frameind)
            % FRAMETIMES - the time of each requested frame, in EPOCHCLOCK units
            %
            % T = FRAMETIMES(NDI_DAQREADER_IMAGE_OBJ, EPOCHFILES, FRAMEIND)
            %
            % Abstract. Adapted from nansen.stack.ImageStack/getFrameTimes.
            error('ndi:daq:reader:image:abstract','frametimes must be overridden by a concrete ndi.daq.reader.image subclass.');
        end % frametimes()

        function frames = readframes(ndi_daqreader_image_obj, epochfiles, frameind, options)
            % READFRAMES - read image frames from an epoch
            %
            % FRAMES = READFRAMES(NDI_DAQREADER_IMAGE_OBJ, EPOCHFILES, FRAMEIND)
            % FRAMES = READFRAMES(..., 'SelectC', C, 'SelectZ', Z)
            %
            % Returns an array in DIMENSIONORDER (default 'YXCZT') with the
            % timepoints FRAMEIND collapsed to the trailing dimension:
            % [Y X numel(C) numel(Z) numel(FRAMEIND)]. The name/value options
            % 'SelectC' / 'SelectZ' select a subset of the channel / plane axes
            % (default [] = all).
            %
            % Abstract. Adapted from nansen.stack.ImageStack/getFrameSet.
            arguments
                ndi_daqreader_image_obj
                epochfiles
                frameind = []
                options.SelectC (1,:) double = []
                options.SelectZ (1,:) double = []
            end
            error('ndi:daq:reader:image:abstract','readframes must be overridden by a concrete ndi.daq.reader.image subclass.');
        end % readframes()

        function channels = getchannelsepoch(ndi_daqreader_image_obj, epochfiles)
            % GETCHANNELSEPOCH - list channels available for an image epoch
            %
            % CHANNELS = GETCHANNELSEPOCH(NDI_DAQREADER_IMAGE_OBJ, EPOCHFILES)
            %
            % Default: a single 'image' channel named 'image1'. Concrete
            % readers may override.
            channels = vlt.data.emptystruct('name','type','time_channel');
            channels(1).name = 'image1';
            channels(1).type = 'image';
            channels(1).time_channel = [];
        end % getchannelsepoch()

        function m = metadata(ndi_daqreader_image_obj, epochfiles)
            % METADATA - standardized image-acquisition metadata for an epoch
            %
            % M = METADATA(NDI_DAQREADER_IMAGE_OBJ, EPOCHFILES)
            %
            % Returns a struct of standardized image-acquisition metadata for
            % the epoch: the raster-scan timing and geometry that let a caller
            % reconstruct when each line/pixel was sampled, separately from the
            % pixel data. ALL TIME FIELDS ARE IN SECONDS. The struct fields are:
            %
            %   israster        - logical; true if this epoch is a raster scan
            %                     with known line/frame timing
            %   frame_period    - time to acquire one frame (s)
            %   line_period     - time to acquire one scanned line/row (s)
            %   dwell_time      - per-pixel dwell time (s)
            %   lines_per_frame - number of scanned lines (rows) per frame
            %   pixels_per_line - number of pixels (columns) per line
            %   bidirectional   - logical; true if alternate lines are scanned
            %                     in the reverse direction
            %
            % The default returns the "empty" struct (israster=false, NaN
            % timing) from ndi.daq.reader.image.emptymetadata. Concrete readers
            % that can supply acquisition metadata (e.g. ndi.daq.reader.image.ndr
            % forwarding a raster reader) override this. Not every image epoch is
            % a raster scan, and not every raster scan preserves this timing, so
            % callers should check ISRASTER / for NaN fields.
            %
            % See also: ndi.daq.reader.image.emptymetadata,
            %   ndi.daq.reader.image.ndr/metadata, ndi.probe.image/linetimes
            m = ndi.daq.reader.image.emptymetadata();
        end % metadata()

        %% ingestion

        function d = ingest_epochfiles(ndi_daqreader_image_obj, epochfiles, epoch_id)
            % INGEST_EPOCHFILES - create a document with the ingested image data for an epoch
            %
            % D = INGEST_EPOCHFILES(NDI_DAQREADER_IMAGE_OBJ, EPOCHFILES, EPOCH_ID)
            %
            % Creates an ndi.document of type 'daqreader_image_epochdata_ingested'
            % that stores the image frames (as a flat raw binary, 'frames.bin')
            % plus a small queryable header (dimension order/size, data type,
            % number of frames, frame times, clock type) and the epoch clock /
            % t0_t1 of the base daqreader_epochdata_ingested. The document D is
            % NOT added to any database.
            %
            sz = ndi_daqreader_image_obj.framesize(epochfiles);
            dorder = ndi_daqreader_image_obj.dimensionorder(epochfiles);
            dtype = ndi_daqreader_image_obj.datatype(epochfiles);
            n = ndi_daqreader_image_obj.numframes(epochfiles);
            ft = ndi_daqreader_image_obj.frametimes(epochfiles, 1:n);

            ec = ndi_daqreader_image_obj.epochclock(epochfiles);
            ec_ = {};
            for i=1:numel(ec)
                ec_{i} = ec{i}.ndi_clocktype2char();
            end
            daqreader_epochdata_ingested.epochtable.epochclock = ec_;
            daqreader_epochdata_ingested.epochtable.t0_t1 = ndi.fun.doc.t0_t1cell2array(...
                ndi_daqreader_image_obj.t0_t1(epochfiles));

            header.dimension_order = dorder;
            header.dimension_size = sz(:)';
            header.data_type = dtype;
            header.num_frames = n;
            % always store one time per frame as a 1xN row (NaN for clockless
            % epochs). The frametimes field is a matrix in the schema, so it
            % must be a 1-row vector; an empty [] (0x0) fails validation.
            ftrow = ft(:)';
            if isempty(ftrow)
                ftrow = nan(1, max(n,1));
            end
            header.frametimes = ftrow;
            if ~isempty(ec)
                header.clocktype = ec{1}.ndi_clocktype2char();
            else
                header.clocktype = 'no_time';
            end

            % standardized image-acquisition metadata (raster line/frame timing
            % etc., in seconds), so it rides along with the ingested frames and
            % can be read back by metadata_ingested.
            header.metadata = ndi_daqreader_image_obj.metadata(epochfiles);

            epochid_struct.epochid = epoch_id;

            d = ndi.document('daqreader_image_epochdata_ingested', ...
                'daqreader_image_epochdata_ingested', header, ...
                'daqreader_epochdata_ingested', daqreader_epochdata_ingested, ...
                'epochid', epochid_struct);
            d = d.set_dependency_value('daqreader_id', ndi_daqreader_image_obj.id());

            % write the frames to a flat raw binary file (column-major, dtype)
            frames = ndi_daqreader_image_obj.readframes(epochfiles, 1:n);
            framesfile = ndi.file.temp_name();
            fid = fopen(framesfile,'w');
            if fid<0
                error('ndi:daq:reader:image:writefail',['Could not open temp file ' framesfile ' for writing.']);
            end
            fwrite(fid, frames, dtype);
            fclose(fid);
            d = d.add_file('frames.bin', framesfile);
        end % ingest_epochfiles()

        %% read-from-ingested-document API

        function header = ingested_header(ndi_daqreader_image_obj, epochfiles, S)
            % INGESTED_HEADER - return the image header struct from an ingested epoch document
            %
            % HEADER = INGESTED_HEADER(NDI_DAQREADER_IMAGE_OBJ, EPOCHFILES, S)
            %
            d = ndi_daqreader_image_obj.getingesteddocument(epochfiles, S);
            header = d.document_properties.daqreader_image_epochdata_ingested;
        end % ingested_header()

        function n = numframes_ingested(ndi_daqreader_image_obj, epochfiles, S)
            % NUMFRAMES_INGESTED - number of frames for an ingested image epoch
            header = ndi_daqreader_image_obj.ingested_header(epochfiles, S);
            n = header.num_frames;
        end % numframes_ingested()

        function sz = framesize_ingested(ndi_daqreader_image_obj, epochfiles, S)
            % FRAMESIZE_INGESTED - [Y X C Z T] extent for an ingested image epoch
            header = ndi_daqreader_image_obj.ingested_header(epochfiles, S);
            sz = header.dimension_size(:)';
        end % framesize_ingested()

        function order = dimensionorder_ingested(ndi_daqreader_image_obj, epochfiles, S)
            % DIMENSIONORDER_INGESTED - dimension order for an ingested image epoch
            header = ndi_daqreader_image_obj.ingested_header(epochfiles, S);
            order = header.dimension_order;
        end % dimensionorder_ingested()

        function dt = datatype_ingested(ndi_daqreader_image_obj, epochfiles, S)
            % DATATYPE_INGESTED - numeric class for an ingested image epoch
            header = ndi_daqreader_image_obj.ingested_header(epochfiles, S);
            dt = header.data_type;
        end % datatype_ingested()

        function t = frametimes_ingested(ndi_daqreader_image_obj, epochfiles, frameind, S)
            % FRAMETIMES_INGESTED - per-frame times for an ingested image epoch
            header = ndi_daqreader_image_obj.ingested_header(epochfiles, S);
            allt = header.frametimes(:);
            if isempty(allt) % clockless epoch: reconstruct NaN per frame
                allt = nan(header.num_frames,1);
            end
            if nargin<3 || isempty(frameind)
                t = allt;
            else
                t = allt(frameind);
            end
        end % frametimes_ingested()

        function frames = readframes_ingested(ndi_daqreader_image_obj, epochfiles, frameind, S, options)
            % READFRAMES_INGESTED - read frames for an ingested image epoch
            %
            % FRAMES = READFRAMES_INGESTED(NDI_DAQREADER_IMAGE_OBJ, EPOCHFILES, FRAMEIND, S)
            % FRAMES = READFRAMES_INGESTED(..., 'SelectC', C, 'SelectZ', Z)
            %
            % Reads the requested frames back from the 'frames.bin' binary of
            % the ingested document and returns them in 'YXCZT' order with the
            % timepoints collapsed to the trailing dimension. The 'SelectC' /
            % 'SelectZ' options subset the channel / plane axes (default [] =
            % all) by post-selection.
            %
            arguments
                ndi_daqreader_image_obj
                epochfiles
                frameind = []
                S = []
                options.SelectC (1,:) double = []
                options.SelectZ (1,:) double = []
            end
            d = ndi_daqreader_image_obj.getingesteddocument(epochfiles, S);
            header = d.document_properties.daqreader_image_epochdata_ingested;
            sz = header.dimension_size(:)';
            Y = sz(1); X = sz(2); C = sz(3);
            n = header.num_frames;
            dtype = header.data_type;
            if nargin<3 || isempty(frameind)
                frameind = 1:n;
            end
            binobj = S.database_openbinarydoc(d,'frames.bin');
            fname = binobj.fullpathfilename;
            fid = fopen(fname,'r');
            if fid<0
                S.database_closebinarydoc(binobj);
                error('ndi:daq:reader:image:readfail',['Could not open ingested frames file ' fname '.']);
            end
            raw = fread(fid, Y*X*C*n, ['*' dtype]);
            fclose(fid);
            S.database_closebinarydoc(binobj);
            allframes = reshape(raw, [Y X C 1 n]);
            frames = allframes(:,:,:,1,frameind);
            if ~isempty(options.SelectC)
                frames = frames(:,:,options.SelectC,:,:);
            end
            if ~isempty(options.SelectZ)
                frames = frames(:,:,:,options.SelectZ,:);
            end
        end % readframes_ingested()

        function channels = getchannelsepoch_ingested(ndi_daqreader_image_obj, epochfiles, S)
            % GETCHANNELSEPOCH_INGESTED - list channels for an ingested image epoch
            channels = ndi_daqreader_image_obj.getchannelsepoch(epochfiles);
        end % getchannelsepoch_ingested()

        function m = metadata_ingested(ndi_daqreader_image_obj, epochfiles, S)
            % METADATA_INGESTED - image-acquisition metadata for an ingested image epoch
            %
            % M = METADATA_INGESTED(NDI_DAQREADER_IMAGE_OBJ, EPOCHFILES, S)
            %
            % Returns the standardized image-acquisition metadata (see
            % ndi.daq.reader.image/metadata) recorded in the ingested epoch
            % document header. Documents ingested before the metadata field
            % existed do not carry it; in that case the default "empty" struct
            % (ndi.daq.reader.image.emptymetadata) is returned.
            %
            % See also: ndi.daq.reader.image/metadata, ndi.daq.reader.image/ingest_epochfiles
            header = ndi_daqreader_image_obj.ingested_header(epochfiles, S);
            if isfield(header,'metadata') && isstruct(header.metadata)
                m = header.metadata;
            else
                m = ndi.daq.reader.image.emptymetadata();
            end
        end % metadata_ingested()

    end % methods

    methods (Static)
        function m = emptymetadata()
            % EMPTYMETADATA - the standardized image-metadata struct with default (unknown) values
            %
            % M = ndi.daq.reader.image.emptymetadata()
            %
            % Returns the standardized image-acquisition metadata struct used by
            % ndi.daq.reader.image/metadata, with every field at its "unknown"
            % default: israster=false, bidirectional=false, and NaN for each
            % timing/geometry value. This mirrors ndr.reader.base.emptyimagemetadata
            % on the NDR side, so the NDI and NDR structs share the same fields.
            % ALL TIME FIELDS ARE IN SECONDS.
            %
            % See also: ndi.daq.reader.image/metadata
            m = struct('israster', false, ...
                'frame_period', NaN, ...
                'line_period', NaN, ...
                'dwell_time', NaN, ...
                'lines_per_frame', NaN, ...
                'pixels_per_line', NaN, ...
                'bidirectional', false);
        end % emptymetadata()
    end % methods (Static)

end % classdef
