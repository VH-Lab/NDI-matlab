classdef image < ndi.probe
    % ndi.probe.image - an imaging probe backed by an ndi.daq.system.image
    %
    % ndi.probe.image is the imaging counterpart of the ndi.probe.timeseries /
    % ndi.probe.timeseries.mfdaq pair. It reads image frames from the
    % ndi.daq.system.image that acquired them and returns each frame's time
    % through the NDI epoch clock / syncgraph system, mirroring how
    % ndi.probe.timeseries returns sample times for ephys.
    %
    % The key call is READFRAMES (alias READIMAGES):
    %
    %   [IMAGES, T, TIMEREF] = READFRAMES(PROBE, TIMEREF_OR_EPOCH, T0, T1)
    %
    % How frame timestamps are returned (the imageseries timestamp question):
    %   - The daq.reader (in NDR) supplies per-frame times via FRAMETIMES, in
    %     the units of the epoch's clock (EPOCHCLOCK). For a movie that clock
    %     is real (e.g. 'dev_local_time'); for a clockless stack it is
    %     'no_time' and the times are NaN.
    %   - READFRAMES maps the requested [T0,T1] from the caller's time
    %     reference into the epoch's clock using session.syncgraph.time_convert,
    %     selects the frames whose times fall in range, reads them, and
    %     converts their times BACK into the caller's time reference. This is
    %     exactly the path ndi.probe.timeseries/readtimeseries uses, so an
    %     imageseries movie participates in the syncgraph like any timeseries.
    %
    % See also: ndi.probe, ndi.probe.timeseries, ndi.daq.system.image,
    %   ndi.element.image

    properties (GetAccess=public, SetAccess=protected)
    end

    methods
        function obj = image(varargin)
            % ndi.probe.image - create a new ndi.probe.image object
            %
            %  OBJ = ndi.probe.image(SESSION, NAME, REFERENCE, TYPE)
            %
            obj = obj@ndi.probe(varargin{:});
        end % ndi.probe.image

        function [images, t, timeref_out] = readframesepoch(ndi_probe_image_obj, epoch, t0, t1)
            % READFRAMESEPOCH - read image frames from a single epoch
            %
            % [IMAGES, T, TIMEREF_OUT] = READFRAMESEPOCH(NDI_PROBE_IMAGE_OBJ, EPOCH, T0, T1)
            %
            % EPOCH is the epoch number or id. For a movie, returns the frames
            % whose times (in the epoch's clock) fall within [T0,T1] and T is
            % those times relative to the start of the epoch. For a clockless
            % ('no_time') epoch, T0,T1 are inclusive frame-index bounds and T
            % is the frame indices. TIMEREF_OUT describes the epoch.
            %
            if nargin<3, t0 = -Inf; end
            if nargin<4, t1 = Inf; end

            [dev,devname,devepoch,channeltype,channel] = ndi_probe_image_obj.getchanneldevinfo(epoch);
            eid = ndi_probe_image_obj.epochid(epoch);

            if numel(vlt.data.equnique(dev))>1
                error('ndi:probe:image:mixeddevices','Do not know how to mix devices for an image probe.');
            end
            dsys = dev{1};
            if ~isa(dsys,'ndi.daq.system.image')
                error('ndi:probe:image:notimagedaq','ndi.probe.image must be backed by an ndi.daq.system.image.');
            end

            ec = dsys.epochclock(devepoch{1});
            isclockless = ~isempty(ec) && strcmp(ec{1}.type,'no_time');

            n = dsys.numframes(devepoch{1});
            ft = dsys.frametimes(devepoch{1}, 1:n);
            ft = ft(:);

            if isclockless
                % t0,t1 are frame-index bounds
                lo = max(1, ceil(t0));
                hi = min(n, floor(t1));
                if ~isfinite(lo), lo = 1; end
                if ~isfinite(hi), hi = n; end
                frameind = lo:hi;
                t = frameind(:);
            else
                frameind = find(ft>=t0 & ft<=t1);
                frameind = frameind(:)';
                t = ft(frameind);
            end

            images = dsys.readframes(devepoch{1}, frameind);

            if nargout>=3
                if isclockless
                    timeref_out = ndi.time.timereference(ndi_probe_image_obj, ndi.time.clocktype('no_time'), eid, 0);
                else
                    timeref_out = ndi.time.timereference(ndi_probe_image_obj, ec{1}, eid, 0);
                end
            end
        end % readframesepoch()

        function [images, t, timeref] = readframes(ndi_probe_image_obj, timeref_or_epoch, t0, t1)
            % READFRAMES - read image frames with frame times via the epoch clock system
            %
            % [IMAGES, T, TIMEREF] = READFRAMES(NDI_PROBE_IMAGE_OBJ, TIMEREF_OR_EPOCH, T0, T1)
            %
            % Reads image frames from the backing ndi.daq.system.image. If
            % TIMEREF_OR_EPOCH is an ndi.time.timereference, T0,T1 are times in
            % that reference; the request is mapped into the epoch's own clock
            % via the syncgraph, the in-range frames are read, and their times
            % are converted back into TIMEREF's units. If TIMEREF_OR_EPOCH is an
            % epoch number/id, the read is performed directly in that epoch's
            % clock (T0,T1 are times for a movie, or frame indices for a
            % clockless epoch).
            %
            if nargin<3, t0 = -Inf; end
            if nargin<4, t1 = Inf; end

            if ~isa(timeref_or_epoch,'ndi.time.timereference')
                % direct epoch read, in the epoch's own clock
                [images,t,timeref] = ndi_probe_image_obj.readframesepoch(timeref_or_epoch, t0, t1);
                return;
            end

            timeref = timeref_or_epoch;

            [epoch_t0_out, epoch0_timeref, msg] = ndi_probe_image_obj.session.syncgraph.time_convert(timeref, t0, ...
                ndi_probe_image_obj, ndi.time.clocktype('dev_local_time'));
            [epoch_t1_out, epoch1_timeref, msg] = ndi_probe_image_obj.session.syncgraph.time_convert(timeref, t1, ...
                ndi_probe_image_obj, ndi.time.clocktype('dev_local_time'));

            if isempty(epoch0_timeref) | isempty(epoch1_timeref)
                error('ndi:probe:image:notimemapping',['Could not find time mapping (maybe wrong epoch name?): ' msg ]);
            end

            [er,et,gt0_t1] = ndi.epoch.epochrange(epoch0_timeref.referent, ndi.time.clocktype('dev_local_time'), ...
                epoch0_timeref.epoch, epoch1_timeref.epoch);

            images = [];
            t = [];

            for i=1:numel(er)
                if (i==1)
                    startTime = epoch_t0_out;
                else
                    startTime = gt0_t1(i,1);
                    if isnan(startTime), startTime = -Inf; end
                end
                if (i==numel(er))
                    stopTime = epoch_t1_out;
                else
                    stopTime = gt0_t1(i,2);
                    if isnan(stopTime), stopTime = Inf; end
                end
                [images_here, t_here] = ndi_probe_image_obj.readframesepoch(er{i}, startTime, stopTime);
                t_here = t_here(:);
                images = cat(5, images, images_here);
                % convert frame times back into the requested timeref units
                epoch_here_timeref = ndi.time.timereference(epoch0_timeref.referent, epoch0_timeref.clocktype, er{i}, epoch0_timeref.time);
                if isnumeric(t_here) && ~any(isnan(t_here))
                    t_here = ndi_probe_image_obj.session.syncgraph.time_convert(epoch_here_timeref, t_here, ...
                        timeref.referent, timeref.clocktype);
                end
                t = cat(1, t, t_here);
            end
        end % readframes()

        function [images, t, timeref] = readimages(ndi_probe_image_obj, timeref_or_epoch, t0, t1)
            % READIMAGES - alias of READFRAMES
            %
            % See also: ndi.probe.image/readframes
            if nargin<3, t0 = -Inf; end
            if nargin<4, t1 = Inf; end
            [images,t,timeref] = ndi_probe_image_obj.readframes(timeref_or_epoch, t0, t1);
        end % readimages()

        function n = numframes(ndi_probe_image_obj, epoch)
            % NUMFRAMES - number of frames available to this probe in an epoch
            %
            % N = NUMFRAMES(NDI_PROBE_IMAGE_OBJ, EPOCH)
            %
            [dev,~,devepoch] = ndi_probe_image_obj.getchanneldevinfo(epoch);
            n = dev{1}.numframes(devepoch{1});
        end % numframes()

        function sz = framesize(ndi_probe_image_obj, epoch)
            % FRAMESIZE - [Y X C Z T] extent of the probe's image data in an epoch
            [dev,~,devepoch] = ndi_probe_image_obj.getchanneldevinfo(epoch);
            sz = dev{1}.framesize(devepoch{1});
        end % framesize()

        function ndi_document_obj = newdocument(ndi_probe_image_obj, varargin)
            ndi_document_obj = newdocument@ndi.probe(ndi_probe_image_obj, varargin{:});
        end % newdocument

        function sq = searchquery(ndi_probe_image_obj, varargin)
            sq = searchquery@ndi.probe(ndi_probe_image_obj, varargin{:});
        end % searchquery

    end % methods
end % classdef
