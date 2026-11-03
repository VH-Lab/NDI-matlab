classdef TestSpikeParametersMigrated < matlab.unittest.TestCase
%TESTSPIKEPARAMETERSMIGRATED ndi.app.spikeextractor / spikesorter find and
%   read their named parameter sets in a migrated session (#1053).
%
%   Migration folds a v1 spike_extraction_parameters or sorting_parameters
%   document into a v2 `method` document (DID-matlab
%   +migrators_j/private/jMethodParameters.m): same id, the preset name in
%   `method.name` (Jess Haley 2026-10-30 [preset name stays on method],
%   did-schema did_v2_go_forward_class_audit.md), no `base.name`, and the
%   settings as `method.parameters`, four of the extraction settings under
%   new names (jSpikeExtractionSettings.m). find_appdoc searched only
%   `base.name` + the v1 class, so it found nothing.
%
%   THE FIXTURE IS MIGRATED HERE, by DID-matlab's own converter
%   (did2.convert.v1_to_v2), from the bodies NDI's writer makes: the
%   templates' fields and defaults, as DID-matlab's
%   testMigratorsJMethodParams transcribes them. Both presets are named
%   'default', so the lookup must tell an extraction method from a sorting
%   method by its parameters. The app block names no OS or interpreter: one
%   that does is carried whole as v1 ([small unread settings] (1)) and keeps
%   its base.name, which the v1 lookup already finds.
%
%   Filtered (never passed) when did2.convert or a v2 schema with `entity`
%   is missing.

    properties
        Dir
        Session
        ExtractionId
        SortingId
    end

    methods (TestClassSetup)
        function needV2(testCase)
            testCase.assumeTrue(~isempty(which('did2.convert.v1_to_v2')), ...
                'did2.convert (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a v2 schema with `entity`');
        end
    end

    methods (TestMethodSetup)
        function makeMigratedSession(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
            sid = ndi.ido.unique_id();
            testCase.ExtractionId = ndi.ido.unique_id();
            testCase.SortingId = ndi.ido.unique_id();
            docs = {};
            for v1 = {extractionBody(testCase.ExtractionId, 'default', sid), ...
                    sortingBody(testCase.SortingId, 'default', sid)}
                out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'did_v2');
                testCase.assertEmpty(out.quarantine, 'fixture: the migration quarantined a body');
                docs = [docs, cellfun(@(d) d.toStruct(), out.migrated, ...
                    'UniformOutput', false)]; %#ok<AGROW>
            end
            % the fixture is the migrated shape: two `method` documents with
            % the v1 ids, the name in method.name and no base.name
            for id = {testCase.ExtractionId, testCase.SortingId}
                m = docs(cellfun(@(d) strcmp(d.base.id, id{1}), docs));
                testCase.assertNumElements(m, 1, 'fixture: the migrated method is missing');
                testCase.assertEqual(char(m{1}.document_class.class_name), 'method');
                testCase.assertEqual(char(m{1}.method.name), 'default');
                testCase.assertFalse(isfield(m{1}.base, 'name') && ~isempty(m{1}.base.name), ...
                    'fixture: a migrated method writes no base.name');
            end
            testCase.Session = ndi.setup.V2.createSession(testCase.Dir, 'migrated', ...
                'SessionId', sid, 'Documents', docs, 'Validate', false);
        end
    end

    methods (Test)

        function testExtractionPresetIsFoundAndRead(testCase)
            se = ndi.app.spikeextractor(testCase.Session);
            d = se.find_appdoc('extraction_parameters', 'default');
            testCase.assertNumElements(d, 1, ...
                'exactly the extraction method, not the sorting method of the same name');
            testCase.verifyEqual(d{1}.id(), testCase.ExtractionId);

            p = se.extraction_parameters(d{1});
            want = extractionSettings();
            for f = fieldnames(want)'
                testCase.assertTrue(isfield(p, f{1}), sprintf('%s not rebuilt', f{1}));
                if ischar(want.(f{1}))
                    testCase.verifyEqual(char(p.(f{1})), want.(f{1}), f{1});
                else
                    testCase.verifyEqual(double(p.(f{1})), want.(f{1}), ...
                        'AbsTol', 1e-12, f{1});
                end
            end
            testCase.verifyTrue(se.isvalid_appdoc_struct('extraction_parameters', p));
            % the filter the extraction would use
            fs = se.makefilterstruct(d{1}, 30000);
            testCase.verifyNotEmpty(fs);
        end

        function testSortingPresetIsFoundAndRead(testCase)
            ss = ndi.app.spikesorter(testCase.Session);
            d = ss.find_appdoc('sorting_parameters', 'default');
            testCase.assertNumElements(d, 1, ...
                'exactly the sorting method, not the extraction method of the same name');
            testCase.verifyEqual(d{1}.id(), testCase.SortingId);
            p = ss.sorting_parameters(d{1});
            want = sortingSettings();
            for f = fieldnames(want)'
                testCase.verifyEqual(double(p.(f{1})), want.(f{1}), f{1});
            end
        end

        function testAnotherNameIsNotFound(testCase)
            se = ndi.app.spikeextractor(testCase.Session);
            testCase.verifyEmpty(se.find_appdoc('extraction_parameters', 'other'));
            ss = ndi.app.spikesorter(testCase.Session);
            testCase.verifyEmpty(ss.find_appdoc('sorting_parameters', 'other'));
        end

        function testAV1PresetIsStillFound(testCase)
            % a preset the app writes now (v1 template, base.name) beside the
            % migrated ones: both shapes are found by their own name
            se = ndi.app.spikeextractor(testCase.Session);
            s = extractionSettings();
            s.threshold_parameter = -5;
            doc = se.struct2doc('extraction_parameters', s, 'fresh');
            doc = doc.set_session_id(testCase.Session.id());
            testCase.Session.database_add(doc);
            d = se.find_appdoc('extraction_parameters', 'fresh');
            testCase.assertNumElements(d, 1);
            testCase.verifyEqual(d{1}.id(), doc.id());
            testCase.verifyEqual(se.extraction_parameters(d{1}).threshold_parameter, -5);
            testCase.verifyNumElements(se.find_appdoc('extraction_parameters', 'default'), 1);
        end
    end
end

% ---- the v1 bodies NDI's writer makes (DID-matlab testMigratorsJMethodParams)

function v1 = extractionBody(id, name, sessionId)
v1 = struct();
v1.document_class = struct('class_name', 'spike_extraction_parameters', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'app',  'class_version', '1.0.0')]);
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', id, 'session_id', sessionId, 'name', name, ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.app = struct('name', 'ndi_app_spikeextractor', 'version', '1.2.3', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab');
v1.spike_extraction_parameters = extractionSettings();
end

