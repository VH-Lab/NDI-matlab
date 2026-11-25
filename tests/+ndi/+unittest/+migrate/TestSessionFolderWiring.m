classdef TestSessionFolderWiring < matlab.unittest.TestCase
%TESTSESSIONFOLDERWIRING A migrated session's wiring and epoch ids come from its database, not its folder.
%
%   Jess Haley's decisions of 2026-11-19, did-schema
%   docs/plans/did_v2_standing_wiring_plan.md:
%     [session folder wiring migrated]  migration writes the `connected to`
%         relations of a non-ingested epoch from the session folder's
%         `.epochprobemap.ndi` files when the folder is present; the build
%         is tested on a fixture with a real session folder (NDI's example
%         Intan session);
%     [wiring read from the database only]  after migration NDI reads a
%         session's wiring only from its `connected to` relations, not from
%         the `*.epochprobemap.ndi` files; the files stay in the session as
%         the source; an edit to a file after migration is not seen;
%     [no new hidden epoch-id files]  after migration NDI writes no new
%         `.epochid.ndi` file into a migrated session's folders; an epoch's
%         id is read from its `recording epoch` entity's `local_identifier`;
%         existing hidden files are left as they are.
%
%   THE FIXTURE is a real v1 session folder, NOT ingested: three epochs of
%   the Intan file NDI ships (e1, e2, e3), each with its probe map. The
%   n-trode `ctx` is on intan1:ai1 in e1 and e3 and on intan1:ai2 in e2 (a
%   probe rewired between epochs); the stimulator `stim` is on intan1:di1 in
%   e1 and e2 and absent from e3. The v1 session is read (epoch table, the
%   probes and their epochs, the samples of `ctx`), migrated in place with
%   ndi.migrate.local, reopened and read again. Then the folder is changed
%   the way a person might change it after migration: e1's probe map file
%   moves `ctx` to intan1:ai5 and adds a probe, and e3's hidden epoch-id
%   file is deleted. The session is reopened and read a third time.
%
%   The comparison is with v1: the epochs, the probe-map rows (as a set,
%   [probe map rows compared as a set]), the probes and their epochs, and
%   the samples must be the same after migration, and stay the same after
%   the folder changes.
%
%   Filtered (never passed) when mksqlite, DID-matlab's did2 converter or a
%   v2 schema set with `entity` is missing. test-eta-migrate-e2e.yml runs it.

    properties
        F   % struct: the readings (see build)
    end

    properties (Constant)
        Epochs = {'e1', 'e2', 'e3'}
        SubjectString = 'anteater27@nosuchlab.org'
        IntanFile = 'Intan_160317_125049_short.rhd'
    end

    methods (TestClassSetup)
        function buildReadMigrateRead(testCase)
            testCase.assumeFalse(isempty(which('mksqlite')), 'mksqlite is not on the path');
            testCase.assumeFalse(isempty(which('did2.convert.v1_to_v2')), ...
                'did2.convert.v1_to_v2 (DID-matlab V2) is not on the path');
            testCase.assumeTrue(~isempty(which('did2.schema.cache')) && ...
                did2.schema.cache.shared().hasClass('entity'), ...
                'no v2 schema set (`entity`) where did2.schema.cache looks');
            root = tempname;
            mkdir(root);
            testCase.addTeardown(@() ndi.unittest.migrate.TestSessionFolderWiring.removeDir(root));
            try
                testCase.F = ndi.unittest.migrate.TestSessionFolderWiring.build(root);
            catch ME
                testCase.F = struct('setupError', sprintf('%s (%s)', ME.message, ME.identifier));
            end
            testCase.F.root = root;
        end
    end

    methods (Test)
        function testTheMigrationWritesTheFolderWiring(testCase)
            % [session folder wiring migrated]: one `connected to` relation
            % per probe-map row with channels, timed onto that row's epoch
            F = testCase.ready();
            want = sort(cellfun(@(r) [r{1} '@' r{2} '=' r{3}], F.v1Wired, 'UniformOutput', false));
            got = sort(cellfun(@(r) [r{1} '@' r{2} '=' r{3}], F.wiring, 'UniformOutput', false));
            fprintf('  v1 probe-map rows with channels: %d; `connected to` relations after migration: %d\n', ...
                numel(want), numel(got));
            fprintf('    v1:       %s\n    migrated: %s\n', strjoin(want, ', '), strjoin(got, ', '));
            testCase.assertNotEmpty(want, 'the v1 session has no wired row (nothing measured)');
            testCase.verifyEqual(got, want, ...
                'the migrated wiring is not the v1 probe maps'' wiring, row for row');
        end

        function testTheEpochIdsAreTheEpochEntities(testCase)
            % [no new hidden epoch-id files]: each epoch's id is a
            % `recording epoch` entity's local_identifier
            F = testCase.ready();
            fprintf('  recording epoch entities: %s\n', strjoin(sort(F.epochEntities), ', '));
            testCase.verifyEqual(sort(F.epochEntities), sort({F.v1.epochs.epoch_id}), ...
                'the migrated epoch entities are not the v1 epochs');
        end

        function testTheMigratedSessionReadsAsV1(testCase)
            F = testCase.ready();
            testCase.verifySameAsV1(F.v2, 'after migration');
        end

        function testAnEditedProbeMapFileIsNotSeen(testCase)
            % [wiring read from the database only]: e1's probe map file was
            % changed after migration; the session reads as before
            F = testCase.ready();
            testCase.assertTrue(F.edited, 'the probe map file was not edited (nothing measured)');
            testCase.verifySameAsV1(F.v3, 'after editing e1''s probe map file');
        end

        function testNoHiddenEpochIdFileIsWritten(testCase)
            % [no new hidden epoch-id files]: reading the migrated session
            % writes no `.epochid.ndi` file, and an epoch whose hidden file
            % was deleted keeps its id
            F = testCase.ready();
            fprintf('  hidden epoch-id files: v1 %d; after migration and a read %d; after deleting e3''s and a read %d\n', ...
                numel(F.hidden.v1), numel(F.hidden.v2), numel(F.hidden.v3));
            fprintf('    v1: %s\n    v2: %s\n    v3: %s\n', strjoin(F.hidden.v1, ', '), ...
                strjoin(F.hidden.v2, ', '), strjoin(F.hidden.v3, ', '));
            testCase.assertNotEmpty(F.hidden.v1, 'the v1 read wrote no hidden epoch-id file (nothing measured)');
            testCase.verifyEqual(F.hidden.v2, F.hidden.v1, ...
                'migrating and reading the session changed its hidden epoch-id files');
            testCase.verifyEqual(F.hidden.v3, reshape(setdiff(F.hidden.v1, F.hidden.deleted), 1, []), ...
                'reading the migrated session wrote a hidden epoch-id file');
        end
    end

    methods (Access = private)
        function F = ready(testCase)
            F = testCase.F;
            testCase.assertFalse(isfield(F, 'setupError'), ...
                ['building, migrating or reading the fixture raised: ' ...
                 ndi.unittest.migrate.TestSessionFolderWiring.fieldOr(F, 'setupError')]);
            testCase.assertEmpty(F.migrateError, ['ndi.migrate.local raised: ' F.migrateError]);
            testCase.assertTrue(F.isV2, 'the reopened session is not on the migrated database');
        end

        function verifySameAsV1(testCase, R, when)
            F = testCase.F;
            P = ndi.unittest.migrate.TestSessionFolderWiring;
            P.printReading('v1', F.v1);
            P.printReading(when, R);
            testCase.assertEmpty(R.err, sprintf('%s: reading raised: %s', when, R.err));
            testCase.verifyEqual({R.epochs.epoch_id}, {F.v1.epochs.epoch_id}, ...
                sprintf('%s: the epoch ids differ from v1', when));
            testCase.assertNumElements(R.epochs, numel(F.v1.epochs));
            for k = 1:numel(F.v1.epochs)
                testCase.verifyEqual(R.epochs(k).rows, F.v1.epochs(k).rows, sprintf( ...
                    '%s: epoch %s''s probe map differs from v1', when, F.v1.epochs(k).epoch_id));
            end
            testCase.verifyEqual(R.probes, F.v1.probes, ...
                sprintf('%s: the probes or their epochs differ from v1', when));
            testCase.assertEqual(fieldnames(R.samples), fieldnames(F.v1.samples));
            for f = fieldnames(F.v1.samples)'
                testCase.verifyEqual(R.samples.(f{1}), F.v1.samples.(f{1}), ...
                    sprintf('%s: ctx''s samples in %s differ from v1', when, f{1}));
            end
        end
    end

    methods (Static)
        function F = build(root)
            % The v1 session, read; migrated; read; the folder edited; read.
            P = ndi.unittest.migrate.TestSessionFolderWiring;
            maps = struct( ...
                'e1', {{'ctx', 'n-trode', 'intan1:ai1'; 'stim', 'stimulator', 'intan1:di1'}}, ...
                'e2', {{'ctx', 'n-trode', 'intan1:ai2'; 'stim', 'stimulator', 'intan1:di1'}}, ...
                'e3', {{'ctx', 'n-trode', 'intan1:ai1'}});
            src = fullfile(ndi.common.PathConstants.ExampleDataFolder, 'exp1_eg_saved', P.IntanFile);
            for k = 1:numel(P.Epochs)
                e = P.Epochs{k};
                copyfile(src, fullfile(root, [e '.rhd']));
                P.writeProbemap(fullfile(root, [e '.epochprobemap.ndi']), maps.(e));
            end
            S = ndi.session.dir('folder wiring', root);
            nav = ndi.file.navigator(S, {'#.rhd', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)epochprobemap.ndi'});
            S.daqsystem_add(ndi.daq.system.mfdaq('intan1', nav, ndi.daq.reader.mfdaq.intan()));
            subject = ndi.subject(P.SubjectString, '');
            S.database_add(subject.newdocument());
            S.cache.clear();
            % the v1 reading (getprobes writes the probes' element documents)
            F = struct();
            F.v1 = P.readSession(S);
            assert(isempty(F.v1.err), 'the v1 read raised: %s', F.v1.err);
            assert(numel(F.v1.probes) == 2, 'expected the probes ctx and stim, found %d', numel(F.v1.probes));
            F.hidden.v1 = P.hiddenFiles(root);
            % the rows the migration must wire: (probe, epoch, devicestring)
            F.v1Wired = {};
            for k = 1:numel(F.v1.epochs)
                rows = F.v1.epochs(k).rows;
                for r = 1:numel(rows)
                    F.v1Wired{end+1} = {rows(r).name, F.v1.epochs(k).epoch_id, rows(r).devicestring}; %#ok<AGROW>
                end
            end
            clear S nav subject
            F.migrateError = '';
            F.result = [];
            try
                F.result = ndi.migrate.local(root, 'Validate', true, 'Backup', false);
                P.printMigration(F.result);
            catch ME
                F.migrateError = sprintf('%s (%s)', ME.message, ME.identifier);
                return;
            end
            S2 = ndi.session.dir(root);
            F.isV2 = ndi.daq.reader.isv2database(S2);
            [F.wiring, F.epochEntities] = P.readWiring(S2);
            F.v2 = P.readSession(S2);
            F.hidden.v2 = P.hiddenFiles(root);
            clear S2
            % the folder changed after migration
            edited = maps.e1;
            edited{1, 3} = 'intan1:ai5';
            edited(end+1, :) = {'extra', 'n-trode', 'intan1:ai7'};
            P.writeProbemap(fullfile(root, 'e1.epochprobemap.ndi'), edited);
            F.edited = true;
            e3hidden = F.hidden.v1(startsWith(F.hidden.v1, '.e3.'));
            for k = 1:numel(e3hidden)
                delete(fullfile(root, e3hidden{k}));
            end
            F.hidden.deleted = e3hidden;
            S3 = ndi.session.dir(root);
            F.v3 = P.readSession(S3);
            F.hidden.v3 = P.hiddenFiles(root);
        end

        function R = readSession(S)
            % The intan1 epoch table (epoch ids in order, each epoch's
            % probe-map rows sorted), the probes (name, reference, type,
            % subject, epoch ids) sorted by name, and ctx's samples per epoch
            R = struct('err', '', 'epochs', struct('epoch_id', {}, 'rows', {}), ...
                'probes', struct('name', {}, 'reference', {}, 'type', {}, 'subject', {}, ...
                'epoch_ids', {}), 'samples', struct());
            try
                S.cache.clear();
                dev = S.daqsystem_load('name', 'intan1');
                if iscell(dev); dev = dev{1}; end
                et = dev.epochtable();
                for k = 1:numel(et)
                    R.epochs(end+1) = struct('epoch_id', char(et(k).epoch_id), ...
                        'rows', ndi.unittest.migrate.TestSessionFolderWiring.sortedRows(et(k).epochprobemap)); %#ok<AGROW>
                end
                [~, o] = sort({R.epochs.epoch_id});
                R.epochs = R.epochs(o);
                probes = S.getprobes();
                if ~iscell(probes); probes = {probes}; end
                for k = 1:numel(probes)
                    pet = probes{k}.epochtable();
                    R.probes(end+1) = struct('name', char(probes{k}.name), ...
                        'reference', double(probes{k}.reference), 'type', char(probes{k}.type), ...
                        'subject', char(probes{k}.subject_id), ...
                        'epoch_ids', {sort(cellfun(@char, {pet.epoch_id}, 'UniformOutput', false))}); %#ok<AGROW>
                end
                [~, o] = sort({R.probes.name});
                R.probes = R.probes(o);
                ctx = probes{strcmp(cellfun(@(p) char(p.name), probes, 'UniformOutput', false), 'ctx')};
                pet = ctx.epochtable();
                for k = 1:numel(pet)
                    [d, t] = ctx.readtimeseries(pet(k).epoch_id, -Inf, Inf);
                    R.samples.(matlab.lang.makeValidName(['epoch_' char(pet(k).epoch_id)])) = ...
                        struct('data', d, 't', t);
                end
            catch ME
                R.err = sprintf('%s (%s)', ME.message, ME.identifier);
                if ~isempty(ME.stack)
                    R.err = sprintf('%s at %s line %d', R.err, ME.stack(1).name, ME.stack(1).line);
                end
            end
        end

        function [wiring, epochIds] = readWiring(S)
            % Every `connected to` (RO:0002170) relation as {probe name,
            % epoch id, devicestring}, and every recording epoch entity's
            % local_identifier
            wiring = {};
            rels = S.database_search(ndi.query('', 'isa', 'directed_relation', ''));
            nAll = numel(rels);
            rels = rels(cellfun(@(d) ndi.unittest.vintage.TestStimulatorRowFromWiring.isWiring(d), rels));
            for k = 1:numel(rels)
                child = ndi.unittest.migrate.TestSessionFolderWiring.byId(S, ...
                    ndi.vintage.edgeTargets(rels{k}, 'child_id'));
                name = '';
                if ~isempty(child)
                    name = char(ndi.vintage.elementFields(child, S).name);
                end
                epoch = '';
                anchors = ndi.vintage.edgeTargets(rels{k}, 'time_reference_id');
                for a = 1:numel(anchors)
                    an = ndi.unittest.migrate.TestSessionFolderWiring.byId(S, anchors(a));
                    if isempty(an); continue; end
                    ep = ndi.unittest.migrate.TestSessionFolderWiring.byId(S, ...
                        ndi.vintage.edgeTargets(an, 'referent_id'));
                    if ~isempty(ep) && isfield(ep.document_properties, 'entity')
                        epoch = char(ep.document_properties.entity.local_identifier);
                    end
                end
                sysId = ndi.vintage.edgeTargets(rels{k}, 'parent_id');
                sysOf = ndi.vintage.rigSystems(S, sysId);
                if ~isempty(sysId) && isKey(sysOf, sysId{1}); sysId = {sysOf(sysId{1})}; end
                ds = '';
                if ~isempty(child) && ~isempty(sysId)
                    ds = char(ndi.vintage.wiredDeviceString(S, [], char(sysId{1}), char(child.id()), ...
                        struct('doc', containers.Map('KeyType', 'char', 'ValueType', 'any')), anchors));
                end
                wiring{end+1} = {name, epoch, ds}; %#ok<AGROW>
            end
            ents = S.database_search(ndi.query('', 'isa', 'entity', ''));
            epochIds = {};
            for k = 1:numel(ents)
                e = ents{k}.document_properties.entity;
                if isfield(e, 'type') && isstruct(e.type) && isfield(e.type, 'node') ...
                        && strcmp(char(e.type.node), 'EMPTY:0000383')
                    epochIds{end+1} = char(e.local_identifier); %#ok<AGROW>
                end
            end
            fprintf('  DENOMINATOR: %d directed_relation(s), %d `connected to`; %d entities, %d recording epoch(s)\n', ...
                nAll, numel(rels), numel(ents), numel(epochIds));
        end

        function d = byId(S, ids)
            d = [];
            if isempty(ids); return; end
            found = S.database_search(ndi.query('base.id', 'exact_string', char(ids{1}), ''));
            if ~isempty(found); d = found{1}; end
        end

        function r = sortedRows(pm)
            % probe-map rows sorted ([probe map rows compared as a set])
            r = ndi.unittest.vintage.TestIngestedReadsBatched.rowsOf(pm);
            if isempty(r); return; end
            keys = arrayfun(@(x) strjoin({x.name, num2str(x.reference), x.type, x.devicestring, ...
                x.subjectstring}, char(0)), r, 'UniformOutput', false);
            [~, o] = sort(keys);
            r = r(o);
        end

        function names = hiddenFiles(root)
            d = dir(fullfile(root, '.*.epochid.ndi'));
            names = reshape(sort({d.name}), 1, []);
        end

        function writeProbemap(file, rows)
            P = ndi.unittest.migrate.TestSessionFolderWiring;
            fid = fopen(file, 'wt');
            fprintf(fid, 'name\treference\ttype\tdevicestring\tsubjectstring\n');
            for r = 1:size(rows, 1)
                fprintf(fid, '%s\t1\t%s\t%s\t%s\n', rows{r, 1}, rows{r, 2}, rows{r, 3}, P.SubjectString);
            end
            fclose(fid);
        end

        function printMigration(result)
            fprintf('\n  MIGRATED: %d source document(s), %d quarantined\n', ...
                result.summary.total, numel(result.quarantine));
            sp = result.secondPass;
            for f = {'navigatorEpochFiles', 'epochProbemapFold'}
                r = sp.(f{1});
                if ~isstruct(r); fprintf('  %s: not run\n', f{1}); continue; end
                parts = {};
                for g = fieldnames(r)'
                    v = r.(g{1});
                    if (isnumeric(v) || islogical(v)) && isscalar(v)
                        parts{end+1} = sprintf('%s=%g', g{1}, double(v)); %#ok<AGROW>
                    elseif ischar(v) && ~isempty(v)
                        parts{end+1} = sprintf('%s="%s"', g{1}, v); %#ok<AGROW>
                    end
                end
                fprintf('  %s: %s\n', f{1}, strjoin(parts, ', '));
            end
        end

        function printReading(label, R)
            fprintf('  %s:', label);
            if ~isempty(R.err); fprintf(' ERROR %s\n', R.err); return; end
            fprintf('\n');
            for k = 1:numel(R.epochs)
                rows = R.epochs(k).rows;
                txt = arrayfun(@(x) sprintf('%s %d %s %s', x.name, x.reference, x.type, x.devicestring), ...
                    rows, 'UniformOutput', false);
                fprintf('    epoch %s: %s\n', R.epochs(k).epoch_id, strjoin(txt, '; '));
            end
            for k = 1:numel(R.probes)
                fprintf('    probe %s %d %s: epochs %s\n', R.probes(k).name, R.probes(k).reference, ...
                    R.probes(k).type, strjoin(R.probes(k).epoch_ids, ', '));
            end
        end

        function v = fieldOr(s, f)
            v = '';
            if isfield(s, f); v = s.(f); end
        end

        function removeDir(d)
            try
                if isfolder(d); rmdir(d, 's'); end
            catch
            end
        end
    end
end
