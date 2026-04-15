classdef testDocumentClassCounts < matlab.unittest.TestCase
%TESTDOCUMENTCLASSCOUNTS Tests the GET /datasets/:datasetId/document-class-counts endpoint.
%
%   This class tests ndi.cloud.api.documents.documentClassCounts, which returns
%   a flat histogram of leaf data.document_class.class_name counts for a single
%   dataset. The endpoint intentionally does NOT roll up inheritance. Documents
%   with missing or empty class_name bucket under "unknown", and the total
%   must equal the sum of the per-class counts.
%
%   These are read-only tests that target a small, fixed remote dataset that is
%   expected to exist in the NDI Cloud (~750 documents).

    properties (Constant)
        % Fixed remote dataset used for read-only verification. Small enough
        % (~750 documents) that a full aggregation is fast and cheap.
        TestDatasetID (1,1) string = "668b0539f13096e04f1feccd"
    end

    properties
        Narrative (1,:) string
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            testCase.fatalAssertNotEmpty(username, 'NDI_CLOUD_USERNAME not set.');
            testCase.fatalAssertNotEmpty(password, 'NDI_CLOUD_PASSWORD not set.');
        end
    end

    methods (Test)

        function testResponseShape(testCase)
            % Verify the response has the documented top-level shape:
            %   datasetId (string), totalDocuments (integer), classCounts (struct).
            testCase.Narrative = "Begin testResponseShape";
            narrative = testCase.Narrative;

            narrative(end+1) = "Calling documentClassCounts for dataset " + testCase.TestDatasetID;
            [b, answer, resp, url] = ndi.cloud.api.documents.documentClassCounts(testCase.TestDatasetID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);

            testCase.fatalAssertTrue(b, "documentClassCounts call failed. " + msg);
            testCase.verifyTrue(isstruct(answer), "Answer should be a struct. " + msg);

            testCase.verifyTrue(isfield(answer, 'datasetId'), ...
                "Answer should have a datasetId field. " + msg);
            testCase.verifyTrue(isfield(answer, 'totalDocuments'), ...
                "Answer should have a totalDocuments field. " + msg);
            testCase.verifyTrue(isfield(answer, 'classCounts'), ...
                "Answer should have a classCounts field. " + msg);

            testCase.verifyEqual(string(answer.datasetId), testCase.TestDatasetID, ...
                "Returned datasetId does not match the requested dataset. " + msg);

            testCase.verifyTrue(isnumeric(answer.totalDocuments), ...
                "totalDocuments should be numeric. " + msg);
            testCase.verifyGreaterThanOrEqual(answer.totalDocuments, 0, ...
                "totalDocuments must be non-negative. " + msg);

            testCase.verifyTrue(isstruct(answer.classCounts), ...
                "classCounts should be decoded as a struct. " + msg);

            testCase.Narrative = narrative;
        end

        function testTotalEqualsSumOfCounts(testCase)
            % Spec: totalDocuments must equal the sum of classCounts values.
            % Documents with missing/empty class_name are not silently dropped;
            % they are bucketed under "unknown".
            testCase.Narrative = "Begin testTotalEqualsSumOfCounts";
            narrative = testCase.Narrative;

            [b, answer, resp, url] = ndi.cloud.api.documents.documentClassCounts(testCase.TestDatasetID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
            testCase.fatalAssertTrue(b, "documentClassCounts call failed. " + msg);

            fn = fieldnames(answer.classCounts);
            total = 0;
            for i = 1:numel(fn)
                v = answer.classCounts.(fn{i});
                testCase.verifyTrue(isnumeric(v), ...
                    sprintf('classCounts.%s should be numeric. %s', fn{i}, msg));
                testCase.verifyGreaterThanOrEqual(v, 0, ...
                    sprintf('classCounts.%s must be non-negative. %s', fn{i}, msg));
                total = total + v;
            end

            testCase.verifyEqual(total, double(answer.totalDocuments), ...
                "Sum of classCounts values must equal totalDocuments. " + msg);

            testCase.Narrative = narrative;
        end

        function testCountsAreLeafClassNames(testCase)
            % The endpoint is deliberately flat: keys must be leaf class_name
            % strings, not class paths or URIs. Specifically, no key should
            % contain a '/' or end with '.json', which would indicate we
            % accidentally bucketed by document_class.definition.
            testCase.Narrative = "Begin testCountsAreLeafClassNames";
            narrative = testCase.Narrative;

            [b, answer, resp, url] = ndi.cloud.api.documents.documentClassCounts(testCase.TestDatasetID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
            testCase.fatalAssertTrue(b, "documentClassCounts call failed. " + msg);

            fn = fieldnames(answer.classCounts);
            testCase.verifyNotEmpty(fn, ...
                "Expected at least one class bucket in a 750-doc dataset. " + msg);

            for i = 1:numel(fn)
                key = fn{i};
                testCase.verifyEmpty(regexp(key, '/', 'once'), ...
                    sprintf('classCounts key "%s" contains a slash; expected a leaf class_name. %s', key, msg));
                testCase.verifyFalse(endsWith(key, '.json'), ...
                    sprintf('classCounts key "%s" looks like a definition path, not a class_name. %s', key, msg));
            end

            testCase.Narrative = narrative;
        end

        function testAgreesWithDocumentCount(testCase)
            % The histogram's total should equal the document_count endpoint's
            % result for the same dataset. Both exclude logically deleted docs.
            testCase.Narrative = "Begin testAgreesWithDocumentCount";
            narrative = testCase.Narrative;

            [b1, ans1, resp1, url1] = ndi.cloud.api.documents.documentClassCounts(testCase.TestDatasetID);
            msg1 = ndi.unittest.cloud.APIMessage(narrative, b1, ans1, resp1, url1);
            testCase.fatalAssertTrue(b1, "documentClassCounts call failed. " + msg1);

            [b2, ans2, resp2, url2] = ndi.cloud.api.documents.documentCount(testCase.TestDatasetID);
            msg2 = ndi.unittest.cloud.APIMessage(narrative, b2, ans2, resp2, url2);
            testCase.fatalAssertTrue(b2, "documentCount call failed. " + msg2);

            testCase.verifyEqual(double(ans1.totalDocuments), double(ans2), ...
                "documentClassCounts.totalDocuments must match documentCount. " + msg1);

            testCase.Narrative = narrative;
        end

        function testInvalidDatasetReturnsError(testCase)
            % A bogus dataset id should produce a non-success response
            % (typically 404 from the userHasAccessToDataset middleware).
            testCase.Narrative = "Begin testInvalidDatasetReturnsError";
            narrative = testCase.Narrative;

            bogus = "000000000000000000000000";
            [b, answer, resp, url] = ndi.cloud.api.documents.documentClassCounts(bogus);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);

            testCase.verifyFalse(b, ...
                "documentClassCounts should fail for an unknown dataset id. " + msg);

            testCase.Narrative = narrative;
        end

        function testVeracityAgainstDocumentListing(testCase)
            % Ground-truth check: download every document summary in the
            % dataset via listDatasetDocumentsAll, tally class_name buckets
            % locally using the same "empty -> unknown" rule the server
            % applies, and compare bucket-for-bucket against the endpoint
            % response.
            %
            % This is the slowest test in this class (it paginates all
            % documents in the dataset) but it is the only one that proves
            % the endpoint produces the correct answer, not merely a
            % self-consistent one.
            testCase.Narrative = "Begin testVeracityAgainstDocumentListing";
            narrative = testCase.Narrative;

            % 1. Endpoint under test.
            narrative(end+1) = "Calling documentClassCounts.";
            [b1, ans1, resp1, url1] = ndi.cloud.api.documents.documentClassCounts(testCase.TestDatasetID);
            msg1 = ndi.unittest.cloud.APIMessage(narrative, b1, ans1, resp1, url1);
            testCase.fatalAssertTrue(b1, "documentClassCounts call failed. " + msg1);

            % 2. Ground truth: list every document summary in the dataset.
            narrative(end+1) = "Listing all document summaries for veracity check.";
            [b2, docs, resp2, url2] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.TestDatasetID);
            msg2 = ndi.unittest.cloud.APIMessage(narrative, b2, docs, resp2, url2);
            testCase.fatalAssertTrue(b2, "listDatasetDocumentsAll failed. " + msg2);
            testCase.fatalAssertNotEmpty(docs, "Expected a non-empty document listing. " + msg2);

            % 3. Tally class names locally. Empty/missing -> "unknown",
            %    matching the server-side bucketing rule.
            localCounts = struct();
            for i = 1:numel(docs)
                if isfield(docs(i), 'className') && ~isempty(docs(i).className) ...
                        && ~(ischar(docs(i).className) && strcmp(docs(i).className, '')) ...
                        && ~(isstring(docs(i).className) && strcmp(docs(i).className, ""))
                    key = char(string(docs(i).className));
                else
                    key = 'unknown';
                end
                % Field names in structs must be valid identifiers; class_name
                % values are expected to be valid identifiers already, but
                % defend against that assumption.
                if ~isvarname(key)
                    key = matlab.lang.makeValidName(key);
                end
                if isfield(localCounts, key)
                    localCounts.(key) = localCounts.(key) + 1;
                else
                    localCounts.(key) = 1;
                end
            end

            % 4. Compare totals first (fast sanity check).
            testCase.verifyEqual(numel(docs), double(ans1.totalDocuments), ...
                "totalDocuments must equal the number of documents returned by listDatasetDocumentsAll. " + msg1);

            % 5. Compare bucket-for-bucket. The set of keys must match
            %    exactly and each count must match.
            serverKeys = fieldnames(ans1.classCounts);
            localKeys  = fieldnames(localCounts);

            % Normalize server keys the same way we normalized local keys,
            % so isvarname-style rewrites (if any) don't cause a spurious
            % mismatch on exotic class names.
            serverKeysNormalized = cell(size(serverKeys));
            serverCountsNormalized = struct();
            for i = 1:numel(serverKeys)
                k = serverKeys{i};
                if ~isvarname(k)
                    kNorm = matlab.lang.makeValidName(k);
                else
                    kNorm = k;
                end
                serverKeysNormalized{i} = kNorm;
                serverCountsNormalized.(kNorm) = double(ans1.classCounts.(k));
            end

            testCase.verifyEqual(sort(serverKeysNormalized), sort(localKeys), ...
                "Set of class buckets returned by the endpoint must match the set computed from the document listing. " + msg1);

            for i = 1:numel(localKeys)
                k = localKeys{i};
                testCase.verifyTrue(isfield(serverCountsNormalized, k), ...
                    sprintf('Endpoint is missing class bucket "%s". %s', k, msg1));
                testCase.verifyEqual(serverCountsNormalized.(k), double(localCounts.(k)), ...
                    sprintf('Count mismatch for class "%s": endpoint=%d, listing=%d. %s', ...
                        k, serverCountsNormalized.(k), localCounts.(k), msg1));
            end

            testCase.Narrative = narrative;
        end
    end
end
