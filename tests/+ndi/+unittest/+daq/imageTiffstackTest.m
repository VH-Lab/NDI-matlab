classdef imageTiffstackTest < matlab.unittest.TestCase
    % IMAGETIFFSTACKTEST - end-to-end test of the imageseries DAQ machinery
    %
    %   Exercises ndi.daq.system.image with the NDR bridge reader
    %   ndi.daq.reader.image.ndr('tiffstack'): builds a session with two
    %   epochs (a clockless image stack and a movie with per-frame times),
    %   then checks the live frame API, the ndi.probe.image / ndi.element.image
    %   read path (frame times through the NDI epoch-clock / syncgraph system),
    %   and ingestion followed by reading the frames/times back from the
    %   ingested documents.
    %
    %   The test is skipped (via assumeTrue) when NDR-matlab or its 'tiffstack'
    %   reader is not on the path, so it does not fail in environments without
    %   the dependency.

    methods (Test)

        function testImageDaqEndToEnd(testCase)
            import ndi.unittest.daq.imageTiffstackTest

            testCase.assumeTrue(imageTiffstackTest.tiffstackAvailable(), ...
                'NDR-matlab ''tiffstack'' reader is not available; skipping imageseries DAQ test.');

            dirname = tempname();
            mkdir(dirname);
            cleaner = onCleanup(@() imageTiffstackTest.removeDir(dirname));

            % ---- synthesize two epochs of TIFF data ----------------------
            Y = 10; X = 8; T = 6;
            truthA = imageTiffstackTest.makeStack(Y,X,T,0);     % clockless stack
            truthB = imageTiffstackTest.makeStack(Y,X,T,1000);  % movie

            fileA = fullfile(dirname,'stackA.tif');
            fileB = fullfile(dirname,'movieB.tif');
            imageTiffstackTest.writeMultipageTiff(fileA, truthA);
            imageTiffstackTest.writeMultipageTiff(fileB, truthB);

            timesB = (0:T-1)' * 0.05 + 100;   % dev_local_time, seconds
            imageTiffstackTest.writeAscii(fullfile(dirname,'movieB_frametimes.txt'), timesB);

            imageTiffstackTest.writeProbeMap(fullfile(dirname,'stackA.epochprobemap.ndi'));
            imageTiffstackTest.writeProbeMap(fullfile(dirname,'movieB.epochprobemap.ndi'));

            % ---- build the session and image daq.system ------------------
            E = ndi.session.dir('imgexp', dirname);
            E.database_clear('yes');

            subject = ndi.subject('mouse1@nosuchlab.org','');
            E.database_add(subject.newdocument());

            nav = ndi.file.navigator(E, {'#.tif', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)\.epochprobemap.ndi'});
            reader = ndi.daq.reader.image.ndr('tiffstack');
            dev = ndi.daq.system.image('image1', nav, reader);
            E.daqsystem_add(dev);
            E.cache.clear();

            % ---- map epoch ids to our two known epochs -------------------
            et = dev.epochtable();
            testCase.assertEqual(numel(et), 2, 'Expected 2 epochs.');
            epochA = imageTiffstackTest.findEpoch(et, 'stackA');
            epochB = imageTiffstackTest.findEpoch(et, 'movieB');

            % ---- (1) live frame API on the daq.system --------------------
            testCase.verifyEqual(dev.numframes(epochA), T, 'numframes (clockless) mismatch.');
            testCase.verifyEqual(dev.framesize(epochA), [Y X 1 1 T], 'framesize (clockless) mismatch.');
            testCase.verifyEqual(dev.datatype(epochA), 'uint16', 'datatype mismatch.');

            ecA = dev.epochclock(epochA);
            testCase.verifyEqual(ecA{1}.type, 'no_time', 'clockless epoch clock should be no_time.');
            ecB = dev.epochclock(epochB);
            testCase.verifyEqual(ecB{1}.type, 'dev_local_time', 'movie epoch clock should be dev_local_time.');

            testCase.verifyEqual(dev.readframes(epochA), truthA, 'clockless frames did not round-trip (live).');
            testCase.verifyEqual(dev.readframes(epochB), truthB, 'movie frames did not round-trip (live).');

            ftB = dev.frametimes(epochB);
            testCase.verifyEqual(ftB(:), timesB, 'movie frametimes mismatch (live).');
            testCase.verifyTrue(all(isnan(dev.frametimes(epochA))), 'clockless frametimes should be NaN (live).');

            % ---- (2) read through the probe / element --------------------
            p = E.getprobes('name','camera');
            testCase.assertNotEmpty(p, 'Expected an imaging probe.');
            if iscell(p), p = p{1}; end
            testCase.verifyClass(p, 'ndi.probe.image', 'Imaging probe should be an ndi.probe.image.');

            % time-windowed read of the movie: frames whose times are in [t_lo,t_hi]
            t_lo = timesB(2); t_hi = timesB(4);
            [imgs, tt] = p.readframes(epochB, t_lo, t_hi);
            testCase.verifyEqual(size(imgs,5), 3, 'Time-windowed movie read should return 3 frames.');
            testCase.verifyEqual(tt(:), timesB(2:4), 'Time-windowed movie read returned wrong timestamps.');
            testCase.verifyEqual(imgs, truthB(:,:,:,:,2:4), 'Time-windowed movie read returned wrong frames.');

            elem = ndi.element.image(E, 'camera_elem', 1, 'wide-field-imaging', p, 1);
            [imgs2, tt2] = elem.readframes(epochB, t_lo, t_hi);
            testCase.verifyEqual(imgs2, imgs, 'element.image read disagreed with probe read (frames).');
            testCase.verifyEqual(tt2(:), tt(:), 'element.image read disagreed with probe read (times).');

            % ---- (3) ingest, then read back from ingested documents ------
            [b, ~] = dev.ingest();
            testCase.verifyEqual(b, 1, 'ingest() did not report success.');
            E.cache.clear();

            testCase.verifyEqual(dev.readframes(epochA), truthA, 'clockless frames did not round-trip (ingested).');
            testCase.verifyEqual(dev.readframes(epochB), truthB, 'movie frames did not round-trip (ingested).');
            ftB_i = dev.frametimes(epochB);
            testCase.verifyEqual(ftB_i(:), timesB, 'movie frametimes mismatch (ingested).');
            ecB_i = dev.epochclock(epochB);
            testCase.verifyEqual(ecB_i{1}.type, 'dev_local_time', 'movie epoch clock should be dev_local_time (ingested).');
        end

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

        function epoch_id = findEpoch(et, stem)
            epoch_id = '';
            for i=1:numel(et)
                ef = et(i).underlying_epochs.underlying;
                if ~isempty(strfind(strjoin(ef,' '), [stem '.tif']))
                    epoch_id = et(i).epoch_id;
                    return;
                end
            end
            error(['Could not find epoch for stem ' stem '.']);
        end

        function s = makeStack(Y,X,T,offset)
            s = zeros(Y,X,1,1,T,'uint16');
            for i=1:T
                s(:,:,1,1,i) = uint16( reshape(1:(Y*X), Y, X) + (i-1)*100 + offset );
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
            if isfolder(dirname)
                try, rmdir(dirname,'s'); catch, end
            end
        end

    end % methods (Static)

end % classdef
