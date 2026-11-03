classdef testDatasetMarkerUnfiltered < matlab.unittest.TestCase
    % TESTDATASETMARKERUNFILTERED - a dataset folder opened as one of its
    % member sessions is still recorded as a dataset (#1015, #974).
    %
    % A dataset downloaded from NDI Cloud has no object-type marker, and
    % ndi.session.dir(PATH) adopts the session that .ndi/unique_reference.txt
    % names, which need not be the dataset's own. updateObjectTypeMarker
    % looked for the dataset bookkeeping documents with database_search, which
    % keeps only that session's documents; the bookkeeping documents carry the
    % dataset's session id, so none was found, the folder was marked
    % 'session', and ndi.dataset.dir refused it (NDI:dataset:dir:NotADataset).
    %
    % Each test puts a dataset folder in that state: no marker (or the wrong
    % 'session' marker the old code wrote), and unique_reference.txt naming a
    % member session. v1 datasets keep `session_in_a_dataset` documents; V2
    % datasets file each session under the `dataset` entity with an
    % `included_in` relation (Jess Haley 2026-10-25 [session membership
    % records linked or ingested], did-schema did_v2_go_forward_class_audit.md).

    properties
        Paths = {}
    end

    methods (TestMethodTeardown)
        function removeFolders(testCase)
            for k = 1:numel(testCase.Paths)
                if isfolder(testCase.Paths{k})
                    rmdir(testCase.Paths{k}, 's');
                end
            end
        end
    end

    methods (Test)

        function testV1DatasetWithoutMarkerOpenedAsMember(testCase)
            [p, dsId, memberId] = testCase.v1Dataset();
            delete(markerFile(p));
            openAs(p, memberId);

            % the reproduction: before the fix this recorded 'session'
            s = ndi.session.dir(p);
            testCase.verifyEqual(s.id(), memberId, ...
                'fixture: the bare open should adopt the member session');
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'dataset');

            delete(markerFile(p));
            openAs(p, memberId);
            d = ndi.dataset.dir(p);
            testCase.verifyEqual(d.id(), dsId);
            [~, ids] = d.session_list();
            testCase.verifyEqual(ids, {memberId});
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'dataset');
        end

        function testV1DatasetWronglyMarkedSessionIsCorrected(testCase)
            [p, dsId, memberId] = testCase.v1Dataset();
            vlt.file.str2text(markerFile(p), 'session');   % what the old code wrote
            openAs(p, memberId);
            d = ndi.dataset.dir(p);
            testCase.verifyEqual(d.id(), dsId);
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'dataset');
        end

        function testPlainSessionStillRefused(testCase)
            S = ndi.unittest.session.buildSession.withDocsAndFiles();
            testCase.Paths{end+1} = S.path;
            testCase.verifyEqual(ndi.session.dir.directorytype(S.path), 'session');
            testCase.verifyError(@() ndi.dataset.dir(S.path), 'NDI:dataset:dir:NotADataset');
            delete(markerFile(S.path));
            testCase.verifyError(@() ndi.dataset.dir(S.path), 'NDI:dataset:dir:NotADataset');
        end

        function testV2DatasetWithoutMarkerOpenedAsMember(testCase)
            [p, dsId, memberId] = testCase.v2Dataset();
            delete(markerFile(p));
            openAs(p, memberId);
            s = ndi.session.dir(p);
            testCase.verifyEqual(s.id(), memberId, ...
                'fixture: the bare open should adopt the member session');
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'dataset');

            vlt.file.str2text(markerFile(p), 'session');   % what the old code wrote
            openAs(p, memberId);
            d = ndi.dataset.dir(p);
            testCase.verifyEqual(d.id(), dsId);
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'dataset');
        end

        function testV2PlainSessionStaysSession(testCase)
            needV2(testCase);
            p = tempname;
            mkdir(p);
            testCase.Paths{end+1} = p;
            ndi.setup.V2.createSession(p, 'plain1');
            delete(markerFile(p));
            ndi.session.dir(p);
            testCase.verifyEqual(ndi.session.dir.directorytype(p), 'session');
            testCase.verifyError(@() ndi.dataset.dir(p), 'NDI:dataset:dir:NotADataset');
        end
    end

    methods
        function [p, dsId, memberId] = v1Dataset(testCase)
            [ds, S] = ndi.unittest.dataset.buildDataset.sessionWithIngestedDocsAndFiles();
            testCase.Paths = [testCase.Paths, {ds.path, S.path}];
            p = ds.path;
            dsId = ds.id();
            memberId = S.id();
            testCase.assertEqual(ndi.session.dir.directorytype(p), 'dataset');
        end

        function [p, dsId, memberId] = v2Dataset(testCase)
            needV2(testCase);
            root = tempname;
            mkdir(root);
            testCase.Paths{end+1} = root;
            p = fullfile(root, 'dataset');
            dsId = ndi.ido.unique_id();
            memberId = ndi.ido.unique_id();
            dsDocs = ndi.setup.V2.entityDocuments('dataset', struct('name', 'Marker test'), ...
                struct(), 'SessionId', dsId, 'Id', dsId);
            sess = ndi.setup.V2.entityDocuments('session', struct('local_identifier', 'day1'), ...
                struct(), 'SessionId', memberId, 'Id', memberId);
            included = did2.build.directedRelation(memberId, dsId, 'included_in', ...
                'SessionId', memberId);
            ndi.setup.V2.createDataset(p, 'marker', dsId, dsDocs, {[sess, {included}]}, ...
                'Strict', true, 'Progress', false);
            testCase.assertEqual(ndi.session.dir.directorytype(p), 'dataset');
        end
    end
end

function needV2(testCase)
testCase.assumeTrue(~isempty(which('did2.build.document')), ...
    'did2.build (DID-matlab V2) is not on the path');
schemaPath = getenv('DID_SCHEMA_PATH');
testCase.assumeTrue(~isempty(schemaPath) && ...
    isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
    'DID_SCHEMA_PATH does not hold a V2 schema with `entity`');
end

function f = markerFile(p)
f = fullfile(p, '.ndi', ndi.session.dir.objecttypemarkerfilename());
end

function openAs(p, sessionId)
% the folder opens as SESSIONID, as a downloaded copy may
vlt.file.str2text(fullfile(p, '.ndi', 'unique_reference.txt'), sessionId);
end
