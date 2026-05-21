classdef NormalizeDependsOnTest < matlab.unittest.TestCase
%NORMALIZEDEPENDSONTEST Unit tests for ndi.compat.normalizeDependsOn.
%
%   Covers the constructor-time normalisation that canonicalises
%   depends_on entry keys to V_delta `document_id`, accepting v1
%   `id` and the earlier V_delta-draft `value` as synonyms.

    methods (Test)

        function test_id_rewritten_to_document_id(testCase)
            body = i_body();
            body.depends_on = struct( ...
                'name', {'parent'}, ...
                'id',   {'aabb1122ccdd3344_0011223344556677'});
            out = ndi.compat.normalizeDependsOn(body);
            testCase.verifyTrue(isfield(out.depends_on, 'document_id'));
            testCase.verifyFalse(isfield(out.depends_on, 'id'));
            testCase.verifyEqual(out.depends_on(1).document_id, ...
                'aabb1122ccdd3344_0011223344556677');
        end

        function test_value_rewritten_to_document_id(testCase)
            body = i_body();
            body.depends_on = struct( ...
                'name',  {'parent'}, ...
                'value', {'aabb1122ccdd3344_0011223344556677'});
            out = ndi.compat.normalizeDependsOn(body);
            testCase.verifyTrue(isfield(out.depends_on, 'document_id'));
            testCase.verifyFalse(isfield(out.depends_on, 'value'));
            testCase.verifyEqual(out.depends_on(1).document_id, ...
                'aabb1122ccdd3344_0011223344556677');
        end

        function test_document_id_passes_through(testCase)
            body = i_body();
            body.depends_on = struct( ...
                'name',        {'parent'}, ...
                'document_id', {'aabb1122ccdd3344_0011223344556677'});
            out = ndi.compat.normalizeDependsOn(body);
            testCase.verifyEqual(out.depends_on, body.depends_on);
        end

        function test_precedence_document_id_over_value_over_id(testCase)
            % All three keys populated: document_id wins.
            body = i_body();
            body.depends_on = struct( ...
                'name',        {'parent'}, ...
                'id',          {'id-from-v1'}, ...
                'value',       {'value-from-draft'}, ...
                'document_id', {'document_id-canonical'});
            out = ndi.compat.normalizeDependsOn(body);
            testCase.verifyEqual(out.depends_on(1).document_id, ...
                'document_id-canonical');
            testCase.verifyFalse(isfield(out.depends_on, 'value'));
            testCase.verifyFalse(isfield(out.depends_on, 'id'));
        end

        function test_precedence_value_over_id_when_no_document_id(testCase)
            body = i_body();
            body.depends_on = struct( ...
                'name',  {'parent'}, ...
                'id',    {'id-from-v1'}, ...
                'value', {'value-from-draft'});
            out = ndi.compat.normalizeDependsOn(body);
            testCase.verifyEqual(out.depends_on(1).document_id, ...
                'value-from-draft');
        end

        function test_empty_document_id_falls_back(testCase)
            % document_id present but empty falls back to value, then
            % to id. Avoids the foot-gun of an upstream that
            % auto-extended a struct array with empty `document_id` on
            % entries.
            body = i_body();
            body.depends_on = struct( ...
                'name',        {'parent'}, ...
                'id',          {'id-from-v1'}, ...
                'document_id', {''});
            out = ndi.compat.normalizeDependsOn(body);
            testCase.verifyEqual(out.depends_on(1).document_id, ...
                'id-from-v1');
        end

        function test_empty_depends_on_array_canonicalises_schema(testCase)
            body = i_body();
            body.depends_on = struct('name', {}, 'value', {});
            out = ndi.compat.normalizeDependsOn(body);
            testCase.verifyEqual(numel(out.depends_on), 0);
            testCase.verifyTrue(isfield(out.depends_on, 'document_id'));
            testCase.verifyFalse(isfield(out.depends_on, 'value'));
        end

        function test_missing_depends_on_field_unchanged(testCase)
            body = i_body();
            out = ndi.compat.normalizeDependsOn(body);
            testCase.verifyFalse(isfield(out, 'depends_on'));
        end

        function test_idempotent(testCase)
            body = i_body();
            body.depends_on = struct( ...
                'name', {'parent'}, ...
                'id',   {'aabb1122ccdd3344_0011223344556677'});
            once  = ndi.compat.normalizeDependsOn(body);
            twice = ndi.compat.normalizeDependsOn(once);
            testCase.verifyEqual(twice, once);
        end

        function test_multi_entry_struct_array(testCase)
            body = i_body();
            body.depends_on = struct( ...
                'name', {'parent', 'sibling'}, ...
                'id',   {'aabb1122ccdd3344_0011223344556677', ...
                         'aabb1122ccdd3344_8899aabbccddeeff'});
            out = ndi.compat.normalizeDependsOn(body);
            testCase.verifyEqual(numel(out.depends_on), 2);
            testCase.verifyEqual(out.depends_on(1).document_id, ...
                'aabb1122ccdd3344_0011223344556677');
            testCase.verifyEqual(out.depends_on(2).document_id, ...
                'aabb1122ccdd3344_8899aabbccddeeff');
        end

        function test_ndi_document_constructor_normalises(testCase)
            % Acceptance: ndi.document constructor invokes
            % normalizeDependsOn so the body's depends_on uses
            % document_id by the time anyone reads it.
            body = i_body();
            body.depends_on = struct( ...
                'name', {'parent'}, ...
                'id',   {'aabb1122ccdd3344_0011223344556677'});
            doc = ndi.document(body);
            testCase.verifyTrue(isfield( ...
                doc.document_properties.depends_on, 'document_id'));
            testCase.verifyFalse(isfield( ...
                doc.document_properties.depends_on, 'id'));
        end
    end
end

function body = i_body()
body = struct();
body.document_class = struct( ...
    'class_name',    'demo_a', ...
    'class_version', '2.0.0', ...
    'superclasses',  struct( ...
        'class_name',    'base', ...
        'class_version', '2.0.0'));
body.base = struct( ...
    'id',         'aabb1122ccdd3344_1234567890abcdef', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       'demo_a', ...
    'datestamp',  '2026-05-20T12:00:00.000Z');
end
