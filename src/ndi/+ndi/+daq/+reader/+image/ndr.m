classdef ndr < ndi.daq.reader.image
    % ndi.daq.reader.image.ndr - read image-series data into NDI using NDR-matlab
    %
    % ndi.daq.reader.image.ndr is a thin BRIDGE that lets an
    % ndi.daq.system.image read image frames through an NDR-matlab reader
    % (ndr.reader). It is the image-series twin of ndi.daq.reader.mfdaq.ndr
    % (which does the same for multichannel/multifunction time-series data).
    %
    % ARCHITECTURE
    %   The object stores a single reader string (e.g. 'tiffstack',
    %   'prairieview', 'imagestack'). Every data call instantiates the
    %   corresponding ndr.reader and forwards to it, performing only NDI-side
    %   adaptation (for example converting ndr.time.clocktype objects to
    %   ndi.time.clocktype objects). This class does NO file I/O of its own;
    %   all file-format decoding lives in NDR-matlab and, for some readers,
    %   in NANSEN (see REQUIREMENTS).
    %
    %       ndi.daq.system.image
    %             |
    %       ndi.daq.reader.image.ndr   (this class: NDI <-> NDR adapter)
    %             |
    %       ndr.reader('<reader string>')
    %             |
    %       ndr.reader.tiffstack / .prairieview / .imagestack / ...  (decoding)
    %
    % FRAME AND DIMENSION MODEL
    %   A "frame" is a single timepoint. Multi-channel (e.g. multi-color)
    %   acquisitions are NOT separate frames: the channels are returned on the
    %   C axis of the pixel array. Frames are addressed by a 1-based index
    %   FRAMEIND into the time (T) axis. The extent of an epoch is reported by
    %   FRAMESIZE as [Y X C Z T] and the axis order of returned arrays by
    %   DIMENSIONORDER (default 'YXCZT'). See FRAMESIZE / READFRAMES.
    %
    % TIME MODEL
    %   EPOCHCLOCK reports the clock(s) for an epoch. A movie with real
    %   per-frame timestamps uses 'dev_local_time' and FRAMETIMES returns those
    %   times (in seconds); a clockless stack (e.g. a z-stack or slide scan)
    %   uses 'no_time' and FRAMETIMES returns NaN. T0_T1 gives the [t0 t1]
    %   bounds per clock. These are what let an image-series epoch participate
    %   in the NDI syncgraph exactly like a time series.
    %
    % EPOCH FILES
    %   Every data method takes EPOCHFILES: a cell array of the file paths that
    %   make up ONE epoch, as assembled by the ndi.file.navigator of the owning
    %   ndi.daq.system.image. EPOCHFILES is passed straight through to the NDR
    %   reader as its EPOCHSTREAMS argument. Because NDI delivers a single
    %   epoch's files per call, the NDR per-file epoch index (EPOCH_SELECT) is
    %   always 1 here.
    %
    % LIVE VS INGESTED
    %   The methods below implement the "live" path, reading from the files on
    %   disk. The parallel "ingested" path (reading frames back from an ingested
    %   ndi.document instead of the original files) is provided generically by
    %   the parent class ndi.daq.reader.image (numframes_ingested,
    %   readframes_ingested, frametimes_ingested, ...) and is not overridden
    %   here.
    %
    % EXAMPLE
    %   % build a reader for multipage-TIFF stacks and read the first 10 frames
    %   r = ndi.daq.reader.image.ndr('tiffstack');
    %   epochfiles = {'/path/to/movie.tif'};
    %   sz     = r.framesize(epochfiles);      % [Y X C Z T]
    %   frames = r.readframes(epochfiles, 1:10);
    %   t      = r.frametimes(epochfiles, 1:10);
    %
    % REQUIREMENTS
    %   NDR-matlab must be installed: https://github.com/VH-Lab/NDR-matlab/
    %   Some readers (e.g. 'imagestack') additionally wrap NANSEN
    %   (VervaekeLab, https://github.com/VervaekeLab/NANSEN); the frame API is
    %   adapted from nansen.stack.ImageStack.
    %
    % See also: ndi.daq.reader.image, ndi.daq.system.image, ndi.probe.image,
    %   ndi.daq.reader.mfdaq.ndr, ndr.reader, ndr.known_readers

    properties
        % ndr_reader_string - the NDR reader type this bridge forwards to.
        %   A char row vector naming one of the readers in ndr.known_readers()
        %   (for example 'tiffstack', 'prairieview', or 'imagestack'). Set at
        %   construction and used to instantiate an ndr.reader on each call.
        ndr_reader_string (1,:) char {mustBeTextScalar}
    end

    methods
        function obj = ndr(varargin)
            % NDR - create a new ndi.daq.reader.image.ndr object
            %
            %   OBJ = ndi.daq.reader.image.ndr()
            %   OBJ = ndi.daq.reader.image.ndr(READER_STRING)
            %   OBJ = ndi.daq.reader.image.ndr(SESSION, DOCUMENT)
            %
            %   Creates a bridge that reads image frames through an NDR-matlab
            %   ndr.reader. There are three calling forms:
            %
            %     ndr()                 - use the default reader, 'tiffstack'.
            %     ndr(READER_STRING)    - use the named NDR reader. READER_STRING
            %                             is a char/string scalar naming an image
            %                             reader type, e.g. 'tiffstack',
            %                             'prairieview', or 'imagestack'. It is
            %                             matched case-insensitively against
            %                             ndr.known_readers() and stored in its
            %                             canonical spelling.
            %     ndr(SESSION, DOCUMENT)- reconstruct an object from an
            %                             ndi.document of type 'daqreader_ndr'
            %                             (used when loading from the database);
            %                             SESSION is an ndi.session and DOCUMENT
            %                             is the ndi.document. The identifier and
            %                             reader string are taken from DOCUMENT.
            %
            %   Inputs:
            %     READER_STRING - (optional) char/string scalar; a member (or
            %                     alias) of ndr.known_readers().
            %     SESSION       - an ndi.session (two-argument form only).
            %     DOCUMENT      - an ndi.document (two-argument form only).
            %
            %   Outputs:
            %     OBJ - the new ndi.daq.reader.image.ndr object.
            %
            %   Throws an error if READER_STRING is empty, is not a known NDR
            %   reader, or if the arguments match none of the forms above.
            %
            %   See also: ndr.known_readers, ndi.daq.reader.image.ndr/newdocument

            finished = 0;

            if nargin==0
                reader_string = 'tiffstack';
            elseif nargin==1
                reader_string = char(varargin{1});
                if isempty(reader_string)
                    error('READER_STRING must be not empty.');
                end
            elseif nargin==2 & isa(varargin{1},'ndi.session') & isa(varargin{2},'ndi.document')
                obj.identifier = varargin{2}.document_properties.base.id;
                obj.ndr_reader_string = varargin{2}.document_properties.daqreader_ndr.ndr_reader_string;
                finished = 1;
            else
                error('Unknown arguments.');
            end

            if ~finished
                kr = ndr.known_readers();
                index = find(strcmpi(reader_string,kr));
                if isempty(index)
                    error('READER_STRING must be a member of the known readers of NDR, as listed in ndr.known_readers()');
                end
                obj.ndr_reader_string = kr{index};
            end
        end % ndr()

        %% live frame API (forwarded to ndr.reader)

        function n = numframes(ndi_daqreader_image_ndr_obj, epochfiles)
            % NUMFRAMES - number of frames (timepoints) in an image epoch
            %
            %   N = NUMFRAMES(OBJ, EPOCHFILES)
            %
            %   Returns the number of frames (timepoints) in the epoch. A frame
            %   is one timepoint; multiple channels of a timepoint count once
            %   (they are the C axis of READFRAMES, not separate frames).
            %
            %   Inputs:
            %     OBJ        - an ndi.daq.reader.image.ndr object.
            %     EPOCHFILES - cell array of file paths making up one epoch.
            %
            %   Outputs:
            %     N - scalar double, the number of frames.
            %
            %   Forwards to ndr.reader/numframes (epoch_select fixed at 1).
            %   Adapted from nansen.stack.ImageStack NumTimepoints/NumPlanes.
            %
            %   See also: framesize, readframes
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            n = ndr_reader.numframes(epochfiles,1);
        end % numframes()

        function sz = framesize(ndi_daqreader_image_ndr_obj, epochfiles)
            % FRAMESIZE - [Y X C Z T] extent of an image epoch, without reading pixels
            %
            %   SZ = FRAMESIZE(OBJ, EPOCHFILES)
            %
            %   Returns the full extent of the epoch as a 1x5 vector
            %   [Y X C Z T] (rows, columns, channels, planes, timepoints)
            %   without reading any pixel data. SZ(5) equals NUMFRAMES.
            %
            %   Inputs:
            %     OBJ        - an ndi.daq.reader.image.ndr object.
            %     EPOCHFILES - cell array of file paths making up one epoch.
            %
            %   Outputs:
            %     SZ - 1x5 double [Y X C Z T].
            %
            %   Forwards to ndr.reader/framesize (epoch_select fixed at 1).
            %   Adapted from nansen.stack.ImageStack/getFrameSetSize.
            %
            %   See also: numframes, dimensionorder, readframes
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            sz = ndr_reader.framesize(epochfiles,1);
        end % framesize()

        function order = dimensionorder(ndi_daqreader_image_ndr_obj, epochfiles)
            % DIMENSIONORDER - axis order of the arrays returned by READFRAMES
            %
            %   ORDER = DIMENSIONORDER(OBJ, EPOCHFILES)
            %
            %   Returns the order of the dimensions in the pixel arrays returned
            %   by READFRAMES, as a character vector over the letters Y, X, C, Z
            %   and T (default 'YXCZT'). This is the axis order that pairs with
            %   the extents reported by FRAMESIZE.
            %
            %   Inputs:
            %     OBJ        - an ndi.daq.reader.image.ndr object.
            %     EPOCHFILES - cell array of file paths making up one epoch.
            %
            %   Outputs:
            %     ORDER - char vector, a permutation of 'YXCZT'.
            %
            %   Forwards to ndr.reader/dimensionorder (epoch_select fixed at 1).
            %   Adapted from nansen.stack.ImageStack DataDimensionOrder.
            %
            %   See also: framesize, readframes
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            order = ndr_reader.dimensionorder(epochfiles,1);
        end % dimensionorder()

        function dt = datatype(ndi_daqreader_image_ndr_obj, epochfiles)
            % DATATYPE - numeric class of the image data
            %
            %   DT = DATATYPE(OBJ, EPOCHFILES)
            %
            %   Returns the underlying numeric class of the pixel data (e.g.
            %   'uint16'), i.e. the class of the array returned by READFRAMES.
            %
            %   Inputs:
            %     OBJ        - an ndi.daq.reader.image.ndr object.
            %     EPOCHFILES - cell array of file paths making up one epoch.
            %
            %   Outputs:
            %     DT - char vector naming a MATLAB numeric class.
            %
            %   Forwards to ndr.reader/datatype (epoch_select fixed at 1).
            %   Adapted from nansen.stack.ImageStack DataType.
            %
            %   See also: readframes, framesize
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            dt = ndr_reader.datatype(epochfiles,1);
        end % datatype()

        function t = frametimes(ndi_daqreader_image_ndr_obj, epochfiles, frameind)
            % FRAMETIMES - time of each requested frame, in epoch-clock units
            %
            %   T = FRAMETIMES(OBJ, EPOCHFILES)
            %   T = FRAMETIMES(OBJ, EPOCHFILES, FRAMEIND)
            %
            %   Returns the time of each requested frame, expressed in the units
            %   of the epoch's clock (see EPOCHCLOCK). For a movie whose clock is
            %   'dev_local_time' these are times in seconds; for a clockless
            %   epoch whose clock is 'no_time' the times are NaN.
            %
            %   Inputs:
            %     OBJ        - an ndi.daq.reader.image.ndr object.
            %     EPOCHFILES - cell array of file paths making up one epoch.
            %     FRAMEIND   - (optional) vector of 1-based frame (timepoint)
            %                  indices. If omitted, times for all frames are
            %                  returned.
            %
            %   Outputs:
            %     T - column vector of frame times, numel(FRAMEIND) long (or
            %         NUMFRAMES long if FRAMEIND is omitted).
            %
            %   Forwards to ndr.reader/frametimes (epoch_select fixed at 1).
            %   Adapted from nansen.stack.ImageStack/getFrameTimes.
            %
            %   See also: epochclock, t0_t1, readframes, numframes
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            if nargin<3
                t = ndr_reader.frametimes(epochfiles,1);
            else
                t = ndr_reader.frametimes(epochfiles,1,frameind);
            end
        end % frametimes()

        function frames = readframes(ndi_daqreader_image_ndr_obj, epochfiles, frameind)
            % READFRAMES - read image frames (pixel data) from an epoch
            %
            %   FRAMES = READFRAMES(OBJ, EPOCHFILES)
            %   FRAMES = READFRAMES(OBJ, EPOCHFILES, FRAMEIND)
            %
            %   Reads pixel data for the requested frames and returns them as a
            %   numeric array whose axis order is given by DIMENSIONORDER
            %   (default 'YXCZT') and whose class is given by DATATYPE. With the
            %   default order the result is sized [Y X C Z numel(FRAMEIND)];
            %   multi-channel (e.g. multi-color) data occupy the C axis.
            %
            %   Inputs:
            %     OBJ        - an ndi.daq.reader.image.ndr object.
            %     EPOCHFILES - cell array of file paths making up one epoch.
            %     FRAMEIND   - (optional) vector of 1-based frame (timepoint)
            %                  indices to read. If omitted, all frames are read.
            %
            %   Outputs:
            %     FRAMES - numeric array of pixel data (see DIMENSIONORDER and
            %              DATATYPE for its shape and class).
            %
            %   Forwards to ndr.reader/readframes (epoch_select fixed at 1).
            %   Adapted from nansen.stack.ImageStack/getFrameSet.
            %
            %   See also: framesize, dimensionorder, datatype, frametimes,
            %     numframes, ndi.probe.image/readframes
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            if nargin<3
                frames = ndr_reader.readframes(epochfiles,1);
            else
                frames = ndr_reader.readframes(epochfiles,1,frameind);
            end
        end % readframes()

        function channels = getchannelsepoch(ndi_daqreader_image_ndr_obj, epochfiles)
            % GETCHANNELSEPOCH - list the channels available in an image epoch
            %
            %   CHANNELS = GETCHANNELSEPOCH(OBJ, EPOCHFILES)
            %
            %   Returns the channels the reader exposes for the epoch. Image
            %   readers typically present a single logical image channel (e.g.
            %   named 'image1', of type 'image') regardless of how many color
            %   channels the data contain; color is carried on the C axis of
            %   READFRAMES rather than as separate channels here.
            %
            %   Inputs:
            %     OBJ        - an ndi.daq.reader.image.ndr object.
            %     EPOCHFILES - cell array of file paths making up one epoch.
            %
            %   Outputs:
            %     CHANNELS - struct array with fields:
            %       'name'         - channel name (e.g. 'image1').
            %       'type'         - channel type (e.g. 'image').
            %       'time_channel' - index of an associated time channel, if any.
            %
            %   Forwards to ndr.reader/getchannelsepoch (epoch_select fixed at 1).
            %
            %   See also: framesize, readframes
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            channels = ndr_reader.getchannelsepoch(epochfiles,1);
        end % getchannelsepoch()

        function ec = epochclock(ndi_daqreader_image_ndr_obj, epochfiles)
            % EPOCHCLOCK - the ndi.time.clocktype objects for an epoch
            %
            %   EC = EPOCHCLOCK(OBJ, EPOCHFILES)
            %
            %   Returns the clock type(s) available for the epoch as a cell array
            %   of ndi.time.clocktype objects. A movie with real per-frame
            %   timestamps returns 'dev_local_time'; a clockless stack (z-stack,
            %   slide scan) returns 'no_time'. The NDR reader reports its clocks
            %   as ndr.time.clocktype objects; this method converts each one to
            %   the corresponding ndi.time.clocktype.
            %
            %   Inputs:
            %     OBJ        - an ndi.daq.reader.image.ndr object.
            %     EPOCHFILES - cell array of file paths making up one epoch.
            %
            %   Outputs:
            %     EC - cell array of ndi.time.clocktype objects.
            %
            %   Forwards to ndr.reader/epochclock (epoch_select fixed at 1) and
            %   adapts ndr.time.clocktype -> ndi.time.clocktype.
            %
            %   See also: t0_t1, frametimes, ndi.time.clocktype
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            ec_ndr = ndr_reader.epochclock(epochfiles,1);
            ec = {};
            for i=1:numel(ec_ndr)
                ec{i} = ndi.time.clocktype(ec_ndr{i}.type);
            end
        end % epochclock()

        function t0t1 = t0_t1(ndi_daqreader_image_ndr_obj, epochfiles)
            % T0_T1 - the [t0 t1] begin/end times of an epoch
            %
            %   T0T1 = T0_T1(OBJ, EPOCHFILES)
            %
            %   Returns the beginning (t0) and end (t1) times of the epoch, one
            %   [t0 t1] pair per clock type reported by EPOCHCLOCK, in that
            %   clock's units. For a movie the pair is in seconds; for a
            %   clockless epoch the pair reflects the frame-index bounds.
            %
            %   Inputs:
            %     OBJ        - an ndi.daq.reader.image.ndr object.
            %     EPOCHFILES - cell array of file paths making up one epoch.
            %
            %   Outputs:
            %     T0T1 - cell array with one 1x2 vector [t0 t1] per EPOCHCLOCK
            %            clock type.
            %
            %   Forwards to ndr.reader/t0_t1 (epoch_select fixed at 1).
            %
            %   See also: epochclock, frametimes
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            t0t1 = ndr_reader.t0_t1(epochfiles,1);
        end % t0_t1()

        %% documentservice

        function ndi_document_obj = newdocument(ndi_daqreader_obj)
            % NEWDOCUMENT - create an ndi.document describing this reader
            %
            %   NDI_DOCUMENT_OBJ = NEWDOCUMENT(OBJ)
            %
            %   Creates an ndi.document that captures enough state to
            %   reconstruct this object from the database. It reuses the generic
            %   'daqreader_ndr' document type (shared with
            %   ndi.daq.reader.mfdaq.ndr), recording the NDR reader string and
            %   the concrete NDI reader class name. The two-argument constructor
            %   form ndr(SESSION, DOCUMENT) rebuilds the object from such a
            %   document.
            %
            %   Inputs:
            %     OBJ - an ndi.daq.reader.image.ndr object.
            %
            %   Outputs:
            %     NDI_DOCUMENT_OBJ - an ndi.document of type 'daqreader_ndr'.
            %
            %   See also: ndi.document, ndi.daq.reader.image.ndr/ndr
            ndi_document_obj = ndi.document('daqreader_ndr',...
                'daqreader.ndi_daqreader_class',class(ndi_daqreader_obj),...
                'daqreader_ndr.ndr_reader_string', ndi_daqreader_obj.ndr_reader_string,...
                'daqreader_ndr.ndi_daqreader_ndr_class',class(ndi_daqreader_obj),...
                'base.id', ndi_daqreader_obj.id(),...
                'base.session_id',ndi.session.empty_id());
        end % newdocument()

    end % methods
end % classdef
