classdef ingestedReadPastEpochEdges < ndi.unittest.session.buildSession
    % INGESTEDREADPASTEPOCHEDGES - the ingested mfdaq reader survives windows past epoch edges
    %
    %   The ingested reader addresses concrete _seg.nbf_N files. In NDI the
    %   first sample of an epoch is 1, so a request with s0 <= 0 must be
    %   clamped rather than passed through -- unclamped it computes
    %   SEG_start = 0 and asks the document for _seg.nbf_0, which no writer
    %   has ever produced (VH-Lab/NDI-matlab#993).
    %
    %   A local reader in the same shape (ndi.daq.reader.mfdaq.intan and
    %   friends) hands the value to an external file library and quietly
    %   gets back an empty or short slice, so pyraview's own excess-read
    %   never surfaced this over local files. These tests ingest the
    %   buildSession's example probe, then read through
    %   probe.readtimeseries -- pyraview's own call chain -- with the
    %   windows that used to fail.

    methods (Test)

        function testReadReachesBeforeEpochStart(testCase)
            % pyraview shape: probe.readtimeseries(epochid, t0 - 1, ...).
            % Before the fix this raises DID:SQLITEDB:open naming a
            % non-existent _seg.nbf_0.
            [probe, epoch] = setupIngestedProbeEpoch(testCase);

            t0_t1 = pickDevLocalT0T1(testCase, epoch);
            t0 = t0_t1(1);
            t1 = t0_t1(2);

            % Ask for one second before the epoch to one second in --
            % straddles the epoch's start the way pyraview's first chunk
            % does with a 1-second warm-up.
            [data, t] = probe.readtimeseries(epoch.epoch_id, t0 - 1, ...
                min(t0 + 1, t1));

            testCase.verifyNotEmpty(data, ...
                'A read that spans the epoch start should still return in-range samples.');
            testCase.verifyGreaterThanOrEqual(t(1), t0 - 10*eps(t0), ...
                'The first returned sample cannot precede the epoch''s t0.');
        end

        function testReadReachesAfterEpochEnd(testCase)
            % Symmetric case: a read that ends past t1 must not ask for a
            % _seg.nbf_<past-end>.
            [probe, epoch] = setupIngestedProbeEpoch(testCase);

            t0_t1 = pickDevLocalT0T1(testCase, epoch);
            t0 = t0_t1(1);
            t1 = t0_t1(2);

            [data, t] = probe.readtimeseries(epoch.epoch_id, ...
                max(t1 - 1, t0), t1 + 1);

            testCase.verifyNotEmpty(data, ...
                'A read that spans the epoch end should still return in-range samples.');
            testCase.verifyLessThanOrEqual(t(end), t1 + 10*eps(t1), ...
                'The last returned sample cannot exceed the epoch''s t1.');
        end

        function testReadEntirelyBeforeEpochReturnsEmpty(testCase)
            % A window that lies entirely before t0 has no samples to
            % return; the reader gives an empty result rather than
            % erroring.
            [probe, epoch] = setupIngestedProbeEpoch(testCase);

            t0_t1 = pickDevLocalT0T1(testCase, epoch);
            t0 = t0_t1(1);

            data = probe.readtimeseries(epoch.epoch_id, t0 - 2, t0 - 1);

            testCase.verifyEqual(size(data, 1), 0, ...
                'A fully pre-epoch window should return zero rows.');
        end

        function testReadInfBoundsStillReadWholeEpoch(testCase)
            % Regression guard: the pre-existing +/-Inf clamp survives the
            % new finite clamp block.
            [probe, epoch] = setupIngestedProbeEpoch(testCase);

            t0_t1 = pickDevLocalT0T1(testCase, epoch);
            t0 = t0_t1(1);
            t1 = t0_t1(2);

            [data, t] = probe.readtimeseries(epoch.epoch_id, -Inf, Inf);

            testCase.verifyNotEmpty(data, ...
                '[-Inf, Inf] must still read a whole epoch.');
            testCase.verifyGreaterThanOrEqual(t(1), t0 - 10*eps(t0));
            testCase.verifyLessThanOrEqual(t(end), t1 + 10*eps(t1));
        end

    end
end

function [probe, epoch] = setupIngestedProbeEpoch(testCase)
    % Ingest the buildSession's local session in place, then return a
    % probe whose epochs resolve through the ingested path.
    S = testCase.Session;
    [b, msg] = S.ingest();
    testCase.assertTrue(b, ['Ingestion failed: ' msg]);
    S.cache.clear();

    probes = S.getprobes('type', 'n-trode');
    testCase.assumeNotEmpty(probes, ...
        'buildSession must yield an n-trode probe.');
    probe = probes{1};

    et = probe.epochtable();
    testCase.assumeNotEmpty(et, 'Probe must have at least one epoch.');
    epoch = et(1);

    % Confirm the ingested path is actually what we exercise. Without
    % this guard, a future change that stops the daq system dispatching
    % to the ingested reader would silently move the tests to the local
    % reader (which has always clamped, see NDR-matlab's Intan reader)
    % and pass without covering the fix. Query the daq system's own
    % filenavigator, which is what the reader does on line 178 of
    % src/ndi/+ndi/+daq/+system/mfdaq.m -- getchanneldevinfo returns
    % devepoch as a cell of epoch IDs, not the epochfiles cell isingested
    % wants.
    dev = S.daqsystem_load('name', 'intan1');
    testCase.assertNotEmpty(dev, ...
        'buildSession must have added the "intan1" daq system.');
    if iscell(dev), dev = dev{1}; end
    epochfiles = getepochfiles(dev.filenavigator, epoch.epoch_id);
    testCase.assertTrue( ...
        ndi.file.navigator.isingested(epochfiles), ...
        'Test setup did not route the read through the ingested path.');
end

function t0_t1 = pickDevLocalT0T1(testCase, epoch_entry)
    % Choose the dev_local_time clock from the probe's epoch entry.
    for i = 1:numel(epoch_entry.epoch_clock)
        if strcmp(epoch_entry.epoch_clock{i}.type, 'dev_local_time')
            t0_t1 = epoch_entry.t0_t1{i};
            return;
        end
    end
    testCase.assumeFail('Epoch is missing a dev_local_time clock.');
end
