classdef TestControlRecordsFromV1 < matlab.unittest.TestCase
%TESTCONTROLRECORDSFROMV1 NDI's second pass reads a v1 control_stimulus_ids
%   from the ORIGINAL v1 document, not from pass 1's output.
%
%   Decided by Jess Haley, 2026-10-27 [second pass reads control stimuli from
%   v1] (did-schema V_eta_go_forward_class_audit.md): so DID-matlab can move
%   the class to its raw-v1 path. ndi.migrate.internal.controlRecordsByPresentation
%   is what ndi.migrate.local's stimulus pass now calls on the v1 bodies; the
%   fold itself (stimulusPresentationToItem) is TestControlCovariate's.
%
%   The fixtures are shaped as NDI's writer writes the record
%   (+app/+stimulus/tuning_response.m): `depends_on` entry
%   `stimulus_presentation_id` keyed `value`, the `control_stimulus_ids`
%   block, an `app` block.

    methods (Test)
        function testRecordsAreGroupedByTheirV1Presentation(testCase)
            bodies = {v1Control('c1', 'p1', [2 2 NaN]), v1Control('c2', 'p2', 1), ...
                v1Control('c3', 'p1', [1 1 1]), otherDoc('x1')};
            [m, r] = ndi.migrate.internal.controlRecordsByPresentation(bodies, ...
                {'c1', 'c2', 'c3', 'x1'});
            testCase.verifyEqual(r.bodies_inspected, 4);
            testCase.verifyEqual(r.control_records_v1, 3);
            testCase.verifyEqual(r.control_records_read, 3);
            testCase.verifyEqual(sort(m.keys()), {'p1', 'p2'});
            p1 = m('p1');
            testCase.verifyEqual(numel(p1), 2);
            testCase.verifyEqual(p1{1}.base.id, 'c1');
            testCase.verifyEqual(p1{2}.base.id, 'c3');
        end

        function testTheRecordIsTheV1BodyUnchanged(testCase)
            % the fold receives exactly what v1 holds: the `app` block and the
            % `value`-keyed edge, not a pass-1 rewrite of them
            b = v1Control('c1', 'p1', [2 2 1]);
            m = ndi.migrate.internal.controlRecordsByPresentation({b}, {'c1'});
            got = m('p1');
            testCase.verifyEqual(got{1}, b);
        end

        function testJsonTextBodiesAreRead(testCase)
            % ndi.migrate.local's first-run readers hand over JSON text
            b = jsonencode(v1Control('c1', 'p1', [1 2]));
            [m, r] = ndi.migrate.internal.controlRecordsByPresentation({b}, {'c1'});
            testCase.verifyEqual(r.control_records_read, 1);
            testCase.verifyTrue(isKey(m, 'p1'));
        end

        function testARecordPassOneDidNotHandOnIsNotFolded(testCase)
            % quarantined by pass 1: folding it would put a calculation beside
            % the quarantined original under one id
            bodies = {v1Control('c1', 'p1', 1), v1Control('c2', 'p1', 1)};
            [m, r] = ndi.migrate.internal.controlRecordsByPresentation(bodies, {'c1'});
            testCase.verifyEqual(r.control_records_v1, 2);
            testCase.verifyEqual(r.control_not_handed_on, 1);
            testCase.verifyEqual(r.control_records_read, 1);
            held = m('p1');
            testCase.verifyEqual(numel(held), 1);
            testCase.verifyEqual(held{1}.base.id, 'c1');
        end

        function testNoHandedOnListTakesEveryRecord(testCase)
            bodies = {v1Control('c1', 'p1', 1), v1Control('c2', 'p1', 1)};
            [~, r] = ndi.migrate.internal.controlRecordsByPresentation(bodies);
            testCase.verifyEqual(r.control_records_read, 2);
            testCase.verifyEqual(r.control_not_handed_on, 0);
        end

        function testARecordNamingNoPresentationIsCounted(testCase)
            b = v1Control('c1', '', 1);
            [m, r] = ndi.migrate.internal.controlRecordsByPresentation({b}, {'c1'});
            testCase.verifyEqual(r.control_records_read, 1);
            testCase.verifyEqual(r.control_no_presentation, 1);
            testCase.verifyEqual(double(m.Count), 0);
        end

        function testUnreadableEntriesAreCountedNotFatal(testCase)
            [m, r] = ndi.migrate.internal.controlRecordsByPresentation( ...
                {'{not json', 42, v1Control('c1', 'p1', 1)}, {'c1'});
            testCase.verifyEqual(r.bodies_inspected, 3);
            testCase.verifyEqual(r.bodies_unreadable, 2);
            testCase.verifyTrue(isKey(m, 'p1'));
        end
    end
end

function d = v1Control(id, presId, ids)
d = struct();
d.document_class = struct('class_name', 'control_stimulus_ids', 'class_version', 1);
d.base = struct('id', id, 'session_id', 'sess1', 'name', '', ...
    'datestamp', '2021-11-16T12:00:00.000Z');
d.app = struct('name', 'ndi_app_tuning_response', 'version', 'abc', ...
    'url', '', 'os', 'GLNXA64', 'os_version', '', 'interpreter', 'MATLAB', ...
    'interpreter_version', '9.10');
d.depends_on = struct('name', 'stimulus_presentation_id', 'value', presId);
d.control_stimulus_ids = struct('control_stimulus_ids', ids, ...
    'control_stimulus_id_method', struct('method', 'pseudorandom', ...
    'controlid', 'isblank', 'controlid_value', 1));
end

function d = otherDoc(id)
d = struct();
d.document_class = struct('class_name', 'stimulus_presentation', 'class_version', 1);
d.base = struct('id', id, 'session_id', 'sess1');
end
