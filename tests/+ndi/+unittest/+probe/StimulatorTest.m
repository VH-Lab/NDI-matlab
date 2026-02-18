classdef StimulatorTest < matlab.unittest.TestCase
    properties
        Session
        TempDir
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.Session = ndi.session.dir('test_session', testCase.TempDir);

            % Create a mock DAQ system
            % Need a file navigator.
            % Create a dummy file in temp dir so file navigator works.
            touch(fullfile(testCase.TempDir, 'test.bin'));

            % We need an epochprobemap file or object.
            % Create an epochprobemap.ndi file
            fid = fopen(fullfile(testCase.TempDir, 'test.epochprobemap.ndi'), 'wt');
            fprintf(fid, 'name\treference\ttype\tdevicestring\tsubjectstring\n');
            % Create a probe named 'stim' type 'event' mapped to 'mockdev:dep1'
            fprintf(fid, 'stim\t1\tevent\tmockdev:dep1\tsubject1\n');
            fclose(fid);

            % Setup file navigator
            fn = ndi.file.navigator(testCase.Session, {'test.bin', 'test.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'test.epochprobemap.ndi'});

            % Setup Mock Reader
            reader = ndi.unittest.probe.MockDAQReader();

            % Setup DAQ System
            dev = ndi.daq.system.mfdaq('mockdev', fn, reader);
            testCase.Session.daqsystem_add(dev);
        end
    end

    methods (TestMethodTeardown)
        function teardownSession(testCase)
            % Cleanup
            if exist(testCase.TempDir, 'dir')
                rmdir(testCase.TempDir, 's');
            end
        end
    end

    methods (Test)
        function testReadTimeSeries(testCase)
            % Get the probe
            p = testCase.Session.getprobes();
            testCase.verifyNotEmpty(p, 'Probe should be found');
            probe = p{1};

            testCase.verifyEqual(probe.name, 'stim');
            testCase.verifyEqual(probe.type, 'event');

            % Verify we have epochs
            et = probe.epochtable();
            testCase.verifyNotEmpty(et, 'Epoch table should not be empty');

            % Read timeseries
            % epoch 1
            [d, t] = probe.readtimeseries(1, -inf, inf);

            % Check if we got events
            % We expect rising edges at t=1.0 and t=3.0

            % The current implementation of stimulator should fail (return empty)
            % because 'dep' is not handled in markermode/dimmode logic unless we fix it.

            % If it fails:
            % t.stimevents will be missing or empty?
            % If markermode/dimmode fails, t is empty struct or just []?
            % In stimulator.m: t = struct; ... if no mode matches, returns t=struct (empty fields).
            % But readtimeseries wrapper might convert it.

            if isstruct(t)
                 if isfield(t, 'stimevents')
                     testCase.verifyNotEmpty(t.stimevents, 'stimevents should not be empty');
                     % Check values
                     events = t.stimevents{1};
                     testCase.verifyEqual(events(1), 1.0, 'First event at 1.0s');
                     testCase.verifyEqual(events(2), 3.0, 'Second event at 3.0s');
                 else
                     % This is expected failure condition
                     testCase.verifyFail('stimevents field missing in t');
                 end
            else
                 testCase.verifyFail('t is not a struct');
            end
        end
    end
end

function touch(filename)
    fclose(fopen(filename, 'w'));
end
