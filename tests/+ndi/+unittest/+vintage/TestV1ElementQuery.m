classdef TestV1ElementQuery < matlab.unittest.TestCase
%TESTV1ELEMENTQUERY A v1 element search on a v2 database starts from the class.
%
%   ndi.vintage.v1ElementQuery ANDs `isa element` onto a search of the v1
%   `element` block's fields when the session's database is a v2 one, so
%   DID-matlab can start the search from the class index instead of reading
%   every document of the session (Decided by Jess Haley, 2026-11-06 [read
%   speed margin], did-schema did_v2_go_forward_class_audit.md;
%   VH-Lab/NDI-matlab#1266). The answers must be the same documents in the
%   same order as the search without it.
%
%   Filtered (never passed) when did2.build or a v2 schema with `entity` is
%   missing.

    properties
        Dir
    end

    methods (TestClassSetup)
        function needV2(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a v2 schema with `entity`');
        end
    end

    methods (TestMethodSetup)
        function makeDir(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
        end
    end

    methods (Test)
        function testTheSameElementsInTheSameOrder(testCase)
            S = ndi.setup.V2.createSession(testCase.Dir, 'd1');
            names = {'p2', 'p1', 'p3'};
            for k = 1:numel(names)
                d = ndi.document('element', 'element.ndi_element_class', 'ndi.probe.timeseries.mfdaq', ...
                    'element.name', names{k}, 'element.reference', k, 'element.type', 'n-trode', ...
                    'element.direct', 1) + S.newdocument();
                S.database_add(d);
            end
            sub = ndi.subject('mouse1@nosuchlab.org', '');
            S.database_add(sub.newdocument(S));
            searches = {ndi.query('element.name', 'exact_string', 'p1', ''), ...
                ndi.query('element.ndi_element_class', 'contains_string', 'probe', ''), ...
                ndi.query('element.name', 'exact_string', 'p1', '') & ...
                    ndi.query('element.reference', 'exact_number', 2, ''), ...
                ndi.query('element.name', 'exact_string', 'none', '')};
            expected = {{'p1'}, {'p2', 'p1', 'p3'}, {'p1'}, {}};
            for k = 1:numel(searches)
                plain = namesOf(S.database_search(searches{k}));
                started = namesOf(S.database_search(ndi.vintage.v1ElementQuery(S, searches{k})));
                testCase.verifyEqual(started, plain, sprintf('search %d', k));
                testCase.verifyEqual(started, expected{k}, sprintf('search %d', k));
            end
            % on the v2 database the class is ANDed on
            testCase.assertTrue(S.writesV2());
            q = ndi.vintage.v1ElementQuery(S, searches{1});
            testCase.verifyNotEqual(q.searchstructure, searches{1}.searchstructure);
        end

        function testElsewhereTheSearchIsUnchanged(testCase)
            Q = ndi.query('element.name', 'exact_string', 'p1', '');
            q = ndi.vintage.v1ElementQuery(struct('database', []), Q);
            testCase.verifyEqual(q.searchstructure, Q.searchstructure);
            q = ndi.vintage.v1ElementQuery(struct(), Q);
            testCase.verifyEqual(q.searchstructure, Q.searchstructure);
        end
    end
end

function n = namesOf(docs)
n = cellfun(@(d) char(d.document_properties.element.name), docs, 'UniformOutput', false);
n = reshape(n, 1, []);
if isempty(n); n = {}; end
end
