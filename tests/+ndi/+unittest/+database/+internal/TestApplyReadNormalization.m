classdef TestApplyReadNormalization < matlab.unittest.TestCase
%TESTAPPLYREADNORMALIZATION Unit tests for the read-time wrapper that
%   concrete ndi.database subclasses call from do_read and do_search.
%
%   Since 2026-10-23 (Jess Haley: "there should be no mention of V_delta")
%   the read path converts nothing: a v1 body is read exactly as stored
%   (beyond what ndi.document's own constructor does to every body), and a
%   V_eta body is read as V_eta. The tests that asserted the removed
%   v1 -> V_delta read-time conversion (schema_version stamped 'V_delta',
%   the converter's idempotency short-circuit) were replaced by these.

    methods (Test)

        function testEmptyReturnsEmpty(testCase)
            verifyEmpty(testCase, ...
                ndi.database.internal.applyReadNormalization([]));
            verifyEmpty(testCase, ...
                ndi.database.internal.applyReadNormalization(struct([])));
        end

        function testAV1BodyIsReadExactlyAsStored(testCase)
            % Every field the removed read-time conversion used to rewrite
            % is present: no schema_version stamp, `app.name` /
            % `app.version` (not app_name / app_version), `base.datestamp`,
            % and a v1 superclass block (`epochclocktimes.clocktype` /
            % `t0_t1`) that a base migrator used to reshape.
            v1 = makeV1Body('alpha');
            v1.app = struct('name', 'ndi_app_example', 'version', '1.2.3');
            v1.epochclocktimes = struct('clocktype', 'dev_local_time', ...
                't0_t1', [0 28.5]);
            doc = ndi.database.internal.applyReadNormalization(v1);

            verifyClass(testCase, doc, 'ndi.document');
            p = doc.document_properties;
            verifyFalse(testCase, isfield(p.document_class, 'schema_version'), ...
                'a v1 body was stamped with a schema version on read');
            verifyEqual(testCase, char(p.document_class.class_name), 'demo_a');
            verifyEqual(testCase, p.app.name, 'ndi_app_example');
            verifyEqual(testCase, p.app.version, '1.2.3');
            verifyFalse(testCase, isfield(p.app, 'app_name'));
            verifyEqual(testCase, p.base.datestamp, '2024-06-01T12:00:00.000Z');
            verifyEqual(testCase, p.epochclocktimes.clocktype, 'dev_local_time');
            verifyEqual(testCase, p.epochclocktimes.t0_t1, [0 28.5]);
            % ...and nothing beyond what wrapping the stored body gives
            verifyEqual(testCase, p, ndi.document(v1).document_properties);
        end

        function testAV1BodyIsTheSameReadTwice(testCase)
            v1 = makeV1Body('beta');
            firstPass = ndi.database.internal.applyReadNormalization(v1);
            secondPass = ndi.database.internal.applyReadNormalization( ...
                firstPass.document_properties);
            verifyEqual(testCase, secondPass.document_properties, ...
                firstPass.document_properties);
        end

        function testAVEtaBodyIsReadAsVEta(testCase)
            % A V_eta body keeps its stamp and its fields; it is not pushed
            % through any migrator.
            b = makeV1Body('eta');
            b.document_class.schema_version = 'V_eta';
            b.base = rmfield(b.base, 'datestamp');
            b.base.creation_timestamp = '2024-06-01T12:00:00.000Z';
            doc = ndi.database.internal.applyReadNormalization(b);
            p = doc.document_properties;
            verifyEqual(testCase, char(p.document_class.schema_version), 'V_eta');
            verifyEqual(testCase, p.base.creation_timestamp, '2024-06-01T12:00:00.000Z');
            verifyFalse(testCase, isfield(p.base, 'datestamp'));
            verifyEqual(testCase, p.demo_a.marker, 'eta');
        end

        function testLegacyCamelCaseClassNamePreserved(testCase)
            % NDI's on-disk schemas (e.g. demoNDI) spell their classnames
            % in camelCase, and the v1 validator compares class_name
            % strings exactly. The read path must not touch identifiers.
            v1 = makeV1Body('alpha');
            v1.document_class.class_name = 'demoNDI';
            v1 = rmfield(v1, 'demo_a');
            v1.demoNDI = struct('value', 5);

            doc = ndi.database.internal.applyReadNormalization(v1);

            verifyEqual(testCase, ...
                char(doc.document_properties.document_class.class_name), ...
                'demoNDI');
            verifyTrue(testCase, isfield(doc.document_properties, 'demoNDI'));
            verifyFalse(testCase, isfield(doc.document_properties, 'demo_ndi'));
            verifyFalse(testCase, isfield( ...
                doc.document_properties.document_class, 'schema_version'));
        end

        function testNdiDocumentPassThrough(testCase)
            % An ndi.document already lives at the abstraction layer
            % the helper is normalising into, so it is returned
            % verbatim.
            v1 = makeV1Body('gamma');
            wrapped = ndi.document(v1);
            doc = ndi.database.internal.applyReadNormalization(wrapped);
            verifyClass(testCase, doc, 'ndi.document');
            verifyEqual(testCase, doc.document_properties, ...
                wrapped.document_properties);
        end

        function testAcceptsDid2Document(testCase)
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
