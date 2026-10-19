classdef feedbackTest < matlab.unittest.TestCase
% feedbackTest - Test suite for the ndi.cloud.api.feedback commands.
%
%   Exercises the client wrappers around the in-app problem report
%   endpoints (ndi-cloud-node#158):
%
%     POST   /feedback
%     DELETE /feedback/{feedbackId}
%
%   Every report a test submits is deleted again (by the test itself, or
%   by a teardown if the test fails part-way), so the suite does not
%   leave reports in the admin triage queue. Deleted reports do not count
%   against the server's limit of 10 reports per user per hour.
%
%   Each test follows the narrative + APIMessage pattern used throughout
%   ndi.unittest.cloud so a failure carries every step and the URL of the
%   last API call.
%
%   Requirements:
%     - NDI_CLOUD_USERNAME and NDI_CLOUD_PASSWORD environment variables
%     - CLOUD_API_ENVIRONMENT=dev to run against the dev API

    properties (Constant)
        AppName = "NDI-matlab-unittest";
        % Valid 24-hex id that will not match any stored report.
        NonexistentID = "000000000000000000000000";
    end

    properties
        Narrative (1,:) string
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            diagMsg = ['Missing NDI Cloud credentials (NDI_CLOUD_USERNAME/', ...
                'NDI_CLOUD_PASSWORD). Skipping cloud-dependent tests.'];
            testCase.assumeNotEmpty(username, diagMsg);
            testCase.assumeNotEmpty(password, diagMsg);
        end

        function checkEndpointDeployed(testCase)
            % The cloud suite runs against both prod and dev. Skip (rather
            % than fail) in an environment that does not have the feedback
            % endpoint yet: once deployed, a malformed id is answered 400 by
            % the route; before that, the API's catch-all answers 404.
            [~, ~, resp] = ndi.cloud.api.feedback.deleteFeedback("not-a-valid-id");
            testCase.assumeNotEqual(double(resp.StatusCode), 404, ...
                "The /feedback endpoint is not deployed in this API environment. Skipping feedbackTest.");
        end
    end

    methods (TestMethodSetup)
        function resetNarrative(testCase)
            testCase.Narrative = "Begin feedbackTest";
        end
    end

    methods (Access = private)
        function registerCleanup(testCase, feedbackID)
            % Delete the report at teardown if the test did not get to it.
            % deleteFeedback returning 404 here just means it is already gone.
            arguments
                testCase (1,1) ndi.unittest.cloud.feedbackTest
                feedbackID {mustBeText}
            end
            testCase.addTeardown(@() ndi.cloud.api.feedback.deleteFeedback(feedbackID));
        end
    end

    methods (Test)
        % ------------------------------------------------------------------
        % Happy path: submit a minimal report, delete it, and confirm a
        % second delete reports 404.
        function testSubmitAndDelete(testCase)
            narrative = testCase.Narrative;

            narrative(end+1) = "Preparing to call submitFeedback with only the required fields.";
            [b, feedbackID, resp, url] = ndi.cloud.api.feedback.submitFeedback( ...
                testCase.AppName, "other", "feedbackTest: minimal report (safe to ignore)");
            narrative(end+1) = "Attempted to call API with URL " + string(url);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, feedbackID, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 201, msg);
            testCase.verifyClass(feedbackID, 'char', msg);
            testCase.verifyNotEmpty(feedbackID, msg);
            testCase.registerCleanup(feedbackID);
            narrative(end+1) = "Report stored with id " + string(feedbackID);

            narrative(end+1) = "Preparing to call deleteFeedback on the new report.";
            [b_del, ans_del, resp_del, url_del] = ndi.cloud.api.feedback.deleteFeedback(feedbackID);
            msg_del = ndi.unittest.cloud.APIMessage(narrative, b_del, ans_del, resp_del, url_del);
            testCase.verifyTrue(b_del, msg_del);
            testCase.verifyEqual(double(resp_del.StatusCode), 204, msg_del);

            narrative(end+1) = "Deleting the same report again; expecting 404.";
            [b_again, ans_again, resp_again, url_again] = ndi.cloud.api.feedback.deleteFeedback(feedbackID);
            msg_again = ndi.unittest.cloud.APIMessage(narrative, b_again, ans_again, resp_again, url_again);
            testCase.verifyFalse(b_again, msg_again);
            testCase.verifyEqual(double(resp_again.StatusCode), 404, msg_again);
        end

        % ------------------------------------------------------------------
        % Every optional field, including a log that carries credentials the
        % server is expected to redact. (The reporter cannot read reports
        % back, so redaction itself is checked in the server's own tests.)
        function testSubmitFullReport(testCase)
            narrative = testCase.Narrative;

            environment = struct('os', string(computer()), ...
                'matlab', string(version()), 'launchedFrom', "matlab");
            state = struct('level', 3, 'fetchStats', struct('ok', 10, 'failed', 2));
            fakeToken = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1bml0dGVzdCJ9.c2lnbmF0dXJlX3VuaXR0ZXN0";
            logText = "[lightsheet] GET https://bucket.s3.amazonaws.com/k?X-Amz-Signature=deadbeef01" ...
                + newline + "Authorization: Bearer " + fakeToken;

            narrative(end+1) = "Preparing to call submitFeedback with all optional fields.";
            [b, feedbackID, resp, url] = ndi.cloud.api.feedback.submitFeedback( ...
                testCase.AppName, "bug", "feedbackTest: full report (safe to ignore)", ...
                'appVersion', "NDI-matlab unittest", ...
                'datasetId', testCase.NonexistentID, ...
                'documentId', "unittest-document", ...
                'environment', environment, ...
                'state', state, ...
                'log', logText, ...
                'traceback', "feedbackTest: no real traceback");
            narrative(end+1) = "Attempted to call API with URL " + string(url);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, feedbackID, resp, url);
            testCase.assertTrue(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 201, msg);
            testCase.registerCleanup(feedbackID);

            narrative(end+1) = "Deleting report " + string(feedbackID);
            [b_del, ans_del, resp_del, url_del] = ndi.cloud.api.feedback.deleteFeedback(feedbackID);
            msg_del = ndi.unittest.cloud.APIMessage(narrative, b_del, ans_del, resp_del, url_del);
            testCase.verifyTrue(b_del, msg_del);
        end

        % ------------------------------------------------------------------
        % Server-side validation (400), sent through the implementation
        % class so the wrapper's own argument validation does not stop it.
        function testInvalidCategoryIsRejected(testCase)
            narrative = testCase.Narrative;
            body = struct('schemaVersion', 1, 'app', testCase.AppName, ...
                'category', "feature", 'description', "feedbackTest: invalid category");

            narrative(end+1) = "Submitting a report with category 'feature'; expecting 400.";
            call = ndi.cloud.api.implementation.feedback.SubmitFeedback('feedbackStruct', body);
            [b, answer, resp, url] = call.execute();
            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
            if b
                testCase.registerCleanup(answer);
            end
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 400, msg);
        end

        function testMissingDescriptionIsRejected(testCase)
            narrative = testCase.Narrative;
            body = struct('schemaVersion', 1, 'app', testCase.AppName, 'category', "bug");

            narrative(end+1) = "Submitting a report without a description; expecting 400.";
            call = ndi.cloud.api.implementation.feedback.SubmitFeedback('feedbackStruct', body);
            [b, answer, resp, url] = call.execute();
            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
            if b
                testCase.registerCleanup(answer);
            end
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 400, msg);
        end

        function testUnsupportedSchemaVersionIsRejected(testCase)
            narrative = testCase.Narrative;
            body = struct('schemaVersion', 99, 'app', testCase.AppName, ...
                'category', "bug", 'description', "feedbackTest: bad schemaVersion");

            narrative(end+1) = "Submitting a report with schemaVersion 99; expecting 400.";
            call = ndi.cloud.api.implementation.feedback.SubmitFeedback('feedbackStruct', body);
            [b, answer, resp, url] = call.execute();
            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
            if b
                testCase.registerCleanup(answer);
            end
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 400, msg);
        end

        % ------------------------------------------------------------------
        % Size cap (413): a log over the 500,000-character field cap but
        % under the 1 MB request cap.
        function testOversizeLogIsRejected(testCase)
            narrative = testCase.Narrative;

            narrative(end+1) = "Submitting a report with a 600,000-character log; expecting 413.";
            [b, feedbackID, resp, url] = ndi.cloud.api.feedback.submitFeedback( ...
                testCase.AppName, "performance", "feedbackTest: oversize log", ...
                'log', string(repmat('x', 1, 600000)));
            msg = ndi.unittest.cloud.APIMessage(narrative, b, feedbackID, resp, url);
            if b
                testCase.registerCleanup(feedbackID);
            end
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 413, msg);
        end

        % ------------------------------------------------------------------
        % Requests without a token are refused. The API answers missing or
        % invalid tokens with 403 throughout; 401 is accepted too.
        function testUnauthenticatedSubmitIsRejected(testCase)
            narrative = testCase.Narrative;
            body = struct('schemaVersion', 1, 'app', testCase.AppName, ...
                'category', "bug", 'description', "feedbackTest: no token");

            narrative(end+1) = "POSTing a report with no Authorization header; expecting 401/403.";
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            acceptField = matlab.net.http.HeaderField('accept', 'application/json');
            request = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.POST, ...
                [acceptField contentTypeField], matlab.net.http.MessageBody(body));
            url = ndi.cloud.api.url("submit_feedback");
            resp = request.send(url);
            msg = ndi.unittest.cloud.APIMessage(narrative, false, [], resp, url);
            testCase.verifyTrue(ismember(double(resp.StatusCode), [401 403]), msg);
        end

        % ------------------------------------------------------------------
        % Delete edge cases.
        function testDeleteNonexistentReport(testCase)
            narrative = testCase.Narrative;

            narrative(end+1) = "Deleting a well-formed id that matches no report; expecting 404.";
            [b, answer, resp, url] = ndi.cloud.api.feedback.deleteFeedback(testCase.NonexistentID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 404, msg);
        end

        function testDeleteMalformedID(testCase)
            narrative = testCase.Narrative;

            narrative(end+1) = "Deleting a malformed id; expecting 400.";
            [b, answer, resp, url] = ndi.cloud.api.feedback.deleteFeedback("not-a-valid-id");
            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
            testCase.verifyFalse(b, msg);
            testCase.verifyEqual(double(resp.StatusCode), 400, msg);
        end

        % ------------------------------------------------------------------
        % Client-side validation in the wrapper (no network call).
        function testWrapperRejectsUnknownCategory(testCase)
            testCase.verifyError(@() ndi.cloud.api.feedback.submitFeedback( ...
                testCase.AppName, "feature", "never sent"), ...
                'MATLAB:validators:mustBeMember');
        end

        function testWrapperRejectsEmptyDescription(testCase)
            testCase.verifyError(@() ndi.cloud.api.feedback.submitFeedback( ...
                testCase.AppName, "bug", ""), ...
                'MATLAB:validators:mustBeNonzeroLengthText');
        end
    end
end
