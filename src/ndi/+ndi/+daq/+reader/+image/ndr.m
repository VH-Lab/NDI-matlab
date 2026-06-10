classdef ndr < ndi.daq.reader.image
    % ndi.daq.reader.image.ndr - Allows NDI to use NDR-matlab image readers
    %
    % This is the imageseries twin of ndi.daq.reader.mfdaq.ndr: a THIN BRIDGE
    % that reads image frames using NDR-matlab ndr.reader objects. It holds a
    % reader string and forwards each frame call to ndr.reader, performing only
    % NDI-side adaptation (e.g. ndr.time.clocktype -> ndi.time.clocktype). It
    % does no file I/O of its own; the file-format reading lives in NDR-matlab.
    %
    % NDR-MATLAB must be installed: https://github.com/VH-Lab/NDR-matlab/
    %
    % The frame API is adapted from nansen.stack.ImageStack (VervaekeLab,
    % https://github.com/VervaekeLab/NANSEN); the actual format support lives in
    % the NDR reader (e.g. ndr.reader.tiffstack or ndr.reader.imagestack).
    %
    % See also: ndi.daq.reader.image, ndi.daq.reader.mfdaq.ndr

    properties
        ndr_reader_string (1,:) char {mustBeTextScalar}
    end

    methods
        function obj = ndr(varargin)
            % NDR - create a new ndi.daq.reader.image.ndr object
            %
            % OBJ = NDR(READER_STRING)
            %
            % Creates a new ndi.daq.reader.image.ndr object for reading image
            % frames with ndr.reader objects.
            %
            % READER_STRING should be a string that specifies an image reader
            % type, such as 'tiffstack' or 'imagestack'.
            %
            % A list of valid strings may be obtained from
            %   reader_string = ndr.known_readers()
            %

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
            % NUMFRAMES - number of frames in an image epoch (via NDR)
            %
            % Forwards to ndr.reader/numframes. Adapted from
            % nansen.stack.ImageStack NumTimepoints/NumPlanes.
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            n = ndr_reader.numframes(epochfiles,1);
        end % numframes()

        function sz = framesize(ndi_daqreader_image_ndr_obj, epochfiles)
            % FRAMESIZE - [Y X C Z T] extent (via NDR), without reading pixels
            %
            % Forwards to ndr.reader/framesize. Adapted from
            % nansen.stack.ImageStack/getFrameSetSize.
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            sz = ndr_reader.framesize(epochfiles,1);
        end % framesize()

        function order = dimensionorder(ndi_daqreader_image_ndr_obj, epochfiles)
            % DIMENSIONORDER - dimension order of returned frames (via NDR)
            %
            % Forwards to ndr.reader/dimensionorder. Adapted from
            % nansen.stack.ImageStack DataDimensionOrder.
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            order = ndr_reader.dimensionorder(epochfiles,1);
        end % dimensionorder()

        function dt = datatype(ndi_daqreader_image_ndr_obj, epochfiles)
            % DATATYPE - underlying numeric class of the image data (via NDR)
            %
            % Forwards to ndr.reader/datatype. Adapted from
            % nansen.stack.ImageStack DataType.
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            dt = ndr_reader.datatype(epochfiles,1);
        end % datatype()

        function t = frametimes(ndi_daqreader_image_ndr_obj, epochfiles, frameind)
            % FRAMETIMES - per-frame times in epoch-clock units (via NDR)
            %
            % Forwards to ndr.reader/frametimes. Adapted from
            % nansen.stack.ImageStack/getFrameTimes.
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            if nargin<3
                t = ndr_reader.frametimes(epochfiles,1);
            else
                t = ndr_reader.frametimes(epochfiles,1,frameind);
            end
        end % frametimes()

        function frames = readframes(ndi_daqreader_image_ndr_obj, epochfiles, frameind)
            % READFRAMES - read image frames from an epoch (via NDR)
            %
            % Forwards to ndr.reader/readframes. Adapted from
            % nansen.stack.ImageStack/getFrameSet.
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            if nargin<3
                frames = ndr_reader.readframes(epochfiles,1);
            else
                frames = ndr_reader.readframes(epochfiles,1,frameind);
            end
        end % readframes()

        function channels = getchannelsepoch(ndi_daqreader_image_ndr_obj, epochfiles)
            % GETCHANNELSEPOCH - list channels for an image epoch (via NDR)
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            channels = ndr_reader.getchannelsepoch(epochfiles,1);
        end % getchannelsepoch()

        function ec = epochclock(ndi_daqreader_image_ndr_obj, epochfiles)
            % EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch (via NDR)
            %
            % Forwards to ndr.reader/epochclock and converts each
            % ndr.time.clocktype to an ndi.time.clocktype. A movie returns
            % 'dev_local_time'; a clockless stack returns 'no_time'.
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            ec_ndr = ndr_reader.epochclock(epochfiles,1);
            ec = {};
            for i=1:numel(ec_ndr)
                ec{i} = ndi.time.clocktype(ec_ndr{i}.type);
            end
        end % epochclock()

        function t0t1 = t0_t1(ndi_daqreader_image_ndr_obj, epochfiles)
            % T0_T1 - return the [t0 t1] begin/end epoch times for an epoch (via NDR)
            ndr_reader = ndr.reader(ndi_daqreader_image_ndr_obj.ndr_reader_string);
            t0t1 = ndr_reader.t0_t1(epochfiles,1);
        end % t0_t1()

        %% documentservice

        function ndi_document_obj = newdocument(ndi_daqreader_obj)
            % NEWDOCUMENT - create a new ndi.document for this image.ndr reader
            %
            % Reuses the generic 'daqreader_ndr' document type, recording the
            % NDR reader string and the concrete NDI reader class so the object
            % can be reconstructed.
            ndi_document_obj = ndi.document('daqreader_ndr',...
                'daqreader.ndi_daqreader_class',class(ndi_daqreader_obj),...
                'daqreader_ndr.ndr_reader_string', ndi_daqreader_obj.ndr_reader_string,...
                'daqreader_ndr.ndi_daqreader_ndr_class',class(ndi_daqreader_obj),...
                'base.id', ndi_daqreader_obj.id(),...
                'base.session_id',ndi.session.empty_id());
        end % newdocument()

    end % methods
end % classdef
