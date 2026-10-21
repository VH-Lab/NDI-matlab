classdef TestEntityTypesFor < matlab.unittest.TestCase
%TESTENTITYTYPESFOR The entity types come from the schema's registry, with one fallback.
%
%   ndi.v2.entityTypesFor reads binding_registry_meta.json's
%   `entity_type_bindings` (did-schema #88 lists 19 types and retires
%   web_resource); a registry without the list falls back to the types NDI
%   hard-coded. ndi.setup.V2.schemaHasField asks the same function which
%   class names live in entity.json, so the two cannot disagree.
%
%   Each test writes a scratch schema folder, so neither CI leg filters it.
%
%   UNVERIFIED: written without MATLAB; CI is the first run.

    properties
        Dir
    end

    methods (TestMethodSetup)
        function scratch(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
            prev = getenv('DID_SCHEMA_PATH');
            testCase.addTeardown(@() setenv('DID_SCHEMA_PATH', prev));
        end
    end

    methods (Test)
        function testTheRegistryGivesTheTypes(testCase)
            p = schemaFolder(testCase, {'organism', 'culture', 'tissue', 'cell', 'group', ...
                'device', 'material', 'strain', 'product', 'software', 'person', ...
                'organization', 'funding', 'dataset', 'study', 'publication', ...
                'protocol', 'session', 'epoch'});
            testCase.verifyEqual(ndi.v2.entityTypesFor('subject', p), ...
                {'organism', 'culture', 'tissue', 'cell', 'group', 'device', 'material'});
            testCase.verifyEqual(ndi.v2.entityTypesFor('protocol', p), {'protocol'});
            testCase.verifyEqual(ndi.v2.entityTypesFor('session', p), {'session'});
            testCase.verifyEmpty(ndi.v2.entityTypesFor('web_resource', p), ...
                'a type the registry does not list is not an entity type');
            testCase.verifyEmpty(ndi.v2.entityTypesFor('organism', p), ...
                'a type is not a pre-2026-10-08 class name');
        end

        function testANewPhysicalKindIsASubjectType(testCase)
            p = schemaFolder(testCase, {'organism', 'colony', 'strain', 'session'});
            testCase.verifyEqual(ndi.v2.entityTypesFor('subject', p), {'organism', 'colony'});
        end

        function testWithoutTheListTheFallbackHolds(testCase)
            p = schemaFolder(testCase, []);
            testCase.verifyEqual(ndi.v2.entityTypesFor('subject', p), ...
                {'organism', 'culture', 'tissue', 'cell', 'group', 'device', 'material'});
            for c = {'strain', 'web_resource', 'protocol', 'session', 'epoch'}
                testCase.verifyEqual(ndi.v2.entityTypesFor(c{1}, p), c, c{1});
            end
            testCase.verifyEmpty(ndi.v2.entityTypesFor('statement', p));
        end

        function testSchemaHasFieldAsksTheSameList(testCase)
            % entity.json holds the identity fields of every merged class
            for registered = {[], {'organism', 'protocol', 'session'}}
                p = schemaFolder(testCase, registered{1});
                fid = fopen(fullfile(p, 'entity.json'), 'w');
                fwrite(fid, jsonencode(struct('classname', 'entity', ...
                    'fields', {{struct('name', 'name'), struct('name', 'type')}})));
                fclose(fid);
                setenv('DID_SCHEMA_PATH', p);
                for c = {'protocol', 'session', 'subject'}
                    testCase.verifyEqual(ndi.setup.V2.schemaHasField(c{1}, 'name'), ...
                        ~isempty(ndi.v2.entityTypesFor(c{1}, p)), c{1});
                end
                testCase.verifyTrue(ndi.setup.V2.schemaHasField('protocol', 'name'), ...
                    'protocol is an entity type in both lists');
            end
        end
    end
end

function p = schemaFolder(testCase, types)
% a scratch schema folder whose registry lists TYPES as entity_type_bindings
% ([] for a registry with no such list)
[~, u] = fileparts(tempname);
p = fullfile(testCase.Dir, u);
mkdir(p);
reg = struct('relation_bindings', {{}});
if ~isempty(types)
    reg.entity_type_bindings = cellfun(@(t) struct('type', t, 'requires', {{'name'}}), ...
        types, 'UniformOutput', false);
end
fid = fopen(fullfile(p, 'binding_registry_meta.json'), 'w');
fwrite(fid, jsonencode(reg));
fclose(fid);
end
