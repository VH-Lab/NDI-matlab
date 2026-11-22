classdef TestRigDevice < matlab.unittest.TestCase
%TESTRIGDEVICE ndi.setup.V2.rigDevice mints a rig's device as the migration does.
%
%   did-schema docs/plans/did_v2_standing_wiring_plan.md [device id required
%   and named by the rig]: NDI's v2 writers create the rig's device entity,
%   one per rig per session, named with the rig's name in `name` only, and
%   the acquisition_configuration names it by `device_id`. Its id is the one
%   DID-matlab's +migrators_j/daqsystem.m mints for a v1 daqsystem of the
%   same id (did2.convert.mintId 'rig device', in the context keyed on the
%   v1 base.id), so a freshly written and a migrated session agree.
%
%   Filtered (never passed) when did2.build or a v2 schema with `entity` is
%   missing.

    methods (TestClassSetup)
        function needV2(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            testCase.assumeTrue(~isempty(which('did2.convert.mintId')), ...
                'did2.convert.mintId (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a v2 schema with `entity` (did-schema #88)');
        end
    end

    methods (Test)
        function testTheDeviceIsNamedByTheRigOnly(testCase)
            sid = did.ido.unique_id();
            cid = did.ido.unique_id();
            docs = ndi.setup.V2.rigDevice('intan1', cid, sid);
            testCase.assertNumElements(docs, 1, 'one device per rig');
            d = docs{1};
            testCase.verifyEqual(d.document_class.class_name, 'entity');
            testCase.verifyEqual(ndi.v2.vocabHandle('entity_type', d.entity.type), 'device');
            testCase.verifyEqual(char(d.entity.name), 'intan1');
            testCase.verifyFalse(isfield(d.entity, 'local_identifier') && ...
                ~isempty(d.entity.local_identifier), 'the rig device writes name only');
            testCase.verifyEqual(ndi.v2.edgeIds(d, 'session_id'), {sid}, 'in the session given');
        end

        function testTheIdIsTheMigrationsId(testCase)
            cid = did.ido.unique_id();
            docs = ndi.setup.V2.rigDevice('intan1', cid, did.ido.unique_id());
            % as DID-matlab's v1_to_v2 mints it: a context keyed on the v1
            % daqsystem's base.id (did2.convert.mintKey), then the role alone
            depth = did2.convert.mintId('-depth');
            testCase.addTeardown(@() did2.convert.mintId('-popto', depth));
            did2.convert.mintId('-push', cid);
            migrated = did2.convert.mintId('rig device');
            did2.convert.mintId('-popto', depth);
            testCase.verifyEqual(docs{1}.base.id, migrated);
            testCase.verifyTrue(did.ido.isvalid(docs{1}.base.id), 'a did.ido id');
            % derived, not random: the same configuration gives the same id
            again = ndi.setup.V2.rigDevice('intan1', cid, did.ido.unique_id());
            testCase.verifyEqual(again{1}.base.id, docs{1}.base.id);
            other = ndi.setup.V2.rigDevice('intan1', did.ido.unique_id(), did.ido.unique_id());
            testCase.verifyNotEqual(other{1}.base.id, docs{1}.base.id, ...
                'another rig (another configuration) is another device');
        end

        function testARigWithNoNameMintsNoDevice(testCase)
            testCase.verifyEmpty(ndi.setup.V2.rigDevice('', did.ido.unique_id(), did.ido.unique_id()));
        end
    end
end
