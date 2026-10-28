classdef TestExpectedEpochPairs < matlab.unittest.TestCase
%TESTEXPECTEDEPOCHPAIRS The (session, epoch string) pairs epochMint will mint,
%   predicted before it runs.
%
%   Decided by Jess Haley, 2026-10-27 [epoch-less presentations carry]
%   (did-schema V_eta_go_forward_class_audit.md): NDI's stimulus pass carries
%   a presentation as v1 when no epoch will be minted for its pair. The rules
%   are did2.convert.epochMint's find-or-create loop; TestMigrateLocalEta
%   (testAPresentationWhoseEpochIsNotMintedIsCarriedAsV1 and
%   testAPresentationManipulationIsAnchoredToItsEpoch) drives both outcomes
%   through ndi.migrate.local.

    methods (TestClassSetup)
        function needsDid(testCase)
            testCase.assumeTrue(~isempty(which('did2.validate.epochStrings')), ...
                'needs DID-matlab did2.validate.epochStrings');
        end
    end

    methods (Test)
        function testAPairWithOneSessionDocumentIsExpected(testCase)
            s = {sessionDoc('sessdoc', 'S1'), carrier('c1', 'S1', 't00001')};
            [p, r] = ndi.migrate.internal.expectedEpochPairs(s);
            testCase.verifyEqual(r.documents_inspected, 2);
            testCase.verifyEqual(r.session_documents, 1);
            testCase.verifyEqual(r.pairs_expected, 1);
            testCase.verifyTrue(isKey(p, did2.convert.epochIndex.pairKey('S1', 't00001')));
        end

        function testAMigratedSessionEntityIsASessionDocument(testCase)
            % on did-schema #88 pass 1 turns the v1 `session` into an `entity`
            % of type session; epochMint counts it, so the prediction must too
            v1 = struct();
            v1.document_class = struct('class_name', 'session', 'class_version', '1.0.0', ...
                'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
            v1.depends_on = struct('name', {}, 'value', {});
            v1.base = struct('id', 'aabb1122ccdd3344_77000000000000aa', ...
                'session_id', 'aabb1122ccdd3344_77000000000000bb', ...
                'name', 'session', 'datestamp', '2024-06-01T12:00:00.000Z');
            v1.session = struct('reference', 'exp_1');
            r1 = did2.convert.v1_to_v2({v1}, 'Validate', false);
            testCase.assumeNotEmpty(r1.migrated, 'pass 1 did not migrate the session');
            sess = r1.migrated{1}.toStruct();
            [p, r] = ndi.migrate.internal.expectedEpochPairs({sess, ...
                carrier('c1', 'aabb1122ccdd3344_77000000000000bb', 't00001')});
            testCase.verifyEqual(r.session_documents, 1, ...
                sprintf('the migrated session (class %s) was not counted', ...
                sess.document_class.class_name));
            testCase.verifyTrue(isKey(p, did2.convert.epochIndex.pairKey( ...
                'aabb1122ccdd3344_77000000000000bb', 't00001')));
        end

        function testTheKeyIsThePairNotTheString(testCase)
            s = {sessionDoc('sessdoc', 'S1'), carrier('c1', 'S1', 't00001')};
            p = ndi.migrate.internal.expectedEpochPairs(s);
            testCase.verifyFalse(isKey(p, did2.convert.epochIndex.pairKey('S2', 't00001')));
        end

        function testNoSessionDocumentMintsNothing(testCase)
            [p, r] = ndi.migrate.internal.expectedEpochPairs({carrier('c1', 'S1', 't00001')});
            testCase.verifyEqual(double(p.Count), 0);
            testCase.verifyEqual(r.refused_no_session_document, 1);
        end

        function testTwoSessionDocumentsMintNothing(testCase)
            s = {sessionDoc('a', 'S1'), sessionDoc('b', 'S1'), carrier('c1', 'S1', 't00001')};
            [p, r] = ndi.migrate.internal.expectedEpochPairs(s);
            testCase.verifyEqual(double(p.Count), 0);
            testCase.verifyEqual(r.refused_ambiguous_session, 1);
        end

        function testASyntheticStringMintsNothing(testCase)
            s = {sessionDoc('sessdoc', 'S1'), carrier('c1', 'S1', 'whole_session_x')};
            [p, r] = ndi.migrate.internal.expectedEpochPairs(s);
            testCase.verifyEqual(double(p.Count), 0);
            testCase.verifyEqual(r.refused_synthetic, 1);
        end

        function testUnreadableEntriesAreCounted(testCase)
            [~, r] = ndi.migrate.internal.expectedEpochPairs({42, []});
            testCase.verifyEqual(r.documents_inspected, 2);
            testCase.verifyEqual(r.documents_unreadable, 2);
        end
    end
end

function b = sessionDoc(id, sid)
b = struct();
b.document_class = struct('class_name', 'session', 'class_version', '1.0.0');
b.base = struct('id', id, 'session_id', sid);
end

function b = carrier(id, sid, epochString)
% a v1 element_epoch: its `epochid` block is an epoch string epochMint reads
b = struct();
b.document_class = struct('class_name', 'element_epoch', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'epochid'}, 'class_version', '1.0.0'));
b.base = struct('id', id, 'session_id', sid);
b.epochid = struct('epochid', epochString);
b.element_epoch = struct('epoch_clock', 'dev_local_time', 't0_t1', [0 1]);
end
