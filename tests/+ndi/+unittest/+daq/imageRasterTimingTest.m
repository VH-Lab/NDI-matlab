classdef imageRasterTimingTest < matlab.unittest.TestCase
    % IMAGERASTERTIMINGTEST - test ndi.probe.image sub-frame (line/pixel) timing
    %
    %   Builds a single-epoch image movie (via the NDR 'tiffstack' reader)
    %   with known per-frame times, and injects known raster metadata through
    %   a test-double reader (rasterSidecarReader reads a 'raster.mat'
    %   sidecar). It then checks that:
    %     - the metadata is passed forward (daq.system and probe),
    %     - linetimes() = frametime + (row-1)*line_period, with row 1 equal to
    %       the frame time (the frame-START convention),
    %     - pixeltimes() is the compact [Y X 1 1 nframes] map with the dwell
    %       offset added along the pixel (X) axis,
    %     - a non-raster reader reports israster=false.
    %
    %   Skipped when NDR-matlab's 'tiffstack' reader is not on the path.

    properties (Constant)
        Y = 6;    % lines per frame (rows)
        X = 8;    % pixels per line (cols)
        T = 5;    % number of frames
        LinePeriod = 0.010;   % s per line
        DwellTime  = 2e-6;    % s per pixel
        FramePeriod = 2.0;    % s per frame (slow raster: top acquired ~2 s before next frame)
    end

    methods (Test)

        function testRasterTiming(testCase)
            import ndi.unittest.daq.imageRasterTimingTest

            testCase.assumeTrue(imageRasterTimingTest.tiffstackAvailable(), ...
                'NDR-matlab ''tiffstack'' reader is not available; skipping raster-timing test.');

            Y = testCase.Y; X = testCase.X; T = testCase.T;

            dirname = tempname();
            mkdir(dirname);
            cleaner = onCleanup(@() imageRasterTimingTest.removeDir(dirname));

            % ---- synthesize a movie epoch with known frame START times -----
            truth = imageRasterTimingTest.makeStack(Y,X,T);
            moviefile = fullfile(dirname,'movie.tif');
            imageRasterTimingTest.writeMultipageTiff(moviefile, truth);

            times = (0:T-1)' * testCase.FramePeriod + 10;   % dev_local_time, seconds
            imageRasterTimingTest.writeAscii(fullfile(dirname,'movie_frametimes.txt'), times);
            imageRasterTimingTest.writeProbeMap(fullfile(dirname,'movie.epochprobemap.ndi'));

            % ---- known raster metadata via the sidecar --------------------
            m = ndi.daq.reader.image.emptymetadata();
            m.israster = true;
            m.frame_period = testCase.FramePeriod;
            m.line_period = testCase.LinePeriod;
            m.dwell_time = testCase.DwellTime;
            m.lines_per_frame = Y;
            m.pixels_per_line = X;
            m.bidirectional = false;
            save(fullfile(dirname,'raster.mat'), 'm');

            % ---- build the session / image daq.system ---------------------
            E = ndi.session.dir('rasterexp', dirname);
            E.database_clear('yes');
            subject = ndi.subject('mouse1@nosuchlab.org','');
            E.database_add(subject.newdocument());

            nav = ndi.file.navigator(E, {'#.tif', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)\.epochprobemap.ndi'});
            reader = ndi.unittest.daq.rasterSidecarReader('tiffstack');
            dev = ndi.daq.system.image('image1', nav, reader);
            E.daqsystem_add(dev);
            E.cache.clear();

            et = dev.epochtable();
            testCase.assertEqual(numel(et), 1, 'Expected a single movie epoch.');
            epoch = et(1).epoch_id;

            % ---- (1) metadata is passed forward at the daq.system ----------
            md = dev.metadata(epoch);
            testCase.verifyTrue(md.israster, 'daq.system metadata should report israster.');
            testCase.verifyEqual(md.line_period, testCase.LinePeriod, 'AbsTol', 1e-12, ...
                'daq.system line_period mismatch.');

            % ---- (2) probe: metadata + sub-frame timing --------------------
            p = E.getprobes('name','camera');
            testCase.assertNotEmpty(p, 'Expected an imaging probe.');
            if iscell(p), p = p{1}; end
            testCase.verifyClass(p, 'ndi.probe.image', 'Imaging probe should be an ndi.probe.image.');

            pm = p.imagemetadata(epoch);
            testCase.verifyTrue(pm.israster, 'probe imagemetadata should survive the round-trip.');
            testCase.verifyEqual(pm.dwell_time, testCase.DwellTime, 'AbsTol', 1e-15, ...
                'probe dwell_time mismatch (metadata lost on round-trip?).');

            % linetimes: [Y x T], row 1 == frame start time, step by line_period
            tl = p.linetimes(epoch);
            testCase.verifyEqual(size(tl), [Y T], 'linetimes should be [lines x frames].');
            expected_tl = (0:Y-1)' * testCase.LinePeriod + times';
            testCase.verifyEqual(tl, expected_tl, 'AbsTol', 1e-9, 'linetimes values mismatch.');
            testCase.verifyEqual(tl(1,:), times', 'AbsTol', 1e-9, ...
                'linetimes row 1 should equal the frame START times.');

            % pixeltimes: compact [Y X 1 1 T]; dwell offset along X
            tp = p.pixeltimes(epoch);
            testCase.verifyEqual(size(tp), [Y X 1 1 T], 'pixeltimes should be compact [Y X 1 1 nframes].');
            offYX = (0:Y-1)' * testCase.LinePeriod + (0:X-1) * testCase.DwellTime;   % Y x X
            for k=1:T
                testCase.verifyEqual(tp(:,:,1,1,k), offYX + times(k), 'AbsTol', 1e-9, ...
                    sprintf('pixeltimes frame %d mismatch.', k));
            end

            % windowed selection matches the frames readframes would return
            t_lo = times(2); t_hi = times(4);
            tlw = p.linetimes(epoch, t_lo, t_hi);
            testCase.verifyEqual(size(tlw,2), 3, 'Windowed linetimes should cover 3 frames.');
            testCase.verifyEqual(tlw, (0:Y-1)' * testCase.LinePeriod + times(2:4)', 'AbsTol', 1e-9, ...
                'Windowed linetimes values mismatch.');

            % ---- (3) element delegates to the probe ------------------------
            elem = ndi.element.image(E, 'camera_elem', 1, 'wide-field-imaging', p, 1);
            tle = elem.linetimes(epoch);
            testCase.verifyEqual(tle, tl, 'AbsTol', 1e-12, 'element.image linetimes disagreed with probe.');

            % ---- (4) a non-raster reader reports israster=false ------------
            plain = ndi.daq.reader.image.ndr('tiffstack');
            m0 = plain.metadata({moviefile});
            testCase.verifyFalse(m0.israster, 'A plain tiffstack reader should not report raster timing.');
        end % testRasterTiming

    end % methods (Test)

    methods (Static)

        function tf = tiffstackAvailable()
            tf = false;
            if isempty(which('ndr.known_readers')), return; end
            try
                tf = any(strcmpi('tiffstack', ndr.known_readers()));
            catch
                tf = false;
            end
        end

        function s = makeStack(Y,X,T)
            s = zeros(Y,X,1,1,T,'uint16');
            for i=1:T
                s(:,:,1,1,i) = uint16( reshape(1:(Y*X), Y, X) + (i-1)*100 );
            end
        end

        function writeMultipageTiff(filename, data)
            sz = size(data);
            if numel(sz)<5, sz(end+1:5) = 1; end
            T = sz(5);
            t = Tiff(filename,'w');
            c = onCleanup(@() t.close());
            for i=1:T
                tags.ImageLength = sz(1);
                tags.ImageWidth = sz(2);
                tags.Photometric = Tiff.Photometric.MinIsBlack;
                tags.BitsPerSample = 16;
                tags.SamplesPerPixel = sz(3);
                tags.SampleFormat = Tiff.SampleFormat.UInt;
                tags.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
                tags.Compression = Tiff.Compression.None;
                t.setTag(tags);
                t.write(squeeze(data(:,:,:,1,i)));
                if i<T, t.writeDirectory(); end
            end
        end

        function writeAscii(filename, v)
            fid = fopen(filename,'w');
            c = onCleanup(@() fclose(fid));
            fprintf(fid,'%.10g\n', v);
        end

        function writeProbeMap(filename)
            fid = fopen(filename,'wt');
            if fid<0, error(['Could not open ' filename ' for writing.']); end
            c = onCleanup(@() fclose(fid));
            fprintf(fid,'name\treference\ttype\tdevicestring\tsubjectstring\n');
            fprintf(fid,'camera\t1\twide-field-imaging\timage1:image1\tmouse1@nosuchlab.org\n');
        end

        function removeDir(dirname)
            if ~isempty(dirname) && isfolder(dirname)
                try
                    rmdir(dirname,'s');
                catch ME
                    warning('Could not remove temporary directory %s: %s', dirname, ME.message);
                end
            end
        end

    end % methods (Static)
end % classdef
