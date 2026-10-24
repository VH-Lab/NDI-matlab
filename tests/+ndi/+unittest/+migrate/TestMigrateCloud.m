classdef TestMigrateCloud < matlab.unittest.TestCase
%TESTMIGRATECLOUD Unit tests for ndi.migrate.cloud.
%
%   Drives ndi.migrate.cloud against an in-memory FakeCloudClient that
%   implements the same interface as ndi.migrate.internal.cloudClient.
%   ndi.migrate.cloud runs only pass 1 of the V_eta migration, so it refuses
%   to write (NDI:migrate:cloudIncomplete) unless 'DryRun' is true. These
%   tests cover that refusal (before any client call that locks, unpublishes
%   or uploads) and the DryRun report: listing -> fetching -> converting,
%   the published-state guard, idempotent re-run on already-V_eta content,
%   quarantine surfacing and the references report.
%
%   These tests run with Validate=false so the test runner doesn't
%   need a checked-out did-schema next to it.

    methods (Test)

        function testRefusesToWriteBecauseItRunsPassOneOnly(testCase)
            % Jess Haley, 2026-10-24: no upload until this runs the same
            % full pipeline as ndi.migrate.local. Refused before the
            % client is asked for anything that writes.
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', {makeV1Body('alpha'), makeV1Body('beta')});
            verifyError(testCase, ...
                @() ndi.migrate.cloud("d-1", 'Validate', false, 'Client', fake), ...
                'NDI:migrate:cloudIncomplete');
            verifyEqual(testCase, fake.AcquireLockCalls, 0);
            verifyEqual(testCase, fake.UnpublishCalls, 0);
            verifyEqual(testCase, fake.UploadCalls, 0);
            verifyEqual(testCase, fake.PublishCalls, 0);

            % ForceUnpublish on a published dataset does not get past it either
            fake2 = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', true), ...
                'documents', {makeV1Body('alpha')});
            verifyError(testCase, ...
                @() ndi.migrate.cloud("d-1", 'Validate', false, ...
                    'ForceUnpublish', true, 'Client', fake2), ...
                'NDI:migrate:cloudIncomplete');
            verifyEqual(testCase, fake2.UnpublishCalls, 0);
            verifyEqual(testCase, fake2.UploadCalls, 0);
        end

        function testRefusesPublishedDatasetWithoutForce(testCase)
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', true), ...
                'documents', {makeV1Body('alpha')});

            verifyError(testCase, ...
                @() ndi.migrate.cloud("d-1", ...
                    'Validate', false, 'DryRun', true, 'Client', fake), ...
                'NDI:migrate:cloud:publishedRefuse');

            % Refused before acquiring the lock or uploading anything.
            verifyEqual(testCase, fake.AcquireLockCalls, 0);
            verifyEqual(testCase, fake.UnpublishCalls, 0);
            verifyEqual(testCase, fake.UploadCalls, 0);
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

        function testIdempotentReRunOnAlreadyVEtaContent(testCase)
            % Bodies already at V_eta short-circuit the converter and
            % are still counted as migrated.
            bodies = {makeVEtaBody('alpha'), makeVEtaBody('beta')};
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', bodies);

            result = ndi.migrate.cloud("d-1", ...
                'Validate', false, 'DryRun', true, 'Client', fake);

            verifyEqual(testCase, result.summary.migrated_count, 2);
            verifyEqual(testCase, result.summary.quarantine_count, 0);
        end

        function testQuarantineSurfacedAndContinueOnErrorFalseRaises(testCase)
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', {makeV1Body('alpha'), 'not json {'});

            % With ContinueOnError=true (the default), the quarantine
            % is surfaced in the result and the rest of the run
            % proceeds.
            result = ndi.migrate.cloud("d-1", ...
                'Validate', false, 'DryRun', true, 'Client', fake);
            verifyEqual(testCase, result.summary.total, 2);
            verifyEqual(testCase, result.summary.migrated_count, 1);
            verifyEqual(testCase, result.summary.quarantine_count, 1);
            verifyFalse(testCase, result.lock.acquired);

            % With ContinueOnError=false, the function raises after
            % conversion.
            fake2 = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', {makeV1Body('alpha'), 'not json {'});
            verifyError(testCase, ...
                @() ndi.migrate.cloud("d-1", ...
                    'Validate', false, 'DryRun', true, 'ContinueOnError', false, ...
                    'Client', fake2), ...
                'NDI:migrate:cloud:hadQuarantine');
            verifyEqual(testCase, fake2.UploadCalls, 0);
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
                'Validate', false, 'DryRun', true, 'Client', fake);

            verifyEqual(testCase, result.summary.migrated_count, 2);
            verifyEqual(testCase, result.references.orphan_count, 1);
            verifyEqual(testCase, result.references.edges_examined, 1);
        end

        function testEmptyDatasetSkipsUpload(testCase)
            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', {});

            result = ndi.migrate.cloud("d-1", ...
                'Validate', false, 'DryRun', true, 'Client', fake);

            verifyEqual(testCase, result.summary.total, 0);
            verifyEqual(testCase, fake.UploadCalls, 0);
            verifyEmpty(testCase, result.upload);
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

function body = makeVEtaBody(name)
body = makeV1Body(name);
body.document_class.schema_version = 'V_eta';
end

function s = pad16(name)
hex = lower(dec2hex(double(name)));
joined = strjoin(cellstr(hex(:)'), '');
joined = [joined repmat('0', 1, 16)];
s = joined(1:16);
end
