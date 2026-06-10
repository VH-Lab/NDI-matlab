classdef image < ndi.element
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
    % In v1, an ndi.element.image is typically created 'direct' on top of an
    % ndi.probe.image, and the read calls are delegated to that probe.
    %
    % See also: ndi.element, ndi.element.timeseries, ndi.probe.image

    properties (SetAccess=protected, GetAccess=public)
    end % properties

    methods
        function [ndi_element_image_obj] = image(varargin)
            [ndi_element_image_obj] = ndi_element_image_obj@ndi.element(varargin{:});
        end % ndi.element.image()

        function [images, t, timeref] = readframes(ndi_element_image_obj, timeref_or_epoch, t0, t1)
            % READFRAMES - read image frames from an element, with frame times via the epoch clock system
            %
            % [IMAGES, T, TIMEREF] = READFRAMES(NDI_ELEMENT_IMAGE_OBJ, TIMEREF_OR_EPOCH, T0, T1)
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
            if nargin<3, t0 = -Inf; end
            if nargin<4, t1 = Inf; end
            if ndi_element_image_obj.direct
                [images,t,timeref] = ndi_element_image_obj.underlying_element.readframes(timeref_or_epoch, t0, t1);
            else
                error('ndi:element:image:notdirect',...
                    ['Reading frames from a non-direct ndi.element.image is not supported in v1. ' ...
                     'Create the element ''direct'' on an ndi.probe.image, whose data live in the ' ...
                     'ingested image-epoch documents.']);
            end
        end % readframes()

        function [images, t, timeref] = readimages(ndi_element_image_obj, timeref_or_epoch, t0, t1)
            % READIMAGES - alias of READFRAMES
            %
            % [IMAGES, T, TIMEREF] = READIMAGES(NDI_ELEMENT_IMAGE_OBJ, TIMEREF_OR_EPOCH, T0, T1)
            %
            % See also: ndi.element.image/readframes
            if nargin<3, t0 = -Inf; end
            if nargin<4, t1 = Inf; end
            [images,t,timeref] = ndi_element_image_obj.readframes(timeref_or_epoch, t0, t1);
        end % readimages()

        function ndi_document_obj = newdocument(ndi_element_image_obj, varargin)
            ndi_document_obj = newdocument@ndi.element(ndi_element_image_obj, varargin{:});
        end % newdocument

        function sq = searchquery(ndi_element_image_obj, varargin)
            sq = searchquery@ndi.element(ndi_element_image_obj, varargin{:});
        end % searchquery

    end % methods
end % classdef
