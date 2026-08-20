classdef TestMigrateCloud < matlab.unittest.TestCase
%TESTMIGRATECLOUD Unit tests for ndi.migrate.cloud.
%
%   Drives ndi.migrate.cloud against an in-memory FakeCloudClient that
%   implements the same interface as ndi.migrate.internal.cloudClient.
%   The tests cover the orchestration the cloud function is responsible
%   for — lock acquire/release, published-state guard and restoration,
%   listing → fetching → converting → uploading happy path, dry-run
%   suppression of the write side, idempotent re-run on already-V_delta
%   content, and quarantine surfacing.
%
%   These tests run with Validate=false so the test runner doesn't
%   need a checked-out did-schema next to it.

    methods (Test)

        function testRefreshLockCalledDuringMigration(testCase)
            % The function refreshes the lock between bulk-fetch
            % batches and once again before the final upload pass.
            bodies = {makeV1Body('alpha'), makeV1Body('beta')};
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', bodies);

            ndi.migrate.cloud("d-1", 'Validate', false, 'Client', fake);

            verifyGreaterThanOrEqual(testCase, fake.RefreshLockCalls, 1);
        end

        function testHappyPathMigratesAndReleasesLock(testCase)
            bodies = {makeV1Body('alpha'), makeV1Body('beta')};
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', bodies);

            result = ndi.migrate.cloud("d-1", ...
                'Validate', false, 'Client', fake);

            verifyEqual(testCase, result.summary.total, 2);
            verifyEqual(testCase, result.summary.migrated_count, 2);
            verifyEqual(testCase, result.summary.quarantine_count, 0);
            verifyTrue(testCase, result.lock.acquired);
            verifyTrue(testCase, result.lock.released);
            verifyFalse(testCase, result.publishState.wasPublished);
            verifyFalse(testCase, result.publishState.republished);

            verifyEqual(testCase, fake.AcquireLockCalls, 1);
            verifyEqual(testCase, fake.ReleaseLockCalls, 1);
            verifyEqual(testCase, fake.UploadCalls, 1);
            verifyEqual(testCase, fake.UnpublishCalls, 0);
            verifyEqual(testCase, fake.PublishCalls, 0);
            verifyNotEmpty(testCase, result.upload);
        end

        function testRefusesPublishedDatasetWithoutForce(testCase)
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', true), ...
                'documents', {makeV1Body('alpha')});

            verifyError(testCase, ...
                @() ndi.migrate.cloud("d-1", ...
                    'Validate', false, 'Client', fake), ...
                'NDI:migrate:cloud:publishedRefuse');

            % Refused before acquiring the lock or uploading anything.
            verifyEqual(testCase, fake.AcquireLockCalls, 0);
            verifyEqual(testCase, fake.UnpublishCalls, 0);
            verifyEqual(testCase, fake.UploadCalls, 0);
        end

        function testForceUnpublishUnpublishesAndRepublishes(testCase)
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', true), ...
                'documents', {makeV1Body('alpha')});

            result = ndi.migrate.cloud("d-1", ...
                'Validate', false, 'ForceUnpublish', true, ...
                'Client', fake);

            verifyTrue(testCase, result.publishState.wasPublished);
            verifyTrue(testCase, result.publishState.republished);
            verifyEqual(testCase, fake.UnpublishCalls, 1);
            verifyEqual(testCase, fake.PublishCalls, 1);
            verifyEqual(testCase, fake.UnpublishOrder, 1, ...
                'unpublish must happen before upload');
            verifyEqual(testCase, fake.UploadOrder, 2);
            verifyEqual(testCase, fake.PublishOrder, 3);
        end

        function testLockHeldByOtherClientRaises(testCase)
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', {makeV1Body('alpha')}, ...
                'lockHeldByOther', true);

            verifyError(testCase, ...
                @() ndi.migrate.cloud("d-1", ...
                    'Validate', false, 'Client', fake), ...
                'NDI:migrate:cloud:lockHeld');

            verifyEqual(testCase, fake.UploadCalls, 0);
            verifyEqual(testCase, fake.ReleaseLockCalls, 0);
        end

        function testDryRunSkipsWritesAndLock(testCase)
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', {makeV1Body('alpha'), makeV1Body('beta')});

            result = ndi.migrate.cloud("d-1", ...
                'Validate', false, 'DryRun', true, 'Client', fake);

            verifyTrue(testCase, result.dryRun);
            verifyFalse(testCase, result.lock.acquired);
            verifyFalse(testCase, result.lock.released);
            verifyEqual(testCase, fake.AcquireLockCalls, 0);
            verifyEqual(testCase, fake.UploadCalls, 0);
            verifyEqual(testCase, fake.UnpublishCalls, 0);
            verifyEqual(testCase, fake.PublishCalls, 0);
            % Conversion still ran so summary is honest.
            verifyEqual(testCase, result.summary.migrated_count, 2);
            verifyEmpty(testCase, result.upload);
        end

        function testIdempotentReRunOnAlreadyVDeltaContent(testCase)
            % Already-V_delta bodies short-circuit the converter and
            % the function still uploads them back (no information
            % about whether the cloud already has them — the cloud is
            % responsible for de-dup on bulk-upload).
            bodies = {makeVDeltaBody('alpha'), makeVDeltaBody('beta')};
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', bodies);

            result = ndi.migrate.cloud("d-1", ...
                'Validate', false, 'Client', fake);

            verifyEqual(testCase, result.summary.migrated_count, 2);
            verifyEqual(testCase, result.summary.quarantine_count, 0);
        end

        function testQuarantineSurfacedAndContinueOnErrorFalseRaises(testCase)
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', {makeV1Body('alpha'), 'not json {'});

            % With ContinueOnError=true (the default), the quarantine
            % is surfaced in the result and the rest of the migration
            % proceeds.
            result = ndi.migrate.cloud("d-1", ...
                'Validate', false, 'Client', fake);
            verifyEqual(testCase, result.summary.total, 2);
            verifyEqual(testCase, result.summary.migrated_count, 1);
            verifyEqual(testCase, result.summary.quarantine_count, 1);
            verifyTrue(testCase, result.lock.released);

            % With ContinueOnError=false, the function raises after
            % conversion (the lock is still released by cleanup).
            fake2 = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', {makeV1Body('alpha'), 'not json {'});
            verifyError(testCase, ...
                @() ndi.migrate.cloud("d-1", ...
                    'Validate', false, 'ContinueOnError', false, ...
                    'Client', fake2), ...
                'NDI:migrate:cloud:hadQuarantine');
            verifyEqual(testCase, fake2.ReleaseLockCalls, 1);
        end

        function testReferencesReported(testCase)
            good = makeV1Body('alpha');
            orphan = makeV1Body('beta');
            orphan.depends_on = struct( ...
                'name',  'parent_id', ...
                'value', 'deadbeefdeadbeef_0000111122223333');

            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', {good, orphan});

            result = ndi.migrate.cloud("d-1", ...
                'Validate', false, 'Client', fake);

            verifyEqual(testCase, result.summary.migrated_count, 2);
            verifyEqual(testCase, result.references.orphan_count, 1);
            verifyEqual(testCase, result.references.edges_examined, 1);
        end

        function testEmptyDatasetSkipsUpload(testCase)
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', {});

            result = ndi.migrate.cloud("d-1", ...
                'Validate', false, 'Client', fake);

            verifyEqual(testCase, result.summary.total, 0);
            verifyEqual(testCase, fake.UploadCalls, 0);
            verifyTrue(testCase, result.lock.released);
            verifyEmpty(testCase, result.upload);
        end

        function testLockReleasedOnUploadFailure(testCase)
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', {makeV1Body('alpha')}, ...
                'failUpload', true);

            verifyError(testCase, ...
                @() ndi.migrate.cloud("d-1", ...
                    'Validate', false, 'Client', fake), ...
                'FakeCloud:uploadFailed');
            verifyEqual(testCase, fake.ReleaseLockCalls, 1);
        end

        function testRepublishAttemptedOnFailureIfWasPublished(testCase)
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', true), ...
                'documents', {makeV1Body('alpha')}, ...
                'failUpload', true);

            verifyError(testCase, ...
                @() ndi.migrate.cloud("d-1", ...
                    'Validate', false, 'ForceUnpublish', true, ...
                    'Client', fake), ...
                'FakeCloud:uploadFailed');

            % unpublish ran once; cleanup re-publishes once.
            verifyEqual(testCase, fake.UnpublishCalls, 1);
            verifyEqual(testCase, fake.PublishCalls, 1);
            verifyEqual(testCase, fake.ReleaseLockCalls, 1);
        end

    end
end

% ---- helpers --------------------------------------------------------------

function body = makeV1Body(name)
body = struct();
body.document_class = struct( ...
    'class_name',    'demo_a', ...
    'class_version', '1.0.0', ...
    'superclasses',  struct( ...
        'class_name',    'base', ...
        'class_version', '1.0.0'));
body.depends_on = struct('name', {}, 'value', {});
body.base = struct( ...
    'id',         ['aabb1122ccdd3344_' pad16(name)], ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       name, ...
    'datestamp',  '2024-06-01T12:00:00.000Z');
body.demo_a = struct('marker', name);
end

function body = makeVDeltaBody(name)
body = makeV1Body(name);
body.base.schema_version = 'V_delta';
end

function s = pad16(name)
hex = lower(dec2hex(double(name)));
joined = strjoin(cellstr(hex(:)'), '');
joined = [joined repmat('0', 1, 16)];
s = joined(1:16);
end
