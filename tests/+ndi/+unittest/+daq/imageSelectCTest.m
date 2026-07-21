classdef imageSelectCTest < matlab.unittest.TestCase
    % IMAGESELECTCTEST - test SelectC channel selection through the NDI image path
    %
    %   Builds a 2-channel movie epoch (interleaved-sample multipage TIFF, via
    %   the NDR 'tiffstack' reader) and checks that the 'SelectC' option
    %   returns only the requested channel(s) at every layer that exposes it:
    %   the ndi.daq.system.image, the ndi.probe.image (readframes and
    %   readtimeseries), and the delegating ndi.element.image. SelectZ is a
    %   singleton here (tiffstack has one plane), so this focuses on SelectC.
    %
    %   Skipped when NDR-matlab's 'tiffstack' reader is not on the path.

    properties (Constant)
        Y = 5;
        X = 7;
        C = 2;
        T = 4;
    end

    methods (Test)

        function testSelectC(testCase)
            import ndi.unittest.daq.imageSelectCTest

            testCase.assumeTrue(imageSelectCTest.tiffstackAvailable(), ...
                'NDR-matlab ''tiffstack'' reader is not available; skipping SelectC test.');

            Y = testCase.Y; X = testCase.X; C = testCase.C; T = testCase.T;

            dirname = tempname();
            mkdir(dirname);
            cleaner = onCleanup(@() imageSelectCTest.removeDir(dirname));

            % ---- 2-channel movie with distinct per-channel content ---------
            truth = zeros(Y,X,C,1,T,'uint16');
            for c=1:C
                for i=1:T
                    truth(:,:,c,1,i) = uint16( reshape(1:(Y*X), Y, X) + (i-1)*100 + c*10000 );
                end
            end
            moviefile = fullfile(dirname,'movie.tif');
            imageSelectCTest.writeMultiChannelTiff(moviefile, truth);

            times = (0:T-1)' * 0.5 + 5;   % dev_local_time, seconds (a movie)
            imageSelectCTest.writeAscii(fullfile(dirname,'movie_frametimes.txt'), times);
            imageSelectCTest.writeProbeMap(fullfile(dirname,'movie.epochprobemap.ndi'));

            % ---- session / image daq.system --------------------------------
            E = ndi.session.dir('selectc', dirname);
            E.database_clear('yes');
            subject = ndi.subject('mouse1@nosuchlab.org','');
            E.database_add(subject.newdocument());

            nav = ndi.file.navigator(E, {'#.tif', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)\.epochprobemap.ndi'});
            reader = ndi.daq.reader.image.ndr('tiffstack');
            dev = ndi.daq.system.image('image1', nav, reader);
            E.daqsystem_add(dev);
            E.cache.clear();

            et = dev.epochtable();
            testCase.assertEqual(numel(et), 1, 'Expected a single movie epoch.');
            epoch = et(1).epoch_id;

            % ---- (1) daq.system: full read then SelectC --------------------
            testCase.verifyEqual(dev.framesize(epoch), [Y X C 1 T], 'framesize mismatch.');
            testCase.verifyEqual(dev.readframes(epoch), truth, 'Full 2-channel read mismatch.');
            f2 = dev.readframes(epoch, [], 'SelectC', 2);
            testCase.verifyEqual(size(f2,3), 1, 'daq.system SelectC=2 should return one channel.');
            testCase.verifyEqual(f2, truth(:,:,2,:,:), 'daq.system SelectC=2 returned the wrong channel.');
            % reversed order
            f21 = dev.readframes(epoch, [], 'SelectC', [2 1]);
            testCase.verifyEqual(f21, truth(:,:,[2 1],:,:), 'daq.system SelectC=[2 1] order mismatch.');

            % ---- (2) probe: readframes / readtimeseries with SelectC -------
            p = E.getprobes('name','camera');
            testCase.assertNotEmpty(p, 'Expected an imaging probe.');
            if iscell(p), p = p{1}; end

            imgs_all = p.readframes(epoch);
            testCase.verifyEqual(imgs_all, truth, 'probe full read mismatch.');

            imgs_c1 = p.readframes(epoch, -Inf, Inf, 'SelectC', 1);
            testCase.verifyEqual(imgs_c1, truth(:,:,1,:,:), 'probe readframes SelectC=1 mismatch.');

            [data_c2, t_c2] = p.readtimeseries(epoch, -Inf, Inf, 'SelectC', 2);
            testCase.verifyEqual(data_c2, truth(:,:,2,:,:), 'probe readtimeseries SelectC=2 mismatch.');
            testCase.verifyEqual(t_c2(:), times, 'AbsTol', 1e-9, 'probe readtimeseries times mismatch.');

            % ---- (3) element delegates SelectC -----------------------------
            elem = ndi.element.image(E, 'camera_elem', 1, 'wide-field-imaging', p, 1);
            imgs_e = elem.readframes(epoch, -Inf, Inf, 'SelectC', 2);
            testCase.verifyEqual(imgs_e, truth(:,:,2,:,:), 'element readframes SelectC=2 mismatch.');
        end % testSelectC

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

        function writeMultiChannelTiff(filename, data)
            sz = size(data);
            if numel(sz)<5, sz(end+1:5) = 1; end
            Y = sz(1); X = sz(2); C = sz(3); T = sz(5);
            t = Tiff(filename,'w');
            c = onCleanup(@() t.close());
            for i=1:T
                tags.ImageLength = Y;
                tags.ImageWidth = X;
                tags.Photometric = Tiff.Photometric.MinIsBlack;
                tags.BitsPerSample = 16;
                tags.SamplesPerPixel = C;
                tags.SampleFormat = Tiff.SampleFormat.UInt;
                tags.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
                tags.Compression = Tiff.Compression.None;
                if C>1
                    tags.ExtraSamples = repmat(Tiff.ExtraSamples.Unspecified, 1, C-1);
                end
                t.setTag(tags);
                t.write(reshape(data(:,:,:,1,i), Y, X, C));
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
