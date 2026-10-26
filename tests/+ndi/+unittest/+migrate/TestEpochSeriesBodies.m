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
            res = did2.convert.v1_to_v2(out, 'Validate', true, 'TargetVersion', 'V_eta');
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
            % [generic stage is lossless] (Jess Haley, 2026-10-25, audit
            % item 5): the split drops column 2 and rewrites the values, so
            % ndi.migrate.local (no 'SplitJH') leaves the .vhsb body exactly
            % as pass 1 wrote it, counted. The tests below drive the split
            % itself with 'SplitJH', true -- the rule stays for the JH map.
            t = (0:4)' * 0.25;
            xy = [10 20; 11 21; 12 22; NaN NaN; 14 24];
            vlt.file.custom_file_formats.vhsb_write( ...
                fullfile(testCase.Dir, 'files', 'u_pos_g'), t, xy, 'use_filelock', 0);
            structs = jhPositionTriple('u_pos_g');
            [out, rep, added] = ndi.migrate.internal.epochSeriesBodies(structs, testCase.Dir);
            testCase.verifyEqual(rep.jh_bodies_seen, 1);
            testCase.verifyEqual(rep.jh_split_withheld, 1);
            testCase.verifyEqual(rep.position_split, 0);
            testCase.verifyEmpty(added);
            testCase.verifyEqual(out, structs, 'nothing changed');
        end

        function testAJHPositionIsSplitIntoTrackDocumentsArray(testCase)
            % Decided by Jess Haley, 2026-10-22 [JH position and distance]:
            % the second pass splits the columns where the bytes are present.
            t = (0:4)' * 0.25;
            xy = [10 20; 11 21; 12 22; NaN NaN; 14 24];
            vlt.file.custom_file_formats.vhsb_write( ...
                fullfile(testCase.Dir, 'files', 'u_pos'), t, xy, 'use_filelock', 0);
            structs = jhPositionTriple('u_pos');
            [out, rep, added] = ndi.migrate.internal.epochSeriesBodies(structs, testCase.Dir, 'SplitJH', true);
            testCase.verifyEqual(rep.jh_bodies_seen, 1);
            testCase.verifyEqual(rep.position_split, 1);
            testCase.verifyEmpty(added);
            b = out{2};
            testCase.verifyEqual(b.document_class.class_name, 'sampled_body');
            testCase.verifyEqual(b.base.id, 'body_pos', 'the body keeps its id');
            o = out{1};
            testCase.verifyEqual(o.value.data_type, 'float64');
            testCase.verifyEqual(arrayfun(@(d) double(d.n), o.data.dimensions), [5 1 2]);
            testCase.verifyEqual(char(o.data.dimensions(1).term.node), 'EMPTY:0000309');
            % the bytes are trackDocuments': position less half a pixel, column-major
            g = gunzip(b.files.file_info(1).locations.location, tempname());
            fid = fopen(g{1}, 'r', 'ieee-le'); v = fread(fid, Inf, 'double'); fclose(fid);
            testCase.verifyEqual(v(1:3), [9.5; 10.5; 11.5]);
            testCase.verifyEqual(numel(v), 10);
            res = did2.convert.v1_to_v2(out(1:2), 'Validate', true, 'TargetVersion', 'V_eta');
            testCase.verifyEmpty(res.quarantine);
        end

        function testAJHDistanceWithNoVideoScaleKeepsTheVhsbForLength(testCase)
            % no video reachable from the worm: no scale, so the length
            % calculation keeps the .vhsb (never an invented scale)
            t = (0:2)' * 0.25;
            y = [3.5 1 1; -2 1 2; 0.5 1 NaN];
            vlt.file.custom_file_formats.vhsb_write( ...
                fullfile(testCase.Dir, 'files', 'u_dist'), t, y, 'use_filelock', 0);
            structs = jhDistanceQuad('u_dist');
            [out, rep, added] = ndi.migrate.internal.epochSeriesBodies(structs, testCase.Dir, 'SplitJH', true);
            testCase.verifyEqual(rep.nearest_patch_split, 1);
            testCase.verifyEqual(rep.length_not_split_no_scale, 1);
            testCase.assertNumElements(added, 1);
            nb = added{1};
            testCase.verifyEqual(nb.document_class.class_name, 'sampled_body');
            g = gunzip(nb.files.file_info(1).locations.location, tempname());
            fid = fopen(g{1}, 'r'); v = fread(fid, Inf, 'uint8'); fclose(fid);
            testCase.verifyEqual(v, [0; 1; 255]);
            testCase.verifyEqual(out{3}.value.data_type, 'uint8');
            owners = arrayfun(@(d) char(d.document_id), out{4}.depends_on( ...
                strcmp({out{4}.depends_on.name}, 'owner_id')), 'UniformOutput', false);
            testCase.verifyEqual(owners, {'len_1'}, 'the .vhsb stays with the length calculation');
            res = did2.convert.v1_to_v2([out(3:4), added], 'Validate', true, 'TargetVersion', 'V_eta');
            testCase.verifyEmpty(res.quarantine);
        end

        function testAJHDistanceIsSplitIntoMetresByTheVideosScale(testCase)
            % Decided by Jess Haley, 2026-10-23 [JH signed distance in
            % metres]: column 1 (pixels) times 1e-3 / scale, scale the v1
            % video imageStack's dimension_scale (pixels per mm), reached
            % through the group the worm is member_of; the length
            % calculation's own float64 body replaces the .vhsb (id kept).
            t = (0:3)' * 0.25;
            y = [3.5 1 1; -2 1 2; NaN 1 NaN; 0 1 1];
            vlt.file.custom_file_formats.vhsb_write( ...
                fullfile(testCase.Dir, 'files', 'u_dm'), t, y, 'use_filelock', 0);
            scale = 32.930525883464774;
            structs = [jhDistanceQuad('u_dm'), videoOf('grp_1', 'vid_1', scale), ...
                {memberOf('worm_1', 'grp_1')}];
            [out, rep, added] = ndi.migrate.internal.epochSeriesBodies(structs, testCase.Dir, 'SplitJH', true);
            testCase.verifyEqual(rep.length_split_metres, 1);
            testCase.verifyEqual(rep.length_not_split_no_scale, 0);
            testCase.verifyEqual(rep.length_not_split_scale_ambiguous, 0);
            testCase.verifyEqual(rep.nearest_patch_split, 1);
            testCase.assertNumElements(added, 1, 'only the item body is new');
            lb = out{4};
            testCase.verifyEqual(lb.document_class.class_name, 'sampled_body');
            testCase.verifyEqual(lb.base.id, 'body_dist', 'the length body keeps the .vhsb id');
            owners = arrayfun(@(d) char(d.document_id), lb.depends_on( ...
                strcmp({lb.depends_on.name}, 'owner_id')), 'UniformOutput', false);
            testCase.verifyEqual(owners, {'len_1'});
            testCase.verifyEqual(out{2}.value.data_type, 'float64');
            testCase.verifyEqual(arrayfun(@(d) double(d.n), out{2}.data.dimensions), [4 1]);
            g = gunzip(lb.files.file_info(1).locations.location, tempname());
            fid = fopen(g{1}, 'r', 'ieee-le'); v = fread(fid, Inf, 'double'); fclose(fid);
            want = y(:, 1) * (1e-3 / scale);
            testCase.verifyEqual(numel(v), 4);
            testCase.verifyEqual(v([1 2 4]), want([1 2 4]), 'AbsTol', 1e-15);
            testCase.verifyTrue(isnan(v(3)), 'NaN stays NaN');
            testCase.verifyTrue(contains(lb.data_body.description, '32.930525883464774'), ...
                'the body states the scale it used');
            res = did2.convert.v1_to_v2([out(2:4), added], 'Validate', true, 'TargetVersion', 'V_eta');
            testCase.verifyEmpty(res.quarantine);
        end

        function testAJHDistanceWithTwoVideoScalesKeepsTheVhsb(testCase)
            % a worm on two videos of its plate with different scales: which
            % applies cannot be read, so the .vhsb stays, counted
            t = (0:2)' * 0.25;
            y = [3.5 1 1; -2 1 2; 0.5 1 NaN];
            vlt.file.custom_file_formats.vhsb_write( ...
                fullfile(testCase.Dir, 'files', 'u_amb'), t, y, 'use_filelock', 0);
            structs = [jhDistanceQuad('u_amb'), videoOf('grp_1', 'vid_1', 32.4924), ...
                videoOf('worm_1', 'vid_2', 32.4920), {memberOf('worm_1', 'grp_1')}];
            [out, rep] = ndi.migrate.internal.epochSeriesBodies(structs, testCase.Dir, 'SplitJH', true);
            testCase.verifyEqual(rep.length_split_metres, 0);
            testCase.verifyEqual(rep.length_not_split_scale_ambiguous, 1);
            testCase.verifyEqual(rep.nearest_patch_split, 1);
            testCase.verifyEqual(out{4}.document_class.class_name, 'opaque_body');
        end

        function testAVideoScaleInAnotherUnitIsNotRead(testCase)
            % only the v1 label's unit (micrometre) marks the raw v1
            % dimension_scale; a spacing in another unit is not read as one
            t = (0:2)' * 0.25;
            y = [3.5 1 1; -2 1 2; 0.5 1 NaN];
            vlt.file.custom_file_formats.vhsb_write( ...
                fullfile(testCase.Dir, 'files', 'u_unit'), t, y, 'use_filelock', 0);
            vid = videoOf('worm_1', 'vid_1', 3.0e-5);
            for i = 1:2
                vid{2}.data.covariates(i).source_unit = struct('node', 'om:metre', 'name', 'metre');
            end
            [~, rep] = ndi.migrate.internal.epochSeriesBodies( ...
                [jhDistanceQuad('u_unit'), vid], testCase.Dir, 'SplitJH', true);
            testCase.verifyEqual(rep.length_split_metres, 0);
            testCase.verifyEqual(rep.length_not_split_no_scale, 1);
        end

    end
