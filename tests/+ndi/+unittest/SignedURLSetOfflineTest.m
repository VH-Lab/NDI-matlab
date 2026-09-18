classdef SignedURLSetOfflineTest < matlab.unittest.TestCase
% SIGNEDURLSETOFFLINETEST - offline tests for the signed-url-set client.
%
% Covers the parts that can be exercised without a live cloud: URL
% construction, query-string assembly, and the uid recovery that keeps
% JSONDECODE from silently renaming file uids.
%
% The live-cloud round trip belongs under tests/+ndi/+unittest/+cloud, which
% the no-cloud CI suite excludes by namespace.

    methods (Test)

        % ---- endpoint URLs ------------------------------------------------

        function testSignedURLSetEndpoint(testCase)
            u = ndi.cloud.api.url('get_signed_url_set', ...
                'dataset_id', "ds1", 'document_id', "doc1");
            testCase.verifyTrue(endsWith(string(u), ...
                "/datasets/ds1/documents/doc1/signed-url-set"));
        end

        function testSignedURLSetJobEndpoints(testCase)
            u = ndi.cloud.api.url('create_signed_url_set_job', ...
                'dataset_id', "ds1", 'document_id', "doc1");
            testCase.verifyTrue(endsWith(string(u), ...
                "/datasets/ds1/documents/doc1/signed-url-set-jobs"));

            u2 = ndi.cloud.api.url('get_signed_url_set_job', 'job_id', "job1");
            testCase.verifyTrue(endsWith(string(u2), "/signed-url-set-jobs/job1"));
        end

        function testMissingPathParameterIsRefused(testCase)
            testCase.verifyError(...
                @() ndi.cloud.api.url('get_signed_url_set', 'dataset_id', "ds1"), ...
                'NDI:CloudApiUrl:MissingPathParameter');
        end

        % ---- which route a document id namespace selects -------------------
        %
        % Two routes serve the same set, addressed by different ids: the
        % original one takes the cloud _id, the ndi-documents one takes the
        % NDI document id and resolves it server-side. NDI's own callers hold
        % the NDI id, so they must ask for "ndi"; sending an NDI id to the
        % by-_id route is a 404 that reads exactly like a deleted document,
        % which is how it went unnoticed from #952 until #968. Nothing here
        % needs a server, so it runs in the fast suite where a regression
        % would otherwise wait for the next live cloud run to surface.

        function testNdiDocumentEndpointUrls(testCase)
            u = ndi.cloud.api.url('get_ndi_signed_url_set', ...
                'dataset_id', "ds1", 'ndi_document_id', "ndidoc1");
            testCase.verifyTrue(endsWith(string(u), ...
                "/datasets/ds1/ndi-documents/ndidoc1/signed-url-set"));

            u2 = ndi.cloud.api.url('create_ndi_signed_url_set_job', ...
                'dataset_id', "ds1", 'ndi_document_id', "ndidoc1");
            testCase.verifyTrue(endsWith(string(u2), ...
                "/datasets/ds1/ndi-documents/ndidoc1/signed-url-set-jobs"));
        end

        function testMissingNdiDocumentIdIsRefused(testCase)
            % The id arrives from a caller, not a literal, so an empty one
            % must not build ".../ndi-documents//signed-url-set".
            testCase.verifyError(...
                @() ndi.cloud.api.url('get_ndi_signed_url_set', 'dataset_id', "ds1"), ...
                'NDI:CloudApiUrl:MissingPathParameter');
        end

        function testTheDefaultNamespaceIsStillTheByIdRoute(testCase)
            % Every caller that predates idNamespace passes a cloud _id and
            % says nothing. Their route must not have moved.
            call = ndi.cloud.api.implementation.files.GetSignedURLSet(...
                'cloudDatasetID', "ds1", 'cloudDocumentID', "doc1");
            u = string(call.buildURL());
            testCase.verifyTrue(contains(u, "/datasets/ds1/documents/doc1/signed-url-set"));
            testCase.verifyFalse(contains(u, "ndi-documents"));
            testCase.verifyEqual(call.idNamespace, "cloud");
        end

        function testTheNdiNamespaceSelectsTheNdiDocumentsRoute(testCase)
            call = ndi.cloud.api.implementation.files.GetSignedURLSet(...
                'cloudDatasetID', "ds1", 'cloudDocumentID', "ndidoc1", ...
                'idNamespace', "ndi");
            u = string(call.buildURL());
            testCase.verifyTrue(contains(u, ...
                "/datasets/ds1/ndi-documents/ndidoc1/signed-url-set"));
            testCase.verifyEqual(call.endpointName, 'get_ndi_signed_url_set');
        end

        function testTheNdiRouteStillCarriesTheQuery(testCase)
            % The whole point of the batch call is the fileSeries scoping;
            % changing route must not have dropped it off the query.
            call = ndi.cloud.api.implementation.files.GetSignedURLSet(...
                'cloudDatasetID', "ds1", 'cloudDocumentID', "ndidoc1", ...
                'idNamespace', "ndi", ...
                'limit', 250, 'cursor', "abc", 'fileSeries', "chunkdata.bin");
            u = string(call.buildURL());
            testCase.verifyTrue(contains(u, "ndi-documents/ndidoc1"));
            testCase.verifyTrue(contains(u, "limit=250"));
            testCase.verifyTrue(contains(u, "cursor=abc"));
            testCase.verifyTrue(contains(u, "fileSeries=chunkdata.bin"));
        end

        function testTheJobPostRoutesByNamespaceToo(testCase)
            byId = ndi.cloud.api.implementation.files.CreateSignedURLSetJob(...
                'cloudDatasetID', "ds1", 'cloudDocumentID', "doc1");
            u = string(byId.buildURL());
            testCase.verifyTrue(endsWith(u, ...
                "/datasets/ds1/documents/doc1/signed-url-set-jobs"));

            byNdi = ndi.cloud.api.implementation.files.CreateSignedURLSetJob(...
                'cloudDatasetID', "ds1", 'cloudDocumentID', "ndidoc1", ...
                'idNamespace', "ndi", 'fileSeries', "chunkdata.bin");
            u2 = string(byNdi.buildURL());
            testCase.verifyTrue(contains(u2, ...
                "/datasets/ds1/ndi-documents/ndidoc1/signed-url-set-jobs"));
            testCase.verifyTrue(contains(u2, "fileSeries=chunkdata.bin"));
        end

        function testTheWalkerKeepsTheNamespaceItWasGiven(testCase)
            % GetSignedURLSetAll builds no URL of its own; it hands the
            % namespace to every page it fetches. If it dropped it, page one
            % would 404 and the batch would fall back to per-uid calls -- the
            % exact silent regression #968 was.
            call = ndi.cloud.api.implementation.files.GetSignedURLSetAll(...
                'cloudDatasetID', "ds1", 'cloudDocumentID', "ndidoc1", ...
                'idNamespace', "ndi");
            testCase.verifyEqual(call.idNamespace, "ndi");
            testCase.verifyEqual(call.endpointName, 'get_ndi_signed_url_set');

            byDefault = ndi.cloud.api.implementation.files.GetSignedURLSetAll(...
                'cloudDatasetID', "ds1", 'cloudDocumentID', "doc1");
            testCase.verifyEqual(byDefault.idNamespace, "cloud");
            testCase.verifyEqual(byDefault.endpointName, 'get_signed_url_set');
        end

        function testAnUnknownNamespaceIsRefusedBeforeAnyRequest(testCase)
            % mustBeMember on the public wrappers: a typo has to fail at the
            % call, not resolve to a default route and 404 later. These throw
            % during argument validation, so no network is touched.
            testCase.verifyError(...
                @() ndi.cloud.api.files.getSignedURLSet("ds1", "doc1", ...
                    'idNamespace', "cloudy"), ...
                'MATLAB:validators:mustBeMember');
            testCase.verifyError(...
                @() ndi.cloud.api.files.getSignedURLSetAll("ds1", "doc1", ...
                    'idNamespace', "cloudy"), ...
                'MATLAB:validators:mustBeMember');
            testCase.verifyError(...
                @() ndi.cloud.api.files.createSignedURLSetJob("ds1", "doc1", ...
                    'idNamespace', "cloudy"), ...
                'MATLAB:validators:mustBeMember');
        end

        % ---- query string -------------------------------------------------

        function testUrlCarriesLimitByDefault(testCase)
            call = ndi.cloud.api.implementation.files.GetSignedURLSet(...
                'cloudDatasetID', "ds1", 'cloudDocumentID', "doc1");
            u = string(call.buildURL());
            testCase.verifyTrue(contains(u, "limit=500"));
            testCase.verifyFalse(contains(u, "cursor="), ...
                'no cursor is sent for the first page');
            testCase.verifyFalse(contains(u, "fileSeries="));
        end

        function testUrlCarriesCursorAndFileSeries(testCase)
            call = ndi.cloud.api.implementation.files.GetSignedURLSet(...
                'cloudDatasetID', "ds1", 'cloudDocumentID', "doc1", ...
                'limit', 1000, 'cursor', "abc", 'fileSeries', "chunkdata.bin");
            u = string(call.buildURL());
            testCase.verifyTrue(contains(u, "limit=1000"));
            testCase.verifyTrue(contains(u, "cursor=abc"));
            testCase.verifyTrue(contains(u, "fileSeries=chunkdata.bin"));
        end

        function testUrlEncodesAnOpaqueCursor(testCase)
            % Cursors are opaque server state; a server is free to hand back
            % base64 with '+', '/' and '=' in it, and those must not reach the
            % wire unescaped or the cursor comes back different.
            call = ndi.cloud.api.implementation.files.GetSignedURLSet(...
                'cloudDatasetID', "ds1", 'cloudDocumentID', "doc1", ...
                'cursor', "a+b/c=");
            u = string(call.buildURL());
            testCase.verifyTrue(contains(u, "cursor="));
            testCase.verifyFalse(contains(u, "cursor=a+b/c="), ...
                'the raw cursor must not appear unencoded');
        end

        % ---- uid recovery -------------------------------------------------

        function testUidStartingWithADigitSurvives(testCase)
            % This is the whole point of signedURLFileMap. A did.ido uid is
            % NUM2HEX(<date>) '_' NUM2HEX(<rand>), so it starts with a digit
            % most of the time, and JSONDECODE renames such a field to 'x...'.
            uid = '4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6';
            txt = ['{"files":{"' uid '":"https://s3/x"},"nextCursor":null}'];
            data = jsondecode(txt);

            % Confirm the hazard is real on this MATLAB, so the test still
            % means something if JSONDECODE ever stops renaming.
            testCase.verifyFalse(isfield(data.files, uid), ...
                'Expected JSONDECODE to rename a field starting with a digit.');

            m = ndi.cloud.api.implementation.files.signedURLFileMap(data.files, txt);
            testCase.verifyTrue(m.isKey(uid));
            testCase.verifyEqual(m(uid), 'https://s3/x');
        end

        function testKeysAndValuesStayPaired(testCase)
            uids = {'9a11111111111111_1111111111111111', ...
                    '0b22222222222222_2222222222222222', ...
                    'cc33333333333333_3333333333333333'};
            parts = cell(1, numel(uids));
            for i = 1:numel(uids)
                parts{i} = sprintf('"%s":"https://s3/%d"', uids{i}, i);
            end
            txt = ['{"files":{' strjoin(parts, ',') '},"nextCursor":"z"}'];
            data = jsondecode(txt);

            m = ndi.cloud.api.implementation.files.signedURLFileMap(data.files, txt);
            testCase.verifyEqual(double(m.Count), numel(uids));
            for i = 1:numel(uids)
                testCase.verifyEqual(m(uids{i}), sprintf('https://s3/%d', i));
            end
        end

        function testBraceInsideAUrlDoesNotEndTheObject(testCase)
            txt = '{"files":{"9a":"https://s3/x?p={weird}&q=1","9b":"https://s3/y"}}';
            data = jsondecode(txt);
            m = ndi.cloud.api.implementation.files.signedURLFileMap(data.files, txt);
            testCase.verifyEqual(double(m.Count), 2);
            testCase.verifyEqual(m('9a'), 'https://s3/x?p={weird}&q=1');
        end

        function testEscapedQuoteInsideAUrlIsHandled(testCase)
            txt = '{"files":{"9a":"https://s3/x?q=\"quoted\""},"nextCursor":"z"}';
            data = jsondecode(txt);
            m = ndi.cloud.api.implementation.files.signedURLFileMap(data.files, txt);
            testCase.verifyEqual(double(m.Count), 1);
            testCase.verifyTrue(m.isKey('9a'));
        end

        function testLiteralFilesTextInAValueIsNotTheObject(testCase)
            txt = '{"kind":"files","files":{"9a":"u1"}}';
            data = jsondecode(txt);
            m = ndi.cloud.api.implementation.files.signedURLFileMap(data.files, txt);
            testCase.verifyEqual(double(m.Count), 1);
            testCase.verifyEqual(m('9a'), 'u1');
        end

        function testNestedFilesObjectIsNotMistakenForTheTopLevelOne(testCase)
            txt = '{"meta":{"files":{"zz":"nope"}},"files":{"9a":"u1"}}';
            data = jsondecode(txt);
            m = ndi.cloud.api.implementation.files.signedURLFileMap(data.files, txt);
            testCase.verifyEqual(double(m.Count), 1);
            testCase.verifyTrue(m.isKey('9a'));
            testCase.verifyFalse(m.isKey('zz'));
        end

        function testFilesObjectAfterOtherKeys(testCase)
            txt = '{"nextCursor":"z","expiresAt":"2026-01-01","files":{"9a":"u1","9b":"u2"}}';
            data = jsondecode(txt);
            m = ndi.cloud.api.implementation.files.signedURLFileMap(data.files, txt);
            testCase.verifyEqual(double(m.Count), 2);
            testCase.verifyEqual(m('9b'), 'u2');
        end

        function testWhitespaceBetweenTokens(testCase)
            txt = sprintf('{\n  "files" : {\n    "9a" : "u1" ,\n    "9b" : "u2"\n  }\n}');
            data = jsondecode(txt);
            m = ndi.cloud.api.implementation.files.signedURLFileMap(data.files, txt);
            testCase.verifyEqual(double(m.Count), 2);
            testCase.verifyEqual(m('9a'), 'u1');
        end

        function testEmptyFilesObjectGivesAnEmptyMap(testCase)
            txt = '{"files":{},"nextCursor":null}';
            data = jsondecode(txt);
            m = ndi.cloud.api.implementation.files.signedURLFileMap(data.files, txt);
            testCase.verifyEqual(double(m.Count), 0);
        end

        function testMissingFilesFieldGivesAnEmptyMap(testCase)
            m = ndi.cloud.api.implementation.files.signedURLFileMap([], '{"nextCursor":"z"}');
            testCase.verifyEqual(double(m.Count), 0);
        end

        function testKeyCountMismatchIsAnErrorNotAGuess(testCase)
            % A payload the scanner cannot read must not silently pair the
            % decoded values with the wrong uids: a wrong uid downloads the
            % wrong file, which is worse than a failed call.
            txt = '{"files":{"9a":"u1","9b":"u2"}}';
            data = jsondecode(txt);
            testCase.verifyError(...
                @() ndi.cloud.api.implementation.files.signedURLFileMap(...
                    data.files, '{"files":{"9a":"u1"}}'), ...
                'NDI:CloudApi:SignedURLSet:KeyCountMismatch');
        end

        function testTruncatedPayloadIsRefused(testCase)
            txt = '{"files":{"9a":"u1","9b":"u2"}}';
            data = jsondecode(txt);
            testCase.verifyError(...
                @() ndi.cloud.api.implementation.files.signedURLFileMap(...
                    data.files, '{"files":{"9a":"u1'), ...
                'NDI:CloudApi:SignedURLSet:KeyCountMismatch');
        end

        function testRawPayloadMayBeUint8(testCase)
            % matlab.net.http hands back Body.Payload as uint8.
            txt = '{"files":{"9a":"u1"}}';
            data = jsondecode(txt);
            m = ndi.cloud.api.implementation.files.signedURLFileMap(...
                data.files, uint8(txt));
            testCase.verifyEqual(m('9a'), 'u1');
        end

        function testManyEntriesKeepTheirOrder(testCase)
            % The pairing is positional, so a large object is the case that
            % would expose any drift between decoded order and payload order.
            n = 500;
            uids = cell(1, n);
            parts = cell(1, n);
            for i = 1:n
                uids{i} = sprintf('%016x_%016x', i, n - i);
                parts{i} = sprintf('"%s":"https://s3/%d"', uids{i}, i);
            end
            txt = ['{"files":{' strjoin(parts, ',') '},"nextCursor":"z"}'];
            data = jsondecode(txt);

            m = ndi.cloud.api.implementation.files.signedURLFileMap(data.files, txt);
            testCase.verifyEqual(double(m.Count), n);
            for i = 1:n
                testCase.verifyEqual(m(uids{i}), sprintf('https://s3/%d', i));
            end
        end

        % ---- page assembly ------------------------------------------------

        function testKeyScannerReturnsKeysInPayloadOrder(testCase)
            keys = ndi.cloud.api.implementation.files.signedURLFileMap_keys(...
                '{"files":{"9a":"u1","0b":"u2","cc":"u3"}}');
            testCase.verifyEqual(keys, {'9a','0b','cc'});
        end

        function testKeyScannerOnEmptyInput(testCase)
            testCase.verifyEqual(...
                ndi.cloud.api.implementation.files.signedURLFileMap_keys(''), {});
            testCase.verifyEqual(...
                ndi.cloud.api.implementation.files.signedURLFileMap_keys([]), {});
        end
    end
end
