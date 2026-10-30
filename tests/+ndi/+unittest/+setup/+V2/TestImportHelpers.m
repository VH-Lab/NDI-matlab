classdef TestImportHelpers < matlab.unittest.TestCase
%TESTIMPORTHELPERS The public pieces every V2 import shares (ndi.setup.V2).
%
%   The Haley import and the starter template both call these, so a new
%   import calls them too instead of copying them:
%     writeDataset        a dataset with its sessions linked, checked as one
%                         set; a session's study ids however the table holds
%                         them (cell2table unwraps a one-id cell to char)
%     checkTerms          every unregistered term of a run, listed, with the
%                         term-registry switches restored even on error
%     utcReference        a UTC time from a wall-clock time and a time zone
%     applyCorrection     the one correction function
%     sourceUnit          a source unit as its registered term, by spelling,
%                         label or CURIE
%     recordingDocuments  the five documents one recorded file needs
%
%   Needs did2.build (DID-matlab V2) and a did-schema #88 schema with a term
%   registry on DID_SCHEMA_PATH; without them the tests that build documents
%   are filtered, which test-import-v2.yml counts as a failure.

    properties
        Root
    end

    methods (TestMethodSetup)
        function fixture(testCase)
            testCase.Root = tempname;
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
        end
    end

    methods (Test)
        % ---- applyCorrection: needs nothing but MATLAB --------------------------
        function testACorrectionIsAppliedOnlyWhileTheSourceReadsWas(testCase)
            x = struct('key', 'probe', 'column', 'temperature_C', 'was', '21.5', ...
                'value', '22', 'reason', 'the probe was misread');
            [v, applied, note, line] = ndi.setup.V2.applyCorrection(x, '21.5', 's1 w1');
            testCase.verifyTrue(applied);
            testCase.verifyEqual(v, '22');
            testCase.verifyEqual(note, 'Corrected from 21.5: the probe was misread (correction probe)');
            testCase.verifyTrue(contains(line, '"21.5" -> "22"'), line);

            [v, applied, note, line] = ndi.setup.V2.applyCorrection(x, '30', 's1 w1');
            testCase.verifyFalse(applied, 'the source reads otherwise: refused');
            testCase.verifyEqual(v, '30', 'a refused correction leaves the value');
            testCase.verifyEmpty(note);
            testCase.verifyTrue(contains(line, 'left as it is'), line);

            n = struct('key', 'n', 'column', 'c', 'was', 3, 'value', 4, 'reason', 'r');
            [v, applied] = ndi.setup.V2.applyCorrection(n, 3, 'here');
            testCase.verifyTrue(applied);
            testCase.verifyEqual(v, 4, 'typed as the source value is');

            noWas = struct('key', 'k', 'column', 'c', 'value', 'x', 'reason', 'r');
            [~, applied, ~, line] = ndi.setup.V2.applyCorrection(noWas, 'y', 'here');
            testCase.verifyFalse(applied, 'a correction with no `was` cannot be checked');
            testCase.verifyTrue(contains(line, 'cannot be checked'), line);
        end

        % ---- utcReference ----------------------------------------------------------
        function testAHandWrittenInstantKeepsItsPrecision(testCase)
            testCase.needSchema();
            d = ndi.setup.V2.utcReference(datetime(2026, 1, 5, 10, 0, 0), 'America/New_York', ...
                'sid_test', 'Format', 'yyyy-MM-dd''T''HH:mm', 'Tolerance', [60 60]);
            j = jsonencode(d);
            testCase.verifyTrue(contains(j, '"utc":"2026-01-05T15:00:00.000Z"'), j);
            testCase.verifyTrue(contains(j, '"source_value":"2026-01-05T10:00"'), ...
                ['no seconds the source did not write: ' j]);
            testCase.verifyTrue(contains(j, '"source_timezone":"America/New_York"'), j);
            testCase.verifyTrue(contains(j, '"approximate":true'), j);
        end

        function testAWindowAcrossADaylightSavingChange(testCase)
            testCase.needSchema();
            % 8 March 2026, 01:00 -> 04:00 New York: the clocks say 3 h, it was 2 h
            d = ndi.setup.V2.utcReference(datetime(2026, 3, 8, 1, 0, 0), 'America/New_York', ...
                'sid_test', 'End', datetime(2026, 3, 8, 4, 0, 0));
            j = jsonencode(d);
            testCase.verifyTrue(contains(j, '"seconds":7200'), j);
            testCase.verifyTrue(contains(j, '"utc":"2026-03-08T08:00:00.000Z"'), ['the end: ' j]);
        end

        function testSourceTextAndDurationForARecordingStart(testCase)
            testCase.needSchema();
            d = ndi.setup.V2.utcReference(datetime(2026, 1, 5, 10, 0, 0), 'UTC', 'sid_test', ...
                'SourceText', '2026-01-05T10:00:00', 'Duration', 60);
            j = jsonencode(d);
            testCase.verifyTrue(contains(j, '"source_value":"2026-01-05T10:00:00"'), j);
            testCase.verifyTrue(contains(j, '"seconds":60'), j);
            testCase.verifyTrue(contains(j, '"approximate":false'), ['exact: ' j]);
        end

        % ---- sourceUnit ------------------------------------------------------------
        function testASourceUnitByItsSpellingLabelOrCurie(testCase)
            testCase.needRegistry();
            u = ndi.setup.V2.sourceUnit('mm');
            testCase.verifyEqual(u.node, 'om:millimetre', 'a decided spelling');
            u = ndi.setup.V2.sourceUnit('millimetre');
            testCase.verifyEqual(u.node, 'om:millimetre', 'any registered label');
            u = ndi.setup.V2.sourceUnit('Micrometre');
            testCase.verifyEqual(u.node, 'om:micrometre', 'a label in any case');
            testCase.verifyEqual(u.name, 'micrometre', 'written as the registry spells it');
            u = ndi.setup.V2.sourceUnit('om:nanometre');
            testCase.verifyEqual(u.node, 'om:nanometre', 'a CURIE');
            u = ndi.setup.V2.sourceUnit('furlongs per fortnight (not a registered unit)');
            testCase.verifyEmpty(u.node, 'an unknown spelling is kept, not guessed');
            testCase.verifyEqual(u.name, 'furlongs per fortnight (not a registered unit)');
            testCase.verifyEqual(ndi.setup.V2.sourceUnit(''), '', 'no unit: no term');
        end

        % ---- checkTerms ------------------------------------------------------------
        function testCheckTermsListsTermsAndRestoresTheSwitches(testCase)
            testCase.needRegistry();
            prevStrict = did2.schema.cache.strictMode('TermRegistry', true);
            testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prevStrict));
            prevCollect = did2.build.unregisteredTerms('-collect', false);
            testCase.addTeardown(@() did2.build.unregisteredTerms('-collect', prevCollect));
            name = 'import helpers test term that is not registered';
            [L, st] = ndi.setup.V2.checkTerms(@() unregisteredStatement(name), 'Print', false);
            testCase.verifyTrue(isstruct(st), 'the function''s own output comes back');
            testCase.verifyTrue(any(strcmp({L.name}, name)), 'the term is listed, not an error');
            testCase.verifyTrue(did2.schema.cache.strictMode('TermRegistry'), 'the error is back on');
            testCase.verifyFalse(did2.build.unregisteredTerms('-collecting'), 'collection is back off');

            testCase.verifyError(@() ndi.setup.V2.checkTerms(@() unregisteredStatement(name), ...
                'Print', false, 'Raise', true, 'ErrorId', 'ndi:test:terms'), 'ndi:test:terms');
            testCase.verifyTrue(did2.schema.cache.strictMode('TermRegistry'), 'restored after Raise');

            testCase.verifyError(@() ndi.setup.V2.checkTerms(@() error('ndi:test:inner', 'x'), ...
                'Print', false), 'ndi:test:inner', 'the function''s own error passes through');
            testCase.verifyTrue(did2.schema.cache.strictMode('TermRegistry'), 'restored after an error');
            testCase.verifyFalse(did2.build.unregisteredTerms('-collecting'));

            L = ndi.setup.V2.checkTerms(@() did2.build.term('', 'x'), 'Print', false);
            testCase.verifyEmpty(L, 'nothing written, nothing listed');
        end

        % ---- recordingDocuments ----------------------------------------------------
        function testOneRecordedFileInOneCall(testCase)
            testCase.needRegistry();
            file = fullfile(testCase.Root, 'rec_0001.mp4');
            fid = fopen(file, 'w'); fwrite(fid, uint8(1:32)); fclose(fid);
            sid = char(ndi.ido.unique_id());
            [docs, ids] = ndi.setup.V2.recordingDocuments('subject_id_test', file, ...
                datetime(2026, 1, 5, 10, 0, 0), 'UTC', sid, ...
                'ValueKind', 'intensity', ...
                'Variable', ndi.setup.V2.registeredTerm('', 'Imaging Signal Intensity'), ...
                'Method', ndi.setup.V2.registeredTerm('', 'brightfield imaging'), ...
                'Format', ndi.setup.V2.registeredTerm('', 'MPEG-4'), 'DatumType', 'uint8', ...
                'Duration', 60, 'Epoch', 's1_rec_0001');
            testCase.verifyNumElements(docs, 5);
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            testCase.verifyEqual(classes{1}, 'absolute_time_reference');
            testCase.verifyEqual(classes{3}, 'relative_time_reference');
            testCase.verifyEqual(classes{5}, 'opaque_body');
            testCase.verifyEqual(ids.time_reference_id, docs{1}.base.id);
            testCase.verifyEqual(ids.epoch_id, docs{2}.base.id);
            testCase.verifyEqual(ids.statement_id, docs{4}.base.id);
            testCase.verifyEqual(ids.body_id, docs{5}.base.id);
            st = jsonencode(docs{4});
            testCase.verifyTrue(contains(st, ids.time_reference_id) && ...
                contains(st, ids.epoch_time_reference_id), 'timed by both clocks');
            testCase.verifyTrue(contains(jsonencode(docs{2}), 's1_rec_0001'));
            [tf, where] = ndi.database.fun.externalFileLocation(docs{5}, 'body_data_0');
            testCase.verifyTrue(tf, 'the body names its file by location');
            testCase.verifyEqual(where, file);
            testCase.verifyEqual(double(docs{5}.files.file_info.locations.ingest), 0, 'never copied');
            testCase.verifyError(@() ndi.setup.V2.recordingDocuments('s', file, ...
                datetime(2026, 1, 5), 'UTC', sid, 'ValueKind', 'intensity'), ...
                'ndi:setup:V2:recordingOption');
        end

        % ---- writeDataset ----------------------------------------------------------
        function testWriteDatasetLinksSessionsWhateverHoldsTheirStudyIds(testCase)
            testCase.needRegistry();
            dsid = char(ndi.ido.unique_id());
            m = ndi.setup.V2.datasetMetadata(struct( ...
                'dataset', struct('name', 'Helpers dataset', 'description', 'A test.'), ...
                'studies', {{struct('key', 'study', 'name', 'Helpers study', ...
                'description', 'The one study.')}}), dsid, 'Studies', "include");
            study = m.ids('study');
            dsPath = fullfile(testCase.Root, 'dataset');
            s1 = char(ndi.ido.unique_id());
            s2 = char(ndi.ido.unique_id());
            sub = ndi.setup.V2.entityDocuments('subject', struct('local_identifier', 's1_w1'), ...
                struct(), 'SessionId', s1, 'Type', 'organism');
            % row 1 holds its study id as a one-id cell, row 2 as char -- what
            % cell2table gives depending on how the rows were made
            T = table({'s1'; 's2'}, {fullfile(testCase.Root, 's1'); fullfile(testCase.Root, 's2')}, ...
                {s1; s2}, {'Session one'; 'Session two'}, {{study}; study}, {sub; {}}, ...
                'VariableNames', {'local_identifier', 'path', 'session_id', 'name', ...
                'study_ids', 'documents'});
            out = ndi.setup.V2.writeDataset(dsPath, 'dataset', dsid, m.documents, T, ...
                'Progress', false);
            testCase.verifyEmpty(out.report.sessions.notInDataset, ...
                'both sessions are in the dataset through their study');
            testCase.verifyEqual(height(out.report.edges.dangling), 0);
            testCase.verifyEqual(sort(out.sessionReferences), {'s1', 's2'});
            testCase.verifyEqual(out.sessions.session_id, {s1; s2});
            testCase.verifyGreaterThan(out.documents, numel(m.documents));
            ds = ndi.dataset.dir(dsPath);
            notes = ds.session_notes();
            testCase.verifyTrue(contains(notes{1}, '0 ingested and 2 linked'), notes{1});
            S = ds.open_session(s1);
            e = ndi.entity.search(S, {'local_identifier', 's1_w1'});
            testCase.verifyNumElements(e, 1, 'the session''s own documents are in its folder');
            testCase.verifyEqual(S.reference, 's1');
            % the session folder has no study relation of its own: membership is the dataset's
            rel = S.database_search(ndi.v2.isaQuery('directed_relation'));
            testCase.verifyEmpty(rel);
            % each session's link is one direct relation to the dataset document,
            % method "database linking" with its Pathname (Jess Haley
            % 2026-10-29 [linked session link details]); no linked_session
            dsDoc = m.documents(cellfun(@(d) strcmp(ndi.v2.kindOf(d), 'dataset'), m.documents));
            sids = {s1, s2};
            refs = {'s1', 's2'};
            for k = 1:2
                q = ndi.query('', 'isa', 'directed_relation', '') & ...
                    ndi.query('', 'depends_on', 'child_id', sids{k});
                rels = ds.database_search(q);
                links = cellfun(@(r) ndi.v2.sessionLinkOf(r), rels, 'UniformOutput', false);
                links = links(cellfun(@(x) strcmp(x.kind, 'linked'), links));
                links = [links{:}];
                testCase.verifyNumElements(links, 1, 'one linking relation per session');
                if isempty(links), continue; end
                testCase.verifyEqual(links(1).parent_id, dsDoc{1}.base.id);
                testCase.verifyEqual(links(1).software_class, 'ndi.session.dir');
                testCase.verifyEqual(links(1).path, ...
                    ndi.v2.linkPath(fullfile(testCase.Root, refs{k}), dsPath));
            end
            testCase.verifyEmpty(ds.database_search(ndi.query('', 'isa', 'linked_session', '')));
        end

        function testASessionOfANestedStudyIsInTheDataset(testCase)
            % Jess Haley 2026-10-23 [nested studies]: a study may be included_in
            % a parent study (Haley #144); its sessions are in the dataset, both
            % for the write check and for ndi.dataset's listing
            testCase.needRegistry();
            dsid = char(ndi.ido.unique_id());
            m = ndi.setup.V2.datasetMetadata(struct( ...
                'dataset', struct('name', 'Helpers dataset', 'description', 'A test.'), ...
                'studies', {{struct('key', 'parent', 'name', 'Parent study', ...
                'description', 'Holds the other.'), struct('key', 'child', 'name', ...
                'Child study', 'description', 'Inside the parent.', 'included_in', 'parent')}}), ...
                dsid, 'Studies', "include");
            dsPath = fullfile(testCase.Root, 'dataset');
            s1 = char(ndi.ido.unique_id());
            T = table({'s1'}, {fullfile(testCase.Root, 's1')}, {s1}, {m.ids('child')}, ...
                'VariableNames', {'local_identifier', 'path', 'session_id', 'study_ids'});
            out = ndi.setup.V2.writeDataset(dsPath, 'dataset', dsid, m.documents, T, ...
                'Progress', false);
            testCase.verifyEmpty(out.report.sessions.notInDataset, ...
                'session -> child study -> parent study -> dataset');
            ds = ndi.dataset.dir(dsPath);
            [refs, ids] = ds.session_list();
            testCase.verifyEqual(numel(refs), 1, 'the one session is listed');
            testCase.verifyTrue(ismember('s1', refs));
            testCase.verifyTrue(ismember(s1, ids));
        end

        function testWriteDatasetIsStrictByDefault(testCase)
            testCase.needRegistry();
            dsid = char(ndi.ido.unique_id());
            m = ndi.setup.V2.datasetMetadata(struct( ...
                'dataset', struct('name', 'Helpers dataset', 'description', 'A test.'), ...
                'studies', {{struct('key', 'study', 'name', 'Helpers study', ...
                'description', 'The one study.')}}), dsid, 'Studies', "include");
            dsPath = fullfile(testCase.Root, 'dataset');
            s1 = char(ndi.ido.unique_id());
            T = table({'s1'}, {fullfile(testCase.Root, 's1')}, {s1}, {'no_such_study_id'}, ...
                'VariableNames', {'local_identifier', 'path', 'session_id', 'study_ids'});
            testCase.verifyError(@() ndi.setup.V2.writeDataset(dsPath, 'dataset', dsid, ...
                m.documents, T, 'Progress', false), 'ndi:setup:V2:datasetCheckFailed');
            testCase.verifyFalse(isfolder(fullfile(testCase.Root, 's1', '.ndi')), ...
                'no session folder was written');
            T.session_id = {''};
            testCase.verifyError(@() ndi.setup.V2.writeDataset(dsPath, 'dataset', dsid, ...
                m.documents, T, 'Progress', false), 'ndi:setup:V2:badSessionTable');
        end
    end

    methods
        function needBuild(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
        end

        function needSchema(testCase)
            % did2.build checks against the schema, so a document can only be
            % built where a V_eta schema set is (DID_SCHEMA_PATH, or a
            % did-schema checkout beside DID-matlab), as this file's header says
            testCase.needBuild();
            testCase.assumeTrue(did2.schema.cache.shared().hasClass('entity'), ...
                'no V_eta schema set (did-schema #88, `entity`) where did2.schema.cache looks');
        end

        function needRegistry(testCase)
            testCase.needBuild();
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')) ...
                && isfile(ndi.v2.schemaFile(schemaPath, 'term_registry_meta.json')), ...
                'DID_SCHEMA_PATH does not hold a did-schema #88 schema with a term registry');
        end
    end
end

function st = unregisteredStatement(name)
% a statement whose variable the registry does not hold
arguments
    name {mustBeText}
end
st = did2.build.statement('observation', 'subject_id_test', ...
    did2.build.term('', name), did2.build.valueCell('temperature', 21.5), ...
    'TimeReferenceIds', {'time_reference_id_test'}, 'SessionId', 'session_id_test', 'ValueKind', 'temperature');
end