end

function s = videoOf(entityId, id, scale)
% a migrated v1 video imageStack, as did2.convert +migrators_j/image_stack
% writes it: an observation about ENTITYID, its sampled_body [Y X T] with the
% v1 dimension_scale as the Y/X spacing, source unit micrometre (the v1 label)
prev = did2.schema.cache.strictMode('TermRegistry', false);
c = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev));
obs = did2.build.statement('observation', entityId, ...
    struct('node', '', 'name', 'image intensity'), [], ...
    'DataBody', true, 'TimeReferenceIds', {'tr_v'}, 'Id', id, ...
    'SessionId', 'sess_1', 'Validate', false, 'ValueKind', 'intensity');
um = struct('node', 'om:micrometre', 'name', 'micrometre');
h = struct('node', '', 'name', 'height');
w = struct('node', '', 'name', 'width');
tm = struct('node', 'om:Time', 'name', 'time');
dims = did2.build.list(did2.build.dimension(h, 8), did2.build.dimension(w, 8), ...
    did2.build.dimension(tm, 3));
covs = did2.build.list( ...
    did2.build.covariate(h, 0, 'Origin', 0, 'Spacing', scale, 'SourceOrigin', 0, ...
        'SourceSpacing', scale, 'SourceUnit', um), ...
    did2.build.covariate(w, 1, 'Origin', 0, 'Spacing', scale, 'SourceOrigin', 0, ...
        'SourceSpacing', scale, 'SourceUnit', um));
