classdef TestEpochSeriesBodies < matlab.unittest.TestCase
%TESTEPOCHSERIESBODIES ndi.migrate.internal.epochSeriesBodies: the NDI second
%   pass describes a spike train's .vhsb as a sampled_body with COMPLETE
%   extents when the bytes are on this computer (Decided by Jess Haley,
%   2026-10-22 [epoch dissolution before merge]; TEAM-SIGN-OFF [epoch]
%   2026-08-17 Q3), and leaves the opaque_body by location when they are not.
%   The .vhsb is written by NDI's own writer (vlt vhsb_write, as
%   ndi.element.timeseries/addepoch does).

    properties
        Dir
    end

    methods (TestClassSetup)
        function needSchema(testCase)
            % Builds did-schema #88 documents (did2.build), so it needs a V_eta
            % schema set where did2.schema.cache looks (DID_SCHEMA_PATH, or a
            % did-schema checkout beside DID-matlab). run-tests.yml provides
            % none; test-eta-migrate-e2e.yml does, and runs this class there.
            testCase.assumeTrue(~isempty(which('did2.schema.cache')) && ...
                did2.schema.cache.shared().hasClass('entity'), ...
                'no V_eta schema set (did-schema #88, `entity`) where did2.schema.cache looks');
        end
    end

    methods (TestMethodSetup)
        function makeDir(testCase)
            testCase.Dir = tempname();
            mkdir(fullfile(testCase.Dir, 'files'));
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
        end
    end

    methods (Test)

        function testBytesHereBecomeASampledBodyWithTheirCount(testCase)
            spikes = [0.5; 1.25; 2; 7.75];
            vlt.file.custom_file_formats.vhsb_write( ...
                fullfile(testCase.Dir, 'files', 'u_train'), spikes, ones(size(spikes)), ...
                'use_filelock', 0);
            structs = trainPair('u_train');
            [out, rep] = ndi.migrate.internal.epochSeriesBodies(structs, testCase.Dir);
            testCase.verifyEqual(rep.train_bodies_seen, 1);
            testCase.verifyEqual(rep.bodies_described, 1);
            testCase.verifyEqual(rep.bytes_not_here, 0);
            b = out{2};
            testCase.verifyEqual(b.document_class.class_name, 'sampled_body');
            testCase.verifyEqual(b.base.id, 'body_1', 'the body keeps its id');
            testCase.verifyEqual(numel(b.data.dimensions), 1);
            testCase.verifyEqual(double(b.data.dimensions(1).n), 4);
            testCase.verifyEqual(char(b.data.dimensions(1).term.node), 'GO:0001508');
            testCase.verifyEqual(char(b.files.file_info(1).locations.uid), 'u_train');
            testCase.verifyEqual(out{1}.value.data_type, 'float64');
            testCase.verifyEqual(sort(rep.changed_ids), sort({'body_1', 'ee_1'}));
            % the pair validates against the real schema
            res = did2.convert.v1_to_v2(out, 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.verifyEmpty(res.quarantine);
        end

        function testBytesNotHereLeaveTheOpaqueBody(testCase)
            structs = trainPair('u_absent');
            [out, rep] = ndi.migrate.internal.epochSeriesBodies(structs, testCase.Dir);
            testCase.verifyEqual(rep.bytes_not_here, 1);
            testCase.verifyEqual(rep.bodies_described, 0);
            testCase.verifyEqual(out{2}.document_class.class_name, 'opaque_body');
            testCase.verifyEmpty(rep.changed_ids);
        end

        function testAnOwnerThatIsNotASpikeTrainIsLeftAndCounted(testCase)
            structs = trainPair('u_x');
            structs{1}.statement.variable = struct('node', '', 'name', 'position');
            [~, rep] = ndi.migrate.internal.epochSeriesBodies(structs, testCase.Dir);
            testCase.verifyEqual(rep.other_owner, 1);
            testCase.verifyEqual(rep.bodies_described, 0);
        end

        function testTheGenericStageLeavesAJHBodyAsItIs(testCase)
            % The Haley worm-track split left the generic migration
            % ([dataset-specific logic leaves the generic migration],
            % [dataset audit batch 1 and 2] (1), Jess Haley 2026-10-26): a
            % JH position .vhsb is not a spike train, so it is left exactly
            % as pass 1 wrote it, counted. (The split tests went with it.)
            t = (0:4)' * 0.25;
            xy = [10 20; 11 21; 12 22; NaN NaN; 14 24];
            vlt.file.custom_file_formats.vhsb_write( ...
                fullfile(testCase.Dir, 'files', 'u_pos_g'), t, xy, 'use_filelock', 0);
            structs = jhPositionTriple('u_pos_g');
            [out, rep, added] = ndi.migrate.internal.epochSeriesBodies(structs, testCase.Dir);
            testCase.verifyFalse(isfield(rep, 'jh_bodies_seen'));
            testCase.verifyEqual(rep.other_owner, 1);
            testCase.verifyEqual(rep.bodies_described, 0);
            testCase.verifyEmpty(added);
            testCase.verifyEqual(out, structs, 'nothing changed');
        end
    end
end

function s = jhPositionTriple(uid)
prev = did2.schema.cache.strictMode('TermRegistry', false);
c = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev));
pos = did2.build.statement('calculation', 'worm_1', ...
    struct('node', 'PATO:0000140', 'name', 'position'), [], ...
    'DataBody', true, 'TimeReferenceIds', {'tr_1'}, 'Id', 'ee_pos', ...
    'InstrumentId', 'el_pos', 'Edges', struct('coordinate_system_id', 'cs_1'), ...
    'SessionId', 'sess_1', 'Validate', false, 'ValueKind', 'position');
body = jhBody({'ee_pos'}, 'body_pos', uid);
el = did2.build.document('entity', struct('type', struct('node', '', 'name', 'device'), ...
    'local_identifier', 'N2_x_head_position (ref 1)'), 'Id', 'el_pos', ...
    'SessionId', 'sess_1', 'Validate', false);
s = {pos, body, el};
end

function body = jhBody(owners, id, uid)
body = did2.build.opaqueBody(owners, struct('node', 'EDAM:format_2333', ...
    'name', 'Binary format'), 'Fields', struct('filename', 'epoch_binary_data.vhsb'), ...
    'Id', id, 'SessionId', 'sess_1', 'Validate', false);
body.files.file_info = struct('name', 'body_data_0', 'locations', struct( ...
    'delete_original', 0, 'uid', uid, 'location', '/not/here.vhsb', ...
    'parameters', '', 'location_type', 'file', 'ingest', 1));
end

function s = trainPair(uid)
prev = did2.schema.cache.strictMode('TermRegistry', false);
c = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev));
obs = did2.build.statement('observation', 'el_neuron', ...
    struct('node', 'GO:0001508', 'name', 'action potential'), [], ...
    'DataBody', true, 'TimeReferenceIds', {'tr_1'}, 'Id', 'ee_1', ...
    'SessionId', 'sess_1', 'Validate', false, 'ValueKind', 'time');
body = did2.build.opaqueBody({'ee_1'}, struct('node', 'EDAM:format_2333', ...
    'name', 'Binary format'), 'Fields', struct('filename', 'epoch_binary_data.vhsb'), ...
    'Id', 'body_1', 'SessionId', 'sess_1', 'Validate', false);
body.files.file_info = struct('name', 'body_data_0', 'locations', struct( ...
    'delete_original', 0, 'uid', uid, 'location', '/not/on/this/computer.vhsb', ...
    'parameters', '', 'location_type', 'file', 'ingest', 1));
s = {obs, body};
end
