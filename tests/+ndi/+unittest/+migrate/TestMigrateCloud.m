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
            % ONE DELIBERATELY DANGLING EDGE, beta's parent_id, and nothing
            % else dangles. Under V_eta `base.session_id` is the `session_id`
            % EDGE (did-schema V_eta_relation_inheritance_plan.md; DID-matlab
            % did2.convert.v1_to_v2 renameOutboundBaseFields moves it when
            % did2.schema.cache.sessionIdIsEdge() is true), so every migrated
            % document carries one, to the session. The session document is
            % therefore in the batch: migrators_j.session gives the session
            % entity the session id as its base.id (DID-matlab
            % testSessionIdEdge, "the session entity points at itself"), so
            % those edges resolve. Without it, alpha's and beta's session_id
            % edges dangled too (3 orphans of 3 edges, run 40108434320).
            testCase.assumeTrue(~isempty(which('did2.schema.cache')) && ...
                did2.schema.cache.shared().sessionIdIsEdge(), ...
                'no V_eta schema where did2.schema.cache looks (`base` declares no session_id edge)');
            sess = makeV1SessionBody();
            good = makeV1Body('alpha');
            orphan = makeV1Body('beta');
            orphan.depends_on = struct( ...
                'name',  'parent_id', ...
                'value', 'deadbeefdeadbeef_0000111122223333');

            fake = ndi.unittest.migrate.FakeCloudClient( ...
                'datasetInfo', struct('id', 'd-1', 'isPublished', false), ...
                'documents', {sess, good, orphan});

            result = ndi.migrate.cloud("d-1", ...
                'Validate', false, 'DryRun', true, 'Client', fake);

            verifyEqual(testCase, result.summary.migrated_count, 3);
            verifyEqual(testCase, result.summary.quarantine_count, 0);
            % edges: beta parent_id and the session entity's own session_id
            % (to itself) = 2; 1 dangles. alpha and beta are carried whole as
            % v1 by pass 1 (projectvar, carry-162), so each keeps v1's
            % base.session_id FIELD, not the edge ([passthrough stays v1: how])
            verifyEqual(testCase, result.references.edges_examined, 2);
            verifyEqual(testCase, result.references.orphan_count, 1);
            testCase.assertNumElements(result.references.orphans, 1);
            verifyEqual(testCase, result.references.orphans(1).edge_name, 'parent_id');
            verifyEqual(testCase, result.references.orphans(1).edge_document_id, ...
                'deadbeefdeadbeef_0000111122223333');
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
% a v1 `projectvar` as NDI's template spells it (database_documents/
% projectvar.json). It has no migrator and its route is recorded: DID-matlab
% carries it whole as v1 (did2.convert.noMigratorCarryRows, carry-162; Decided
% by Jess Haley, 2026-10-31 [classes without a migrator carry as v1]). These
% tests used `demo_a`, a class no NDI template or writer defines, which passed
% through DID-matlab's identity fallback; that fallback is deleted (DID-matlab
% #351, [early migration pieces fixed] (1)), and a class with no migrator and
% no recorded decision is quarantined (did2:convert:noMigrator).
body = struct();
body.document_class = struct( ...
    'class_name',    'projectvar', ...
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
body.projectvar = struct('project', '', 'type', '', 'user', '', 'lab', '', ...
    'description', name, 'data', '');
end

function body = makeV1SessionBody()
% A v1 `session` document as ndi.session writes it: its base.id is minted
% separately from the session id its siblings carry (ndi.document), and
% session.reference is the session's handle (required as local_identifier).
body = struct();
body.document_class = struct( ...
    'class_name',    'session', ...
    'class_version', '1.0.0', ...
    'superclasses',  struct( ...
        'class_name',    'base', ...
        'class_version', '1.0.0'));
body.depends_on = struct('name', {}, 'value', {});
body.base = struct( ...
    'id',         'aabb1122ccdd3344_5e55000000000001', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       'session', ...
    'datestamp',  '2024-06-01T12:00:00.000Z');
body.session = struct('reference', 'exp_cloud_1');
end

function body = makeVEtaBody(name)
body = makeV1Body(name);
body.document_class.schema_version = 'did_v2';
end

function s = pad16(name)
hex = lower(dec2hex(double(name)));
joined = strjoin(cellstr(hex(:)'), '');
joined = [joined repmat('0', 1, 16)];
s = joined(1:16);
end