body = did2.build.sampledBody(id, dims, 'Covariates', covs, 'DatumOrder', 'F', ...
    'Id', [id '_body'], 'SessionId', 'sess_1', 'Validate', false);
s = {obs, body};
end

function r = memberOf(childId, groupId)
r = did2.build.directedRelation(childId, groupId, ...
    struct('node', 'RO:0002350', 'name', 'member of'), ...
    'SessionId', 'sess_1', 'Validate', false);
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

function s = jhDistanceQuad(uid)
prev = did2.schema.cache.strictMode('TermRegistry', false);
c = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev));
len = did2.build.statement('calculation', 'worm_1', ...
    struct('node', 'EMPTY:0000384', 'name', 'signed distance to region boundary'), [], ...
    'DataBody', true, 'TimeReferenceIds', {'tr_1'}, 'Id', 'len_1', ...
    'InstrumentId', 'el_dist', 'SessionId', 'sess_1', 'Validate', false, 'ValueKind', 'length');
it = did2.build.statement('calculation', 'worm_1', ...
    struct('node', 'EMPTY:0000297', 'name', 'nearest bacterial patch'), [], ...
    'DataBody', true, 'TimeReferenceIds', {'tr_1'}, 'Id', 'item_1', ...
    'InstrumentId', 'el_dist', 'Edges', struct('item_id', {{'p1', 'p2'}}), ...
    'SessionId', 'sess_1', 'Validate', false, 'ValueKind', 'item');
el = did2.build.document('entity', struct('type', struct('node', '', 'name', 'device'), ...
    'local_identifier', 'N2_x_midpoint_distance (ref 1)'), 'Id', 'el_dist', ...
    'SessionId', 'sess_1', 'Validate', false);
s = {el, len, it, jhBody({'len_1', 'item_1'}, 'body_dist', uid)};
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
