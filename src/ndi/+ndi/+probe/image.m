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

        %% ndi.time.timeseries interface

        function [data, t, timeref] = readtimeseries(ndi_probe_image_obj, timeref_or_epoch, t0, t1)
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
            if nargin<3, t0 = -Inf; end
            if nargin<4, t1 = Inf; end
            if isa(timeref_or_epoch,'ndi.time.timereference')
                % time-reference path: the syncgraph maps the request into the
                % epoch clock. A clockless epoch has no 'dev_local_time' and so
                % never falls within a time range; READFRAMES handles the rest.
                [data, t, timeref] = ndi_probe_image_obj.readframes(timeref_or_epoch, t0, t1);
            else
                [data, t, timeref] = ndi_probe_image_obj.readtimeseriesepoch(timeref_or_epoch, t0, t1);
            end
        end % readtimeseries()

        function [data, t, timeref] = readtimeseriesepoch(ndi_probe_image_obj, epoch, t0, t1)
            % READTIMESERIESEPOCH - read image frames from one epoch as a time series
            %
            % [DATA, T, TIMEREF] = READTIMESERIESEPOCH(NDI_PROBE_IMAGE_OBJ, EPOCH, T0, T1)
            %
            % Returns the frames of EPOCH whose times (in the epoch's clock) fall
            % within [T0,T1], as DATA, with the frame times T and the epoch
            % TIMEREF. EPOCH is an epoch number or id.
            %
            % If EPOCH is clockless (its clock is 'no_time') this method errors,
            % because a time series has no meaning without a clock; use
            % ndi.probe.image/readframes with frame indices instead.
            %
            if nargin<3, t0 = -Inf; end
            if nargin<4, t1 = Inf; end
            [~, ~, isclockless] = ndi_probe_image_obj.imageepochinfo(epoch);
            if isclockless
                eid = ndi_probe_image_obj.epochid(epoch);
                error('ndi:probe:image:notimeseries', ...
                    ['Epoch ''' eid ''' has clock ''no_time''; it has no ' ...
                     'time <-> frame mapping and cannot be read as a time series. ' ...
                     'Use readframes(epoch, frameind) with frame indices instead.']);
            end
            [data, t, timeref] = ndi_probe_image_obj.readframesepoch(epoch, t0, t1);
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
    end % methods (Access=protected)
end % classdef
