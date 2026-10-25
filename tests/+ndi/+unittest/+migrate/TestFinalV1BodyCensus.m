classdef TestFinalV1BodyCensus < matlab.unittest.TestCase
%TESTFINALV1BODYCENSUS The Bar-2 survivor census decides by BODY, not by NAME.
%
%   Constructed documents, no corpus, no database. Each destination document
%   carries the superclass chain v1_to_v2's ensureClassBlocks would have
%   rebuilt from the pinned schema (did-schema v_eta-pre73), because that
%   chain is the signal finalV1BodyCensus reads.
%
%   The vocabulary is passed explicitly ('V1Vocabulary', {}) so the test does
%   not depend on NDI's template folder: only the source documents' own names
%   and superclass definitions count as v1.

    methods (Test)

        function testEachDocumentLandsInTheRightTable(testCase)
            [src, dst] = fixture();
            census = ndi.unittest.migrate.finalV1BodyCensus(src, dst, ...
                'Deferrals', struct('class_name', {'stimulus_response_scalar'}, ...
                    'label', {'deferred to the migrator port'}), ...
                'V1Vocabulary', {});

            % DENOMINATOR FIRST.
            verifyEqual(testCase, census.denominator.source_read, 6);
            verifyEqual(testCase, census.denominator.source_classified, 6);
            verifyEqual(testCase, census.denominator.dest_read, 7);
            % the minted `tuning_curve_calculation` is not a v1 spelling
            verifyEqual(testCase, census.denominator.dest_v1_spelled, 6);

            % (a) the stimulus_presentation passthrough: v1 chain, same id
            a = census.unconverted;
            verifyEqual(testCase, {a.class_name}, {'stimulus_presentation'});
            verifyEqual(testCase, a(1).count, 1);
            verifyEqual(testCase, a(1).same_id_source, 1);

            % (b) the converted calculators and the persisting subject/session
            b = census.v2_classes;
            verifyEqual(testCase, sort({b.class_name}), ...
                sort({'tuningcurve_calc', 'subject', 'session'}));
            calc = b(strcmp({b.class_name}, 'tuningcurve_calc'));
            verifyEqual(testCase, calc.count, 2);
            verifyEqual(testCase, calc.same_id_source, 2);
            verifyEqual(testCase, calc.veta_ancestor, 'subject_statement');
            subj = b(strcmp({b.class_name}, 'subject'));
            verifyEqual(testCase, subj.veta_ancestor, 'entity');

            % (c) the declared deferral, still a v1 body, listed separately
            c = census.deferred;
            verifyEqual(testCase, {c.class_name}, {'stimulus_response_scalar'});
            verifyEqual(testCase, c(1).count, 1);
            verifyEqual(testCase, c(1).label, 'deferred to the migrator port');
        end

        function testAnUndeclaredDeferralIsFlaggedAsUnconverted(testCase)
            % Without the declaration, stimulus_response_scalar is an
            % unconverted v1 body like any other -- a deferral is a label,
            % never a way to make a v1 body disappear from the census.
            [src, dst] = fixture();
            census = ndi.unittest.migrate.finalV1BodyCensus(src, dst, ...
                'V1Vocabulary', {});
            verifyEqual(testCase, sort({census.unconverted.class_name}), ...
                sort({'stimulus_presentation', 'stimulus_response_scalar'}));
            verifyEmpty(testCase, census.deferred);
        end

        function testAMissingChainReadsAsUnconverted(testCase)
            % THE PESSIMISTIC DIRECTION, on purpose: a destination document
            % with no superclass chain cannot show a V_eta ancestor, so it is
            % reported as a v1 body rather than waved through.
            src = {v1('id_x', 'tuningcurve_calc', {'base', 'app'})};
            dst = {dest('id_x', 'tuningcurve_calc', {})};
            census = ndi.unittest.migrate.finalV1BodyCensus(src, dst, ...
                'V1Vocabulary', {});
            verifyEqual(testCase, {census.unconverted.class_name}, {'tuningcurve_calc'});
        end

        function testCamelCaseSourceMatchesItsSnakeCaseDestination(testCase)
            % universalRenames snake-cases v1 camelCase class names, so a
            % passthrough ontologyTableRow lands as ontology_table_row. The
            % name-only census missed these entirely.
            src = {v1('id_r', 'ontologyTableRow', {'base'})};
            dst = {dest('id_r', 'ontology_table_row', {'base'})};
            census = ndi.unittest.migrate.finalV1BodyCensus(src, dst, ...
                'V1Vocabulary', {});
            verifyEqual(testCase, {census.unconverted.class_name}, {'ontology_table_row'});
            verifyEqual(testCase, census.unconverted(1).same_id_source, 1);
        end

        function testTheReportPrints(testCase)
            [src, dst] = fixture();
            census = ndi.unittest.migrate.finalV1BodyCensus(src, dst, ...
                'V1Vocabulary', {});
            out = evalc('ndi.unittest.migrate.printV1BodyCensus(census, ''fixture'')');
            verifySubstring(testCase, out, 'DENOMINATOR: 6 source document(s) read');
            verifySubstring(testCase, out, '(a) unconverted v1 bodies (FLAGGED):          2');
            verifySubstring(testCase, out, 'via V_eta ancestor `entity`');
        end

    end
end

% ===================== fixtures ============================================

function [src, dst] = fixture()
src = { ...
    v1('id_c1', 'tuningcurve_calc', {'base', 'app', 'stimulus_tuningcurve'}), ...
    v1('id_c2', 'tuningcurve_calc', {'base', 'app', 'stimulus_tuningcurve'}), ...
    v1('id_s',  'subject',          {'base'}), ...
    v1('id_n',  'session',          {'base'}), ...
    v1('id_p',  'stimulus_presentation', {'base', 'epochid'}), ...
    v1('id_r',  'stimulus_response_scalar', {'base', 'stimulus/stimulus_response'})};
calcChain = {'base', 'subject_statement', 'subject_interaction', 'calculator', ...
    'subject_calculation', 'tuning_curve_calculation', 'data', 'data_type', ...
    'tuning_curve'};
dst = { ...
    dest('id_c1', 'tuningcurve_calc', calcChain), ...
    dest('id_c2', 'tuningcurve_calc', calcChain), ...
    dest('id_s',  'subject', {'base', 'entity'}), ...
    dest('id_n',  'session', {'base', 'entity'}), ...
    dest('id_p',  'stimulus_presentation', {'base', 'app', 'epochid'}), ...
    dest('id_r',  'stimulus_response_scalar', {'base', 'stimulus_response'}), ...
    dest('id_new', 'tuning_curve_calculation', calcChain(1:5))};
end

function t = v1(id, className, supers)
defs = cellfun(@(s) struct('definition', ['$NDIDOCUMENTPATH/' s '.json']), ...
    supers, 'UniformOutput', false);
j = struct( ...
    'document_class', struct('definition', ['$NDIDOCUMENTPATH/' className '.json'], ...
        'class_name', className, 'class_version', 1, 'superclasses', {defs}), ...
    'base', struct('id', id, 'session_id', 'sess_1', 'name', '', 'datestamp', ''));
t = jsonencode(j);
end

function d = dest(id, className, chain)
sc = struct('class_name', chain, 'class_version', '1.0.0');
if isempty(chain)
    sc = struct('class_name', {}, 'class_version', {});
end
d = struct( ...
    'document_class', struct('class_name', className, 'superclasses', sc, ...
        'schema_version', 'did_v2'), ...
    'base', struct('id', id));
end
