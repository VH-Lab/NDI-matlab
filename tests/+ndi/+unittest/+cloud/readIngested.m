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
            % Diagnostic test: download a single binary file and check it
            % is a valid gzip (tgz) file. This helps diagnose platform
            % differences in how websave handles binary content.

            % Find a document with ingested ephys data
            p_cf = testCase.Session.getprobes('name', 'carbonfiber', 'reference', 1);
            testCase.fatalAssertNumElements(p_cf, 1);

            e = p_cf{1}.epochsethandle();
            et = e.epochtable();
            epoch_doc = et(1).epoch_id;

            % Search for the daqreader ingested data document for this epoch
            q_epoch = ndi.query('', 'isa', 'daqreader_mfdaq_epochdata_ingested');
            docs = testCase.Session.database_search(q_epoch);
            testCase.fatalAssertNotEmpty(docs, 'No ingested data documents found.');

            % Use the first ingested data document
            d = docs{1};

            % Try to open and read the first binary file
            file_info = d.document_properties.document_class.files;
            testCase.fatalAssertNotEmpty(file_info, 'Document has no binary files.');

            fname = file_info(1).name;
            f = testCase.Session.database_openbinarydoc(d, fname);
            data = f.fread(Inf);
            testCase.Session.database_closebinarydoc(f);

            % Write to temp file and check
            tname = [tempname '.nbf.tgz'];
            fid = fopen(tname, 'wb', 'ieee-le');
            fwrite(fid, data, 'uint8');
            fclose(fid);

            % Diagnostic: check file size and magic bytes
            finfo = dir(tname);
            fprintf('Downloaded file: %s\n', tname);
            fprintf('File size: %d bytes\n', finfo.bytes);

            fid2 = fopen(tname, 'rb');
            magic = fread(fid2, 4, 'uint8');
            fclose(fid2);
            fprintf('First 4 bytes (hex): %s\n', sprintf('%02X ', magic));

            % gzip magic number is 1F 8B
            isGzip = numel(magic) >= 2 && magic(1) == 0x1F && magic(2) == 0x8B;
            fprintf('Is gzip: %d\n', isGzip);

            % Try system gunzip as diagnostic
            [status, result] = system(sprintf('file "%s"', tname));
            fprintf('file command output: %s\n', result);

            if ~isGzip
                % Try untar anyway to capture error
                try
                    untar(tname, tempdir);
                    fprintf('untar succeeded despite non-gzip magic bytes\n');
                catch ME
                    fprintf('untar failed: %s\n', ME.message);
                end
            end

            delete(tname);
            testCase.verifyTrue(isGzip, ...
                sprintf('Downloaded file is not a valid gzip file. Magic bytes: %s', ...
                sprintf('%02X ', magic)));
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
