classdef TestProbeWiring < matlab.unittest.TestCase
%TESTPROBEWIRING A probe's channels are read from its `connected to` relation.
%
%   Decided by Jess Haley, 2026-11-01, did-schema
%   did_v2_go_forward_class_audit.md [probe wiring is a relation] and [wiring
%   relation term]: the wiring of a probe to an acquisition system's channels
%   is a directed_relation `connected to` (RO:0002170) from the probe (child)
%   to the system (parent), timed by the epoch's time reference, one
%   condition per channel type (variable the channel-type term, value the
%   matrix of its numbers); a recording names its system by
%   `acquisition_system_id`.
%
%   The fixture is one V2 session written with ndi.setup.V2.createSession:
%   an acquisition system 'intan1', an epoch anchor, a recording observation
%   naming the system and its probe, and the probe's wiring relation (ai11-14
%   and di1). The tests read it back as NDI's readers do:
%   ndi.vintage.wiredDeviceString rebuilds v1's devicestring, and
%   ndi.vintage.systemStatements finds the system's recordings.
%
%   Filtered (never passed) when did2.build or a V2 schema with a term
%   registry is missing.

    properties
        Dir
        Session
        Ids
    end

    methods (TestClassSetup)
        function writeSession(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.directedRelation')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'term_registry_meta.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with a term registry');

            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
            sid = char(ndi.ido.unique_id());
            T = @(node) ndi.setup.V2.registeredTerm(node);
            S = {'SessionId', sid, 'Validate', false};

            sys = did2.build.document('acquisition_system', struct('name', 'intan1'), ...
                'Edges', struct('reader_id', 'reader_test', ...
                'epoch_file_pattern_id', 'pattern_test'), S{:});
            anchor = did2.build.relativeTimeReference('epoch_test', ...
                'Relation', 'intervalDuring', S{:});
            probeId = 'probe_test';
            obs = did2.build.statement('observation', 'subject_test', T('PATO:0000008'), [], ...
                'DataBody', true, 'InstrumentId', probeId, ...
                'AcquisitionSystemId', sys.base.id, ...
                'TimeReferenceIds', {anchor.base.id}, S{:}, 'ValueKind', 'velocity');
            conds = did2.build.list( ...
                did2.build.condition(T('EMPTY:0000370'), 'Matrix', [11 12 13 14]), ...
                did2.build.condition(T('EMPTY:0000372'), 'Matrix', 1));
            wire = did2.build.directedRelation(probeId, sys.base.id, ...
                T('RO:0002170'), 'TimeReferenceIds', {anchor.base.id}, ...
                'Fields', struct('conditions', {conds}), S{:});

            sessionDir = fullfile(testCase.Dir, 'session');
            mkdir(sessionDir);
            testCase.Session = ndi.setup.V2.createSession(sessionDir, 'probe wiring', ...
                'SessionId', sid, 'Documents', {sys, anchor, obs, wire}, 'Validate', false);
            testCase.Ids = struct('system', sys.base.id, 'observation', obs.base.id, ...
                'probe', probeId, 'session', sid);
        end
    end

    methods (Test)
        function testTheDevicestringIsRebuiltFromTheRelation(testCase)
            S = testCase.Session;
            st = S.database_search(ndi.query('base.id', 'exact_string', testCase.Ids.observation, ''));
            testCase.assertNumElements(st, 1, 'the recording observation was written');
            s = ndi.vintage.wiredDeviceString(S, st{1}, testCase.Ids.system, ...
                testCase.Ids.probe, struct('doc', containers.Map()));
            testCase.verifyEqual(s, 'intan1:ai11-14;di1');
        end

        function testAProbeWithNoRelationGivesTheSystemNameAlone(testCase)
            S = testCase.Session;
            st = S.database_search(ndi.query('base.id', 'exact_string', testCase.Ids.observation, ''));
            s = ndi.vintage.wiredDeviceString(S, st{1}, testCase.Ids.system, ...
                'another_probe', struct('doc', containers.Map()));
            testCase.verifyEqual(s, 'intan1');
        end

        function testAnUnknownSystemGivesNothing(testCase)
            S = testCase.Session;
            st = S.database_search(ndi.query('base.id', 'exact_string', testCase.Ids.observation, ''));
            s = ndi.vintage.wiredDeviceString(S, st{1}, 'no_such_system', ...
                testCase.Ids.probe, struct('doc', containers.Map()));
            testCase.verifyEmpty(s);
        end

        function testTheSystemFindsItsRecordingByItsOwnEdge(testCase)
            S = testCase.Session;
            inSession = ndi.query('base.session_id', 'exact_string', testCase.Ids.session, '');
            found = ndi.vintage.systemStatements(S, testCase.Ids.system, inSession);
            docs = [found{:}];
            ids = cellfun(@(d) d.id(), docs, 'UniformOutput', false);
            testCase.verifyEqual(ids, {testCase.Ids.observation}, ...
                'the one recording, found once, by acquisition_system_id');
        end
    end
end
