classdef TestPresentationEpochAnchors < matlab.unittest.TestCase
%TESTPRESENTATIONEPOCHANCHORS A stimulus presentation's manipulation is
%   anchored to the epoch entity of the epoch the presentation was in.
%
%   Decided by Jess Haley, 2026-10-27 [presentation anchored to its epoch]
%   (did-schema V_eta_go_forward_class_audit.md, option a, no new field).
%   ndi.migrate.internal.presentationEpochAnchors names each manipulation's
%   "during the session" anchor (minted by did2.convert.mintSessionDuring)
%   with the presentation's epoch; ndi.migrate.internal.epochAnchorFold
%   re-points it at the epoch entity. TestMigrateLocalEta
%   (testAPresentationManipulationIsAnchoredToItsEpoch) drives the whole
%   chain through ndi.migrate.local.

    methods (Test)
        function testOneAnchorPerManipulationWithAnEpoch(testCase)
            m = {manip('m1', 'ref1'), manip('m2', 'ref2')};
            info = [epochInfo('sess1', 't00001', 'dev_local_time'), ...
                    epochInfo('sess1', 't00002', 'utc')];
            [a, r] = ndi.migrate.internal.presentationEpochAnchors(m, info);
            testCase.verifyEqual(r.manipulations_inspected, 2);
            testCase.verifyEqual(r.anchors_handed_over, 2);
            testCase.verifyEqual({a.anchor_id}, {'ref1', 'ref2'});
            testCase.verifyEqual({a.epoch_string}, {'t00001', 't00002'});
            testCase.verifyEqual({a.epoch_clock}, {'dev_local_time', 'utc'});
            testCase.verifyEqual({a.session_id}, {'sess1', 'sess1'});
        end

        function testNoEpochStringAndNoReferenceAreCounted(testCase)
            m = {manip('m1', 'ref1'), manip('m2', ''), manip('m3', 'ref3')};
            info = [epochInfo('sess1', '', 'dev_local_time'), ...
                    epochInfo('sess1', 't00002', 'dev_local_time'), ...
                    epochInfo('sess1', 't00003', 'dev_local_time')];
            [a, r] = ndi.migrate.internal.presentationEpochAnchors(m, info);
            testCase.verifyEqual(r.manipulations_inspected, 3);
            testCase.verifyEqual(r.no_epoch_string, 1);
            testCase.verifyEqual(r.no_session_reference, 1);
            testCase.verifyEqual(r.anchors_handed_over, 1);
            testCase.verifyEqual(a(1).anchor_id, 'ref3');
            testCase.verifyEqual(r.manipulations_inspected, r.anchors_handed_over ...
                + r.no_epoch_string + r.no_session_reference);
        end

        function testNoManipulationsGivesAnEmptyAnchorList(testCase)
            [a, r] = ndi.migrate.internal.presentationEpochAnchors({}, ...
                struct('session_id', {}, 'epoch_string', {}, 'epoch_clock', {}));
            testCase.verifyEmpty(a);
            testCase.verifyEqual(r.manipulations_inspected, 0);
            testCase.verifyTrue(isfield(a, 'anchor_id'));
        end

        function testMismatchedInputsAreAnError(testCase)
            testCase.verifyError(@() ndi.migrate.internal.presentationEpochAnchors( ...
                {manip('m1', 'ref1')}, struct('session_id', {}, ...
                'epoch_string', {}, 'epoch_clock', {})), ...
                'NDI:migrate:presentationEpochAnchors:size');
        end

        function testTheFoldRepointsTheAnchorAtTheEpoch(testCase)
            % the session anchor mintSessionDuring gives a manipulation, handed
            % to epochAnchorFold with the epoch epochMint minted for the PAIR
            m = {manip('m1', 'ref1')};
            [a, ~] = ndi.migrate.internal.presentationEpochAnchors(m, ...
                epochInfo('sess1', 't00001', 'dev_local_time'));
            docs = {sessionReference('ref1', 'sess1', 'session_doc')};
            idx = struct('session_id', 'sess1', 'local_identifier', 't00001', ...
                'epoch_document_id', 'epoch_doc_A');
            [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx, a);
            testCase.verifyEqual(report.bath_anchors_seen, 1);
            testCase.verifyEqual(numel(plan), 1);
            b = plan(1).body;
            testCase.verifyEqual(b.base.id, 'ref1');
            testCase.verifyEqual(depValue(b, 'referent_id'), 'epoch_doc_A');
            ndi.unittest.migrate.verifyClock(testCase, b.relative_time_reference.value.clock, ...
                'dev_local_time');   % by node [clock terms get nodes]
        end

        function testAnEpochNotMintedLeavesTheAnchorOnItsSession(testCase)
            m = {manip('m1', 'ref1')};
            [a, ~] = ndi.migrate.internal.presentationEpochAnchors(m, ...
                epochInfo('sess1', 't00009', 'dev_local_time'));
            docs = {sessionReference('ref1', 'sess1', 'session_doc')};
            idx = struct('session_id', 'sess1', 'local_identifier', 't00001', ...
                'epoch_document_id', 'epoch_doc_A');
            [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx, a);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.refused_no_epoch_document, 1);
        end
    end
end

function m = manip(id, refId)
% a manipulation body after did2.convert.mintSessionDuring
m = struct();
m.document_class = struct('class_name', 'manipulation', 'class_version', '1.0.0', ...
    'schema_version', 'did_v2');
m.base = struct('id', id, 'creation_timestamp', '2024-01-01T00:00:00.000Z');
if isempty(refId)
    m.depends_on = struct('name', {'entity_id'}, 'value', {'subj1'});
else
    m.depends_on = struct('name', {'entity_id', 'time_reference_id'}, ...
        'value', {'subj1', refId});
end
end

function s = epochInfo(sessionId, epochString, clock)
s = struct('session_id', sessionId, 'epoch_string', epochString, ...
    'epoch_clock', clock);
end

function b = sessionReference(id, sessionId, sessionDocId)
% the relative_time_reference did2.convert.mintSessionDuring mints
b = struct();
b.document_class = struct('class_name', 'relative_time_reference', ...
    'class_version', '1.0.0', 'superclasses', struct('class_name', ...
    {'time_reference', 'base'}, 'class_version', '1.0.0'), ...
    'schema_version', 'did_v2');
b.depends_on = struct('name', {'referent_id', 'session_id'}, ...
    'value', {sessionDocId, sessionId});
b.base = struct('id', id, 'creation_timestamp', '2024-01-01T00:00:00.000Z');
b.relative_time_reference = struct('value', struct('relation', ...
    struct('node', 'time:intervalDuring', 'name', 'intervalDuring')));
end

function v = depValue(body, name)
v = '';
if ~isfield(body, 'depends_on') || ~isstruct(body.depends_on)
    return;
end
for k = 1:numel(body.depends_on)
    d = body.depends_on(k);
    if isfield(d, 'name') && strcmp(d.name, name)
        if isfield(d, 'value'); v = d.value; else; v = d.document_id; end
        return;
    end
end
end
