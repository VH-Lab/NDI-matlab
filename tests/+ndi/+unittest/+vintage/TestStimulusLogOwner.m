classdef TestStimulusLogOwner < matlab.unittest.TestCase
%TESTSTIMULUSLOGOWNER A stimulus system's events are read from their presentation as from the v1 archive.
%
%   Decided by Jess Haley, 2026-11-19 [stimulus log owned by its
%   presentation] (did-schema docs/plans/did_v2_standing_wiring_plan.md): an
%   epoch's stimulus-system archive files, the event file
%   `evmktx_group1_seg.nbf_1` and `channel_list.bin` (read by
%   ndi.setup.daq.reader.mfdaq.stimulus.vhlabvisspike2), become a data body
%   of that epoch's stimulus-presentation manipulation; where the epoch has
%   no presentation, an observation of the stimulus rig's device owns them.
%   The archive document then goes. NDI reads them first ("siblings first").
%
%   THE FIXTURE is one v2 session (ndi.setup.V2.createSession), two epochs
%   recorded by two systems: an Intan-like system (its own reader) with a
%   recording observation naming its clock reference, and the stimulus
%   system (reader vhlabvisspike2), whose clock reference for the same epoch
%   states another extent and is named by nothing, as DID-matlab writes it
%   when the log moves to a presentation.
%     epoch_s1   the log's two files are opaque bodies of a presentation
%                manipulation (no acquisition system named), their notes
%                opening with ndi.vintage.ingestedStimulusLogKey
%     epoch_s10  the log is owned by the fallback observation: it names the
%                stimulus system and its clock reference ([non-specimen
%                channel groups get their own owner])
%   The epoch ids are chosen so one is a prefix of the other.
%
%   WHAT "THE SAME EVENTS AS THE V1 ARCHIVE" MEANS HERE. With the v1
%   archive, ndi.daq.reader.mfdaq/readevents_epochsamples_ingested copies
%   the archive's attached `evmktx_group1_seg.nbf_1` out of the document
%   (ndi.database.fun.copydocfile2temp) and expands it with
%   ndi.compress.expand_eventmarktext, then keeps the events in [t0 t1]. So
%   the v1 read of an epoch is that expansion of the file the archive
%   attached; these tests compare the reader's v2 read with it, channel by
%   channel, and the channel list with the one NDI's writer wrote.
%
%   Filtered (never passed) when did2.build, did2.convert, a v2 schema with a
%   term registry, or NDI-compress is missing.

    properties
        Dir
        Session
        Files
        ReaderDoc
    end

    properties (Constant)
        IntanReaderId = 'reader_intan_test'
        StimT = [0 9.5]       % the stimulus system's extent of epoch_s1
        IntanT = [0 10.25]    % the Intan system's extent of the same epoch
        Types = {'event', 'marker'}
        Numbers = [1 2]
    end

    methods (TestClassSetup)
        function writeSession(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.relativeTimeReference')), ...
                'did2.build (DID-matlab V2) is not on the path');
            testCase.assumeTrue(~isempty(which('did2.convert.registeredTerm')), ...
                'did2.convert (DID-matlab V2) is not on the path');
            testCase.assumeFalse(isempty(which('ndi.compress.compress_eventmarktext')), ...
                'NDI-compress is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'term_registry_meta.json')), ...
                'DID_SCHEMA_PATH does not hold a v2 schema with a term registry');

            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
            P = ndi.unittest.vintage.TestStimulusLogOwner;
            % the stimulus reader: its id is the v1 daqreader document's
            testCase.ReaderDoc = ndi.document('daqreader');
            readerId = char(testCase.ReaderDoc.id());
            sid = char(ndi.ido.unique_id());
            T = @(node) ndi.setup.V2.registeredTerm(node);
            S = {'SessionId', sid, 'Validate', false};

            % the rig's device, as DID-matlab's migration mints it for a v1
            % daqsystem and NDI's v2 writers write it (did-schema
            % [device id required and named by the rig]: device_id required)
            stimSysId = char(ndi.ido.unique_id());
            stimRig = ndi.setup.V2.rigDevice('vhvis_spike2', stimSysId, sid);
            intanSysId = char(ndi.ido.unique_id());
            intanRig = ndi.setup.V2.rigDevice('vhintan', intanSysId, sid);
            stimSys = did2.build.document(ndi.vintage.acquisitionConfigurationClass(), struct('name', 'vhvis_spike2'), ...
                'Edges', struct('reader_id', readerId, 'epoch_file_pattern_id', 'pattern_stim', ...
                'device_id', stimRig{1}.base.id), 'Id', stimSysId, S{:});
            intanSys = did2.build.document(ndi.vintage.acquisitionConfigurationClass(), struct('name', 'vhintan'), ...
                'Edges', struct('reader_id', P.IntanReaderId, ...
                'epoch_file_pattern_id', 'pattern_intan', 'device_id', intanRig{1}.base.id), ...
                'Id', intanSysId, S{:});
            epochType = did2.convert.registeredTerm( ...
                did2.build.vocabulary('entity_type', 'epoch'), 'recording epoch');

            % the files NDI's ingest writes for a stimulus epoch
            testCase.Files = struct();
            [testCase.Files.ev1, testCase.Files.cl] = P.writeLog(testCase.Dir, 's1', 0);
            [testCase.Files.ev10, ~] = P.writeLog(testCase.Dir, 's10', 100);
            bytes = fullfile(testCase.Dir, 'segment.bin');
            fid = fopen(bytes, 'w');
            fwrite(fid, zeros(1, 8), 'double');
            fclose(fid);

            docs = {stimSys, intanSys, stimRig{1}, intanRig{1}};
            for e = {'epoch_s1', 'epoch_s10'}
                lid = e{1};
                epoch = did2.build.document('entity', ...
                    struct('type', epochType, 'local_identifier', lid), S{:});
                during = did2.build.relativeTimeReference(epoch.base.id, ...
                    'Relation', 'intervalDuring', S{:});
                stimClock = did2.build.relativeTimeReference(epoch.base.id, ...
                    'Clock', 'dev_local_time', 'Start', P.StimT(1), 'End', P.StimT(2), S{:});
                intanClock = did2.build.relativeTimeReference(epoch.base.id, ...
                    'Clock', 'dev_local_time', 'Start', P.IntanT(1), 'End', P.IntanT(2), S{:});
                % the Intan system's recording, naming its own clock
                rec = did2.build.statement('observation', 'subject_test', T('PATO:0000008'), [], ...
                    'DataBody', true, 'AcquisitionSystemId', intanSys.base.id, ...
                    'TimeReferenceIds', {during.base.id, intanClock.base.id}, S{:}, ...
                    'ValueKind', 'velocity');
                ai = did2.build.opaqueBody(rec.base.id, T('EDAM:format_2333'), ...
                    'Fields', struct('filename', 'ai_group1_seg.nbf_#'), S{:});
                ai = ndi.setup.V2.attachFile(ai, 'body_data_0', bytes);
                % intanClock is written first, so a read that took the first
                % reference onto the epoch would take the Intan extent
                docs = [docs, {epoch, during, intanClock, stimClock, rec, ai}]; %#ok<AGROW>
                if strcmp(lid, 'epoch_s1')
                    % the presentation: a manipulation timed onto the epoch,
                    % naming no acquisition system
                    owner = did2.build.statement('manipulation', 'subject_test', ...
                        T('PATO:0000008'), [], 'DataBody', true, ...
                        'TimeReferenceIds', {during.base.id}, S{:}, 'ValueKind', 'velocity');
                    ev = testCase.Files.ev1;
                else
                    % the fallback observation of the rig's device
                    owner = did2.build.statement('observation', 'device_test', ...
                        T('PATO:0000008'), [], 'DataBody', true, ...
                        'AcquisitionSystemId', stimSys.base.id, 'InstrumentId', stimSys.base.id, ...
                        'TimeReferenceIds', {during.base.id, stimClock.base.id}, S{:}, ...
                        'ValueKind', 'velocity');
                    ev = testCase.Files.ev10;
                end
                docs = [docs, {owner, ...
                    P.logBody(owner, lid, readerId, 'evmktx_group1_seg.nbf_#', ev, T, S), ...
                    P.logBody(owner, lid, readerId, 'channel_list.bin', testCase.Files.cl, T, S)}]; %#ok<AGROW>
            end
            sessionDir = fullfile(testCase.Dir, 'session');
            mkdir(sessionDir);
            testCase.Session = ndi.setup.V2.createSession(sessionDir, 'stimulus log owner', ...
                'SessionId', sid, 'Documents', docs, 'Validate', false);
        end
    end

    methods (Test)
        function testTheLogIsFoundOnItsPresentation(testCase)
            A = ndi.vintage.ingestedArchive(testCase.Session, testCase.readerId(), 'epoch_s1');
            testCase.verifyEqual(sort(A.bodies.keys), ...
                sort({'channel_list.bin', 'evmktx_group1_seg.nbf_#'}), ...
                'the presentation''s log bodies are not the archive''s series');
            want = ndi.file.type.mfdaq_epoch_channel(testCase.Files.cl).channel_information;
            testCase.verifyTrue(isequaln(A.channels, want), ...
                'the channel list read from the presentation is not the one the ingest wrote');
        end

        function testTheEventsAreTheV1Archives(testCase)
            % ndi.daq.reader.mfdaq/readevents_epochsamples_ingested, as the
            % stimulus system reads its events, against the v1 read: the
            % archive's attached event file, expanded
            P = ndi.unittest.vintage.TestStimulusLogOwner;
            reader = ndi.setup.daq.reader.mfdaq.stimulus.vhlabvisspike2(testCase.Session, ...
                testCase.ReaderDoc);
            testCase.assertEqual(char(reader.id()), testCase.readerId());
            for e = {{'epoch_s1', testCase.Files.ev1}, {'epoch_s10', testCase.Files.ev10}}
                lid = e{1}{1};
                [ct, cn, Tv1, Dv1] = P.expandFile(e{1}{2});
                for k = 1:numel(P.Types)
                    i = find(strcmp(ct, P.Types{k}) & cn == P.Numbers(k));
                    testCase.assertNumElements(i, 1, 'the v1 file does not hold the channel');
                    [t, d] = reader.readevents_epochsamples_ingested(P.Types(k), P.Numbers(k), ...
                        {['epochid://' lid]}, -Inf, Inf, testCase.Session);
                    testCase.verifyEqual(t, Tv1{i}, sprintf('%s %s %d: the times differ', ...
                        lid, P.Types{k}, P.Numbers(k)));
                    testCase.verifyEqual(d(:), Dv1{i}(:), sprintf('%s %s %d: the data differ', ...
                        lid, P.Types{k}, P.Numbers(k)));
                end
            end
        end

        function testTheClockIsTheStimulusSystems(testCase)
            % no recording names the stimulus system's clock on epoch_s1; the
            % Intan system's reference, written first, is not read
            P = ndi.unittest.vintage.TestStimulusLogOwner;
            for lid = {'epoch_s1', 'epoch_s10'}
                A = ndi.vintage.ingestedArchive(testCase.Session, testCase.readerId(), lid{1}, ...
                    'Channels', false);
                testCase.verifyEqual(A.epochclock, {'dev_local_time'}, [lid{1} ': ' A.clock_problem]);
                testCase.verifyEqual(A.t0_t1, {P.StimT}, [lid{1} ': the extent is not the stimulus system''s']);
            end
            % and the Intan system still reads its own
            A = ndi.vintage.ingestedArchive(testCase.Session, P.IntanReaderId, 'epoch_s1', ...
                'Channels', false);
            testCase.verifyEqual(A.t0_t1, {P.IntanT});
            testCase.verifyFalse(isKey(A.bodies, 'evmktx_group1_seg.nbf_#'), ...
                'the Intan reader read the stimulus system''s log');
        end

        function testTheEpochsAreNotConfused(testCase)
            % epoch_s1 is a prefix of epoch_s10: each reads its own event file
            A = ndi.vintage.ingestedArchive(testCase.Session, testCase.readerId(), 'epoch_s1');
            got = testCase.bytesOf(A, 'evmktx_group1_seg.nbf_1');
            testCase.verifyEqual(got, testCase.bytesOfFile(testCase.Files.ev1));
            B = ndi.vintage.ingestedArchive(testCase.Session, testCase.readerId(), 'epoch_s10');
            got = testCase.bytesOf(B, 'evmktx_group1_seg.nbf_1');
            testCase.verifyEqual(got, testCase.bytesOfFile(testCase.Files.ev10));
        end

        function testAnotherReaderReadsNoLog(testCase)
            testCase.verifyError(@() ndi.vintage.ingestedArchive(testCase.Session, ...
                'reader_nobody', 'epoch_s1'), 'NDI:daq:reader:ingestedNoRecording');
        end

        function testBatchedReadsTheSame(testCase)
            % ndi.vintage.ingestedArchives, as the epoch table reads it:
            % documents, then clocks only without and with the derived index
            ids = {'epoch_s1', 'epoch_s10'};
            for mode = {{false, false}, {true, false}, {true, true}, {true, true}}
                clocksOnly = mode{1}{1};
                useIndex = mode{1}{2};
                M = ndi.vintage.ingestedArchives(testCase.Session, testCase.readerId(), ids, ...
                    'ClocksOnly', clocksOnly, 'UseIndex', useIndex);
                what = sprintf(' (ClocksOnly %d, UseIndex %d)', clocksOnly, useIndex);
                for k = 1:numel(ids)
                    testCase.assertTrue(isKey(M, ids{k}), ['not read at once: ' ids{k} what]);
                    A = ndi.vintage.ingestedArchive(testCase.Session, testCase.readerId(), ids{k}, ...
                        'Channels', false);
                    B = M(ids{k});
                    testCase.verifyEqual(B.epochclock, A.epochclock, [ids{k} what]);
                    testCase.verifyEqual(B.t0_t1, A.t0_t1, [ids{k} what]);
                    if ~clocksOnly
                        testCase.verifyEqual(sort(B.bodies.keys), sort(A.bodies.keys), [ids{k} what]);
                    end
                end
            end
        end
    end

    methods (Access = private)
        function id = readerId(testCase)
            id = char(testCase.ReaderDoc.id());
        end

        function b = bytesOf(testCase, A, filename)
            [tname, ~] = ndi.vintage.ingestedArchiveFile(testCase.Session, A, filename, '.nbf.tgz');
            b = testCase.bytesOfFile(tname);
            delete(tname);
        end
    end

    methods (Static, Access = private)
        function b = bytesOfFile(f)
            fid = fopen(f, 'r');
            b = fread(fid, Inf, 'uint8=>uint8');
            fclose(fid);
        end

        function [evFile, clFile] = writeLog(dir, tag, shift)
            % the event file and channel list NDI's mfdaq ingest writes
            % (ndi.daq.reader.mfdaq/ingest_epochfiles) for an event and a
            % marker channel; SHIFT makes each epoch's events its own
            P = ndi.unittest.vintage.TestStimulusLogOwner;
            T = {shift + [0.5; 1.25; 3.0], shift + [0.75; 2.5]};
            D = {ones(3, 1), [7; 2]};
            stem = fullfile(dir, ['ev_' tag]);
            ndi.compress.compress_eventmarktext(P.Types, P.Numbers, T, D, stem);
            evFile = [stem '.nbf.tgz'];
            ch = struct('name', {'e1', 'mk2'}, 'type', P.Types, 'time_channel', {NaN, NaN}, ...
                'sample_rate', {NaN, NaN}, 'offset', {0, 0}, 'scale', {1, 1});
            clFile = fullfile(dir, ['cl_' tag '.bin']);
            [ok, msg] = ndi.file.type.mfdaq_epoch_channel(ch).writeToFile(clFile);
            assert(logical(ok), msg);
        end

        function body = logBody(owner, lid, readerId, series, file, T, S)
            % one of the log's files as DID-matlab's resolveEpochProbemap
            % writes it when the log moves: an opaque_body of its owner,
            % its notes opening with the key
            notes = [ndi.vintage.ingestedStimulusLogKey(lid, readerId) ...
                ' The ingested recording of epoch ' lid ': v1 attached file series ' ...
                series ', carried as attached (1 member(s)).'];
            body = did2.build.opaqueBody(owner.base.id, T('EDAM:format_2333'), ...
                'Fields', struct('filename', series), 'Notes', notes, S{:});
            body = ndi.setup.V2.attachFile(body, 'body_data_0', file);
        end

        function [ct, cn, Tv, Dv] = expandFile(file)
            % the v1 read: the attached file, expanded as
            % readevents_epochsamples_ingested expands it
            stem = tempname();
            copyfile(file, [stem '.nbf.tgz']);
            c = onCleanup(@() delete([stem '.nbf.tgz']));
            [ct, cn, Tv, Dv] = ndi.compress.expand_eventmarktext(stem);
        end
    end
end
