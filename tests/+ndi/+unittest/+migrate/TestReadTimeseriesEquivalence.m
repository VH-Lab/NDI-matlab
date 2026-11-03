classdef TestReadTimeseriesEquivalence < matlab.unittest.TestCase
%TESTREADTIMESERIESEQUIVALENCE The same time series before and after ndi.migrate.local.
%
%   Object-level equivalence for the migration path (VH-Lab/NDI-matlab#785,
%   as rescoped by Jess Haley on 2026-10-21; VH-Lab/NDI-matlab#1018): open a
%   v1 session, read time series through the NDI object API, migrate the
%   SAME session in place with ndi.migrate.local, reopen it with
%   ndi.session.dir, and read again. Samples, times and epoch tables must be
%   the same.
%
%   THE FIXTURE HAS REAL BINARY DATA. The corpus zips are document-only, so
%   the TestMigrateLocalEta* corpus tests cannot call readtimeseries. This
%   test builds two small sessions from code, from the Intan file NDI ships
%   (ndi_common/example_sessions/exp1_eg_saved/Intan_160317_125049_short.rhd,
%   the file ndi.unittest.session.buildSession uses):
%
%     PLAIN     not ingested; the .rhd stays on disk. It holds
%                 - the n-trode probe `ctx` (read from the .rhd),
%                 - a derived ndi.element.timeseries `lfp_demo` with one
%                   epoch, written by addepoch as epoch_binary_data.vhsb
%                   and read by vhsb_read through database_openbinarydoc,
%                 - an ndi.neuron `unit_demo` with one epoch of spike times
%                   (also a .vhsb) and a neuron_extracellular labelling it
%                   a single unit.
%               Migration CARRIES `lfp_demo` and its epoch as v1 (carry-063)
%               and MIGRATES `unit_demo` (a `cell` entity; its epoch a
%               spike-train observation owning the .vhsb as a data body),
%               so both read paths are compared.
%     INGESTED  the same probe, ingested with ndi.session/ingest (an mfdaq
%               channel group in the database's file store), then the .rhd
%               is DELETED, so every read goes through the ingested path.
%
%   THE INGESTED EPOCH AFTER MIGRATION. Migration turns the ingested
%   channel groups into sampled_body documents, and NDI's mfdaq reader
%   reads them ([V2 ingest is one sampled body per channel group]): the
%   channel list, sample rate and samples are the same
%   (testIngestedChannelsAndSamplesAreTheSame). The epoch's clocks and
%   t0_t1 are on the recording observation's time references ([clock only
%   on the time reference]), so the probe's epoch table, samples and times
%   and the time channel are the same too (testIngestedProbeSeriesIsTheSame).
%
%   Migration runs once per session, in TestClassSetup. Each reading is
%   taken inside try/catch and kept with its error, so one failing read does
%   not hide the others and each test method reports its own.
%
%   Filtered (never passed) when mksqlite, DID-matlab's did2 converter, a v2
%   schema set with `entity`, or NDI-compress is missing.
%   test-eta-migrate-e2e.yml runs it with all four.

    properties
        Plain      % struct: root, v1 and v2 readings, migration result
        Ingested   % same for the ingested session
    end

    methods (TestClassSetup)

        function buildReadMigrateRead(testCase)
            testCase.assumeFalse(isempty(which('mksqlite')), 'mksqlite is not on the path');
            testCase.assumeFalse(isempty(which('did2.convert.v1_to_v2')), ...
                'did2.convert.v1_to_v2 (DID-matlab V2) is not on the path');
            testCase.assumeTrue(~isempty(which('did2.schema.cache')) && ...
                did2.schema.cache.shared().hasClass('entity'), ...
                'no v2 schema set (did-schema #88, `entity`) where did2.schema.cache looks');
            testCase.assumeFalse(isempty(which('ndi.compress.compress_ephys')), ...
                'NDI-compress is not on the path (ingest needs it)');

            P = ndi.unittest.migrate.TestReadTimeseriesEquivalence;

            % Each session is built, read, migrated and read again on its
            % own; an error in one is kept (setupError) and reported by the
            % test methods that need it, and does not stop the other.
            root = tempname;
            mkdir(root);
            testCase.addTeardown(@() P.removeDir(root));
            try
                testCase.Plain = P.plainSession(root);
            catch ME
                testCase.Plain = struct('setupError', P.errorText(ME));
            end
            root2 = tempname;
            mkdir(root2);
            testCase.addTeardown(@() P.removeDir(root2));
            try
                testCase.Ingested = P.ingestedSession(root2);
            catch ME
                testCase.Ingested = struct('setupError', P.errorText(ME));
            end
        end

    end

    methods (Test)

        function testBothSessionsMigrateWithNothingQuarantined(testCase)
            for c = {'Plain', 'Ingested'}
                r = testCase.(c{1});
                testCase.verifyEmpty(r.setupError, ...
                    sprintf('%s: building the session raised: %s', c{1}, r.setupError));
                if ~isempty(r.setupError); continue; end
                testCase.verifyEmpty(r.migrateError, ...
                    sprintf('%s: ndi.migrate.local raised: %s', c{1}, r.migrateError));
                if ~isempty(r.result)
                    testCase.verifyEmpty(r.result.quarantine, ...
                        sprintf('%s: %d document(s) quarantined', c{1}, numel(r.result.quarantine)));
                    testCase.verifyTrue(isfile(r.result.destination), ...
                        sprintf('%s: no migrated database at %s', c{1}, r.result.destination));
                end
            end
        end

        function testTheV1ReadsReturnWhatWasWritten(testCase)
            % The baseline is real: the v1 element and neuron give back the
            % values addepoch wrote. This read goes through
            % database_openbinarydoc and vhsb_read, the call that raised
            % "Read-only file must be opened with 'rb' permission" in #1018.
            testCase.assertEmpty(testCase.Plain.setupError, testCase.Plain.setupError);
            v1 = testCase.Plain.v1;
            w = testCase.Plain.written;
            testCase.assertEmpty(v1.lfp_demo.err, ['v1 element read: ' v1.lfp_demo.err]);
            testCase.verifyEqual(v1.lfp_demo.data, w.element_d);
            testCase.verifyEqual(v1.lfp_demo.t(:), w.element_t, 'AbsTol', 1e-9);
            testCase.assertEmpty(v1.unit_demo.err, ['v1 neuron read: ' v1.unit_demo.err]);
            testCase.verifyEqual(v1.unit_demo.t(:), w.spikes, 'AbsTol', 1e-9);
            testCase.verifyEqual(v1.unit_demo.data(:), ones(size(w.spikes)));
        end

        function testTheUnitIsMigratedAndTheLfpElementCarried(testCase)
            % Which read path each element takes after migration: the
            % labelled unit is migrated, the `lfp` element carried as v1.
            % Without this, a change that carried the unit too would leave
            % every comparison here green while the dissolved read went
            % untested.
            r = testCase.Plain;
            testCase.assertEmpty(r.setupError, r.setupError);
            testCase.assertNotEmpty(r.result, ['no migration result: ' r.migrateError]);
            carried = {};
            for i = 1:numel(r.result.migrationReport)
                c = r.result.migrationReport(i).carried_as_v1;
                for k = 1:numel(c)
                    carried{end+1} = char(c(k).document_id); %#ok<AGROW>
                end
            end
            testCase.verifyFalse(any(strcmp(r.ids.unit_demo, carried)), ...
                'the labelled unit was carried as v1, so the migrated epoch read is not tested');
            testCase.verifyTrue(any(strcmp(r.ids.lfp_demo, carried)), ...
                'the lfp element was not carried as v1 (carry-063); update this test''s description');
        end

        function testProbeSeriesFromTheRawFileIsTheSame(testCase)
            testCase.verifySameReading('Plain', 'ctx');
        end

        function testElementVhsbSeriesIsTheSame(testCase)
            testCase.verifySameReading('Plain', 'lfp_demo');
        end

        function testNeuronSpikeTimesAreTheSame(testCase)
            testCase.verifySameReading('Plain', 'unit_demo');
        end

        function testIngestedChannelsAndSamplesAreTheSame(testCase)
            % The migrated ingested epoch is read from its v2 data bodies
            % (Decided by Jess Haley, 2026-10-29 [V2 ingest is one sampled
            % body per channel group]: "a reader finds an epoch's data
            % through those bodies, not through the v1
            % `daqreader_mfdaq_epochdata_ingested` document"; migration
            % writes them, [ingested archives are sampled bodies]). Read
            % through the acquisition system, before and after migration:
            % the channel list, the sample rate, and every sample of the
            % analog, auxiliary and digital groups, each segment found by
            % the body's time `chunk` ([segment length is the time chunk]).
            r = testCase.Ingested;
            testCase.assertEmpty(r.setupError, ...
                ['building the INGESTED session raised: ' r.setupError]);
            testCase.assertTrue(logical(r.isIngested), ...
                'the INGESTED session''s epoch is not on the ingested path');
            P = ndi.unittest.migrate.TestReadTimeseriesEquivalence;
            for f = {'channels', 'samplerate', 'ai', 'ax', 'di'}
                a = r.v1dev.(f{1});
                b = r.v2dev.(f{1});
                fprintf('  Ingested / intan1 %s\n    v1: %s\n    v2: %s\n', f{1}, ...
                    P.describeValue(a), P.describeValue(b));
                testCase.assertEmpty(a.err, sprintf('v1 ingested %s raised: %s', f{1}, a.err));
                testCase.assertNotEmpty(a.value, sprintf('v1 ingested %s is empty', f{1}));
                testCase.verifyEmpty(b.err, sprintf( ...
                    'the MIGRATED ingested %s raised: %s', f{1}, b.err));
                testCase.verifyEqual(b.value, a.value, sprintf( ...
                    'the ingested %s differs after migration', f{1}));
            end
        end

        function testIngestedProbeSeriesIsTheSame(testCase)
            % The v1 ingested document holds the epoch's clock and extent
            % (`daqreader_epochdata_ingested.epochtable`: epochclock
            % {'dev_local_time'}, t0_t1 [0 2.99995] here). Migration retires
            % that document (DID-matlab did2.convert.resolveEpochProbemap)
            % and, before it does, writes them on the recording
            % observation's time references: one relative_time_reference
            % onto the epoch per clock, {clock, start, duration} (Decided by
            % Jess Haley, 2026-11-01 [clock only on the time reference]:
            % "the recording observation's time references say when the
            % epoch starts on each clock"). So the probe's epoch table
            % (its clocks and t0_t1), its samples and its times, and the
            % acquisition system's time channel, read the same before and
            % after migration.
            %
            % THE TIMES TO THE DECIDED TOLERANCE, NOT TO THE BIT. The v1
            % ingest stores the time channel as samples (`ti_group1`).
            % Migration removes that body because the series is evenly
            % spaced, and only when every sample is t0 + (k-1)/rate to
            % max(1e-9 s, a millionth of a sample)
            % (ndi.migrate.internal.ingestedArchiveBodies). After that, the
            % time is the covariate origin plus spacing (Decided by Jess Haley,
            % 2026-11-01 [evenly spaced time is a covariate]). The reader
            % computes t0 + (s-1)/rate, which differs from v1's stored doubles
            % by a few units in the last place (e.g. 5e-19 s at 0.0009 s, on
            % run 41675185510). The epoch table and the samples are compared
            % exactly; the times are compared to the tolerance migration
            % itself checked.
            r = testCase.Ingested;
            testCase.assertEmpty(r.v1dev.samplerate.err, ...
                ['v1 ingested sample rate raised: ' r.v1dev.samplerate.err]);
            timeTol = max(1e-9, 1e-6 / double(r.v1dev.samplerate.value));
            testCase.verifySameReading('Ingested', 'ctx', timeTol);
            a = r.v1dev.time;
            b = r.v2dev.time;
            fprintf('  Ingested / intan1 time\n    v1: %s\n    v2: %s\n', ...
                ndi.unittest.migrate.TestReadTimeseriesEquivalence.describeValue(a), ...
                ndi.unittest.migrate.TestReadTimeseriesEquivalence.describeValue(b));
            testCase.assertEmpty(a.err, ['v1 ingested time channel raised: ' a.err]);
            testCase.assertNotEmpty(a.value, 'the v1 ingested time channel is empty');
            testCase.verifyEmpty(b.err, ['the MIGRATED ingested time channel raised: ' b.err]);
            testCase.verifyEqual(b.value, a.value, 'AbsTol', timeTol, ...
                'the ingested time channel differs after migration');
        end

    end

    methods (Access = private)

        function verifySameReading(testCase, which, name, timeTol)
            % TIMETOL (default 0: equal to the bit) is the absolute
            % tolerance, in seconds, of the times comparison only.
            if nargin < 4; timeTol = 0; end
            r = testCase.(which);
            testCase.assertEmpty(r.setupError, ...
                sprintf('building the %s session raised: %s', which, r.setupError));
            a = r.v1.(name);
            b = r.v2.(name);
            fprintf('\n  %s / %s, epoch %s\n    v1: %s\n    v2: %s\n', which, name, ...
                r.epoch_id, ndi.unittest.migrate.TestReadTimeseriesEquivalence.describe(a), ...
                ndi.unittest.migrate.TestReadTimeseriesEquivalence.describe(b));
            testCase.assertEmpty(a.err, sprintf('%s/%s v1 read raised: %s', which, name, a.err));
            testCase.assertNotEmpty(a.data, sprintf('%s/%s v1 read returned no samples', which, name));
            testCase.assertEmpty(b.err, sprintf('%s/%s read on the MIGRATED session raised: %s', ...
                which, name, b.err));
            testCase.verifyEqual(b.subject_id, a.subject_id, ...
                sprintf('%s/%s: the subject differs after migration', which, name));
            testCase.verifyEqual(b.underlying_name, a.underlying_name, ...
                sprintf('%s/%s: the underlying element differs after migration', which, name));
            testCase.verifyEqual(b.epochtable, a.epochtable, ...
                sprintf('%s/%s: the epoch table differs after migration', which, name));
            testCase.verifyEqual(size(b.data), size(a.data), ...
                sprintf('%s/%s: sample array size differs after migration', which, name));
            testCase.verifyEqual(b.data, a.data, ...
                sprintf('%s/%s: samples differ after migration', which, name));
            if timeTol == 0
                testCase.verifyEqual(b.t, a.t, ...
                    sprintf('%s/%s: times differ after migration', which, name));
            else
                testCase.verifyEqual(b.t, a.t, 'AbsTol', timeTol, ...
                    sprintf('%s/%s: times differ after migration (tolerance %g s)', ...
                    which, name, timeTol));
            end
        end

    end

    properties (Constant)
        IntanFile = 'Intan_160317_125049_short.rhd'
    end

    methods (Static)

        function plain = plainSession(root)
            % PLAIN: the probe read from the .rhd, a .vhsb element and a
            % neuron; read, migrated in place, reopened and read again.
            P = ndi.unittest.migrate.TestReadTimeseriesEquivalence;
            P.buildIntanSession(root);
            S = ndi.session.dir(root);
            probe = P.theProbe(S);
            et = probe.epochtable();
            assert(~isempty(et), 'the PLAIN probe has no epochs');
            eid = et(1).epoch_id;
            ec = et(1).epoch_clock{1};
            t0t1 = et(1).t0_t1{1};
            [pd, pt] = probe.readtimeseries(eid, -Inf, Inf);

            % the element's series: channel 1, every 20th sample
            keep = 1:20:numel(pt);
            elT = pt(keep); elT = elT(:);
            elD = double(pd(keep, 1));
            el = ndi.element.timeseries(S, 'lfp_demo', 1, 'lfp', probe, 0);
            el.addepoch(eid, ec, t0t1, elT, elD);
            % the neuron's spike times: 37 fixed times inside the epoch
            spikes = linspace(t0t1(1) + 0.01, t0t1(2) - 0.01, 37)';
            nr = ndi.neuron(S, 'unit_demo', 1, 'spikes', probe, 0);
            nr.addepoch(eid, ec, t0t1, spikes, ones(size(spikes)));
            % its sorting run's record, labelled a single unit, as NDI's
            % spike sorters write it: a labelled unit is MIGRATED (a `cell`
            % entity, its epoch a spike-train observation owning the .vhsb
            % as a data body), where an unlabelled one is carried whole as
            % v1 (carry-062), so this is what puts the dissolved epoch on
            % the read path. The `lfp` element stays carried (carry-063: no
            % derived timeseries type is on the element type list), which
            % keeps the carried read on the path too.
            waveform = [0; -1; -3; -1; 0];
            ne = S.newdocument('neuron_extracellular', ...
                'neuron_extracellular.number_of_samples_per_channel', numel(waveform), ...
                'neuron_extracellular.number_of_channels', 1, ...
                'neuron_extracellular.mean_waveform', waveform, ...
                'neuron_extracellular.waveform_sample_times', (-2:2)' / 30000, ...
                'neuron_extracellular.cluster_index', 1, ...
                'neuron_extracellular.quality_number', 1, ...
                'neuron_extracellular.quality_label', 'single');
            ne = ne.set_dependency_value('element_id', nr.id());
            S.database_add(ne);
            S.cache.clear();

            plain = struct('setupError', '', 'root', root, 'epoch_id', eid, ...
                'written', struct('element_t', elT, 'element_d', elD, 'spikes', spikes), ...
                'ids', struct('lfp_demo', el.id(), 'unit_demo', nr.id()));
            plain.v1 = P.readAll(S, eid, {'ctx', 'lfp_demo', 'unit_demo'});
            clear S probe el nr
            [plain.result, plain.migrateError] = P.migrate(root);
            plain.v2 = P.readAll(P.reopen(root), eid, {'ctx', 'lfp_demo', 'unit_demo'});
        end

        function ingested = ingestedSession(root)
            % INGESTED: the probe ingested, the .rhd deleted, so every read
            % goes through the ingested path; read, migrated, read again.
            P = ndi.unittest.migrate.TestReadTimeseriesEquivalence;
            P.buildIntanSession(root);
            S = ndi.session.dir(root);
            [b, msg] = S.ingest();
            assert(logical(b), 'ingest failed: %s', msg);
            delete(fullfile(root, P.IntanFile));
            S.cache.clear();
            probe = P.theProbe(S);
            et = probe.epochtable();
            assert(~isempty(et), 'the INGESTED probe has no epochs after the .rhd was removed');
            dev = S.daqsystem_load('name', 'intan1');
            if iscell(dev); dev = dev{1}; end
            ingested = struct('setupError', '', 'root', root, 'epoch_id', et(1).epoch_id, ...
                'isIngested', ndi.file.navigator.isingested( ...
                    getepochfiles(dev.filenavigator, et(1).epoch_id)));
            ingested.v1 = P.readAll(S, et(1).epoch_id, {'ctx'});
            ingested.v1dev = P.readDevice(S, et(1).epoch_id);
            clear S probe dev
            [ingested.result, ingested.migrateError] = P.migrate(root);
            S2 = P.reopen(root);
            ingested.v2 = P.readAll(S2, ingested.epoch_id, {'ctx'});
            ingested.v2dev = P.readDevice(S2, ingested.epoch_id);
        end

        function R = readDevice(S, epochId)
            % What the intan1 acquisition system reads for one ingested
            % epoch: its channel list, the sample rate of ai1, every sample
            % of the ai, ax and di groups, and the time channel. Each is
            % kept with its error, if any.
            P = ndi.unittest.migrate.TestReadTimeseriesEquivalence;
            dev = {};
            devErr = 'daqsystem_load found none';
            try
                dev = S.daqsystem_load('name', 'intan1');
                if iscell(dev); dev = dev{1}; end
            catch ME
                devErr = P.errorText(ME);
            end
            reads = { ...
                'channels',   @() dev.getchannelsepoch(epochId); ...
                'samplerate', @() dev.samplerate(epochId, 'ai', 1); ...
                'ai',         @() dev.readchannels_epochsamples('ai', 1:32, epochId, 1, Inf); ...
                'ax',         @() dev.readchannels_epochsamples('ax', 1:3, epochId, 1, Inf); ...
                'di',         @() dev.readchannels_epochsamples('di', 1, epochId, 1, Inf); ...
                'time',       @() dev.readchannels_epochsamples('time', 1, epochId, 1, Inf)};
            R = struct();
            for k = 1:size(reads, 1)
                r = struct('value', [], 'err', '');
                if isempty(dev)
                    r.err = ['no intan1 system: ' devErr];
                else
                    try
                        r.value = reads{k, 2}();
                    catch ME
                        r.err = P.errorText(ME);
                    end
                end
                R.(reads{k, 1}) = r;
            end
        end

        function s = describeValue(r)
            if ~isempty(r.err)
                s = ['ERROR ' r.err];
            elseif isstruct(r.value)
                s = sprintf('%d channel(s)', numel(r.value));
            else
                s = sprintf('%s %s', class(r.value), mat2str(size(r.value)));
            end
        end

        function s = errorText(ME)
            s = sprintf('%s (%s)', ME.message, ME.identifier);
            if ~isempty(ME.stack)
                s = sprintf('%s at %s line %d', s, ME.stack(1).name, ME.stack(1).line);
            end
        end

        function buildIntanSession(root)
            % The session of ndi.unittest.session.buildSession, in ROOT: the
            % Intan file, its probe map (n-trode `ctx`), the intan1 daq
            % system and the subject, written by NDI as a v1 session.
            P = ndi.unittest.migrate.TestReadTimeseriesEquivalence;
            copyfile(fullfile(ndi.common.PathConstants.ExampleDataFolder, ...
                'exp1_eg_saved', P.IntanFile), root);
            fid = fopen(fullfile(root, 'Intan_160317_125049_short.epochprobemap.ndi'), 'wt');
            fprintf(fid, 'name\treference\ttype\tdevicestring\tsubjectstring\n');
            fprintf(fid, 'ctx\t1\tn-trode\tintan1:ai1\tanteater27@nosuchlab.org\n');
            fclose(fid);
            S = ndi.session.dir('exp1', root);
            dt = ndi.file.navigator(S, {'#.rhd', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)epochprobemap.ndi'});
            S.daqsystem_add(ndi.daq.system.mfdaq('intan1', dt, ndi.daq.reader.mfdaq.intan()));
            subject = ndi.subject('anteater27@nosuchlab.org', '');
            S.database_add(subject.newdocument());
            S.cache.clear();
        end

        function probe = theProbe(S)
            probes = S.getprobes('type', 'n-trode');
            assert(numel(probes) == 1, 'expected one n-trode probe, found %d', numel(probes));
            probe = probes{1};
        end

        function S = reopen(root)
            S = ndi.session.dir(root);
            db = ndi.database.fun.opendatabase(fullfile(root, '.ndi'), S.id());
            assert(isa(db, 'ndi.database.implementations.database.did2sqlite'), ...
                'the reopened session is not on the migrated database (it opened a %s)', class(db));
        end

        function [result, err] = migrate(root)
            result = [];
            err = '';
            try
                result = ndi.migrate.local(root, 'Validate', true, 'Backup', false);
                fprintf('\n  MIGRATED %s: %d source document(s), %d quarantined\n', root, ...
                    result.summary.total, numel(result.quarantine));
                % what was carried whole as v1, and why: a document carried
                % as v1 is read by the v1 code path after migration too
                rep = result.migrationReport;
                for i = 1:numel(rep)
                    c = rep(i).carried_as_v1;
                    for k = 1:numel(c)
                        fprintf('    carried as v1: %s %s [%s] %s\n', char(c(k).class), ...
                            char(c(k).document_id), strjoin(cellstr(c(k).carry), ', '), ...
                            char(c(k).reason));
                    end
                end
            catch ME
                err = sprintf('%s (%s)', ME.message, ME.identifier);
            end
        end

        function R = readAll(S, epochId, names)
            % One reading per named object (probe or element): samples,
            % times, normalized epoch table, the error if any, and the time
            % the read took (#1018 reported a hang before any data).
            R = struct();
            objs = {};
            lookupErrs = '';
            for getter = {@() S.getprobes(), @() S.getelements()}
                try
                    got = getter{1}();
                catch ME
                    got = {};
                    lookupErrs = [lookupErrs ' ' ME.message]; %#ok<AGROW>
                end
                if isempty(got); got = {}; elseif ~iscell(got); got = {got}; end
                objs = [objs, reshape(got, 1, [])]; %#ok<AGROW>
            end
            P = ndi.unittest.migrate.TestReadTimeseriesEquivalence;
            for k = 1:numel(names)
                r = struct('data', [], 't', [], 'epochtable', [], 'err', '', 'seconds', NaN, ...
                    'underlying', '', 'subject_id', '', 'underlying_name', '');
                try
                    hit = {};
                    for j = 1:numel(objs)
                        if strcmp(objs{j}.name, names{k})
                            hit{end+1} = objs{j}; %#ok<AGROW>
                        end
                    end
                    % a probe is returned by getprobes and getelements alike
                    ids = cellfun(@(o) o.id(), hit, 'UniformOutput', false);
                    [~, u] = unique(ids, 'stable');
                    hit = hit(u);
                    assert(numel(hit) == 1, 'found %d object(s) named %s;%s', numel(hit), names{k}, lookupErrs);
                    o = hit{1};
                    r.underlying = P.underlyingText(o);
                    r.subject_id = char(o.subject_id);
                    if ~isempty(o.underlying_element)
                        r.underlying_name = char(o.underlying_element.name);
                    end
                    r.epochtable = P.normalizeEpochTable(o.epochtable());
                    tic;
                    [r.data, r.t] = o.readtimeseries(epochId, -Inf, Inf);
                    r.seconds = toc;
                catch ME
                    r.err = P.errorText(ME);
                end
                R.(names{k}) = r;
            end
        end

        function n = normalizeEpochTable(et)
            % The epoch table as plain data: ids, numbers, session, clock
            % names, extents, probe-map rows and underlying epoch ids.
            n = struct('epoch_number', {}, 'epoch_id', {}, 'epoch_session_id', {}, ...
                'epoch_clock', {}, 't0_t1', {}, 'epochprobemap', {}, 'underlying_epoch_ids', {});
            for i = 1:numel(et)
                e = et(i);
                n(i).epoch_number = e.epoch_number;
                n(i).epoch_id = char(e.epoch_id);
                n(i).epoch_session_id = char(e.epoch_session_id);
                n(i).epoch_clock = cellfun(@(c) c.ndi_clocktype2char(), e.epoch_clock, ...
                    'UniformOutput', false);
                n(i).t0_t1 = cellfun(@(x) double(x(:)'), e.t0_t1, 'UniformOutput', false);
                pm = {};
                m = e.epochprobemap;
                for k = 1:numel(m)
                    if iscell(m); p = m{k}; else; p = m(k); end
                    pm{end+1} = struct('name', char(p.name), 'reference', double(p.reference), ...
                        'type', char(p.type), 'devicestring', char(p.devicestring), ...
                        'subjectstring', char(p.subjectstring)); %#ok<AGROW>
                end
                n(i).epochprobemap = pm;
                ue = {};
                if isfield(e, 'underlying_epochs')
                    for k = 1:numel(e.underlying_epochs)
                        ue{end+1} = char(e.underlying_epochs(k).epoch_id); %#ok<AGROW>
                    end
                end
                n(i).underlying_epoch_ids = ue;
            end
        end

        function s = underlyingText(o)
            % what the object stands on, for the log: its class, its
            % underlying element and how many epochs that one has
            s = sprintf('%s direct=%d', class(o), logical(o.direct));
            u = o.underlying_element;
            if isempty(u)
                s = [s ', no underlying element'];
                return;
            end
            try
                n = numel(u.epochtable());
                s = sprintf('%s, on %s "%s" (%d epoch(s))', s, class(u), u.name, n);
            catch ME
                s = sprintf('%s, on %s "%s" (epochtable raised: %s)', s, class(u), u.name, ME.message);
            end
        end

        function s = describe(r)
            if ~isempty(r.err)
                s = ['ERROR ' r.err];
                return;
            end
            s = sprintf('%s samples, %d time(s), %d epoch(s), %.2f s; %s', ...
                mat2str(size(r.data)), numel(r.t), numel(r.epochtable), r.seconds, r.underlying);
        end

        function removeDir(d)
            try
                if isfolder(d); rmdir(d, 's'); end
            catch
            end
        end

    end
end
