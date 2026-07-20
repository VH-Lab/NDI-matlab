% NDI_DAQSYSTEM_IMAGE - Image-series DAQ system class
%
% The ndi.daq.system.image object class.
%
% This object addresses data acquisition systems that produce image-series
% data: frames on a pixel grid (2-photon/widefield movies, z-stacks,
% histology/slide scans, etc.). It is the imaging peer of
% ndi.daq.system.mfdaq. Its ndi.daq.reader must be an ndi.daq.reader.image.
%
% Unlike mfdaq, an image daq.system reads FRAMES, not (sample x channel)
% columns. The frame API (numframes, framesize, readframes, frametimes,
% dimensionorder, datatype) is delegated to the reader, transparently using
% either the live files or the ingested-epoch document.
%
% Clock model: a clockless slide scan / z-stack is one epoch with clock
% 'no_time' and frames addressed by index. A movie is one epoch with a real
% clock ('dev_local_time') whose per-frame times come from FRAMETIMES; the
% element/probe surface those through the NDI epoch clock / syncgraph system.
%
% See also: ndi.daq.system, ndi.daq.system.mfdaq, ndi.daq.reader.image

classdef image < ndi.daq.system

    properties (GetAccess=public,SetAccess=protected)
    end

    methods
        function obj = image(varargin)
            % ndi.daq.system.image - Create a new image-series DAQ system object
            %
            %  D = ndi.daq.system.image(NAME, THEFILENAVIGATOR, THEDAQREADER)
            %
            %  Creates a new ndi.daq.system.image object. THEDAQREADER must be
            %  an ndi.daq.reader.image.
            %
            obj = obj@ndi.daq.system(varargin{:});

            if ~isempty(obj.daqreader)
                if ~isa(obj.daqreader,'ndi.daq.reader.image')
                    error('The DAQREADER for an ndi.daq.system.image object must be a type of ndi.daq.reader.image.');
                end
            end
        end % ndi.daq.system.image

        %% functions that override ndi.epoch.epochset

        function ec = epochclock(ndi_daqsystem_image_obj, epoch)
            % EPOCHCLOCK - return the ndi.time.clocktype objects for an epoch
            %
            % EC = EPOCHCLOCK(NDI_DAQSYSTEM_IMAGE_OBJ, EPOCH)
            %
            % For a clockless image epoch this is 'no_time'; for a movie it is
            % the reader's real clock (e.g. 'dev_local_time').
            epochfiles = ndi_daqsystem_image_obj.filenavigator.getepochfiles(epoch);
            if ~ndi.file.navigator.isingested(epochfiles)
                ec = ndi_daqsystem_image_obj.daqreader.epochclock(epochfiles);
            else
                ec = ndi_daqsystem_image_obj.daqreader.epochclock_ingested(epochfiles, ...
                    ndi_daqsystem_image_obj.session());
            end
        end % epochclock()

        function t0t1 = t0_t1(ndi_daqsystem_image_obj, epoch)
            % T0_T1 - return the [t0 t1] begin/end epoch times for an epoch
            %
            % T0T1 = T0_T1(NDI_DAQSYSTEM_IMAGE_OBJ, EPOCH)
            %
            epochfiles = ndi_daqsystem_image_obj.filenavigator.getepochfiles(epoch);
            if ~ndi.file.navigator.isingested(epochfiles)
                t0t1 = ndi_daqsystem_image_obj.daqreader.t0_t1(epochfiles);
            else
                t0t1 = ndi_daqsystem_image_obj.daqreader.t0_t1_ingested(epochfiles, ...
                    ndi_daqsystem_image_obj.session());
            end
        end % t0_t1()

        function channels = getchannels(ndi_daqsystem_image_obj)
            % GETCHANNELS - list the image channels available on this device
            %
            % CHANNELS = GETCHANNELS(NDI_DAQSYSTEM_IMAGE_OBJ)
            %
            channels = struct('name',[],'type',[],'time_channel',[]);
            channels = channels([]);
            N = numepochs(ndi_daqsystem_image_obj);
            for n=1:N
                epochfiles = getepochfiles(ndi_daqsystem_image_obj.filenavigator, n);
                if ~ndi.file.navigator.isingested(epochfiles)
                    channels_here = getchannelsepoch(ndi_daqsystem_image_obj.daqreader, epochfiles);
                else
                    channels_here = getchannelsepoch_ingested(ndi_daqsystem_image_obj.daqreader, ...
                        epochfiles, ndi_daqsystem_image_obj.session());
                end
                channels = vlt.data.equnique( [channels(:); channels_here(:)] );
            end
        end % getchannels()

        function channels = getchannelsepoch(ndi_daqsystem_image_obj, epoch)
            % GETCHANNELSEPOCH - list the image channels available for an epoch
            %
            % CHANNELS = GETCHANNELSEPOCH(NDI_DAQSYSTEM_IMAGE_OBJ, EPOCH)
            %
            channels = struct('name',[],'type',[],'time_channel',[]);
            channels = channels([]);
            epochfiles = getepochfiles(ndi_daqsystem_image_obj.filenavigator, epoch);
            if ~ndi.file.navigator.isingested(epochfiles)
                channels_here = getchannelsepoch(ndi_daqsystem_image_obj.daqreader, epochfiles);
            else
                channels_here = getchannelsepoch_ingested(ndi_daqsystem_image_obj.daqreader, ...
                    epochfiles, ndi_daqsystem_image_obj.session());
            end
            channels = vlt.data.equnique( [channels(:); channels_here(:)] );
        end % getchannelsepoch()

        %% frame API (delegated to the reader, ingested-aware)

        function n = numframes(ndi_daqsystem_image_obj, epoch)
            % NUMFRAMES - number of frames in an image epoch
            %
            % N = NUMFRAMES(NDI_DAQSYSTEM_IMAGE_OBJ, EPOCH)
            %
            epochfiles = getepochfiles(ndi_daqsystem_image_obj.filenavigator, epoch);
            if ~ndi.file.navigator.isingested(epochfiles)
                n = ndi_daqsystem_image_obj.daqreader.numframes(epochfiles);
            else
                n = ndi_daqsystem_image_obj.daqreader.numframes_ingested(epochfiles, ndi_daqsystem_image_obj.session());
            end
        end % numframes()

        function sz = framesize(ndi_daqsystem_image_obj, epoch)
            % FRAMESIZE - [Y X C Z T] extent of an image epoch, without reading pixels
            %
            % SZ = FRAMESIZE(NDI_DAQSYSTEM_IMAGE_OBJ, EPOCH)
            %
            epochfiles = getepochfiles(ndi_daqsystem_image_obj.filenavigator, epoch);
            if ~ndi.file.navigator.isingested(epochfiles)
                sz = ndi_daqsystem_image_obj.daqreader.framesize(epochfiles);
            else
                sz = ndi_daqsystem_image_obj.daqreader.framesize_ingested(epochfiles, ndi_daqsystem_image_obj.session());
            end
        end % framesize()

        function m = metadata(ndi_daqsystem_image_obj, epoch)
            % METADATA - standardized image-acquisition metadata for an epoch
            %
            % M = METADATA(NDI_DAQSYSTEM_IMAGE_OBJ, EPOCH)
            %
            % Returns the standardized image-acquisition metadata struct for the
            % epoch (raster line/frame timing, geometry, scan direction), with
            % all time fields in SECONDS. See ndi.daq.reader.image/metadata for
            % the field list. Read from the live files, or from the ingested
            % epoch document when the epoch has been ingested.
            %
            epochfiles = getepochfiles(ndi_daqsystem_image_obj.filenavigator, epoch);
            if ~ndi.file.navigator.isingested(epochfiles)
                m = ndi_daqsystem_image_obj.daqreader.metadata(epochfiles);
            else
                m = ndi_daqsystem_image_obj.daqreader.metadata_ingested(epochfiles, ndi_daqsystem_image_obj.session());
            end
        end % metadata()

        function order = dimensionorder(ndi_daqsystem_image_obj, epoch)
            % DIMENSIONORDER - dimension order of returned frames for an epoch
            epochfiles = getepochfiles(ndi_daqsystem_image_obj.filenavigator, epoch);
            if ~ndi.file.navigator.isingested(epochfiles)
                order = ndi_daqsystem_image_obj.daqreader.dimensionorder(epochfiles);
            else
                order = ndi_daqsystem_image_obj.daqreader.dimensionorder_ingested(epochfiles, ndi_daqsystem_image_obj.session());
            end
        end % dimensionorder()

        function dt = datatype(ndi_daqsystem_image_obj, epoch)
            % DATATYPE - underlying numeric class of the image data for an epoch
            epochfiles = getepochfiles(ndi_daqsystem_image_obj.filenavigator, epoch);
            if ~ndi.file.navigator.isingested(epochfiles)
                dt = ndi_daqsystem_image_obj.daqreader.datatype(epochfiles);
            else
                dt = ndi_daqsystem_image_obj.daqreader.datatype_ingested(epochfiles, ndi_daqsystem_image_obj.session());
            end
        end % datatype()

        function t = frametimes(ndi_daqsystem_image_obj, epoch, frameind)
            % FRAMETIMES - per-frame times for an epoch, in epoch-clock units
            %
            % T = FRAMETIMES(NDI_DAQSYSTEM_IMAGE_OBJ, EPOCH, FRAMEIND)
            %
            epochfiles = getepochfiles(ndi_daqsystem_image_obj.filenavigator, epoch);
            if nargin<3, frameind = 1:ndi_daqsystem_image_obj.numframes(epoch); end
            if ~ndi.file.navigator.isingested(epochfiles)
                t = ndi_daqsystem_image_obj.daqreader.frametimes(epochfiles, frameind);
            else
                t = ndi_daqsystem_image_obj.daqreader.frametimes_ingested(epochfiles, frameind, ndi_daqsystem_image_obj.session());
            end
        end % frametimes()

        function frames = readframes(ndi_daqsystem_image_obj, epoch, frameind)
            % READFRAMES - read image frames for an epoch
            %
            % FRAMES = READFRAMES(NDI_DAQSYSTEM_IMAGE_OBJ, EPOCH, FRAMEIND)
            %
            % Returns an array in 'YXCZT' order, [Y X C 1 numel(FRAMEIND)].
            %
            epochfiles = getepochfiles(ndi_daqsystem_image_obj.filenavigator, epoch);
            if nargin<3, frameind = 1:ndi_daqsystem_image_obj.numframes(epoch); end
            if ~ndi.file.navigator.isingested(epochfiles)
                frames = ndi_daqsystem_image_obj.daqreader.readframes(epochfiles, frameind);
            else
                frames = ndi_daqsystem_image_obj.daqreader.readframes_ingested(epochfiles, frameind, ndi_daqsystem_image_obj.session());
            end
        end % readframes()

    end % methods
end % classdef