function s = extractionSettings()
% spike_extraction_parameters.json's defaults
s = struct( ...
    'center_range_time',   0.0005, ...
    'overlap',             0.5, ...
    'read_time',           30, ...
    'refractory_time',     0.001, ...
    'spike_start_time',    -0.00045, ...
    'spike_end_time',      0.001, ...
    'do_filter',           1, ...
    'filter_type',         'cheby1high', ...
    'filter_low',          0, ...
    'filter_high',         300, ...
    'filter_order',        4, ...
    'filter_ripple',       0.8, ...
    'threshold_method',    'standard_deviation', ...
    'threshold_parameter', -4, ...
    'threshold_sign',      -1);
end

function v1 = sortingBody(id, name, sessionId)
v1 = struct();
v1.document_class = struct('class_name', 'sorting_parameters', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'app',  'class_version', '1.0.0')]);
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', id, 'session_id', sessionId, 'name', name, ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.app = struct('name', 'ndi_app_spikesorter', 'version', '1.2.3', 'url', '');
v1.sorting_parameters = sortingSettings();
end

function s = sortingSettings()
s = struct('graphical_mode', 1, 'num_pca_features', 10, ...
    'interpolation', 3, 'min_clusters', 3, 'max_clusters', 10, 'num_start', 5);
end
