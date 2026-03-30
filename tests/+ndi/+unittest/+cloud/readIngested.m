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

    methods (TestClassSetup)
        function downloadDataset(testCase)
            testCase.TargetDir = tempdir;
            testCase.addTeardown(@() testCase.cleanupTargetDir());

            testCase.Dataset = ndi.cloud.downloadDataset('668b0539f13096e04f1feccd', testCase.TargetDir);

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

            % Find first doc that has files with ndic:// locations
            doc = [];
            fileUid = '';
            cloudDatasetId = '';
            for i = 1:numel(docs)
                if docs{i}.has_files()
                    fi = docs{i}.document_properties.files.file_info;
                    for j = 1:numel(fi)
                        loc = fi(j).locations(1).location;
                        if startsWith(loc, 'ndic://')
                            doc = docs{i};
                            parts = split(extractAfter(loc, 'ndic://'), '/');
                            cloudDatasetId = parts{1};
                            fileUid = parts{2};
                            break;
                        end
                    end
                    if ~isempty(doc); break; end
                end
            end
            testCase.fatalAssertNotEmpty(doc, 'No document with ndic:// file locations found.');

            % Get download URL
            [success, answer] = ndi.cloud.api.files.getFileDetails(cloudDatasetId, fileUid);
            testCase.fatalAssertTrue(success, 'Failed to get file details from cloud.');
            fileUrl = answer.downloadUrl;

            % Download with websave (default method)
            tname_websave = [tempname '_websave.nbf.tgz'];
            opts = weboptions('ContentType', 'binary', 'Timeout', 60);
            websave(tname_websave, fileUrl, opts);

            % Download with curl
            tname_curl = [tempname '_curl.nbf.tgz'];
            [curlStatus, curlResult] = system(sprintf('curl -s -L -o "%s" "%s"', tname_curl, fileUrl));
            fprintf('curl exit status: %d\n', curlStatus);

            % Check websave file
            fi_ws = dir(tname_websave);
            fid = fopen(tname_websave, 'rb');
            magic_ws = fread(fid, 4, 'uint8');
            fclose(fid);
            fprintf('websave file: %d bytes, magic: %s\n', fi_ws.bytes, sprintf('%02X ', magic_ws));
            [~, ws_filetype] = system(sprintf('file "%s"', tname_websave));
            fprintf('websave file type: %s\n', strtrim(ws_filetype));

            % Check curl file
            fi_curl = dir(tname_curl);
            fid = fopen(tname_curl, 'rb');
            magic_curl = fread(fid, 4, 'uint8');
            fclose(fid);
            fprintf('curl file: %d bytes, magic: %s\n', fi_curl.bytes, sprintf('%02X ', magic_curl));
            [~, curl_filetype] = system(sprintf('file "%s"', tname_curl));
            fprintf('curl file type: %s\n', strtrim(curl_filetype));

            % Try untar on both
            for method = {"websave", "curl"}
                if strcmp(method{1}, 'websave')
                    tf = tname_websave;
                else
                    tf = tname_curl;
                end
                try
                    untar(tf, tempdir);
                    fprintf('%s: untar succeeded\n', method{1});
                catch ME
                    fprintf('%s: untar failed: %s\n', method{1}, ME.message);
                end
            end

            % Cleanup
            if isfile(tname_websave); delete(tname_websave); end
            if isfile(tname_curl); delete(tname_curl); end

            isGzip_ws = numel(magic_ws) >= 2 && magic_ws(1) == 0x1F && magic_ws(2) == 0x8B;
            isGzip_curl = numel(magic_curl) >= 2 && magic_curl(1) == 0x1F && magic_curl(2) == 0x8B;
            testCase.verifyTrue(isGzip_ws || isGzip_curl, ...
                sprintf('Neither websave nor curl produced a valid gzip. websave magic: %s, curl magic: %s', ...
                sprintf('%02X ', magic_ws), sprintf('%02X ', magic_curl)));
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
