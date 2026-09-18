classdef image < ndi.element & ndi.time.timeseries
    % ndi.element.image - an element that exposes image-series (frame) data
    %
    % ndi.element.image is the imaging counterpart of ndi.element.timeseries.
    % It exposes READFRAMES / READIMAGES, which return image frames together
    % with the time of each frame, expressed through the NDI epoch clock /
    % syncgraph system (the same machinery ndi.element.timeseries uses for
    % ephys). For a movie, the returned times are real device/experiment
    % times; for a clockless slide scan / z-stack the epoch clock is 'no_time'
    % and frames are addressed by index.
    %
    % ndi.element.image implements the ndi.time.timeseries interface, so it can
    % be consumed by generic timeseries code: READTIMESERIES returns image
    % frames as the data with each frame's time, and SAMPLERATE /
    % TIMES2SAMPLES / SAMPLES2TIMES provide the (irregular) frame<->time
    % mapping. As with ndi.probe.image, READTIMESERIES requires a real clock
    % and errors on a clockless ('no_time') epoch; use READFRAMES with frame
    % indices there. When the element is 'direct', these calls are delegated to
    % the underlying ndi.probe.image.
    %
    % In v1, an ndi.element.image is typically created 'direct' on top of an
    % ndi.probe.image, and the read calls are delegated to that probe.
    %
    % See also: ndi.element, ndi.element.timeseries, ndi.time.timeseries,
    %   ndi.probe.image

    properties (SetAccess=protected, GetAccess=public)
    end % properties

    methods
        function [ndi_element_image_obj] = image(varargin)
            [ndi_element_image_obj] = ndi_element_image_obj@ndi.element(varargin{:});
        end % ndi.element.image()

        function [images, t, timeref] = readframes(ndi_element_image_obj, timeref_or_epoch, t0, t1, options)
            % READFRAMES - read image frames from an element, with frame times via the epoch clock system
            %
            % [IMAGES, T, TIMEREF] = READFRAMES(NDI_ELEMENT_IMAGE_OBJ, TIMEREF_OR_EPOCH, T0, T1)
            % [IMAGES, T, TIMEREF] = READFRAMES(..., 'SelectC', C, 'SelectZ', Z)
            %
            % Reads image frames from an ndi.element.image object. TIMEREF_OR_EPOCH
            % is either an ndi.time.timereference (then T0,T1 are times in that
            % reference) or an epoch number/id. IMAGES is the frame array in
            % 'YXCZT' order ([Y X C 1 nframes]); T is the time of each frame in
            % the units of TIMEREF (or the epoch's clock); TIMEREF is returned.
            %
            % For a movie, the frames whose times fall within [T0,T1] are
            % returned. For a clockless ('no_time') epoch, T0,T1 are interpreted
            % as inclusive frame-index bounds and T is the frame indices.
            %
            arguments
                ndi_element_image_obj
                timeref_or_epoch
                t0 = -Inf
                t1 = Inf
                options.SelectC (1,:) double = []
                options.SelectZ (1,:) double = []
            end
            if ndi_element_image_obj.direct
                [images,t,timeref] = ndi_element_image_obj.underlying_element.readframes(timeref_or_epoch, t0, t1, ...
                    'SelectC', options.SelectC, 'SelectZ', options.SelectZ);
            else
                error('ndi:element:image:notdirect',...
                    ['Reading frames from a non-direct ndi.element.image is not supported in v1. ' ...
                     'Create the element ''direct'' on an ndi.probe.image, whose data live in the ' ...
                     'ingested image-epoch documents.']);
            end
        end % readframes()

        function [images, t, timeref] = readimages(ndi_element_image_obj, timeref_or_epoch, t0, t1, options)
            % READIMAGES - alias of READFRAMES
            %
            % [IMAGES, T, TIMEREF] = READIMAGES(NDI_ELEMENT_IMAGE_OBJ, TIMEREF_OR_EPOCH, T0, T1)
            % [IMAGES, T, TIMEREF] = READIMAGES(..., 'SelectC', C, 'SelectZ', Z)
            %
            % See also: ndi.element.image/readframes
            arguments
                ndi_element_image_obj
                timeref_or_epoch
                t0 = -Inf
                t1 = Inf
                options.SelectC (1,:) double = []
                options.SelectZ (1,:) double = []
            end
            [images,t,timeref] = ndi_element_image_obj.readframes(timeref_or_epoch, t0, t1, ...
                'SelectC', options.SelectC, 'SelectZ', options.SelectZ);
        end % readimages()

        %% ndi.time.timeseries interface

        function [data, t, timeref] = readtimeseries(ndi_element_image_obj, timeref_or_epoch, t0, t1, options)
            % READTIMESERIES - read image frames as a time series
            %
            % [DATA, T, TIMEREF] = READTIMESERIES(NDI_ELEMENT_IMAGE_OBJ, TIMEREF_OR_EPOCH, T0, T1)
            % [DATA, T, TIMEREF] = READTIMESERIES(..., 'SelectC', C, 'SelectZ', Z)
            %
            % Implements the ndi.time.timeseries interface. Returns image frames
            % as DATA together with each frame's time T and the TIMEREF, using
            % the epoch clock / syncgraph system. TIMEREF_OR_EPOCH is either an
            % ndi.time.timereference or an epoch number/id. Errors on a clockless
            % ('no_time') epoch (use READFRAMES with frame indices there). The
            % 'SelectC' / 'SelectZ' options subset the channel / plane axes
            % (default [] = all).
            %
            % For a 'direct' element the call is delegated to the underlying
            % ndi.probe.image.
            %
            arguments
                ndi_element_image_obj
                timeref_or_epoch
                t0 = -Inf
                t1 = Inf
                options.SelectC (1,:) double = []
                options.SelectZ (1,:) double = []
            end
            if ndi_element_image_obj.direct
                [data,t,timeref] = ndi_element_image_obj.underlying_element.readtimeseries(timeref_or_epoch, t0, t1, ...
                    'SelectC', options.SelectC, 'SelectZ', options.SelectZ);
            else
                error('ndi:element:image:notdirect',...
                    ['Reading from a non-direct ndi.element.image is not supported in v1. ' ...
                     'Create the element ''direct'' on an ndi.probe.image.']);
            end
        end % readtimeseries()

        function sr = samplerate(ndi_element_image_obj, epoch)
            % SAMPLERATE - sample rate of the image element (-1: irregular)
            %
            % SR = SAMPLERATE(NDI_ELEMENT_IMAGE_OBJ, EPOCH)
            %
            % Image frames are not (in general) regularly sampled, so -1 is
            % returned (see ndi.probe.image/samplerate). Delegated to the
            % underlying ndi.probe.image for a 'direct' element.
            %
            if ndi_element_image_obj.direct
                sr = ndi_element_image_obj.underlying_element.samplerate(epoch);
            else
                error('ndi:element:image:notdirect',...
                    'Only ''direct'' ndi.element.image objects are supported in v1.');
            end
        end % samplerate()

        function samples = times2samples(ndi_element_image_obj, epoch, times)
            % TIMES2SAMPLES - map epoch-clock times to frame indices
            %
            % SAMPLES = TIMES2SAMPLES(NDI_ELEMENT_IMAGE_OBJ, EPOCH, TIMES)
            %
            % For image data a "sample" is a frame. Delegated to the underlying
            % ndi.probe.image for a 'direct' element. Errors on a clockless
            % ('no_time') epoch.
            %
            if ndi_element_image_obj.direct
                samples = ndi_element_image_obj.underlying_element.times2samples(epoch, times);
            else
                error('ndi:element:image:notdirect',...
                    'Only ''direct'' ndi.element.image objects are supported in v1.');
            end
        end % times2samples()

        function times = samples2times(ndi_element_image_obj, epoch, samples)
            % SAMPLES2TIMES - map frame indices to epoch-clock times
            %
            % TIMES = SAMPLES2TIMES(NDI_ELEMENT_IMAGE_OBJ, EPOCH, SAMPLES)
            %
            % For image data a "sample" is a frame. Delegated to the underlying
            % ndi.probe.image for a 'direct' element. Errors on a clockless
            % ('no_time') epoch.
            %
            if ndi_element_image_obj.direct
                times = ndi_element_image_obj.underlying_element.samples2times(epoch, samples);
            else
                error('ndi:element:image:notdirect',...
                    'Only ''direct'' ndi.element.image objects are supported in v1.');
            end
        end % samples2times()

        %% raster acquisition metadata and sub-frame timing

        function m = imagemetadata(ndi_element_image_obj, epoch)
            % IMAGEMETADATA - standardized image-acquisition metadata for an epoch
            %
            % M = IMAGEMETADATA(NDI_ELEMENT_IMAGE_OBJ, EPOCH)
            %
            % Returns the standardized image-acquisition metadata struct (raster
            % line/frame timing, geometry, scan direction; time fields in
            % SECONDS) for EPOCH. See ndi.daq.reader.image/metadata for the
            % field list. Delegated to the underlying ndi.probe.image for a
            % 'direct' element.
            %
            % See also: ndi.probe.image/imagemetadata, linetimes, pixeltimes
            if ndi_element_image_obj.direct
                m = ndi_element_image_obj.underlying_element.imagemetadata(epoch);
            else
                error('ndi:element:image:notdirect',...
                    'Only ''direct'' ndi.element.image objects are supported in v1.');
            end
        end % imagemetadata()

        function tl = linetimes(ndi_element_image_obj, timeref_or_epoch, t0, t1)
            % LINETIMES - acquisition time of each line (row) of the selected frames
            %
            % TL = LINETIMES(NDI_ELEMENT_IMAGE_OBJ, TIMEREF_OR_EPOCH, T0, T1)
            %
            % Returns TL [Lines_per_frame x Nframes], the time each line of each
            % selected frame was scanned. Frame selection and time units follow
            % READFRAMES. Delegated to the underlying ndi.probe.image for a
            % 'direct' element. See ndi.probe.image/linetimes for details.
            %
            % See also: pixeltimes, imagemetadata, ndi.probe.image/linetimes
            if nargin<3, t0 = -Inf; end
            if nargin<4, t1 = Inf; end
            if ndi_element_image_obj.direct
                tl = ndi_element_image_obj.underlying_element.linetimes(timeref_or_epoch, t0, t1);
            else
                error('ndi:element:image:notdirect',...
                    'Only ''direct'' ndi.element.image objects are supported in v1.');
            end
        end % linetimes()

        function tp = pixeltimes(ndi_element_image_obj, timeref_or_epoch, t0, t1)
            % PIXELTIMES - acquisition time of every pixel of the selected frames
            %
            % TP = PIXELTIMES(NDI_ELEMENT_IMAGE_OBJ, TIMEREF_OR_EPOCH, T0, T1)
            %
            % Returns the compact per-pixel time map TP [Y X 1 1 Nframes], which
            % broadcasts against the full data array [Y X C Z Nframes]. Frame
            % selection and time units follow READFRAMES. Delegated to the
            % underlying ndi.probe.image for a 'direct' element. See
            % ndi.probe.image/pixeltimes for the full contract and examples
            % (including how to build the full-size matrix if you need it).
            %
            % See also: linetimes, imagemetadata, ndi.probe.image/pixeltimes
            if nargin<3, t0 = -Inf; end
            if nargin<4, t1 = Inf; end
            if ndi_element_image_obj.direct
                tp = ndi_element_image_obj.underlying_element.pixeltimes(timeref_or_epoch, t0, t1);
            else
                error('ndi:element:image:notdirect',...
                    'Only ''direct'' ndi.element.image objects are supported in v1.');
            end
        end % pixeltimes()

        function ndi_document_obj = newdocument(ndi_element_image_obj, varargin)
            ndi_document_obj = newdocument@ndi.element(ndi_element_image_obj, varargin{:});
        end % newdocument

        function sq = searchquery(ndi_element_image_obj, varargin)
            sq = searchquery@ndi.element(ndi_element_image_obj, varargin{:});
        end % searchquery

    end % methods
end % classdef
