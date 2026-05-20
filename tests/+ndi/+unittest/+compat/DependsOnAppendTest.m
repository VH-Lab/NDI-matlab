classdef DependsOnAppendTest < matlab.unittest.TestCase
%DEPENDSONAPPENDTEST Unit tests for ndi.compat.dependsOnAppend.
%
%   Covers the field-schema-misalignment cases that the direct
%   `depends_on(end+1) = entry` pattern in ndi.document used to hit
%   when ndi.compat.augmentRead had added the legacy `id` alias to
%   existing entries.

    methods (Test)

        function test_append_to_plain_array(testCase)
            deps = struct('name', {'a'}, 'value', {'v1'});
            entry = struct('name', 'b', 'value', 'v2');
            out = ndi.compat.dependsOnAppend(deps, entry);
            testCase.verifyEqual(numel(out), 2);
            testCase.verifyEqual(out(2).name, 'b');
            testCase.verifyEqual(out(2).value, 'v2');
        end

        function test_append_to_augmented_array(testCase)
            % Existing array has the legacy `id` field; the new entry
            % does not. Direct assignment would throw
            % "heterogeneousStrucAssignment"; the helper must accept it.
            deps = struct( ...
                'name',  {'a'}, ...
                'value', {'v1'}, ...
                'id',    {'v1'});
            entry = struct('name', 'b', 'value', 'v2');
            out = ndi.compat.dependsOnAppend(deps, entry);
            testCase.verifyEqual(numel(out), 2);
            testCase.verifyEqual(out(2).name, 'b');
            testCase.verifyEqual(out(2).value, 'v2');
            % Legacy alias mirrored on the new entry.
            testCase.verifyEqual(out(2).id, 'v2');
        end

        function test_append_with_entry_carrying_extra_fields(testCase)
            % If the new entry carries fields the existing array does
            % not, the array auto-extends and existing entries get []
            % for the new fields.
            deps = struct('name', {'a'}, 'value', {'v1'});
            entry = struct('name', 'b', 'value', 'v2', 'extra', 'X');
            out = ndi.compat.dependsOnAppend(deps, entry);
            testCase.verifyEqual(numel(out), 2);
            testCase.verifyTrue(isfield(out, 'extra'));
            testCase.verifyEqual(out(2).extra, 'X');
            testCase.verifyEmpty(out(1).extra);
        end

        function test_append_to_empty_struct_array(testCase)
            deps = struct('name', {}, 'value', {});
            entry = struct('name', 'a', 'value', 'v1');
            out = ndi.compat.dependsOnAppend(deps, entry);
            testCase.verifyEqual(numel(out), 1);
            testCase.verifyEqual(out(1).name, 'a');
            testCase.verifyEqual(out(1).value, 'v1');
        end

        function test_append_to_uninitialised_deps(testCase)
            % Some code paths pass [] for "no depends_on yet". The
            % legacy id alias must be mirrored on the fresh entry so
            % the resulting array satisfies the read-time augmentation
            % contract.
            entry = struct('name', 'a', 'value', 'v1');
            out = ndi.compat.dependsOnAppend([], entry);
            testCase.verifyEqual(numel(out), 1);
            testCase.verifyEqual(out(1).name, 'a');
            testCase.verifyEqual(out(1).value, 'v1');
            testCase.verifyEqual(out(1).id, 'v1');
        end

        function test_set_dependency_value_appends_after_augmentation(testCase)
            % Acceptance: regression case from PR #799 CI failure.
            % A body whose depends_on was augmented (has `id` field)
            % must accept new entries via set_dependency_value without
            % heterogeneousStrucAssignment.
            body = i_baseBody('demo_a');
            body.depends_on = struct( ...
                'name',  {'first'}, ...
                'value', {'aabb1122ccdd3344_0011223344556677'});
            doc = ndi.document(body);
            % Post-constructor: depends_on has {name, value, id}.
            testCase.verifyTrue( ...
                isfield(doc.document_properties.depends_on, 'id'));
            % Add a new dependency. With the pre-fix code path this
            % errored at line 733 of ndi.document.
            doc = doc.set_dependency_value('second', ...
                'ccdd3344aabb1122_0011223344556677', ...
                'ErrorIfNotFound', 0);
            deps = doc.document_properties.depends_on;
            testCase.verifyEqual(numel(deps), 2);
            testCase.verifyEqual(deps(2).name, 'second');
            testCase.verifyEqual(deps(2).value, ...
                'ccdd3344aabb1122_0011223344556677');
            % And the legacy id alias mirrors the new value.
            testCase.verifyEqual(deps(2).id, ...
                'ccdd3344aabb1122_0011223344556677');
        end

        function test_set_dependency_value_replace_remirrors_id(testCase)
            % When set_dependency_value replaces an existing entry's
            % value, the legacy id alias must follow.
            body = i_baseBody('demo_a');
            body.depends_on = struct( ...
                'name',  {'first'}, ...
                'value', {'aabb1122ccdd3344_0011223344556677'});
            doc = ndi.document(body);
            newId = 'ffff2222ffff2222_0011223344556677';
            doc = doc.set_dependency_value('first', newId);
            deps = doc.document_properties.depends_on;
            testCase.verifyEqual(deps(1).value, newId);
            testCase.verifyEqual(deps(1).id, newId);
        end

        function test_add_dependency_value_n_after_augmentation(testCase)
            % add_dependency_value_n routes through set_dependency_value
            % with ErrorIfNotFound=0, hitting the append branch.
            body = i_baseBody('demo_a');
            body.depends_on = struct( ...
                'name',  {'related_1'}, ...
                'value', {'aabb1122ccdd3344_0011223344556677'});
            doc = ndi.document(body);
            doc = doc.add_dependency_value_n('related', ...
                'ccdd3344aabb1122_0011223344556677', ...
                'ErrorIfNotFound', 0);
            deps = doc.document_properties.depends_on;
            testCase.verifyEqual(numel(deps), 2);
            testCase.verifyEqual(deps(2).name, 'related_2');
            testCase.verifyEqual(deps(2).value, ...
                'ccdd3344aabb1122_0011223344556677');
            testCase.verifyEqual(deps(2).id, ...
                'ccdd3344aabb1122_0011223344556677');
        end
    end
end

function body = i_baseBody(className)
body = struct();
body.document_class = struct( ...
    'class_name',    className, ...
    'class_version', '2.0.0', ...
    'superclasses',  struct( ...
        'class_name',    'base', ...
        'class_version', '2.0.0'));
body.base = struct( ...
    'id',         'aabb1122ccdd3344_1234567890abcdef', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       className, ...
    'datestamp',  '2026-05-20T12:00:00.000Z');
end
