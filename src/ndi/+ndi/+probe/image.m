classdef image < ndi.probe & ndi.time.timeseries
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
    % ndi.time.timeseries interface:
    %   ndi.probe.image implements ndi.time.timeseries, so it can be consumed
    %   by generic timeseries code. READTIMESERIES returns image frames as the
    %   data together with each frame's time, using the same syncgraph machinery
    %   as READFRAMES. Because image frames are not (in general) regularly
    %   sampled, SAMPLERATE returns -1 and the "sample <-> time" conversions
    %   TIMES2SAMPLES / SAMPLES2TIMES map between frame indices and frame times
    %   directly, via FRAMETIMES, rather than assuming a constant rate.
    %
    %   READTIMESERIES requires a real clock: on a clockless ('no_time') epoch,
    %   where there is no time <-> frame mapping, it ERRORS and directs the
    %   caller to READFRAMES with frame indices. (READFRAMES itself remains
    %   dual-mode: time for a movie, frame indices for a clockless stack.)
    %
    % See also: ndi.probe, ndi.probe.timeseries, ndi.time.timeseries,
    %   ndi.daq.system.image, ndi.element.image

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

        function [images, t, timeref_out] = readframesepoch(ndi_probe_image_obj, epoch, t0, t1, options)
            % READFRAMESEPOCH - read image frames from a single epoch
            %
            % [IMAGES, T, TIMEREF_OUT] = READFRAMESEPOCH(NDI_PROBE_IMAGE_OBJ, EPOCH, T0, T1)
            % [IMAGES, T, TIMEREF_OUT] = READFRAMESEPOCH(..., 'SelectC', C, 'SelectZ', Z)
            %
            % EPOCH is the epoch number or id. For a movie, returns the frames
            % whose times (in the epoch's clock) fall within [T0,T1] and T is
            % those times relative to the start of the epoch. For a clockless
            % ('no_time') epoch, T0,T1 are inclusive frame-index bounds and T
            % is the frame indices. TIMEREF_OUT describes the epoch.
            %
            % The 'SelectC' / 'SelectZ' options subset the returned channel /
            % plane axes (default [] = all).
            %
            arguments
                ndi_probe_image_obj
                epoch
                t0 = -Inf
                t1 = Inf
                options.SelectC (1,:) double = []
                options.SelectZ (1,:) double = []
            end

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

            images = dsys.readframes(devepoch{1}, frameind, ...
                'SelectC', options.SelectC, 'SelectZ', options.SelectZ);

            if nargout>=3
                if isclockless
                    timeref_out = ndi.time.timereference(ndi_probe_image_obj, ndi.time.clocktype('no_time'), eid, 0);
                else
                    timeref_out = ndi.time.timereference(ndi_probe_image_obj, ec{1}, eid, 0);
                end
            end
        end % readframesepoch()

        function [images, t, timeref] = readframes(ndi_probe_image_obj, timeref_or_epoch, t0, t1, options)
            % READFRAMES - read image frames with frame times via the epoch clock system
            %
            % [IMAGES, T, TIMEREF] = READFRAMES(NDI_PROBE_IMAGE_OBJ, TIMEREF_OR_EPOCH, T0, T1)
            % [IMAGES, T, TIMEREF] = READFRAMES(..., 'SelectC', C, 'SelectZ', Z)
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
            % The 'SelectC' / 'SelectZ' options subset the returned channel /
            % plane axes (default [] = all).
            %
            arguments
                ndi_probe_image_obj
                timeref_or_epoch
                t0 = -Inf
                t1 = Inf
                options.SelectC (1,:) double = []
                options.SelectZ (1,:) double = []
            end

            if ~isa(timeref_or_epoch,'ndi.time.timereference')
                % direct epoch read, in the epoch's own clock
                [images,t,timeref] = ndi_probe_image_obj.readframesepoch(timeref_or_epoch, t0, t1, ...
                    'SelectC', options.SelectC, 'SelectZ', options.SelectZ);
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
                [images_here, t_here] = ndi_probe_image_obj.readframesepoch(er{i}, startTime, stopTime, ...
                    'SelectC', options.SelectC, 'SelectZ', options.SelectZ);
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

        function [images, t, timeref] = readimages(ndi_probe_image_obj, timeref_or_epoch, t0, t1, options)
            % READIMAGES - alias of READFRAMES
            %
            % See also: ndi.probe.image/readframes
            arguments
                ndi_probe_image_obj
                timeref_or_epoch
                t0 = -Inf
                t1 = Inf
                options.SelectC (1,:) double = []
                options.SelectZ (1,:) double = []
            end
            [images,t,timeref] = ndi_probe_image_obj.readframes(timeref_or_epoch, t0, t1, ...
                'SelectC', options.SelectC, 'SelectZ', options.SelectZ);
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

        %% ndi.time.timeseries interface

        function [data, t, timeref] = readtimeseries(ndi_probe_image_obj, timeref_or_epoch, t0, t1, options)
            % READTIMESERIES - read image frames as a time series
            %
            % [DATA, T, TIMEREF] = READTIMESERIES(NDI_PROBE_IMAGE_OBJ, TIMEREF_OR_EPOCH, T0, T1)
            %
            % Implements the ndi.time.timeseries interface for an imaging probe.
            % Returns image frames as DATA (a [Y X C Z nframes] array) together
            % with the time T of each frame and the TIMEREF describing T.
            %
            % TIMEREF_OR_EPOCH is either an ndi.time.timereference (then T0,T1
            % are times in that reference and the request is mapped through the
            % syncgraph) or an epoch number/id (then T0,T1 are times in the
            % epoch's own clock). Only frames whose times fall within [T0,T1]
            % are returned.
            %
            % Unlike READFRAMES, this method requires a real clock: reading a
            % clockless ('no_time') epoch raises an error (there is no
            % time <-> frame mapping). Use READFRAMES with frame indices for
            % clockless epochs. See READTIMESERIESEPOCH.
            %
            arguments
                ndi_probe_image_obj
                timeref_or_epoch
                t0 = -Inf
                t1 = Inf
                options.SelectC (1,:) double = []
                options.SelectZ (1,:) double = []
            end
            if isa(timeref_or_epoch,'ndi.time.timereference')
                % time-reference path: the syncgraph maps the request into the
                % epoch clock. A clockless epoch has no 'dev_local_time' and so
                % never falls within a time range; READFRAMES handles the rest.
                [data, t, timeref] = ndi_probe_image_obj.readframes(timeref_or_epoch, t0, t1, ...
                    'SelectC', options.SelectC, 'SelectZ', options.SelectZ);
            else
                [data, t, timeref] = ndi_probe_image_obj.readtimeseriesepoch(timeref_or_epoch, t0, t1, ...
                    'SelectC', options.SelectC, 'SelectZ', options.SelectZ);
            end
        end % readtimeseries()

        function [data, t, timeref] = readtimeseriesepoch(ndi_probe_image_obj, epoch, t0, t1, options)
            % READTIMESERIESEPOCH - read image frames from one epoch as a time series
            %
            % [DATA, T, TIMEREF] = READTIMESERIESEPOCH(NDI_PROBE_IMAGE_OBJ, EPOCH, T0, T1)
            % [DATA, T, TIMEREF] = READTIMESERIESEPOCH(..., 'SelectC', C, 'SelectZ', Z)
            %
            % Returns the frames of EPOCH whose times (in the epoch's clock) fall
            % within [T0,T1], as DATA, with the frame times T and the epoch
            % TIMEREF. EPOCH is an epoch number or id. The 'SelectC' / 'SelectZ'
            % options subset the returned channel / plane axes (default [] = all).
            %
            % If EPOCH is clockless (its clock is 'no_time') this method errors,
            % because a time series has no meaning without a clock; use
            % ndi.probe.image/readframes with frame indices instead.
            %
            arguments
                ndi_probe_image_obj
                epoch
                t0 = -Inf
                t1 = Inf
                options.SelectC (1,:) double = []
                options.SelectZ (1,:) double = []
            end
            [~, ~, isclockless] = ndi_probe_image_obj.imageepochinfo(epoch);
            if isclockless
                eid = ndi_probe_image_obj.epochid(epoch);
                error('ndi:probe:image:notimeseries', ...
                    ['Epoch ''' eid ''' has clock ''no_time''; it has no ' ...
                     'time <-> frame mapping and cannot be read as a time series. ' ...
                     'Use readframes(epoch, frameind) with frame indices instead.']);
            end
            [data, t, timeref] = ndi_probe_image_obj.readframesepoch(epoch, t0, t1, ...
                'SelectC', options.SelectC, 'SelectZ', options.SelectZ);
        end % readtimeseriesepoch()

        function sr = samplerate(ndi_probe_image_obj, epoch)
            % SAMPLERATE - image frames are not regularly sampled; returns -1
            %
            % SR = SAMPLERATE(NDI_PROBE_IMAGE_OBJ, EPOCH)
            %
            % Image frames may be irregularly timed (e.g. PrairieView per-frame
            % timestamps, dropped frames), so no single sample rate applies and
            % -1 is returned, per the ndi.time.timeseries convention. Use
            % FRAMETIMES / TIMES2SAMPLES / SAMPLES2TIMES for the frame<->time
            % mapping.
            %
            sr = -1;
        end % samplerate()

        function samples = times2samples(ndi_probe_image_obj, epoch, times)
            % TIMES2SAMPLES - map epoch-clock times to frame indices
            %
            % SAMPLES = TIMES2SAMPLES(NDI_PROBE_IMAGE_OBJ, EPOCH, TIMES)
            %
            % For image data a "sample" is a frame. Returns, for each requested
            % time in TIMES (in the epoch's clock units), the index of the
            % nearest frame, found from FRAMETIMES. +Inf maps to the last frame
            % and -Inf to the first. Errors on a clockless ('no_time') epoch.
            %
            [~, ~, isclockless, ft] = ndi_probe_image_obj.imageepochinfo(epoch);
            if isclockless
                eid = ndi_probe_image_obj.epochid(epoch);
                error('ndi:probe:image:notimeseries', ...
                    ['Epoch ''' eid ''' has clock ''no_time''; frames are ' ...
                     'addressed by index, not time.']);
            end
            n = numel(ft);
            samples = zeros(size(times));
            for i=1:numel(times)
                if isinf(times(i)) && times(i)<0
                    samples(i) = 1;
                elseif isinf(times(i)) && times(i)>0
                    samples(i) = n;
                else
                    [~,samples(i)] = min(abs(ft - times(i)));
                end
            end
        end % times2samples()

        function times = samples2times(ndi_probe_image_obj, epoch, samples)
            % SAMPLES2TIMES - map frame indices to epoch-clock times
            %
            % TIMES = SAMPLES2TIMES(NDI_PROBE_IMAGE_OBJ, EPOCH, SAMPLES)
            %
            % For image data a "sample" is a frame. Returns the time (from
            % FRAMETIMES, in the epoch's clock units) of each frame index in
            % SAMPLES; out-of-range indices return NaN. Errors on a clockless
            % ('no_time') epoch.
            %
            [~, ~, isclockless, ft] = ndi_probe_image_obj.imageepochinfo(epoch);
            if isclockless
                eid = ndi_probe_image_obj.epochid(epoch);
                error('ndi:probe:image:notimeseries', ...
                    ['Epoch ''' eid ''' has clock ''no_time''; frames are ' ...
                     'addressed by index, not time.']);
            end
            times = nan(size(samples));
            valid = samples>=1 & samples<=numel(ft);
            times(valid) = ft(samples(valid));
        end % samples2times()

        %% raster acquisition metadata and sub-frame timing

        function m = imagemetadata(ndi_probe_image_obj, epoch)
            % IMAGEMETADATA - standardized image-acquisition metadata for an epoch
            %
            % M = IMAGEMETADATA(NDI_PROBE_IMAGE_OBJ, EPOCH)
            %
            % Returns the standardized image-acquisition metadata struct for
            % EPOCH from the backing ndi.daq.system.image: raster line/frame
            % timing, geometry, and scan direction, with all time fields in
            % SECONDS. See ndi.daq.reader.image/metadata for the field list.
            % Fields that are unknown (e.g. for a non-raster stack) are NaN, and
            % M.israster is false.
            %
            % See also: ndi.daq.reader.image/metadata, linetimes, pixeltimes
            [dsys, devepoch] = ndi_probe_image_obj.imageepochinfo(epoch);
            m = dsys.metadata(devepoch{1});
        end % imagemetadata()

        function tl = linetimes(ndi_probe_image_obj, timeref_or_epoch, t0, t1)
            % LINETIMES - acquisition time of each line (row) of the selected frames
            %
            % TL = LINETIMES(NDI_PROBE_IMAGE_OBJ, TIMEREF_OR_EPOCH, T0, T1)
            %
            % A raster scan builds a frame line by line, so at slow frame rates
            % the top of a frame is acquired well before the bottom. LINETIMES
            % returns the time each line (row) was scanned, so you can ask which
            % rows had been acquired at a given moment.
            %
            % The frames are selected exactly as by READFRAMES with the same
            % arguments (TIMEREF_OR_EPOCH is an ndi.time.timereference, then
            % T0,T1 are times in that reference; or an epoch number/id, then
            % T0,T1 are times in the epoch's clock). TL is returned in the SAME
            % time units as those frames.
            %
            % TL is [Lines_per_frame x Nframes]: TL(r,k) is the time the r-th
            % line of the k-th selected frame was scanned, computed as
            %   TL(r,k) = frametime(k) + (r-1) * line_period
            % so TL(1,k) equals that frame's time and each column steps down by
            % line_period. (Scan direction does not change a line's start time,
            % so BIDIRECTIONAL does not affect LINETIMES; it only matters for
            % PIXELTIMES.)
            %
            % Requires a raster epoch with a known line_period (see
            % IMAGEMETADATA); otherwise an error is raised. Clockless ('no_time')
            % epochs also error, as they have no frame times. This assumes
            % FRAMETIMES reports each frame's START time.
            %
            % Only a single epoch per call is supported; a TIMEREF interval that
            % spans multiple epochs raises an error.
            %
            % See also: pixeltimes, imagemetadata, ndi.probe.image/readframes
            if nargin<3, t0 = -Inf; end
            if nargin<4, t1 = Inf; end
            [t, epoch, Y] = ndi_probe_image_obj.frameselect(timeref_or_epoch, t0, t1);
            m = ndi_probe_image_obj.imagemetadata(epoch);
            if isnan(m.line_period)
                error('ndi:probe:image:noraster', ...
                    ['No raster line timing (line_period) is available for this ' ...
                     'epoch, so line times cannot be computed. Check imagemetadata(epoch).']);
            end
            tl = (0:Y-1)' * m.line_period + t(:)';   % [Y x Nframes]
        end % linetimes()

        function tp = pixeltimes(ndi_probe_image_obj, timeref_or_epoch, t0, t1)
            % PIXELTIMES - acquisition time of every pixel of the selected frames
            %
            % TP = PIXELTIMES(NDI_PROBE_IMAGE_OBJ, TIMEREF_OR_EPOCH, T0, T1)
            %
            % Like LINETIMES, but resolved to the individual pixel: the time each
            % pixel was sampled within a raster scan. Frame selection and time
            % units follow READFRAMES with the same arguments (see LINETIMES).
            %
            %   TP(r,c,1,1,k) = frametime(k) + (r-1)*line_period + (c-1)*dwell_time
            %
            % (For a BIDIRECTIONAL scan, alternate lines are traversed in reverse,
            % so the within-line dwell offset is mirrored on those rows.)
            %
            % COMPACT SHAPE (and why): TP is [Y X 1 1 Nframes]. A pixel's sample
            % time depends on its row (line), its column (pixel-in-line) and the
            % frame, but NOT on the color channel C (all detectors sample a given
            % beam position simultaneously) and, in v1, not on the plane Z.
            % Keeping C and Z as SINGLETON dimensions lets TP BROADCAST
            % elementwise against the full data array [Y X C Z Nframes] via
            % implicit expansion, at a fraction of the memory: times are double
            % (8 bytes) versus 2 bytes for typical uint16 pixels, so a full-size
            % time map would be ~4x the size of the image data itself.
            %
            % Example - which pixels had been scanned at an event time:
            %   [data,t,tr] = p.readframes(myref, 0, 100);
            %   tp   = p.pixeltimes(myref, 0, 100);          % [Y X 1 1 nframes]
            %   mask = tp >= eventTime;                      % [Y X 1 1 nframes]
            %   seen = data .* cast(mask, class(data));      % broadcasts over C,Z
            %
            % Example - build the FULL [Y X C Z nframes] matrix if you must:
            %   sz     = size(data);
            %   tpfull = repmat(tp, [1 1 sz(3) sz(4) 1]);    % replicate across C,Z
            % (The compact form is the default precisely so you rarely need this.)
            %
            % Requires a raster epoch with known line_period AND dwell_time;
            % otherwise an error is raised (use LINETIMES for line-level timing
            % when dwell_time is unavailable). Assumes FRAMETIMES reports each
            % frame's START time. Single epoch per call.
            %
            % See also: linetimes, imagemetadata, ndi.probe.image/readframes
            if nargin<3, t0 = -Inf; end
            if nargin<4, t1 = Inf; end
            [t, epoch, Y, X] = ndi_probe_image_obj.frameselect(timeref_or_epoch, t0, t1);
            m = ndi_probe_image_obj.imagemetadata(epoch);
            if isnan(m.line_period)
                error('ndi:probe:image:noraster', ...
                    ['No raster line timing (line_period) is available for this ' ...
                     'epoch, so pixel times cannot be computed. Check imagemetadata(epoch).']);
            end
            if isnan(m.dwell_time)
                error('ndi:probe:image:nodwell', ...
                    ['No per-pixel dwell_time is available for this epoch; ' ...
                     'per-pixel times cannot be computed. Use linetimes for line-level timing.']);
            end
            N = numel(t);
            lineoff = (0:Y-1)' * m.line_period;      % Y x 1 (line start offsets)
            if m.bidirectional
                fwd = (0:X-1) * m.dwell_time;        % 1 x X (forward line)
                rev = (X-1:-1:0) * m.dwell_time;     % 1 x X (reverse line)
                offYX = lineoff + fwd;               % Y x X, forward default
                evenrows = mod((1:Y)'-1, 2) == 1;    % rows 2,4,... traversed in reverse
                offYX(evenrows,:) = lineoff(evenrows) + rev;
            else
                offYX = lineoff + (0:X-1) * m.dwell_time;   % Y x X
            end
            % compact [Y X 1 1 N]: add each frame's start time via implicit expansion
            tp = offYX + reshape(t(:), [1 1 1 1 N]);
        end % pixeltimes()

        function ndi_document_obj = newdocument(ndi_probe_image_obj, varargin)
            ndi_document_obj = newdocument@ndi.probe(ndi_probe_image_obj, varargin{:});
        end % newdocument

        function sq = searchquery(ndi_probe_image_obj, varargin)
            sq = searchquery@ndi.probe(ndi_probe_image_obj, varargin{:});
        end % searchquery

    end % methods

    methods (Access=protected)
        function [dsys, devepoch, isclockless, ft] = imageepochinfo(ndi_probe_image_obj, epoch)
            % IMAGEEPOCHINFO - resolve the backing image daq.system and epoch timing
            %
            % [DSYS, DEVEPOCH, ISCLOCKLESS, FT] = IMAGEEPOCHINFO(OBJ, EPOCH)
            %
            % Helper for the ndi.time.timeseries methods. Returns the backing
            % ndi.daq.system.image DSYS and its epoch file list DEVEPOCH for
            % EPOCH, whether the epoch is clockless (ISCLOCKLESS), and, when a
            % fourth output is requested, the per-frame times FT (column vector)
            % in the epoch's clock. Mirrors the device resolution done in
            % READFRAMESEPOCH.
            %
            [dev,~,devepoch] = ndi_probe_image_obj.getchanneldevinfo(epoch);
            if numel(vlt.data.equnique(dev))>1
                error('ndi:probe:image:mixeddevices','Do not know how to mix devices for an image probe.');
            end
            dsys = dev{1};
            if ~isa(dsys,'ndi.daq.system.image')
                error('ndi:probe:image:notimagedaq','ndi.probe.image must be backed by an ndi.daq.system.image.');
            end
            ec = dsys.epochclock(devepoch{1});
            isclockless = ~isempty(ec) && strcmp(ec{1}.type,'no_time');
            if nargout>=4
                n = dsys.numframes(devepoch{1});
                ft = dsys.frametimes(devepoch{1}, 1:n);
                ft = ft(:);
            end
        end % imageepochinfo()

        function [t, epoch, Y, X] = frameselect(ndi_probe_image_obj, timeref_or_epoch, t0, t1)
            % FRAMESELECT - select frames in [t0,t1] and return their times and geometry
            %
            % [T, EPOCH, Y, X] = FRAMESELECT(OBJ, TIMEREF_OR_EPOCH, T0, T1)
            %
            % Helper for LINETIMES / PIXELTIMES. Chooses the frames of a single
            % image epoch whose times fall within [T0,T1] and returns their
            % times T (a column vector, in the same units as READFRAMES would
            % return: the requested timereference's units, or the epoch's clock
            % when an epoch is passed), the resolved EPOCH id/number, and the
            % frame geometry Y (rows/lines) and X (columns/pixels). It reads
            % frame times and geometry only -- it does NOT read pixel data.
            %
            % TIMEREF_OR_EPOCH follows the READFRAMES convention. Only a single
            % epoch per call is supported; a timereference interval spanning more
            % than one epoch, or one with no time mapping, raises an error, as
            % does a clockless ('no_time') epoch.
            %
            if ~isa(timeref_or_epoch,'ndi.time.timereference')
                epoch = timeref_or_epoch;
                [dsys, devepoch, isclockless] = ndi_probe_image_obj.imageepochinfo(epoch);
                if isclockless
                    eid = ndi_probe_image_obj.epochid(epoch);
                    error('ndi:probe:image:notimeseries', ...
                        ['Epoch ''' eid ''' has clock ''no_time''; it has no frame times.']);
                end
                n = dsys.numframes(devepoch{1});
                ft = dsys.frametimes(devepoch{1}, 1:n); ft = ft(:);
                frameind = find(ft>=t0 & ft<=t1);
                t = ft(frameind);
            else
                timeref = timeref_or_epoch;
                dlt = ndi.time.clocktype('dev_local_time');
                [t0c, e0] = ndi_probe_image_obj.session.syncgraph.time_convert(timeref, t0, ndi_probe_image_obj, dlt);
                [t1c, e1] = ndi_probe_image_obj.session.syncgraph.time_convert(timeref, t1, ndi_probe_image_obj, dlt);
                if isempty(e0) || isempty(e1)
                    error('ndi:probe:image:notimemapping','Could not find a time mapping (maybe a wrong epoch name?).');
                end
                if ~isequal(e0.epoch, e1.epoch)
                    error('ndi:probe:image:multiepoch', ...
                        ['linetimes/pixeltimes support a single epoch per call; the requested ' ...
                         '[t0,t1] spans more than one epoch. Call per epoch.']);
                end
                epoch = e0.epoch;
                [dsys, devepoch, isclockless] = ndi_probe_image_obj.imageepochinfo(epoch);
                if isclockless
                    error('ndi:probe:image:notimeseries', ...
                        ['Epoch ''' ndi_probe_image_obj.epochid(epoch) ''' has clock ''no_time''; it has no frame times.']);
                end
                n = dsys.numframes(devepoch{1});
                ft = dsys.frametimes(devepoch{1}, 1:n); ft = ft(:);   % epoch (dev_local) clock
                frameind = find(ft>=t0c & ft<=t1c);
                ftsel = ft(frameind);
                % convert the selected frame times back into the requested reference
                epoch_here_timeref = ndi.time.timereference(ndi_probe_image_obj, dlt, e0.epoch, 0);
                if ~isempty(ftsel)
                    t = ndi_probe_image_obj.session.syncgraph.time_convert(epoch_here_timeref, ftsel, ...
                        timeref.referent, timeref.clocktype);
                    t = t(:);
                else
                    t = ftsel;
                end
            end
            sz = dsys.framesize(devepoch{1});
            Y = sz(1);
            X = sz(2);
        end % frameselect()
    end % methods (Access=protected)
end % classdef
