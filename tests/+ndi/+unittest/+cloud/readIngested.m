classdef readIngested < matlab.unittest.TestCase
% readIngested - Test reading an ingested dataset from the cloud
%
%   This test downloads a known dataset from the cloud, opens a session,
%   and verifies that probes can be read with expected values.
%

    properties
        TargetDir
        Dataset
        Session
    end

    properties (Constant)
        CloudDatasetId = '668b0539f13096e04f1feccd';
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            diagMsg = 'Missing NDI Cloud credentials. Skipping cloud-dependent tests.';
            testCase.assumeNotEmpty(username, diagMsg);
            testCase.assumeNotEmpty(password, diagMsg);
        end

        function downloadDataset(testCase)
            testCase.TargetDir = tempdir;

            % Remove any leftover dataset folder from a previous run
            datasetFolder = fullfile(testCase.TargetDir, testCase.CloudDatasetId);
            if isfolder(datasetFolder)
                rmdir(datasetFolder, 's');
            end

            testCase.addTeardown(@() testCase.cleanupTargetDir());

            % Re-authenticate in case token expired during a long test suite
            ndi.cloud.authenticate('InteractionEnabled', 'off');

            testCase.Dataset = ndi.cloud.downloadDataset(testCase.CloudDatasetId, testCase.TargetDir);

            [~, sess_ids] = testCase.Dataset.session_list();
            testCase.fatalAssertNumElements(sess_ids, 1, ...
                'Expected exactly one session in the dataset.');

            testCase.Session = testCase.Dataset.open_session(sess_ids{1});
        end
    end

    methods (Access = private)
        function cleanupTargetDir(testCase)
            if ~isempty(testCase.TargetDir) && isfolder(testCase.TargetDir)
                % TargetDir is tempdir, so do not delete it entirely;
                % the downloaded dataset folder will be cleaned up by the OS.
            end
        end
    end

    methods (Test)
        function testBinarySegmentFile(testCase)
            % Diagnostic: use copydocfile2temp on a seg.nbf file and
            % inspect the result to understand why untar fails on Linux.

            q = ndi.query('', 'isa', 'daqreader_mfdaq_epochdata_ingested');
            docs = testCase.Session.database_search(q);
            testCase.fatalAssertNotEmpty(docs, 'No ingested data documents found.');

            % Find a document with seg.nbf files
            doc = [];
            segFileName = '';
            for i = 1:numel(docs)
                if docs{i}.has_files()
                    fi = docs{i}.document_properties.files.file_info;
                    for j = 1:numel(fi)
                        if contains(fi(j).name, 'seg.nbf')
                            doc = docs{i};
                            segFileName = fi(j).name;
                            % Print all location info for this file
                            for k = 1:numel(fi(j).locations)
                                fprintf('File "%s" location %d: type=%s, loc=%s\n', ...
                                    fi(j).name, k, ...
                                    fi(j).locations(k).location_type, ...
                                    fi(j).locations(k).location);
                            end
                            break;
                        end
                    end
                    if ~isempty(doc); break; end
                end
            end
            testCase.fatalAssertNotEmpty(doc, 'No document with seg.nbf files found.');

            % Check DID cache
            try
                cachePath = did.common.PathConstants.filecachepath;
                fprintf('DID cache path: %s\n', cachePath);
                if isfolder(cachePath)
                    d = dir(cachePath);
                    fprintf('Cache has %d entries\n', numel(d)-2);
                end
            catch
                fprintf('Could not check DID cache path\n');
            end

            % Call copydocfile2temp exactly like the mfdaq reader does
            fprintf('Calling copydocfile2temp for "%s"...\n', segFileName);
            [tname, ~] = ndi.database.fun.copydocfile2temp(doc, testCase.Session, segFileName, '.nbf.tgz');

            % Inspect the result
            finfo = dir(tname);
            fprintf('Result file: %s\n', tname);
            fprintf('File size: %d bytes\n', finfo.bytes);

            fid = fopen(tname, 'rb');
            magic = fread(fid, 4, 'uint8');
            allBytes = finfo.bytes;
            fclose(fid);
            fprintf('Magic bytes: %s\n', sprintf('%02X ', magic));

            [~, filetype] = system(sprintf('file "%s"', tname));
            fprintf('file type: %s\n', strtrim(filetype));

            % Print checksum so we can compare with Mac
            [~, md5out] = system(sprintf('md5sum "%s"', tname));
            fprintf('MD5: %s\n', strtrim(md5out));

            isGzip = numel(magic) >= 2 && magic(1) == 0x1F && magic(2) == 0x8B;
            if ~isGzip && allBytes < 5000
                content = fileread(tname);
                fprintf('Content (first 300 chars):\n%.300s\n', content);
            end

            delete(tname);
            testCase.verifyTrue(isGzip, ...
                sprintf('seg.nbf file is not gzip. Size: %d, Magic: %s', ...
                allBytes, sprintf('%02X ', magic)));
        end

        function testReadCarbonFiberProbe(testCase)
            p_cf = testCase.Session.getprobes('name', 'carbonfiber', 'reference', 1);
            testCase.fatalAssertNumElements(p_cf, 1, ...
                'Expected exactly one carbonfiber probe with reference 1.');

            [d1, t1] = p_cf{1}.readtimeseries(1, 10, 20);

            expected_d1 = [ ...
                55.7700; 253.3050; -43.2900; -9.5550; 30.6150; ...
                23.4000; 16.1850; -51.6750; -1.7550; -14.6250; ...
                -32.7600; 45.6300; -7.2150; 0.9750; -1.7550; 45.0450];

            testCase.verifyEqual(d1(1,:)', expected_d1, 'AbsTol', 0.001, ...
                'First row of carbonfiber timeseries data does not match expected values.');

            testCase.verifyEqual(t1(1), 10.0000, 'AbsTol', 0.001, ...
                'First time value should be 10.');
        end

        function testReadStimulatorProbe(testCase)
            p_st = testCase.Session.getprobes('type', 'stimulator');
            testCase.fatalAssertNotEmpty(p_st, ...
                'Expected at least one stimulator probe.');

            [ds, ts, ~] = p_st{1}.readtimeseries(1, 10, 20);

            testCase.verifyEqual(ds.stimid, 31, ...
                'Stimulus ID should be 31.');

            testCase.verifyEqual(ts.stimon, 15.2590, 'AbsTol', 0.001, ...
                'Stimulus onset time should be 15.2590.');
        end
    end
end
