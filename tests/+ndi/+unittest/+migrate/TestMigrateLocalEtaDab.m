classdef TestMigrateLocalEtaDab < matlab.unittest.TestCase
%TESTMIGRATELOCALETADAB The Dabrowska documents through the WHOLE V_eta pipeline.
%
%   The FOURTH corpus to get the PRED / 20211116 / Soph treatment, and the
%   one that exercises a path none of the others do: Dabrowska's 14,644 v1
%   documents, migrated in full through ndi.migrate.local, opened through
%   ndi.session.dir, and read back through the object API.
%
%   DAB.ZIP IS TWO DATASETS, AND THIS TEST READS ONE OF THEM (Jess Haley,
%   2026-10-21). The zip holds 27,561 documents: Dabrowska's (the session
%   `Dabrowska_Electrophysiology`, 14,641, plus the `dabrowska_2025` dataset
%   session, 3) and the WHOLE of corpus B, the Fitzpatrick tree-shrew dataset
%   `2013_treeshrew_LGNctx` (13 sessions dated 2008 plus its dataset session,
%   12,917, byte-identical to B.zip). No depends_on edge crosses between the
%   two halves. keepDabrowskaBodies filters B out at READ time, from the
%   existing zip, by session: it keeps the `dabrowska_2025` dataset session
%   and the sessions it lists. B's checks (the 1,242 stimulus_presentation
%   and the grating census) live in TestMigrateLocalEtaB.
%
%   WHY DAB IS WORTH ITS OWN e2e. Dabrowska holds 17 v1 classes and is the
%   only corpus that holds `ontologyTableRow` at scale (6,205 docs).
%   Since [table rows carried as v1] (Jess Haley, 2026-10-30, did-schema
%   V_eta_go_forward_class_audit.md) every one of those rows is carried whole
%   as v1: the generic migration resolves no subject and fans out no
%   statements, so this corpus is where "every row carried" is checked. Dab
%   also carries the bath / slice / optogenetic-tetanus path (stimulus_bath
%   1,605, openminds_stimulus 635, treatment 49), ingestion (3,209 docs) and
%   openMINDS (2,344). Its Bar-1 (0 quarantine / 0 orphans) is gated independently on
%   the DID-matlab side (test-corpus.yml); what THIS workflow uniquely adds is
%   the NDI second passes + object-layer read-back on Dab's real documents.
%
%   GENERIC STAGE + DABROWSKA MAP (Decided by Jess Haley, 2026-10-25
%   [sliceTetanus to Dab map]; 2026-10-26 [dataset map edits V2]; did-schema
%   did_v2_go_forward_class_audit.md). The slices and tetanus runs are no
%   longer made by ndi.migrate.local's second pass: the generic stage leaves
%   the baths and recordings on the animal and carries the 635 approach
%   documents as v1, and the Dabrowska map (ndi.setup.conv.dabrowska.applyMap)
%   makes them afterwards, on a COPY of the migrated session (MappedRoot).
%   The object equivalence and the other generic checks read the generic
%   output (SessionRoot); the slice / tetanus checks read the mapped copy and
%   pin the census the second-pass step printed before the move (run
%   42163755800), so generic stage + map reproduces that output.
%
%   HARD ASSERTS, because Dab's DID side already proves them clean: the corpus
%   size (14,644 kept of 27,561 read, 12,917 excluded -- all three measured
%   from the zip), 0 quarantine, 0 orphans, 0 fragments, and every
%   `ontologyTableRow` carried ([table rows carried as v1]) -- the point of
%   running over the whole corpus rather than a fixture.
%
%   REPORT-ONLY ON THIS FIRST LANDING for the census + navigation + fan-out
%   count methods, DELIBERATELY (same discipline as the Soph landing). Dab's
%   exact pass-1 unconverted set, final survivor set, per-session read-back
%   counts are MEASURED here before
%   they are pinned -- arming a gate against a guessed document set would
%   either pass vacuously or fail on a persist-legitimate survivor.
%
%   SKIPS, NEVER FAILS, when the environment cannot support it: no mksqlite,
%   NDI_TEST_ETA unset, DID_SCHEMA_PATH unset, or the corpus will not download.
%   "Could not run" and "ran and found a defect" are different results and
%   must stay distinguishable.
%
%   NOT VERIFIED BY EXECUTION: there is no MATLAB in the authoring container;
%   validation runs via CI.

    properties
        SessionRoot
        CorpusDir
        Result
        Bodies
        MappedRoot      % a copy of SessionRoot with the Dabrowska map applied
        MapReport       % ndi.setup.conv.dabrowska.applyMap's report
        ReadCount       % documents in the zip, before the B filter
        ExcludedCount   % documents the B filter dropped
    end

    methods (TestClassSetup)

        function gateAndMigrate(testCase)
            if isempty(which('mksqlite'))
                assumeFail(testCase, 'mksqlite not on path; skipping.');
            end
            if ~etaEnabled()
                assumeFail(testCase, 'NDI_TEST_ETA not truthy; skipping V_eta e2e.');
            end
            if isempty(getenv('DID_SCHEMA_PATH'))
                assumeFail(testCase, 'DID_SCHEMA_PATH unset; skipping.');
            end
            try
                testCase.CorpusDir = ensureDabCorpus();
            catch ME
                assumeFail(testCase, sprintf( ...
                    'could not fetch the Dab corpus (%s); skipping.', ...
                    ME.message));
            end

            testCase.SessionRoot = tempname();
            mkdir(testCase.SessionRoot);
            mkdir(fullfile(testCase.SessionRoot, '.ndi'));

            % PHASE TIMING, kept from the Soph landing so a future timeout is
            % localised from the log rather than guessed.
            t = tic;
            allBodies = readCorpusBodies(testCase.CorpusDir);
            testCase.ReadCount = numel(allBodies);
            fprintf('  [Dab timing] readCorpusBodies: %d docs in %.1f s\n', ...
                testCase.ReadCount, toc(t));
            t = tic;
            testCase.Bodies = keepDabrowskaBodies(allBodies);
            testCase.ExcludedCount = testCase.ReadCount - numel(testCase.Bodies);
            clear allBodies;
            fprintf('  [Dab timing] keepDabrowskaBodies: kept %d, excluded %d (corpus B), in %.1f s\n', ...
                numel(testCase.Bodies), testCase.ExcludedCount, toc(t));
            t = tic;
            buildV1Sqlite(fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite'), ...
                testCase.Bodies);
            fprintf('  [Dab timing] buildV1Sqlite: %.1f s\n', toc(t));

            t = tic;
            testCase.Result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', true, 'TargetVersion', 'did_v2', 'Backup', false);
            fprintf('  [Dab timing] ndi.migrate.local: %.1f s\n', toc(t));

            % THE DABROWSKA MAP, on a copy, so the generic output stays what
            % the generic checks (and the object equivalence) read.
            t = tic;
            testCase.MappedRoot = tempname();
            copyfile(testCase.SessionRoot, testCase.MappedRoot);
            testCase.MapReport = ndi.setup.conv.dabrowska.applyMap( ...
                testCase.MappedRoot, testCase.Bodies);
            fprintf('  [Dab timing] copy + ndi.setup.conv.dabrowska.applyMap: %.1f s\n', toc(t));
        end

    end

    methods (TestClassTeardown)
        function cleanup(testCase)
            try
                if ~isempty(testCase.SessionRoot) && isfolder(testCase.SessionRoot)
                    rmdir(testCase.SessionRoot, 's');
                end
                if ~isempty(testCase.MappedRoot) && isfolder(testCase.MappedRoot)
                    rmdir(testCase.MappedRoot, 's');
                end
            catch
            end
        end
    end

    methods (Test)

        function testTheWholeCorpusMigratesWithNothingQuarantinedOrDangling(testCase)
            % DENOMINATOR FIRST. A pass over zero documents quarantines zero
            % documents, and that reading prints the same digit as a clean
            % migration -- so the corpus size is asserted before anything else.
            % MEASURED from Dab.zip (python zip listing, 2026-10-21): 27,561
            % documents, 14,644 in the two Dabrowska sessions, 12,917 in the 14
            % corpus-B sessions.
            verifyEqual(testCase, [testCase.ReadCount testCase.ExcludedCount], ...
                [27561 12917], sprintf( ...
                ['Dab.zip did not read as 27561 documents with 12917 of corpus B ' ...
                 'filtered out (read %d, excluded %d)'], ...
                testCase.ReadCount, testCase.ExcludedCount));
            verifyEqual(testCase, numel(testCase.Bodies), 14644, sprintf( ...
                ['the Dabrowska half did not read as 14644 documents (got %d); ' ...
                 'every assertion here would be about a different corpus'], ...
                numel(testCase.Bodies)));
            verifyGreaterThan(testCase, testCase.Result.summary.total, 0, ...
                'the migration saw no documents at all');

            % HARD: the whole corpus migrates with nothing quarantined.
            verifyEmpty(testCase, testCase.Result.quarantine, ...
                quarantineDiag(testCase.Result));

            % THE GRAPH CLOSES. The fan-out mints subjects + typed statements
            % that reference each other and the row's ontology terms; a dangling
            % edge among 6,205 fanned-out rows would show here.
            verifyEqual(testCase, testCase.Result.references.orphan_count, 0, ...
                sprintf('the migrated graph does not close: %d orphan(s). %s', ...
                    testCase.Result.references.orphan_count, ...
                    resultDiag(testCase.Result)));
            verifyGreaterThan(testCase, testCase.Result.references.edges_examined, 0, ...
                ['the reference sweep examined 0 edges, so its 0 orphans is a ' ...
                 'statement about the sweep and not about the corpus']);
        end

        function testEveryDocumentThatDidNotConvertDidSoDeliberately(testCase)
            % REPORT-ONLY ON THIS FIRST LANDING (see the class header). The
            % pass-1 conversion census names every class a single-document
            % migrator handed straight back; the deliberate-vs-accidental split
            % is read from THIS run's output before it is pinned. The
            % denominator IS asserted -- a census that read nothing is the
            % silentLoss failure and must not masquerade as "all converted".
            s = testCase.Result.summary;

            fprintf(['\n  PASS-1 CONVERSION CENSUS (Dab)\n' ...
                     '    DENOMINATOR: %d document(s) read, %d migrated, ' ...
                     '%d quarantined\n' ...
                     '    unconverted (migrator returned its input): %d\n' ...
                     '    fragments (emitted, but hollow):           %d\n'], ...
                s.total, s.migrated_count, s.quarantine_count, ...
                s.unconverted_count, s.fragment_count);
            ndi.unittest.migrate.printClassTable(s.unconverted_by_class, '    unconverted');
            ndi.unittest.migrate.printClassTable(s.fragment_by_class,    '    fragment');

            verifyEqual(testCase, s.total, 14644, ...
                'the pass did not see 14644 documents; this figure is about a different corpus');

            % A FRAGMENT IS NEVER DELIBERATE -- a document the migrator DID emit
            % that carries nothing (the isFragment failure). 0 on Dab's DID side.
            verifyEqual(testCase, s.fragment_count, 0, sprintf( ...
                ['%d document(s) migrated to a FRAGMENT. A passthrough is a ' ...
                 'deferral; a fragment is silent loss.'], s.fragment_count));
        end

        function testNoV1DocumentSurvivesUnfoldedInTheFinalOutput(testCase)
            % THE BAR-2 INSTRUMENT, report-only on this first landing. The
            % census above counts pass 1; it cannot see the SECOND PASSES that
            % run afterward (stimulusPresentationToTimed-
            % Sequence, resolveDeferredBaths, resolveResponseParameters), so a
            % class that reads "unconverted" there can still reach decided shape.
            % The only sound test of "is this corpus fully at decided shape" is
            % the FINAL output: a v1 SOURCE class name still labelling a
            % destination document did not fold. Measured before it is asserted.
            src = testCase.Bodies;
            dst = destinationBodies(testCase.Result.destination);
            survivors = ndi.unittest.migrate.finalV1SurvivorCensus( ...
                reshape(src, 1, []), reshape(dst, 1, []));

            fprintf(['\n  BAR-2 FINAL-OUTPUT V1 SURVIVOR CENSUS (Dab)\n' ...
                     '    DENOMINATOR: %d source document(s), %d destination ' ...
                     'document(s)\n' ...
                     '    v1 source class names still labelling a destination ' ...
                     'document: %d\n'], ...
                numel(src), numel(dst), numel(survivors));
            if isempty(survivors)
                fprintf('      (none -- every v1 class folded)\n');
            else
                for k = 1:numel(survivors)
                    note = 'UNFOLDED -- a Bar-2 gap unless persist or a declared deferral';
                    if any(strcmp(survivors(k).class_name, {'subject', 'session'}))
                        note = 'persist (v1 class IS the V_eta class)';
                    elseif strcmp(survivors(k).class_name, 'stimulus_response_scalar_parameters_basic')
                        note = 'SIGNED verify-before-delete deferral (#61)';
                    end
                    fprintf('      %6d  %-40s %s\n', survivors(k).count, ...
                        survivors(k).class_name, note);
                end
            end
            % A denominator that read nothing is the silentLoss failure; assert
            % it even while the survivor set itself is report-only.
            verifyEqual(testCase, numel(src), 14644, ...
                'the source census did not read 14644 documents');
            verifyGreaterThan(testCase, numel(dst), 0, ...
                'the destination census read zero documents');
        end

        function testTheMigratedSessionOpensAndReadsBackThroughNDI(testCase)
            % THE HEADLINE. If this errors, nothing below it is meaningful. Dab
            % holds two sessions in ONE migrated database, so this opens ONE of
            % them -- the `session` document whose session holds the most
            % migrated documents (Dabrowska_Electrophysiology; the other is the
            % 3-document `dabrowska_2025` dataset session, whose read-back
            % would be empty by construction) -- and confirms NDI can reach
            % it on the did2sqlite backend. Per-session object COUNTS are
            % printed, not pinned, on this first landing. What IS asserted: the
            % session opens, the backend chosen is the did2 one, and anything the
            % object API returns is the right TYPE -- zero-with-no-error is the
            % pre-vintage symptom, and a wrong type is a missed rename.
            assertTrue(testCase, isfile(testCase.Result.destination), sprintf( ...
                'ndi.migrate.local reported destination %s and no file is there', ...
                testCase.Result.destination));

            migrated = destinationBodies(testCase.Result.destination);
            % did-schema #88: the session (or, for a dataset's own session,
            % the dataset) entity; its base.id is the session id
            [sessionDoc, sessionId] = ndi.unittest.migrate.largestSessionRecord(migrated);
            assertNotEmpty(testCase, sessionDoc, ...
                'no session or dataset record in the migrated database');
            vlt.file.str2text( ...
                fullfile(testCase.SessionRoot, '.ndi', 'unique_reference.txt'), ...
                sessionId);

            s = ndi.session.dir(testCase.SessionRoot);
            assertTrue(testCase, isa(s, 'ndi.session.dir'), ...
                'ndi.session.dir did not return a session object');

            selected = ndi.database.fun.opendatabase( ...
                fullfile(testCase.SessionRoot, '.ndi'), s.id());
            assertTrue(testCase, isa(selected, ...
                'ndi.database.implementations.database.did2sqlite'), sprintf( ...
                'opendatabase chose a "%s", not a did2sqlite', class(selected)));

            devs = s.daqsystem_load();
            if isempty(devs); devs = {}; elseif ~iscell(devs); devs = {devs}; end
            for k = 1:numel(devs)
                verifyTrue(testCase, isa(devs{k}, 'ndi.daq.system'), sprintf( ...
                    'daqsystem_load returned a "%s"', class(devs{k})));
            end

            els = s.getelements();
            if isempty(els); els = {}; elseif ~iscell(els); els = {els}; end
            for k = 1:numel(els)
                verifyTrue(testCase, isa(els{k}, 'ndi.element'), sprintf( ...
                    'getelements returned a "%s"', class(els{k})));
            end

            fprintf(['\n  READ-BACK (one of Dab''s session(s))\n' ...
                     '    daqsystem_load: %d object(s)\n' ...
                     '    getelements:    %d object(s)\n'], ...
                numel(devs), numel(els));
        end

        function testWiringRepeats(testCase)
            % THROWAWAY (never merged): do the probe wirings and the epoch
            % anchors repeat across epochs? For Jess.
            file = testCase.Result.destination;
            dbid = mksqlite(0, 'open', file);
            c = onCleanup(@() mksqlite(dbid, 'close'));
            q = @(sql) mksqlite(dbid, sql);
            sqlE = ['SELECT DISTINCT d.document_id FROM depends_on d JOIN documents m ON m.id = d.doc_id ' ...
                'WHERE m.classname = ''ingestion_manifest'' AND d.name = ''epoch_id'''];
            % anchor -> epoch
            sqlAE = ['SELECT a.doc_id AS anchor, a.document_id AS epoch FROM depends_on a ' ...
                'JOIN documents ad ON ad.id = a.doc_id WHERE ad.classname = ''relative_time_reference'' ' ...
                'AND a.name = ''referent_id'' AND a.document_id IN (' sqlE ')'];
            % relation -> epoch (through any time_reference_id* edge onto an anchor)
            sqlRE = ['SELECT DISTINCT t.doc_id AS rel, ae.epoch AS epoch FROM depends_on t ' ...
                'JOIN documents rd ON rd.id = t.doc_id AND rd.classname = ''directed_relation'' ' ...
                'JOIN (' sqlAE ') ae ON ae.anchor = t.document_id ' ...
                'WHERE t.name = ''time_reference_id'' OR t.name LIKE ''time_reference_id\_%'' ESCAPE ''\'''];
            fprintf('\n  WIRING REPEATS (Dab, %s)\n', file);
            n = q(['SELECT COUNT(DISTINCT rel) AS nr, COUNT(DISTINCT epoch) AS ne FROM (' sqlRE ')']);
            fprintf('    DENOMINATOR: %d directed_relation(s) timed by anchors onto %d manifest epoch(s)\n', n.nr, n.ne);
            blocks = q(['SELECT j.key AS k, COUNT(*) AS n FROM documents d, json_each(d.body) j ' ...
                'WHERE d.id IN (SELECT rel FROM (' sqlRE ')) GROUP BY j.key ORDER BY j.key']);
            fprintf('    top-level blocks of those relations (documents holding each):');
            for k = 1:numel(blocks); fprintf(' %s %d;', blocks(k).k, blocks(k).n); end
            fprintf('\n');
            edgeNames = q(['SELECT name AS k, COUNT(*) AS n FROM depends_on WHERE doc_id IN (SELECT rel FROM (' sqlRE ')) ' ...
                'GROUP BY name ORDER BY name']);
            fprintf('    edge names on them (sidecar rows):');
            for k = 1:numel(edgeNames); fprintf(' %s %d;', edgeNames(k).k, edgeNames(k).n); end
            fprintf('\n');
            fprintf(['    WIRING KEY = document_class.class_name + the whole directed_relation block + the whole relation\n' ...
                '      block (both as stored) + every depends_on edge (name=target, sorted) EXCEPT session_id and\n' ...
                '      time_reference_id[_n]. EXCLUDED: base, document_class other than class_name.\n']);
            bk = q(['SELECT j.key AS k, COUNT(DISTINCT j.value) AS n FROM documents d, json_each(d.body, ''$.base'') j ' ...
                'WHERE d.id IN (SELECT rel FROM (' sqlRE ')) GROUP BY j.key']);
            fprintf('    base fields (distinct values among them):');
            for k = 1:numel(bk); fprintf(' %s %d;', bk(k).k, bk(k).n); end
            fprintf('\n');
            rb = q(['SELECT COUNT(DISTINCT json_extract(body, ''$.relation'')) AS n, MIN(json_extract(body, ''$.relation'')) AS ex ' ...
                'FROM documents WHERE id IN (SELECT rel FROM (' sqlRE '))']);
            ex = rb.ex; if ~ischar(ex); ex = '(none)'; end
            fprintf('    relation block: %d distinct value(s), e.g. %s\n', rb.n, ex(1:min(end, 300)));
            % base.name / datestamp variation, reported separately
            bn = q(['SELECT COUNT(DISTINCT json_extract(body, ''$.base.name'')) AS names, ' ...
                'COUNT(DISTINCT json_extract(body, ''$.base.datestamp'')) AS stamps FROM documents ' ...
                'WHERE id IN (SELECT rel FROM (' sqlRE '))']);
            fprintf('    (excluded fields: %d distinct base.name, %d distinct base.datestamp among them)\n', bn.names, bn.stamps);
            sqlKey = ['SELECT r.id AS rel, (r.classname || ''|'' || COALESCE(json_extract(r.body, ''$.directed_relation''), ''null'') || ''|'' || ' ...
                'COALESCE(json_extract(r.body, ''$.relation''), ''null'') || ''|'' || ' ...
                'COALESCE((SELECT group_concat(e.name || ''='' || e.document_id, '';'') FROM ' ...
                '(SELECT name, document_id FROM depends_on WHERE doc_id = r.id AND name <> ''session_id'' ' ...
                'AND name <> ''time_reference_id'' AND name NOT LIKE ''time_reference_id\_%'' ESCAPE ''\'' ' ...
                'ORDER BY name, document_id) e), '''')) AS wkey, ' ...
                '(SELECT document_id FROM depends_on WHERE doc_id = r.id AND name = ''child_id'' LIMIT 1) AS probe ' ...
                'FROM documents r WHERE r.id IN (SELECT rel FROM (' sqlRE '))'];
            per = q(['SELECT k.wkey AS wkey, COUNT(DISTINCT re.epoch) AS ne, COUNT(DISTINCT k.rel) AS nrel ' ...
                'FROM (' sqlKey ') k JOIN (' sqlRE ') re ON re.rel = k.rel GROUP BY k.wkey']);
            ne = double([per.ne]);
            fprintf('    relations %d; distinct wiring keys %d; keys in exactly 1 epoch %d; epochs per key min %d / median %g / max %d\n', ...
                sum(double([per.nrel])), numel(per), nnz(ne == 1), min(ne), median(ne), max(ne));
            [~, i1] = max(ne); [~, i2] = min(ne);
            fprintf('    example, most epochs (%d): %s\n', ne(i1), per(i1).wkey(1:min(end, 400)));
            fprintf('    example, fewest epochs (%d): %s\n', ne(i2), per(i2).wkey(1:min(end, 400)));
            pp = q(['SELECT probe, COUNT(DISTINCT wkey) AS nk FROM (' sqlKey ') GROUP BY probe']);
            nk = double([pp.nk]);
            fprintf('    probes (child_id) %d; distinct wiring keys per probe min %d / median %g / max %d; probes with one key %d\n', ...
                numel(pp), min(nk), median(nk), max(nk), nnz(nk == 1));
            % anchors
            na = q(['SELECT COUNT(DISTINCT anchor) AS n, COUNT(DISTINCT epoch) AS e FROM (' sqlAE ')']);
            fprintf('    ANCHORS DENOMINATOR: %d relative_time_reference(s) onto %d manifest epoch(s)\n', na.n, na.e);
            ab = q(['SELECT j.key AS k, COUNT(*) AS n FROM documents d, json_each(d.body, ''$.relative_time_reference'') j ' ...
                'WHERE d.id IN (SELECT anchor FROM (' sqlAE ')) GROUP BY j.key ORDER BY j.key']);
            fprintf('    relative_time_reference fields (documents holding each):');
            for k = 1:numel(ab); fprintf(' %s %d;', ab(k).k, ab(k).n); end
            fprintf('\n');
            fprintf('    ANCHOR KEY (full) = the whole relative_time_reference block as stored; CLOCK KEY = its value.clock only\n');
            af = q(['SELECT COUNT(DISTINCT json_extract(body, ''$.relative_time_reference'')) AS full_, ' ...
                'COUNT(DISTINCT json_extract(body, ''$.relative_time_reference.value.clock'')) AS clocks FROM documents ' ...
                'WHERE id IN (SELECT anchor FROM (' sqlAE '))']);
            fprintf('    distinct full anchor keys %d; distinct clocks %d\n', af.full_, af.clocks);
            byc = q(['SELECT COALESCE(json_extract(body, ''$.relative_time_reference.value.clock.name''), ''(none)'') AS clk, ' ...
                'COUNT(*) AS n, COUNT(DISTINCT json_extract(body, ''$.relative_time_reference'')) AS nd, ' ...
                'MIN(json_extract(body, ''$.relative_time_reference'')) AS ex FROM documents ' ...
                'WHERE id IN (SELECT anchor FROM (' sqlAE ')) GROUP BY clk']);
            for k = 1:numel(byc)
                ex = byc(k).ex; if ~ischar(ex); ex = '(none)'; end
                fprintf('      clock %s: %d anchor(s), %d distinct full block(s); e.g. %s\n', byc(k).clk, byc(k).n, byc(k).nd, ex(1:min(end, 300)));
            end
            vk = q(['SELECT j.key AS k, COUNT(*) AS n, COUNT(DISTINCT j.value) AS nd FROM documents d, ' ...
                'json_each(d.body, ''$.relative_time_reference.value'') j WHERE d.id IN (SELECT anchor FROM (' sqlAE ')) ' ...
                'GROUP BY j.key']);
            fprintf('    relative_time_reference.value fields (anchors holding, distinct values):');
            for k = 1:numel(vk); fprintf(' %s %d/%d;', vk(k).k, vk(k).n, vk(k).nd); end
            fprintf('\n');
            cl = q(['SELECT json_extract(body, ''$.relative_time_reference.value.clock'') AS clk, COUNT(*) AS n FROM documents ' ...
                'WHERE id IN (SELECT anchor FROM (' sqlAE ')) GROUP BY clk ORDER BY n DESC']);
            for k = 1:numel(cl); v = cl(k).clk; if ~ischar(v); v = '(none)'; end; fprintf('      clock %s: %d anchor(s)\n', v, cl(k).n); end
            combos = q(['SELECT combo, COUNT(*) AS n FROM (SELECT ae.epoch, group_concat(c, '','') AS combo FROM ' ...
                '(SELECT ae.epoch AS epoch, json_extract(d.body, ''$.relative_time_reference.value.clock.name'') AS c ' ...
                'FROM (' sqlAE ') ae JOIN documents d ON d.id = ae.anchor ORDER BY ae.epoch, c) ae GROUP BY ae.epoch) ' ...
                'GROUP BY combo ORDER BY n DESC']);
            fprintf('    clock-name sets per epoch (%d distinct):\n', numel(combos));
            for k = 1:numel(combos); v = combos(k).combo; if ~ischar(v); v = '(none)'; end; fprintf('      %d epoch(s): %s\n', combos(k).n, v); end
            clear c;
        end

        function testCensusByClass(testCase)
            % THROWAWAY (never merged): the migrated Dab database by v2
            % class, and what each ingested epoch became, for Jess.
            file = testCase.Result.destination;
            dbid = mksqlite(0, 'open', file);
            c = onCleanup(@() mksqlite(dbid, 'close'));
            q = @(sql) mksqlite(dbid, sql);
            t = q('SELECT COUNT(*) AS n FROM documents');
            fprintf('\n  CENSUS (Dab, migrated database %s)\n', file);
            fprintf('    DENOMINATOR: %d document(s)\n', t.n);
            r = q(['SELECT classname AS c, COUNT(*) AS n, ' ...
                'SUM(json_extract(body, ''$.document_class.schema_version'') = ''did_v1'') AS v1 ' ...
                'FROM documents GROUP BY classname ORDER BY n DESC']);
            fprintf('    by class (%d classes; v1 = carried as did_v1):\n', numel(r));
            for k = 1:numel(r)
                fprintf('      %7d  %-40s v1 %d\n', r(k).n, r(k).c, double(r(k).v1));
            end
            % what the ingested epochs became
            sqlE = ['SELECT DISTINCT d.document_id AS id FROM depends_on d JOIN documents m ON m.id = d.doc_id ' ...
                'WHERE m.classname = ''ingestion_manifest'' AND d.name = ''epoch_id'''];
            sqlA = ['SELECT DISTINCT a.doc_id AS id FROM depends_on a JOIN documents ad ON ad.id = a.doc_id ' ...
                'WHERE ad.classname = ''relative_time_reference'' AND a.name = ''referent_id'' ' ...
                'AND a.document_id IN (' sqlE ')'];
            sqlS = ['SELECT DISTINCT s.doc_id AS id FROM depends_on s WHERE s.name = ''time_reference_id'' ' ...
                'AND s.document_id IN (' sqlA ')'];
            m = q('SELECT COUNT(*) AS n FROM documents WHERE classname = ''ingestion_manifest''');
            e = q(['SELECT COUNT(*) AS n FROM (' sqlE ')']);
            a = q(['SELECT COUNT(*) AS n FROM (' sqlA ')']);
            fprintf('    ingestion_manifest documents: %d; epoch entities they name: %d; anchors (relative_time_reference) onto them: %d\n', ...
                m.n, e.n, a.n);
            r = q(['SELECT d.classname AS c, COUNT(*) AS n FROM documents d WHERE d.id IN (' sqlS ') ' ...
                'GROUP BY d.classname ORDER BY n DESC']);
            fprintf('    documents timed by those anchors (time_reference_id), by class:\n');
            for k = 1:numel(r); fprintf('      %7d  %s\n', r(k).n, r(k).c); end
            r = q(['SELECT d.classname AS c, COUNT(*) AS n FROM documents d JOIN depends_on o ON o.doc_id = d.id ' ...
                'WHERE o.name = ''owner_id'' AND o.document_id IN (' sqlS ') GROUP BY d.classname ORDER BY n DESC']);
            fprintf('    data bodies owned by those documents (owner_id), by class:\n');
            for k = 1:numel(r); fprintf('      %7d  %s\n', r(k).n, r(k).c); end
            % per epoch: anchors and timed documents
            r = q(['SELECT x.e AS e, COUNT(DISTINCT x.a) AS na, COUNT(DISTINCT s.doc_id) AS ns FROM ' ...
                '(SELECT a.document_id AS e, a.doc_id AS a FROM depends_on a JOIN documents ad ON ad.id = a.doc_id ' ...
                'WHERE ad.classname = ''relative_time_reference'' AND a.name = ''referent_id'' ' ...
                'AND a.document_id IN (' sqlE ')) x LEFT JOIN depends_on s ON s.name = ''time_reference_id'' ' ...
                'AND s.document_id = x.a GROUP BY x.e']);
            if ~isempty(r)
                na = double([r.na]); ns = double([r.ns]);
                fprintf('    per epoch (%d epochs): anchors min %d / median %g / max %d; timed documents min %d / median %g / max %d\n', ...
                    numel(r), min(na), median(na), max(na), min(ns), median(ns), max(ns));
            end
            clear c;
        end

        function testEpochRepeats(testCase)
            % THROWAWAY (never merged): which epoch-tied documents record the
            % same fact again in several epochs (Jess Haley, 2026-11-09).
            ndi.unittest.migrate.epochRepeatCensus(testCase.Result.destination, 'Dab');
        end

        function testReadPhasesAreNoSlowerThanV1(testCase)
            % Jess Haley, 2026-11-06: "Speed can't be slower than v1. We
            % need to match or beat." Every session of Dab is read in five
            % phases (subjects, getelements, the elements' facts and epoch
            % tables, getprobes with probe epoch tables, the acquisition
            % systems' epoch tables), before migration and after, each side
            % in a freshly opened session doing the same work
            % (ndi.unittest.migrate.readPhaseTimings). NDI_PROFILE_READS=1
            % profiles the v2 phases (report-only).
            T = ndi.unittest.migrate.readPhaseTimings(testCase.Bodies, ...
                fileparts(testCase.Result.destination), 'Dab', ...
                'Profile', ndi.unittest.migrate.envTrue('NDI_PROFILE_READS'));
            ndi.unittest.migrate.verifyReadPhases(testCase, T);
        end

        function testTheSameObjectsBeforeAndAfterMigration(testCase)
            % Object-level equivalence over the whole corpus
            % (VH-Lab/NDI-matlab#785; Jess Haley, 2026-11-03, queued it):
            % every session of Dab, opened through ndi.session.dir before
            % migration (the same documents in a DID v1 database) and after
            % (a copy of the migrated database), must give the same
            % subjects, subject facts, elements, probes, probe epoch tables,
            % acquisition systems and their epochs, and element epochs; and
            % a document added to a migrated session must read back after
            % reopening. Every category prints its denominator first
            % (ndi.unittest.migrate.corpusObjectEquivalence). Apparatus and
            % equipment entities have no v1 subject object to compare with,
            % so they are counted, not compared. Probe epoch tables: 12 of
            % Dab's 762 probes, evenly spaced (all 762 did not finish in
            % 180 minutes, run 41721521588); every acquisition-system epoch
            % table, probe maps included, is still read whole.
            %
            % RUNS AGAIN since the migrated epoch-read speed fix (Jess
            % Haley, 2026-11-06: "Yes, build the speed fix now"). It was
            % skipped while one acquisition system's epoch table was rebuilt
            % from about 13 database searches per ingested epoch (0.86 s +
            % 2 x 0.34 s per epoch over 1,604 epochs, run 41876678241) and
            % getprobes did not return in 4.5 hours (run 41823644325). The
            % epochs are now read a kind of document at a time
            % (ndi.vintage.ingestedEpochs 'Batch', ndi.vintage.ingestedArchives)
            % and did2 starts a session-scoped search from its edge
            % (DID-matlab compileQuery). 'CountSearches' prints, report-only,
            % the searches per epoch one epoch at a time and batched.
            R = ndi.unittest.migrate.corpusObjectEquivalence(testCase.Bodies, ...
                fileparts(testCase.Result.destination), 'Dab', ...
                'MaxProbeEpochTables', 12, 'CountSearches', true);
            ndi.unittest.migrate.verifyObjectEquivalence(testCase, R);
        end

        function testBathsInOsmOrSaturationAreCarriedAsV1(testCase)
            % Decided by Jess Haley, 2026-11-03 [Dab bath units are
            % Dabrowska's] (did-schema did_v2_go_forward_class_audit.md): the
            % Dabrowska bath rows stated in "osm" and "saturation" (the aCSF and
            % cutting solution, +dabrowska/dabrowska_mixtures.json) are not read
            % by the generic stage; each such bath is carried whole as v1
            % (carry-155) until the Dabrowska dataset map states their meaning.
            % The slices and tetanus runs below are minted from the v1 bath
            % stimulators, so they do not depend on the baths converting.
            expected = {};
            for k = 1:numel(testCase.Bodies)
                txt = testCase.Bodies{k};
                if ~contains(txt, '"stimulus_bath"'); continue; end
                b = jsondecode(txt);
                if ~isempty(ndi.migrate.internal.bathUnreadUnitRows(b))
                    expected{end+1} = b.base.id; %#ok<AGROW>
                end
            end
            r = testCase.Result.secondPass.deferred;
            assertNotEmpty(testCase, r, 'resolveDeferred reported nothing');
            fprintf(['\n  BATHS IN OSM / SATURATION (Dab)\n    deferrals read %d; v1 baths ' ...
                'with such a row %d; carried as v1 %d\n'], r.deferred_seen, ...
                numel(expected), r.baths_carried_unread_unit);
            verifyGreaterThan(testCase, numel(expected), 0, ...
                'no Dab bath has an osm or saturation row: this checks nothing');
            verifyEqual(testCase, r.baths_carried_unread_unit, numel(expected));
            verifyEqual(testCase, sort({r.carry_rows.id}), sort(expected));
            verifyTrue(testCase, all(strcmp({r.carry_rows.row}, 'carry-155')));
            dst = destinationBodies(testCase.Result.destination);
            stamp = containers.Map('KeyType', 'char', 'ValueType', 'char');
            for k = 1:numel(dst)
                b = dst{k};
                if strcmp(b.document_class.class_name, 'stimulus_bath')
                    stamp(b.base.id) = char(b.document_class.schema_version);
                end
            end
            for k = 1:numel(expected)
                verifyTrue(testCase, isKey(stamp, expected{k}) ...
                    && strcmp(stamp(expected{k}), 'did_v1'), ...
                    sprintf('bath %s is not stored as a v1 document', expected{k}));
            end
        end

        function testTheGenericStageLeavesTheSlicesToTheMap(testCase)
            % [sliceTetanus to Dab map] (Jess Haley, 2026-10-25): the generic
            % stage makes no slice and no tetanus run, and carries the 635
            % before/after approach documents whole as v1 (carry-165).
            verifyFalse(testCase, isfield(testCase.Result.secondPass, 'sliceTetanus'), ...
                'ndi.migrate.local still reports a slice / tetanus step');
            dst = destinationBodies(testCase.Result.destination);
            tet = 0; slices = 0; approachV1 = 0; approachOther = 0;
            for k = 1:numel(dst)
                b = dst{k};
                cn = b.document_class.class_name;
                if strcmp(cn, 'manipulation') && isfield(b, 'statement') ...
                        && isfield(b.statement, 'variable') && isfield(b.statement.variable, 'node') ...
                        && strcmp(b.statement.variable.node, 'EMPTY:0000358')
                    tet = tet + 1;
                elseif strcmp(cn, 'entity') && isfield(b, 'entity') && isfield(b.entity, 'type') ...
                        && ndi.v2.vocabIs('entity_type', b.entity.type, 'tissue') ...
                        && startsWith(ndi.v2.notesOf(b.entity), 'brain slice')
                    slices = slices + 1;
                elseif strcmp(cn, 'openminds_stimulus')
                    if strcmp(char(b.document_class.schema_version), 'did_v1')
                        approachV1 = approachV1 + 1;
                    else
                        approachOther = approachOther + 1;
                    end
                end
            end
            fprintf(['\n  GENERIC STAGE (Dab), before the map: %d document(s); tetanus ' ...
                'manipulations %d, slices %d; openminds_stimulus as v1 %d, other %d\n'], ...
                numel(dst), tet, slices, approachV1, approachOther);
            verifyGreaterThan(testCase, numel(dst), 0, 'the generic destination read zero documents');
            verifyEqual(testCase, [tet slices approachV1 approachOther], [0 0 635 0]);
        end

        function testTheMapReproducesTheSecondPassStep(testCase)
            % The census the second-pass step printed on the Dab corpus before
            % the move (run 42163755800, NDI-matlab c94cc5ed1, "SLICE /
            % TETANUS (Dabrowska)"), field by field: generic stage + map must
            % reproduce it ([sliceTetanus to Dab map]). The migrated-document
            % denominator is printed, not pinned: the map reads the finished
            % database, the step read the batch part-way through the pass.
            r = testCase.MapReport;
            assertNotEmpty(testCase, r, 'the Dabrowska map did not run');
            verifyGreaterThan(testCase, r.migrated_documents_read, 0, ...
                'the map read zero migrated documents');
            before = struct( ...
                'v1_documents_read', 14644, 'epoch_index_entries', 1605, ...
                'stimulators', 202, 'slice_bath_stimulators', 202, ...
                'stimulators_not_a_slice_bath', 0, 'stimulators_animal_mismatch', 0, ...
                'slices', 203, 'new_animals', 1, 'epochs_on_a_nested_date', 11, ...
                'new_animal_strain_assertions_copied', 0, ...
                'epoch_statements_examined', 5209, 'epoch_statements_matched', 5183, ...
                'epoch_statements_unmatched', 26, ...
                'unanchored_statements_examined', 400, 'unanchored_statements_matched', 398, ...
                'unanchored_statements_ambiguous', 2, ...
                'element_relations_examined', 202, 'element_relations_matched', 201, ...
                'element_relations_ambiguous', 1, ...
                'approach_labels', 635, 'runs_examined', 56, ...
                'tetanus_manipulations', 56, 'tetanus_on_new_animal', 1, ...
                'tetanus_with_target_region', 55, 'tetanus_without_target_region', 1, ...
                'tetanus_with_parameters', 9, 'tetanus_without_parameters', 47, ...
                'labels_rebuilt', 635, 'labels_not_rebuilt', 0, 'approach_labels_removed', 635, ...
                'treatment_manipulations_found', 0, ...
                'documents_minted', 519, 'minted_folded', 519, 'minted_quarantined', 0, ...
                'documents_reattributed', 5782, 'documents_removed', 635, ...
                'removals_withheld_still_referenced', 0, ...
                'reattributions_applied', 5782, 'removals_applied', 635, ...
                'replacements_refused_have_files', 0);
            byClass = struct('formulation_manipulation', 433, 'term_observation', 398, ...
                'term_manipulation', 1592, 'voltage_observation', 1579, ...
                'current_observation', 1579);
            f = fieldnames(before);
            for k = 1:numel(f)
                verifyEqual(testCase, r.(f{k}), before.(f{k}), sprintf( ...
                    '%s: the map gives %g, the second-pass step gave %g', ...
                    f{k}, r.(f{k}), before.(f{k})));
            end
            got = r.reattributed_by_class;
            cls = union(fieldnames(got), fieldnames(byClass));
            for k = 1:numel(cls)
                a = 0; if isfield(got, cls{k}); a = got.(cls{k}); end
                e = 0; if isfield(byClass, cls{k}); e = byClass.(cls{k}); end
                verifyEqual(testCase, a, e, sprintf('re-attributed %s', cls{k}));
            end
            verifyEqual(testCase, r.database_documents_after, ...
                r.database_documents_before + r.minted_folded - r.removals_applied, ...
                'the mapped database does not hold before + minted - removed documents');
        end

        function testSlicesAndTetanusRunsRebuildEveryApproachLabel(testCase)
            % DECIDED BY JESS HALEY 2026-10-21 (dabrowska/V2_decisions.md):
            % each brain slice is an entity `part_of` its animal; one
            % optogenetic-tetanus manipulation per recording run, on the
            % slice, timed by a RELATIVE reference on exp_global_time
            % (relative_to the last "before" epoch; start = that recording's
            % length, duration = the gap to the first "after" recording);
            % the 635 before/after approach documents are dropped because the
            % window rebuilds them (T6). The Nov 28 run filed under the Dec 02
            % animal is its own animal, slice and run.
            %
            % THE LOSSLESS CHECK IS DONE HERE FROM THE DATABASE, not from the
            % pass's report: every v1 label is rebuilt from the windows the
            % database holds and the v1 epoch times.
            r = testCase.MapReport;
            assertNotEmpty(testCase, r, 'the Dabrowska map did not run');
            fprintf(['\n  SLICE / TETANUS REPORT\n    tetanus %d, slices %d, new animals %d, ' ...
                'labels rebuilt %d/%d, approach docs removed %d, minted quarantined %d\n'], ...
                r.tetanus_manipulations, r.slices, r.new_animals, r.labels_rebuilt, ...
                r.approach_labels, r.approach_labels_removed, r.minted_quarantined);
            verifyEqual(testCase, r.minted_quarantined, 0, 'a minted slice/tetanus document quarantined');
            verifyEqual(testCase, r.approach_labels, 635, 'the pass did not read 635 approach labels');
            verifyEqual(testCase, r.tetanus_manipulations, 56, 'expected 56 tetanus runs (55 stimulators + the Nov 28 run)');
            verifyEqual(testCase, r.slices, 203, 'expected 203 slices (202 bath stimulators + the Nov 28 slice)');
            verifyEqual(testCase, r.new_animals, 1, 'expected one new animal (the Nov 28 run)');
            verifyEqual(testCase, [r.tetanus_with_parameters r.tetanus_without_parameters], [9 47], ...
                'expected 9 runs whose TLS folder states 10 Hz / 20 s and 47 plain TLS');
            verifyEqual(testCase, [r.tetanus_with_target_region r.tetanus_without_target_region], [55 1], ...
                'expected a target region on every run but the Nov 28 one (no treatment record)');
            verifyEqual(testCase, r.labels_not_rebuilt, 0, 'the pass itself could not rebuild a label');

            % the MAPPED copy (generic stage + Dabrowska map)
            migrated = destinationBodies( ...
                ndi.database.implementations.database.did2sqlite.FILEIN( ...
                fullfile(testCase.MappedRoot, '.ndi')));
            byId = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for k = 1:numel(migrated)
                byId(migrated{k}.base.id) = migrated{k};
            end
            % did-schema #88 writes no base.name, so the minted documents are
            % told apart by what they ARE (ndi.migrate.internal.sliceTetanus):
            %   tetanus  a manipulation whose variable is EMPTY:0000358
            %            "optogenetic tetanus stimulation"
            %   slice    a tissue entity described as a "brain slice ..."
            %   part_of  a part_of relation whose child is such a slice
            %   animal   an organism described as filed under another animal
            %            ("... nested inside the other animal's date folder")
            tet = {}; sliceIds = {}; animals = 0; survivors = 0;
            for k = 1:numel(migrated)
                b = migrated{k};
                cn = b.document_class.class_name;
                if strcmp(cn, 'manipulation') && isfield(b, 'statement') ...
                        && isfield(b.statement, 'variable') && isfield(b.statement.variable, 'node') ...
                        && strcmp(b.statement.variable.node, 'EMPTY:0000358')
                    tet{end+1} = b; %#ok<AGROW>
                elseif strcmp(cn, 'entity') && isfield(b, 'entity') && isfield(b.entity, 'type')
                    desc = '';
                    desc = ndi.v2.notesOf(b.entity);   % [one free-text field: notes]
                    if ndi.v2.vocabIs('entity_type', b.entity.type, 'tissue') && startsWith(desc, 'brain slice')
                        sliceIds{end+1} = b.base.id; %#ok<AGROW>
                    elseif ndi.v2.vocabIs('entity_type', b.entity.type, 'organism') && contains(desc, 'nested inside')
                        animals = animals + 1;
                    end
                end
                if strcmp(cn, 'openminds_stimulus')
                    survivors = survivors + 1;
                end
            end
            slices = numel(sliceIds);
            sliceParts = 0;
            for k = 1:numel(migrated)
                b = migrated{k};
                if strcmp(b.document_class.class_name, 'directed_relation') ...
                        && ndi.v2.vocabIs('relation', b.directed_relation.relation, 'part_of') ...
                        && any(strcmp(edgeOf(b, 'child_id'), sliceIds))
                    sliceParts = sliceParts + 1;
                end
            end
            fprintf(['  IN THE DATABASE: tetanus manipulations %d, slices %d (part_of %d), ' ...
                'new animals %d, openminds_stimulus left %d\n'], numel(tet), slices, ...
                sliceParts, animals, survivors);
            verifyEqual(testCase, [numel(tet) slices sliceParts animals survivors], [56 203 203 1 0]);

            % ---- the windows, as stored ---------------------------------
            % #88: the window is the manipulation's time_reference_id, a
            % relative_time_reference whose referent_id is the EPOCH entity
            % (its local_identifier the v1 epoch id, its session_id edge the
            % session)
            win = struct('stim', {}, 'session', {}, 'epoch', {}, 'start', {}, 'duration', {});
            for k = 1:numel(tet)
                m = tet{k};
                ref = byId(edgeOf(m, 'time_reference_id'));
                ep = byId(edgeOf(ref, 'referent_id'));
                v = ref.relative_time_reference.value;
                ndi.unittest.migrate.verifyClock(testCase, v.clock, 'exp_global_time');   % by node [clock terms get nodes]
                win(end+1) = struct('stim', edgeOf(m, 'instrument_id'), ...
                    'session', edgeOf(ep, 'session_id'), 'epoch', ep.entity.local_identifier, ...
                    'start', v.start.seconds, 'duration', v.duration.seconds); %#ok<AGROW>
            end

            % ---- the v1 epoch times and labels ---------------------------
            t0t1 = containers.Map(); labels = {};
            for k = 1:numel(testCase.Bodies)
                txt = testCase.Bodies{k};
                if contains(txt, '"daqreader_mfdaq_epochdata_ingested"') && contains(txt, 'exp_global_time')
                    b = jsondecode(txt);
                    et = b.daqreader_epochdata_ingested.epochtable;
                    i = find(strcmp(cellstr(et.epochclock), 'exp_global_time'), 1);
                    t0t1([b.base.session_id '|' b.epochid.epochid]) = [et.t0_t1(1, i) et.t0_t1(2, i)];
                elseif contains(txt, '"openminds_stimulus"') && contains(txt, 'optogenetic tetanus')
                    b = jsondecode(txt);
                    labels{end+1} = b; %#ok<AGROW>
                end
            end
            rebuilt = 0; wrong = 0;
            for k = 1:numel(labels)
                b = labels{k};
                d = b.depends_on; if iscell(d); d = [d{:}]; end
                stim = d(strcmp({d.name}, 'stimulus_element_id')).value;
                t = t0t1([b.base.session_id '|' b.epochid.epochid]);
                truth = 'before';
                if endsWith(b.openminds.fields.name, 'after optogenetic tetanus'); truth = 'after'; end
                best = Inf; pred = '';
                for w = 1:numel(win)
                    if ~strcmp(win(w).stim, stim) || ~strcmp(win(w).session, b.base.session_id); continue; end
                    ref = t0t1([win(w).session '|' win(w).epoch]);
                    ws = ref(1) + win(w).start / 86400;
                    we = ws + win(w).duration / 86400;
                    dist = abs(t(1) - ws);
                    if dist < best
                        best = dist;
                        if t(2) <= ws + 1e-3/86400; pred = 'before';
                        elseif t(1) >= we - 1e-3/86400; pred = 'after';
                        else; pred = ''; end
                    end
                end
                if strcmp(pred, truth); rebuilt = rebuilt + 1; else; wrong = wrong + 1; end
            end
            fprintf('  LABELS REBUILT FROM THE DATABASE WINDOWS: %d/%d (wrong %d)\n', ...
                rebuilt, numel(labels), wrong);
            verifyEqual(testCase, [numel(labels) rebuilt], [635 635], ...
                'not every before/after label rebuilds from the stored tetanus windows');
        end

        function testEveryOntologyRowIsCarried(testCase)
            % INVERTED from the fan-out test. Decided by Jess Haley,
            % 2026-10-30 [table rows carried as v1] (did-schema
            % V_eta_go_forward_class_audit.md): the generic migration carries
            % every v1 `ontologyTableRow` whole as v1; it resolves no subject
            % and fans out no statements. So every source row is still a
            % table row in the destination, under its own id. The DENOMINATOR
            % is asserted first: a carry test that read zero source rows
            % would be vacuous, and Dab is the corpus that holds them.
            nSrc = 0;
            srcIds = {};
            for k = 1:numel(testCase.Bodies)
                j = jsondecode(testCase.Bodies{k});
                if isfield(j,'document_class') && isfield(j.document_class,'class_name') ...
                        && strcmp(j.document_class.class_name, 'ontologyTableRow')
                    nSrc = nSrc + 1;
                    srcIds{end+1} = j.base.id; %#ok<AGROW>
                end
            end

            dst = destinationBodies(testCase.Result.destination);
            rows = [findAllByClass(dst, 'ontologyTableRow'), ...
                    findAllByClass(dst, 'ontology_table_row')];
            dstIds = cellfun(@(b) b.base.id, rows, 'UniformOutput', false);
            nCarried = sum(ismember(srcIds, dstIds));

            fprintf(['\n  ONTOLOGY TABLE ROWS (Dab, [table rows carried as v1])\n' ...
                     '    DENOMINATOR: %d source `ontologyTableRow` document(s)\n' ...
                     '    carried as a table row, same id:   %d\n' ...
                     '    table rows in the destination:     %d\n'], ...
                nSrc, nCarried, numel(rows));

            verifyGreaterThan(testCase, nSrc, 0, ...
                ['no `ontologyTableRow` documents in the Dab corpus -- the ' ...
                 'carry test would be vacuous, and Dab is the corpus that ' ...
                 'is supposed to hold them']);
            verifyEqual(testCase, nCarried, nSrc, ...
                ['[table rows carried as v1]: every source ontologyTableRow ' ...
                 'must reach the destination as a table row under its own id']);
            count = testCase.Result.secondPass.ontologyRowsCarried;
            verifyNotEmpty(testCase, count, ...
                'the second-pass table-row count did not run');
            verifyEqual(testCase, count.v1_ontology_rows, nSrc);
            verifyEqual(testCase, count.rows_not_carried, 0);
        end

    end
end

% ===================== harness ============================================

function tf = etaEnabled()
v = getenv('NDI_TEST_ETA');
tf = ~isempty(v) && ~any(strcmpi(v, {'0','false','no'}));
end

function corpusDir = ensureDabCorpus()
%ENSUREDABCORPUS Download (once) and extract Dab.zip.
%   Same URL shape and cache layout as the PRED / 20211116 / Soph helpers.
%   Dab.zip is ~35 MB, so the download is quick; the migration at scale is
%   why this is a dispatched job.
corpusURL = 'https://ndi-programming-development.s3.us-east-1.amazonaws.com/Dab.zip';
cacheRoot = fullfile(tempdir(), 'ndi-corpus-Dab');
corpusDir = fullfile(cacheRoot, 'Dab');
if isfolder(corpusDir) && ~isempty(dir(fullfile(corpusDir, '*.json')))
    return;
end
if ~isfolder(cacheRoot); mkdir(cacheRoot); end
zipPath = fullfile(cacheRoot, 'Dab.zip');
if ~isfile(zipPath)
    websave(zipPath, corpusURL);
end
unzip(zipPath, cacheRoot);
if isfolder(corpusDir) && ~isempty(dir(fullfile(corpusDir, '*.json')))
    return;
end
% Fallback: the zip may extract the json documents to cacheRoot directly, or
% under a differently-named single subdirectory. Find the directory that
% actually holds *.json and use it, rather than skipping on a name guess.
if ~isempty(dir(fullfile(cacheRoot, '*.json')))
    corpusDir = cacheRoot;
    return;
end
sub = dir(cacheRoot);
sub = sub([sub.isdir] & ~ismember({sub.name}, {'.','..'}));
for k = 1:numel(sub)
    candidate = fullfile(cacheRoot, sub(k).name);
    if ~isempty(dir(fullfile(candidate, '*.json')))
        corpusDir = candidate;
        return;
    end
end
error('ndi:corpus:noDir', ...
    'Dab.zip did not extract any directory holding *.json under %s', cacheRoot);
end

function bodies = readCorpusBodies(corpusDir)
%READCORPUSBODIES Every v1 document in the corpus, as JSON text.
%   `._` sidecars are macOS resource forks the zip carries; skipping them is
%   what did2.validate.sourceCensus's own reader does.
files = dir(fullfile(corpusDir, '*.json'));
files = files(~startsWith({files.name}, '._'));
bodies = cell(numel(files), 1);
for k = 1:numel(files)
    bodies{k} = fileread(fullfile(files(k).folder, files(k).name));
end
end

function bodies = keepDabrowskaBodies(bodies)
%KEEPDABROWSKABODIES Drop corpus B out of Dab.zip, by session, at read time.
%   Dab.zip bundles the Dabrowska dataset with the whole of corpus B (the
%   Fitzpatrick tree-shrew dataset `2013_treeshrew_LGNctx`). Keep the documents
%   whose base.session_id is the `dabrowska_2025` dataset session or one of the
%   sessions its `session_in_a_dataset` documents list; drop the rest. Selects
%   POSITIVELY (what is Dabrowska's), so a third dataset added to the zip later
%   would be dropped rather than silently tested. Errors when the dataset
%   session is absent: a filter that keeps nothing is a defect, not a skip.
datasetRef = 'dabrowska_2025';
decoded = cell(size(bodies));
sessionOf = cell(size(bodies));
for k = 1:numel(bodies)
    j = jsondecode(bodies{k});
    decoded{k} = j;
    sessionOf{k} = '';
    if isfield(j, 'base') && isfield(j.base, 'session_id')
        sessionOf{k} = j.base.session_id;
    end
end
keep = {};
for k = 1:numel(decoded)
    j = decoded{k};
    if isfield(j, 'document_class') && strcmp(j.document_class.class_name, 'session') ...
            && isfield(j, 'session') && isfield(j.session, 'reference') ...
            && strcmp(j.session.reference, datasetRef)
        keep{end+1} = sessionOf{k}; %#ok<AGROW>
    end
end
if isempty(keep)
    error('ndi:corpus:noDabrowskaDataset', ...
        'Dab.zip holds no `session` document with reference "%s"', datasetRef);
end
for k = 1:numel(decoded)
    j = decoded{k};
    if isfield(j, 'document_class') ...
            && strcmp(j.document_class.class_name, 'session_in_a_dataset') ...
            && any(strcmp(sessionOf{k}, keep)) ...
            && isfield(j, 'session_in_a_dataset')
        keep{end+1} = j.session_in_a_dataset.session_id; %#ok<AGROW>
    end
end
keep = unique(keep);
fprintf('  Dabrowska sessions kept: %s\n', strjoin(keep, ', '));
bodies = bodies(ismember(sessionOf, keep));
end

function buildV1Sqlite(tmpFile, bodies)
%BUILDV1SQLITE A did_v1 sqlite database holding BODIES.
%   The shape is `docs(doc_id, doc_idx, json_code, timestamp)` because that is
%   what did2.convert.readers.sqliteV1 issues (`SELECT json_code FROM docs`),
%   the same columns the real legacy backend writes.
dbid = mksqlite(0, 'open', tmpFile);
cleanup = onCleanup(@() mksqlite(dbid, 'close')); %#ok<NASGU>
mksqlite(dbid, ['CREATE TABLE docs (' ...
    'doc_id    TEXT    NOT NULL UNIQUE, ' ...
    'doc_idx   INTEGER NOT NULL UNIQUE, ' ...
    'json_code TEXT, ' ...
    'timestamp NUMERIC, ' ...
    'PRIMARY KEY(doc_idx AUTOINCREMENT))']);
% BULK INSERT IN ONE TRANSACTION -- one fsync per row outside a transaction is
% pathological at scale (the Soph run #1 timeout). Throwaway fixture DB, so
% drop the per-write durability guarantees too.
mksqlite(dbid, 'PRAGMA synchronous = OFF');
mksqlite(dbid, 'PRAGMA journal_mode = MEMORY');
mksqlite(dbid, 'BEGIN TRANSACTION');
for k = 1:numel(bodies)
    docId = sprintf('id_%06d', k);
    mksqlite(dbid, ...
        'INSERT INTO docs (doc_id, doc_idx, json_code, timestamp) VALUES (?, ?, ?, ?)', ...
        docId, k, bodies{k}, 0);
end
mksqlite(dbid, 'COMMIT');
end

function bodies = destinationBodies(dstPath)
%DESTINATIONBODIES Every document in the destination, as structs, read ONCE.
db = did2.database.sqlitedb(dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
ids = db.allIds();
bodies = cell(1, numel(ids));
for k = 1:numel(ids)
    bodies{k} = db.get(ids{k}).toStruct();
end
end

function hits = findAllByClass(bodies, className)
hits = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if isfield(b,'document_class') && isfield(b.document_class,'class_name') ...
            && strcmp(b.document_class.class_name, className)
        hits{end+1} = b; %#ok<AGROW>
    end
end
end

function doc = findByClass(bodies, className)
doc = [];
hits = findAllByClass(bodies, className);
if ~isempty(hits); doc = hits{1}; end
end

function doc = largestSession(bodies)
%LARGESTSESSION The `session` document whose session holds the most documents.
counts = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(bodies)
    b = bodies{k};
    if isfield(b, 'base') && isfield(b.base, 'session_id') && ischar(b.base.session_id)
        sid = b.base.session_id;
        if isKey(counts, sid); counts(sid) = counts(sid) + 1; else; counts(sid) = 1; end
    end
end
doc = []; best = -1;
sessions = findAllByClass(bodies, 'session');
for k = 1:numel(sessions)
    sid = sessions{k}.base.session_id;
    n = 0;
    if isKey(counts, sid); n = counts(sid); end
    if n > best; best = n; doc = sessions{k}; end
end
end

function s = quarantineDiag(result)
if isempty(result.quarantine)
    s = ''; return;
end
n = numel(result.quarantine);
s = sprintf('%d document(s) quarantined; first %d:', n, min(5,n));
for i = 1:min(5,n)
    s = sprintf('%s\n    %s: %s', s, result.quarantine(i).class_name, ...
        result.quarantine(i).reason);
end
end

function s = resultDiag(result)
s = sprintf('[migrated %d, quarantined %d, edges %d] %s', ...
    result.summary.total, numel(result.quarantine), ...
    result.references.edges_examined, quarantineDiag(result));
end

function v = edgeOf(b, name)
%EDGEOF The value of one depends_on edge of a struct body, '' when absent.
v = '';
d = b.depends_on;
if iscell(d); d = [d{:}]; end
for k = 1:numel(d)
    if strcmp(d(k).name, name)
        if isfield(d(k), 'value'); v = d(k).value; else; v = d(k).document_id; end
        return;
    end
end
end
