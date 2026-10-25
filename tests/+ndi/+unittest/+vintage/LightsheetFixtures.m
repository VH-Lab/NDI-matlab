classdef LightsheetFixtures
%LIGHTSHEETFIXTURES Lightsheet documents in both vintages, built by hand.
%
%   The V_eta builders here are shaped as DID-matlab's lightsheet migration
%   emits them (+migrators_j/lightsheet_zarr_pyramid.m,
%   lightsheet_zarr_level.m, private/jLightsheetKeys.m (through
%   did2.build.key: a regular axis's origin and spacing are {value,
%   source_value} pairs) and the store-record
%   half of +did2/+convert/foldGenericFiles.m, DID-matlab
%   claude/ecstatic-pascal-md91fw at f363d98), AFTER the batch pass:
%
%     pyramid  an `observation` (value kind `intensity`) with the v1 pyramid's
%              id; entity_id = the subject, instrument_id = the element,
%              software_id = the builder `entity`; value.data_type 'uint16',
%              value.source_data_type '<u2' (the v1 dtype), data_body true;
%              variable NCIT:C184706 'Fluorescence Intensity'; method
%              ndi.vintage.lightsheetMethod() (FBbi:00000369, Jess
%              2026-10-15), the mark ndi.vintage.lightsheetPyramidDocs finds;
%              notes = the v1 label (Jess 2026-10-15).
%     software an `entity` of type software named for the builder (the
%              migrator's BUILDER; no longer the finder's mark).
%     store    the v1 fileReference as an UNHELD `opaque_body` owned by the
%              observation, format EMPTY:0000259 OME-Zarr, carrying the
%              full-resolution dimensions and covariates and a description holding the pyramid's
%              NGFF multiscales name (no label, no type: Jess 2026-10-15).
%     level    a `sampled_body` with the v1 level's id, owner_id = the
%              observation; dimensions t,c,z,y,x (t in second, c named by channel,
%              z/y/x converted to meter with the micrometre source kept);
%              datum_order C, byte_order little, fill_value '0'; level 0 is
%              not redundant, a reduced level is `redundant` with a
%              `summary statistic` condition; its chunk.bin_k members are
%              body_data_{k-1}.
%
%   They are hand-built so they need neither DID-matlab's migrators nor a
%   particular did-schema.
%   TestLightsheetMigrated runs the REAL migrator (where it exists) so a
%   drift between these and its output is caught.

    methods (Static)

        function sid = sessionId()
            sid = 'sess_ls_1';
        end

        function s = pyramid(id, softwareId)
            arguments
                id {mustBeText}
                softwareId {mustBeText}
            end
            s = ndi.unittest.vintage.LightsheetFixtures.etaDoc('observation', ...
                {'base', 'statement', 'interaction', 'intensity', 'value'}, id);
            s.depends_on = struct('name', {'entity_id', 'instrument_id', 'software_id'}, ...
                'document_id', {'subj_ls_1', 'elem_scope_1', softwareId});
            s.statement = struct('variable', ...
                struct('node', 'NCIT:C184706', 'name', 'Fluorescence Intensity'), ...
                'notes', 'brain 7 cleared');
            s.interaction = struct('method', struct('term', ndi.vintage.lightsheetMethod()));   % did-schema #88
            s.value = struct('data_type', 'uint16', 'source_data_type', '<u2', ...
                'data_body', true);
        end

        function s = software(id)
            arguments
                id {mustBeText}
            end
            s = ndi.unittest.vintage.LightsheetFixtures.etaDoc('entity', {'base'}, id);
            s.depends_on = struct('name', {}, 'document_id', {});
            s.entity = struct('type', struct('node', '', 'name', 'software'), ...
                'name', 'NDI lightsheet pyramid builder (ndi.fun.doc.lightsheet.makePyramid)');
        end

        function s = store(id, ownerId)
            arguments
                id {mustBeText}
                ownerId {mustBeText}
            end
            s = ndi.unittest.vintage.LightsheetFixtures.etaDoc('opaque_body', ...
                {'base', 'data_body'}, id);
            s.depends_on = struct('name', 'owner_id', 'document_id', ownerId);
            [d, c] = ndi.unittest.vintage.LightsheetFixtures.axesOf(1, false);
            s.data = struct('dimensions', {d}, 'covariates', {c});
            s.data_body = struct( ...
                'format', struct('node', 'EMPTY:0000259', 'name', 'OME-Zarr'), ...
                'filename', 'brain7.ome.zarr', ...
                'description', ['OME-Zarr store, not held in the database; ' ...
                    'NGFF multiscales name "mean"; recorded by location, not ' ...
                    'ingested; .zattrs MD5 0123456789abcdef'], ...
                'redundant', false);
        end

        function s = level(id, ownerId, factor, reduction, memberPaths)
            %LEVEL A migrated level body. FACTOR is the downsampling (1 for
            %   level 0); REDUCTION '' (level 0), 'max' or 'mean'. MEMBERPATHS
            %   is a cellstr of existing files recorded BY LOCATION as
            %   body_data_0, body_data_1, ... ({} for none).

            arguments
                id {mustBeText}
                ownerId {mustBeText}
                factor (1,1) {mustBeNumeric}
                reduction {mustBeText}
                memberPaths
            end
            s = ndi.unittest.vintage.LightsheetFixtures.etaDoc('sampled_body', ...
                {'base', 'data_body'}, id);
            s.depends_on = struct('name', 'owner_id', 'document_id', ownerId);
            [d, c] = ndi.unittest.vintage.LightsheetFixtures.axesOf(factor, true);
            s.data = struct('dimensions', {d}, 'covariates', {c});
            s.sampled_body = struct('datum_order', 'C', 'byte_order', 'little', ...
                'fill_value', '0');
            db = struct();
            if ~isempty(reduction)
                db.compression = 'blosc';
                db.redundant = true;
                switch reduction
                    case 'max',  t = struct('node', 'NCIT:C25564', 'name', 'Maximum');
                    case 'mean', t = struct('node', 'NCIT:C53319', 'name', 'Arithmetic Mean');
                    otherwise,   t = struct('node', '', 'name', reduction);
                end
                db.conditions = struct('variable', struct('name', 'summary statistic'), ...
                    'term', t);
            end
            s.data_body = db;
            if ~isempty(memberPaths)
                names = arrayfun(@(k) sprintf('body_data_%d', k - 1), ...
                    1:numel(memberPaths), 'UniformOutput', false);
                locs = cellfun(@(p) ndi.unittest.vintage.LightsheetFixtures.byLocation(p), ...
                    reshape(memberPaths, 1, []), 'UniformOutput', false);
                % the series is declared (file_list and file_series) by its
                % manifest name, as did.document requires; its members are
                % named outright in file_info, as the migrator renames them
                s.files = struct('file_list', {{'body_data'}}, 'file_series', {{'body_data'}}, ...
                    'file_info', struct('name', names, 'locations', locs));
            end
        end

        function [d, c] = axesOf(factor, withChunks)
            %AXESOF The dimensions t,c,z,y,x of a 1x2x400x2048x2048 '<u2'
            %   volume downsampled by FACTOR in z,y,x, and their covariates
            %   (did-schema data_body plan AMENDMENT 6; the mechanical port of
            %   a key: the dimension's term is the axis, the covariate along
            %   it alone has the same variable): voxel 2 x 0.5 x 0.5
            %   micrometre at level 0, z translated by 10 micrometre. D and C
            %   are cells, one entry each.

            arguments
                factor (1,1) {mustBeNumeric}
                withChunks (1,1) logical
            end
            n = [1 2 ceil(400 / factor) ceil(2048 / factor) ceil(2048 / factor)];
            chunk = [1 1 64 256 256];
            vox = [2 0.5 0.5] * factor;
            names = {'time', 'channel', 'z', 'y', 'x'};
            d = cell(1, 5);
            for a = 1:5
                d{a} = struct('term', struct('name', names{a}), 'n', n(a));
                if withChunks
                    d{a}.chunk = chunk(a);
                end
            end
            t = struct('variable', struct('name', 'time'), ...
                'unit', struct('node', 'UO:0000010', 'name', 'second'), 'along', 0, ...
                'origin', struct('value', 0), 'spacing', struct('value', 1));
            ch = struct('variable', struct('name', 'channel'), 'along', 1, ...
                'term', struct('node', '', 'name', {'GCaMP6s', 'tdTomato'}));
            space = cell(1, 3);
            origin = [10 0 0];
            for a = 1:3
                space{a} = struct('variable', struct('name', names{2 + a}), ...
                    'unit', struct('node', 'UO:0000008', 'name', 'meter'), ...
                    'source_unit', 'micrometer', 'along', 1 + a, ...
                    'origin', struct('value', origin(a) * 1e-6, 'source_value', origin(a)), ...
                    'spacing', struct('value', vox(a) * 1e-6, 'source_value', vox(a)));
            end
            c = [{t, ch}, space];
        end

        function s = v1Level(id, pyramidId, level, reduction, memberPaths)
            %V1LEVEL A lightsheetZarrLevel as makePyramid's makeOneLevel writes
            %   one, members chunk.bin_1.. recorded by location.
            arguments
                id {mustBeText}
                pyramidId {mustBeText}
                level (1,1) {mustBeNumeric}
                reduction {mustBeText}
                memberPaths
            end
            f = 2 ^ level;
            shape = [1 2 ceil(400 / f) ceil(2048 / f) ceil(2048 / f)];
            chunks = [1 1 64 256 256];
            s = struct();
            s.document_class = struct('definition', '', 'validation', '', ...
                'class_name', 'lightsheetZarrLevel', 'property_list_name', ...
                'lightsheetZarrLevel', 'class_version', 1, ...
                'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
            s.depends_on = struct('name', {'lightsheetZarrPyramid_id', 'subject_id'}, ...
                'value', {pyramidId, 'subj_ls_1'});
            s.base = struct('id', id, 'session_id', ...
                ndi.unittest.vintage.LightsheetFixtures.sessionId(), 'name', '', ...
                'datestamp', '2026-10-01T12:00:00.000Z');
            s.lightsheetZarrLevel = struct('label', sprintf('level %d', level), ...
                'level', level, 'reduction_function', reduction, 'axes_order', 'tczyx', ...
                'shape', shape, 'chunks', chunks, 'chunk_grid', ceil(shape ./ chunks), ...
                'n_chunks_stored', numel(memberPaths), 'chunk_index_origin', 1, ...
                'chunk_order', 'C', 'dtype', '<u2', 'fill_value', 0, ...
                'byte_order', 'little', 'codec', 'raw', 'codec_params', '{}', ...
                'voxel_size', [1 1 2 * f 0.5 * f 0.5 * f], ...
                'voxel_size_units', 'micrometer', 'translation', [0 0 10 0 0]);
            if isempty(memberPaths)
                % the template's declared list, nothing attached (the
                % writer's default, materializeChunks false)
                s.files = struct('file_list', {{'chunk.bin'}}, 'file_series', {{'chunk.bin'}}, ...
                    'file_info', struct('name', {}, 'locations', {}));
                return;
            end
            names = arrayfun(@(k) sprintf('chunk.bin_%d', k), 1:numel(memberPaths), ...
                'UniformOutput', false);
            locs = cellfun(@(p) ndi.unittest.vintage.LightsheetFixtures.byLocation(p), ...
                reshape(memberPaths, 1, []), 'UniformOutput', false);
            s.files = struct('file_list', {{'chunk.bin'}}, 'file_series', {{'chunk.bin'}}, ...
                'file_info', struct('name', names, 'locations', locs));
        end

        function l = byLocation(p)
            arguments
                p {mustBeText}
            end
            [~, uid] = fileparts(p);
            l = struct('delete_original', 0, 'uid', uid, 'location', p, ...
                'parameters', '', 'location_type', 'file', 'ingest', 0);
        end

        function s = etaDoc(className, superNames, id)
            % SUPERNAMES are the ancestors only, never the class itself: the
            % did2 database indexes the class name AND its superclasses, and
            % a repeat is a UNIQUE-constraint failure on write.

            arguments
                className {mustBeText}
                superNames cell
                id {mustBeText}
            end
            sc = struct('class_name', superNames, 'class_version', '1.0.0');
            s = struct();
            s.document_class = struct('class_name', className, ...
                'class_version', '1.0.0', 'superclasses', sc, ...
                'schema_version', 'did_v2');
            s.base = struct('id', id, ...
                'session_id', ndi.unittest.vintage.LightsheetFixtures.sessionId(), ...
                'creation_timestamp', '2026-10-01T12:00:00.000Z');
        end

        function p = tempFile(folder, uid, bytes)
            arguments
                folder {mustBeText}
                uid {mustBeText}
                bytes
            end
            p = fullfile(folder, uid);
            fid = fopen(p, 'w');
            fwrite(fid, bytes, 'uint8');
            fclose(fid);
        end

    end
end
