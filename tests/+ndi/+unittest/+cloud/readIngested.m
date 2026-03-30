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
        function downloadDataset(testCase)
            testCase.TargetDir = tempdir;

            % Remove any leftover dataset folder from a previous run
            datasetFolder = fullfile(testCase.TargetDir, testCase.CloudDatasetId);
            if isfolder(datasetFolder)
                rmdir(datasetFolder, 's');
            end

            testCase.addTeardown(@() testCase.cleanupTargetDir());

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
        function testBinaryFileDownload(testCase)
            % Diagnostic test: download a single binary file directly via
            % the cloud API and check if it is a valid gzip (tgz) file.

            % Find an ingested data document that has binary files
            q = ndi.query('', 'isa', 'daqreader_mfdaq_epochdata_ingested');
            docs = testCase.Session.database_search(q);
            testCase.fatalAssertNotEmpty(docs, 'No ingested data documents found.');

            % Find first doc that has a seg.nbf file with ndic:// location
            % (seg.nbf files are the actual compressed binary data segments,
            %  not the channel metadata text files)
            doc = [];
            fileUid = '';
            cloudDatasetId = '';
            fileName = '';
            for i = 1:numel(docs)
                if docs{i}.has_files()
                    fi = docs{i}.document_properties.files.file_info;
                    for j = 1:numel(fi)
                        loc = fi(j).locations(1).location;
                        if startsWith(loc, 'ndic://') && contains(fi(j).name, 'seg.nbf')
                            doc = docs{i};
                            fileName = fi(j).name;
                            parts = split(extractAfter(loc, 'ndic://'), '/');
                            cloudDatasetId = parts{1};
                            fileUid = parts{2};
                            break;
                        end
                    end
                    if ~isempty(doc); break; end
                end
            end
            testCase.fatalAssertNotEmpty(doc, 'No document with ndic:// seg.nbf file found.');
            fprintf('Selected file: %s\n', fileName);

            % Get download URL
            [success, answer] = ndi.cloud.api.files.getFileDetails(cloudDatasetId, fileUid);
            testCase.fatalAssertTrue(success, 'Failed to get file details from cloud.');
            fileUrl = answer.downloadUrl;

            % Print diagnostic info about the file location and URL
            fprintf('cloudDatasetId: %s\n', cloudDatasetId);
            fprintf('fileUid: %s\n', fileUid);
            fprintf('downloadUrl (first 200 chars): %.200s\n', fileUrl);
            fprintf('getFileDetails answer fields: %s\n', strjoin(fieldnames(answer), ', '));

            % Download with curl
            tname_curl = [tempname '_curl.nbf.tgz'];
            [curlStatus, ~] = system(sprintf('curl -s -L -o "%s" "%s"', tname_curl, fileUrl));
            fprintf('curl exit status: %d\n', curlStatus);

            fi_curl = dir(tname_curl);
            fid = fopen(tname_curl, 'rb');
            magic_curl = fread(fid, 4, 'uint8');
            fclose(fid);
            fprintf('curl file: %d bytes, magic: %s\n', fi_curl.bytes, sprintf('%02X ', magic_curl));
            [~, curl_filetype] = system(sprintf('file "%s"', tname_curl));
            fprintf('curl file type: %s\n', strtrim(curl_filetype));

            % Print first 500 chars of the file content if it's ASCII
            isGzip = numel(magic_curl) >= 2 && magic_curl(1) == 0x1F && magic_curl(2) == 0x8B;
            if ~isGzip
                content = fileread(tname_curl);
                fprintf('File content (first 500 chars):\n%.500s\n', content);
            end

            % Cleanup
            if isfile(tname_curl); delete(tname_curl); end

            testCase.verifyTrue(isGzip, ...
                sprintf('Downloaded file is not gzip. Magic: %s, Size: %d bytes', ...
                sprintf('%02X ', magic_curl), fi_curl.bytes));
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
