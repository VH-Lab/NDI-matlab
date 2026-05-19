classdef TestApplyReadNormalization < matlab.unittest.TestCase
%TESTAPPLYREADNORMALIZATION Unit tests for the v1->V_delta read-time
%   normaliser that concrete ndi.database subclasses call from do_read
%   and do_search.
%
%   The normaliser is gated by the env var NDI_DID2_NORMALIZE_ON_READ
%   (OFF by default; see applyReadNormalization.m). Every test below
%   manages that env var explicitly via TestMethodSetup /
%   TestMethodTeardown so the gate state never leaks between tests.
%
%   The active-gate tests use the same v1 body shape as the synthetic-
%   corpus tests under +ndi/+unittest/+migrate, so an upstream change
%   in did2.convert.v1_to_v2 surfaces here too.

    properties (Access = private)
        SavedGate
    end

    methods (TestMethodSetup)
        function captureGate(testCase)
            testCase.SavedGate = getenv('NDI_DID2_NORMALIZE_ON_READ');
            % Default each test to the OFF gate; tests that need the
            % converter wired up flip it on explicitly.
            setenv('NDI_DID2_NORMALIZE_ON_READ', '');
        end
    end

    methods (TestMethodTeardown)
        function restoreGate(testCase)
            setenv('NDI_DID2_NORMALIZE_ON_READ', testCase.SavedGate);
        end
    end

    methods (Test)

        function testEmptyReturnsEmpty(testCase)
            verifyEmpty(testCase, ...
                ndi.database.internal.applyReadNormalization([]));
            verifyEmpty(testCase, ...
                ndi.database.internal.applyReadNormalization(struct([])));
        end

        function testGateOffWrapsBodyUnchanged(testCase)
            % With the gate OFF the v1 field names must survive
            % verbatim so callers above the database layer (e.g.,
            % ndi.database.fun.ndi_document2ndi_object,
            % ndi.daq.metadatareader) still find them. This is the
            % dormant-PR state pending issue 1 / #779.
            v1 = makeV1Body('alpha');
            doc = ndi.database.internal.applyReadNormalization(v1);

            verifyClass(testCase, doc, 'ndi.document');
            % document_class.class_name is not snake-cased while the
            % gate is OFF.
            verifyEqual(testCase, ...
                char(doc.document_properties.document_class.class_name), ...
                'demo_a');
            % The original v1 demo_a block is preserved as-is.
            verifyTrue(testCase, isfield(doc.document_properties, 'demo_a'));
            verifyEqual(testCase, ...
                char(doc.document_properties.demo_a.marker), 'alpha');
            % universalRenames is NOT applied, so base.schema_version
            % was not stamped by the converter.
            verifyFalse(testCase, isfield( ...
                doc.document_properties.base, 'schema_version'));
        end

        function testGateOnConvertsV1StructToVDelta(testCase)
            setenv('NDI_DID2_NORMALIZE_ON_READ', '1');
            v1 = makeV1Body('alpha');
            doc = ndi.database.internal.applyReadNormalization(v1);

            verifyClass(testCase, doc, 'ndi.document');
            % After v1->V_delta normalisation universalRenames stamps
            % base.schema_version to 'V_delta'.
            verifyTrue(testCase, isfield(doc.document_properties, 'base'));
            verifyTrue(testCase, isfield(doc.document_properties.base, ...
                'schema_version'));
            verifyEqual(testCase, ...
                char(doc.document_properties.base.schema_version), ...
                'V_delta');
            verifyEqual(testCase, ...
                char(doc.document_properties.document_class.class_name), ...
                'demo_a');
        end

        function testGateOnVDeltaBodyShortCircuits(testCase)
            setenv('NDI_DID2_NORMALIZE_ON_READ', '1');
            % An already-V_delta body should round-trip with no shape
            % drift (the converter's idempotency check fires).
            v1 = makeV1Body('beta');
            firstPass = ndi.database.internal.applyReadNormalization(v1);
            secondPass = ndi.database.internal.applyReadNormalization( ...
                firstPass.document_properties);

            verifyEqual(testCase, ...
                secondPass.document_properties.base.name, ...
                firstPass.document_properties.base.name);
            verifyEqual(testCase, ...
                char(secondPass.document_properties.base.schema_version), ...
                'V_delta');
        end

        function testNdiDocumentPassThrough(testCase)
            % An ndi.document already lives at the abstraction layer
            % the helper is normalising into, so it is returned
            % verbatim regardless of gate state.
            v1 = makeV1Body('gamma');
            wrapped = ndi.document(v1);
            doc = ndi.database.internal.applyReadNormalization(wrapped);
            verifyClass(testCase, doc, 'ndi.document');
            verifyEqual(testCase, doc.document_properties, ...
                wrapped.document_properties);
        end

        function testGateOnAcceptsDid2Document(testCase)
            setenv('NDI_DID2_NORMALIZE_ON_READ', '1');
            v1 = makeV1Body('delta');
            d2 = did2.document(v1);
            doc = ndi.database.internal.applyReadNormalization(d2);
            verifyClass(testCase, doc, 'ndi.document');
        end

        function testBadInputErrors(testCase)
            verifyError(testCase, ...
                @() ndi.database.internal.applyReadNormalization(42), ...
                'NDI:database:normalizeBadInput');
            verifyError(testCase, ...
                @() ndi.database.internal.applyReadNormalization("not a body"), ...
                'NDI:database:normalizeBadInput');
        end

        function testGateTruthyValues(testCase)
            % '1', 'true', 'yes', 'on' (any case, with whitespace) all
            % count as ON. Anything else is OFF.
            v1 = makeV1Body('eta');
            truthy = {'1', 'true', 'TRUE', 'yes', 'YES', 'on', '  1  '};
            for k = 1:numel(truthy)
                setenv('NDI_DID2_NORMALIZE_ON_READ', truthy{k});
                doc = ndi.database.internal.applyReadNormalization(v1);
                verifyEqual(testCase, ...
                    char(doc.document_properties.base.schema_version), ...
                    'V_delta', ...
                    sprintf('Truthy gate value "%s" did not activate normalisation.', ...
                        truthy{k}));
            end

            falsy = {'0', 'false', 'no', 'off', ''};
            for k = 1:numel(falsy)
                setenv('NDI_DID2_NORMALIZE_ON_READ', falsy{k});
                doc = ndi.database.internal.applyReadNormalization(v1);
                verifyFalse(testCase, isfield( ...
                    doc.document_properties.base, 'schema_version'), ...
                    sprintf('Falsy gate value "%s" unexpectedly activated normalisation.', ...
                        falsy{k}));
            end
        end

    end
end

% ---- helpers -------------------------------------------------------------

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

function s = pad16(name)
hex = lower(dec2hex(double(name)));
joined = strjoin(cellstr(hex(:)'), '');
joined = [joined repmat('0', 1, 16)];
s = joined(1:16);
end
