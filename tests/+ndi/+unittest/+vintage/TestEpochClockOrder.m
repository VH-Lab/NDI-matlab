classdef TestEpochClockOrder < matlab.unittest.TestCase
%TESTEPOCHCLOCKORDER A migrated epoch's clocks are read in the order its recordings name them.
%
%   v1's epoch table lists an epoch's clocks in an order (Dab:
%   dev_local_time, then exp_global_time). DID-matlab's resolveEpochProbemap
%   writes one relative_time_reference per clock onto the epoch entity and
%   gives each recording observation their ids, as `time_reference_id`
%   edges, in that order. NDI rebuilds epoch_clock and t0_t1 from them
%   (private/archiveOf; ndi.vintage.ingestedArchives 'ClocksOnly').
%
%   The order must come from the recordings' edges, not from the order the
%   database holds the references in: that is the order they were written,
%   which followed the clock order only while their ids were random ids that
%   sort in the order they were made. With ids derived from their source
%   (DID-matlab #453) about half of Dab's epochs read their clocks swapped
%   (corpusObjectEquivalence, test-eta-migrate-dab.yml, run 43197684863).
%
%   THE FIXTURE is one v2 session written with ndi.setup.V2.createSession,
%   whose documents are written in the order given, so the database order
%   is chosen: two epochs, each with a dev_local_time and an
%   exp_global_time reference, a recording observation naming the
%   acquisition system and both references, and an archive series body.
%   Epoch A's recording names dev_local_time first and the database holds
%   exp_global_time first; epoch B's recording names exp_global_time first
%   and the database holds dev_local_time first. Both reads must follow the
%   recording.
%
%   Filtered (never passed) when did2.build, did2.convert or a v2 schema
%   with a term registry is missing.

    properties
        Dir
        Session
    end

    properties (Constant)
        ReaderId = 'reader_test'
        DevT = [0 79.951065917968748]
        ExpT = [738328.64514620253 738328.64607156208]
    end

    methods (TestClassSetup)
        function writeSession(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.relativeTimeReference')), ...
                'did2.build (DID-matlab V2) is not on the path');
            testCase.assumeTrue(~isempty(which('did2.convert.registeredTerm')), ...
                'did2.convert (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'term_registry_meta.json')), ...
                'DID_SCHEMA_PATH does not hold a v2 schema with a term registry');

            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
            sid = char(ndi.ido.unique_id());
            T = @(node) ndi.setup.V2.registeredTerm(node);
            S = {'SessionId', sid, 'Validate', false};
            P = ndi.unittest.vintage.TestEpochClockOrder;

            sys = did2.build.document('acquisition_system', struct('name', 'dab1'), ...
                'Edges', struct('reader_id', P.ReaderId, ...
                'epoch_file_pattern_id', 'pattern_test'), S{:});
            % the epoch entity as DID-matlab's epochMint writes it
            epochType = did2.convert.registeredTerm( ...
                did2.build.vocabulary('entity_type', 'epoch'), 'recording epoch');
            bytes = fullfile(testCase.Dir, 'segment.bin');
            fid = fopen(bytes, 'w');
            fwrite(fid, zeros(1, 8), 'double');
            fclose(fid);

            docs = {sys};
            % epoch A: the database holds exp_global_time first; the
            % recording names dev_local_time first
            [a, refsA] = P.epochDocs('epoch_a', epochType, sid, S);
            docs = [docs, {a, refsA.exp, refsA.dev}, ...
                P.recording(sys, {refsA.dev, refsA.exp}, bytes, T, S)];
            % epoch B: the database holds dev_local_time first; the
            % recording names exp_global_time first
            [b, refsB] = P.epochDocs('epoch_b', epochType, sid, S);
            docs = [docs, {b, refsB.dev, refsB.exp}, ...
                P.recording(sys, {refsB.exp, refsB.dev}, bytes, T, S)];

            sessionDir = fullfile(testCase.Dir, 'session');
            mkdir(sessionDir);
            testCase.Session = ndi.setup.V2.createSession(sessionDir, 'epoch clock order', ...
                'SessionId', sid, 'Documents', docs, 'Validate', false);
        end
    end

    methods (Test)
        function testOneEpochAtATimeFollowsTheRecording(testCase)
            P = ndi.unittest.vintage.TestEpochClockOrder;
            A = ndi.vintage.ingestedArchive(testCase.Session, P.ReaderId, 'epoch_a', ...
                'Channels', false);
            testCase.verifyEqual(A.epochclock, {'dev_local_time', 'exp_global_time'}, ...
                ['epoch_a: the clocks are not in the order its recording names them. ' ...
                A.clock_problem]);
            testCase.verifyEqual(A.t0_t1, {P.DevT, P.ExpT});
            B = ndi.vintage.ingestedArchive(testCase.Session, P.ReaderId, 'epoch_b', ...
                'Channels', false);
            testCase.verifyEqual(B.epochclock, {'exp_global_time', 'dev_local_time'}, ...
                ['epoch_b: the clocks are not in the order its recording names them. ' ...
                B.clock_problem]);
            testCase.verifyEqual(B.t0_t1, {P.ExpT, P.DevT});
        end

        function testClocksOnlyFollowsTheRecording(testCase)
            % the set-wise read the epoch table uses, without and then with
            % the derived index
            P = ndi.unittest.vintage.TestEpochClockOrder;
            for useIndex = [false true true]
                M = ndi.vintage.ingestedArchives(testCase.Session, P.ReaderId, ...
                    {'epoch_a', 'epoch_b'}, 'ClocksOnly', true, 'UseIndex', useIndex);
                what = sprintf(' (UseIndex %d)', useIndex);
                testCase.assertTrue(isKey(M, 'epoch_a') && isKey(M, 'epoch_b'), ...
                    ['ingestedArchives did not read both epochs' what]);
                A = M('epoch_a');
                testCase.verifyEqual(A.epochclock, {'dev_local_time', 'exp_global_time'}, ...
                    ['epoch_a' what]);
                testCase.verifyEqual(A.t0_t1, {P.DevT, P.ExpT}, ['epoch_a' what]);
                B = M('epoch_b');
                testCase.verifyEqual(B.epochclock, {'exp_global_time', 'dev_local_time'}, ...
                    ['epoch_b' what]);
                testCase.verifyEqual(B.t0_t1, {P.ExpT, P.DevT}, ['epoch_b' what]);
            end
        end
    end

    methods (Static, Access = private)
        function [epoch, refs] = epochDocs(localId, epochType, sid, S)
            % an epoch entity and its two clock references onto it
            P = ndi.unittest.vintage.TestEpochClockOrder;
            epoch = did2.build.document('entity', ...
                struct('type', epochType, 'local_identifier', localId), ...
                'SessionId', sid, 'Validate', false);
            refs.dev = did2.build.relativeTimeReference(epoch.base.id, ...
                'Clock', 'dev_local_time', 'Start', P.DevT(1), 'End', P.DevT(2), S{:});
            refs.exp = did2.build.relativeTimeReference(epoch.base.id, ...
                'Clock', 'exp_global_time', 'Start', P.ExpT(1), 'End', P.ExpT(2), S{:});
        end

        function docs = recording(sys, refs, bytes, T, S)
            % a recording observation timed by REFS, in that order, and the
            % archive series body it owns
            ids = cellfun(@(r) r.base.id, refs, 'UniformOutput', false);
            obs = did2.build.statement('observation', 'subject_test', T('PATO:0000008'), [], ...
                'DataBody', true, 'AcquisitionSystemId', sys.base.id, ...
                'TimeReferenceIds', ids, S{:}, 'ValueKind', 'velocity');
            body = did2.build.opaqueBody(obs.base.id, T('EDAM:format_2333'), ...
                'Fields', struct('filename', 'ai_group1_seg.nbf_#'), S{:});
            body = ndi.setup.V2.attachFile(body, 'body_data_0', bytes);
            docs = {obs, body};
        end
    end
end
