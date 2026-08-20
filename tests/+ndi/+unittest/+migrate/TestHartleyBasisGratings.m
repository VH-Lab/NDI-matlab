classdef TestHartleyBasisGratings < matlab.unittest.TestCase
%TESTHARTLEYBASISGRATINGS Unit tests for
%   ndi.migrate.internal.hartleyBasisGratings -- the half of the Hartley
%   decomposition that the stimulus_presentation document does not contain.
%   Pure struct assembly: no database, no schema, no toolbox.
%
%   THE FIXTURES ARE TRANSCRIBED FROM REAL 20211116 DOCUMENTS. The numbers
%   they are scaled down from were all re-derived from the corpus rather than
%   quoted (1220 documents read, 21 classes):
%
%     11 stimulus_presentation   1 enumerates 225 stimuli; 10 carry a SINGLE
%                                stimulus that is the generator recipe
%                                {M, K_absmax, L_absmax, sfmax, fps,
%                                 randState, contrast, rect, ...}
%    210 hartley_calc            21 per presentation x 10 presentations
%        hartley_numbers         {S, KXV, KYV, ORDER}, 3360 entries each,
%                                1 DISTINCT VALUE across all 210 documents
%        frameTimes              3360 entries, 10 distinct values (one per
%                                presentation, 21 documents each), monotone,
%                                mean spacing 0.10034 s against fps = 10
%
%   And the structure the emitter depends on, measured on that basis:
%     1680 distinct (kx,ky) pairs, EACH appearing exactly twice
%     3360 distinct (kx,ky,s) triples; s in {-1,+1}, 1680 of each
%     the DC term (0,0) is ABSENT; 41*41 - 1 = 1680 exactly
%     with `phase` the 3360 entries give 3360 distinct value tuples;
%       WITHOUT it they give 1680 -- half the basis would vanish into a dedup
%
%   Run with:  runtests('ndi.unittest.migrate.TestHartleyBasisGratings')

    methods (Test)

        % ================= the shared basis ==============================

        function testTwoPresentationsSharingABasisMintItOnce(testCase)
            % The property the whole design turns on. All ten 20211116
            % Hartley presentations play the SAME 3360 basis functions
            % (hartley_numbers is 1 distinct value across all 210
            % calculators), so minting per presentation would create ten
            % copies of every grating.
            basis = smallBasis();
            bodies = [ presentationAndCalcs('pres_a', basis, [0 0.1 0.2 0.3]), ...
                       presentationAndCalcs('pres_b', basis, [9 9.1 9.2 9.3]) ];

            [gratings, byPres, report] = ...
                ndi.migrate.internal.hartleyBasisGratings(bodies, 'V_eta');

            testCase.verifyEqual(report.generator_presentations, 2);
            testCase.verifyEqual(report.presentations_assembled, 2);
            testCase.verifyEqual(report.frames_assembled, 8);
            % FOUR documents, not eight: the two presentations share them
            testCase.verifyEqual(numel(gratings), 4);
            testCase.verifyEqual(report.distinct_gratings_minted, 4);

            a = byPres('pres_a');
            b = byPres('pres_b');
            testCase.verifyEqual(a.presented_ids, b.presented_ids, ...
                'the two presentations do not reference the same documents');
        end

        function testThePhaseIsWhatKeepsTheSignedPairApart(testCase)
            % WITHOUT `value.phase` the two entries of a (kx,ky) pair are
            % identical in every modelled field and dedup to one document --
            % on the real basis that is 3360 collapsing to 1680.
            basis = struct('kx', [3 3], 'ky', [4 4], 's', [1 -1], ...
                'order', [1 2]);
            bodies = presentationAndCalcs('pres_a', basis, [0 0.1]);
            [gratings, byPres] = ...
                ndi.migrate.internal.hartleyBasisGratings(bodies, 'V_eta');

            testCase.verifyEqual(numel(gratings), 2, ...
                ['the two signs of one (kx,ky) collapsed into one document ' ...
                 '-- `phase` is not separating them']);
            % cas = cos + sin = sqrt(2)*cos(theta - 45deg), and s = -1 is
            % that +180. Only the SEPARATION is established by the data.
            testCase.verifyEqual(gratings{1}.visual_grating.value.phase, -45);
            testCase.verifyEqual(gratings{2}.visual_grating.value.phase, 135);
            testCase.verifyEqual( ...
                gratings{2}.visual_grating.value.phase ...
                - gratings{1}.visual_grating.value.phase, 180);

            % everything else about the pair IS the same, which is the point
            testCase.verifyEqual(gratings{1}.visual_grating.value.angle, ...
                gratings{2}.visual_grating.value.angle);
            testCase.verifyEqual( ...
                gratings{1}.visual_grating.value.source_geometry.spatial_frequency, ...
                gratings{2}.visual_grating.value.source_geometry.spatial_frequency);

            e = byPres('pres_a');
            testCase.verifyEqual(numel(e.presented_ids), 2);
            testCase.verifyEqual(e.order, [1 2]);
        end

        % ================= the value, field by field =====================

        function testTheAngleIsExactAndNeedsNoCalibration(testCase)
            % atan2d(ky,kx), wrapped to [0,360) to match the domain v1
            % `angle` uses. A direction is a ratio, so no pixels-per-degree
            % is involved and nothing is approximated.
            basis = struct('kx', [1 0 -1 0], 'ky', [0 1 0 -1], ...
                's', [1 1 1 1], 'order', 1:4);
            bodies = presentationAndCalcs('pres_a', basis, [0 1 2 3]);
            gratings = ndi.migrate.internal.hartleyBasisGratings(bodies, 'V_eta');
            testCase.verifyEqual(numel(gratings), 4);
            testCase.verifyEqual(gratings{1}.visual_grating.value.angle, 0);
            testCase.verifyEqual(gratings{2}.visual_grating.value.angle, 90);
            testCase.verifyEqual(gratings{3}.visual_grating.value.angle, 180);
            testCase.verifyEqual(gratings{4}.visual_grating.value.angle, 270);
        end

        function testTheSpatialFrequencyGoesToSourceGeometryInCyclesPerPixel(testCase)
            % THE ONE THAT MUST NOT BE GOT WRONG. sqrt(kx^2+ky^2)/M is
            % CYCLES PER PIXEL; `value.spatial_frequency` is documented as
            % cycles per DEGREE, and the conversion factor is rig calibration
            % (NewStim `pixels_per_cm` x distance x tan(1 deg)). A sweep of
            % all 1220 documents of 20211116 over the 229 distinct field
            % names they contain finds `distance` and no other term of that
            % formula. Writing one into the other is a 20-50x error wearing
            % the right unit.
            basis = struct('kx', 3, 'ky', 4, 's', 1, 'order', 1);
            bodies = presentationAndCalcs('pres_a', basis, 0);
            gratings = ndi.migrate.internal.hartleyBasisGratings(bodies, 'V_eta');
            v = gratings{1}.visual_grating.value;

            testCase.verifyEqual(v.source_geometry.spatial_frequency, 5/200, ...
                'AbsTol', 1e-12);   % hypot(3,4)/M, M = 200
            testCase.verifyEqual(v.source_geometry.unit, 'cycles/pixel');

            % the degree-domain fields are ABSENT, not zero: a present 0 is
            % the composite's blank value and would be indistinguishable from
            % a measurement of zero
            testCase.verifyFalse(isfield(v, 'spatial_frequency'));
            testCase.verifyFalse(isfield(v, 'size'));
            testCase.verifyFalse(isfield(v, 'position'));
            testCase.verifyFalse(isfield(v.source_geometry, 'pixels_per_degree'));
            % and a static basis frame has no drift rate to report
            testCase.verifyFalse(isfield(v, 'temporal_frequency'));
        end

        function testDurationIsOneOverFpsAndTheBasisIsNeverBlank(testCase)
            basis = struct('kx', 3, 'ky', 4, 's', 1, 'order', 1);
            bodies = presentationAndCalcs('pres_a', basis, 0);
            [gratings, byPres] = ...
                ndi.migrate.internal.hartleyBasisGratings(bodies, 'V_eta');
            v = gratings{1}.visual_grating.value;
            testCase.verifyEqual(v.duration, 0.1);      % fps = 10
            testCase.verifyEqual(v.contrast, 1);
            % the generator excludes the DC term (measured: (0,0) absent from
            % all 3360 entries), so no basis function is a blank
            testCase.verifyFalse(v.is_blank);
            testCase.verifyEqual(byPres('pres_a').duration, 0.1);
        end

        function testTheMintedDocumentIsAStandaloneVisualGrating(testCase)
            basis = struct('kx', 3, 'ky', 4, 's', 1, 'order', 1);
            bodies = presentationAndCalcs('pres_a', basis, 0);
            gratings = ndi.migrate.internal.hartleyBasisGratings(bodies, 'V_eta');
            g = gratings{1};
            testCase.verifyEqual(g.document_class.class_name, 'visual_grating');
            testCase.verifyEqual(g.document_class.superclasses.class_name, 'data_type');
            testCase.verifyEqual(g.document_class.schema_version, 'V_eta');
            % base declares id / session_id / creation_timestamp mustBeNonEmpty
            testCase.verifyNotEmpty(g.base.id);
            testCase.verifyNotEmpty(g.base.session_id);
            testCase.verifyNotEmpty(g.base.creation_timestamp);
            % a standalone stimulus document names no subject and no
            % instrument -- it is a value, not a statement
            testCase.verifyFalse(isfield(g, 'depends_on'));
        end

        % ================= the playlist and the timing ===================

        function testTheArrayPositionIsTheFrameAndOrderIsTheCanonicalIndex(testCase)
            % ESTABLISHED FROM THE DATA, because the vhlab generator is in no
            % repository this session can read. Sorting the real 3360 entries
            % BY THEIR ORDER VALUE recovers the canonical generator output --
            % (kx,ky) gridded from (-20,-20), s = [-ones(1680,1);
            % ones(1680,1)], entry i pairing with i+1680 on 1680 of 1680 --
            % while the RAW order shows none of it (1 of 1680). So the raw
            % arrays are in PRESENTATION order and ORDER is provenance.
            %
            % This fixture makes the two readings disagree: taking ORDER as
            % the playlist would give [2 1 3] instead of [1 2 3].
            basis = struct('kx', [1 0 -1], 'ky', [0 1 0], 's', [1 1 1], ...
                'order', [2 1 3]);
            bodies = presentationAndCalcs('pres_a', basis, [0 0.1 0.2]);
            [gratings, byPres] = ...
                ndi.migrate.internal.hartleyBasisGratings(bodies, 'V_eta');
            e = byPres('pres_a');
            testCase.verifyEqual(e.order, [1 2 3]);
            testCase.verifyEqual(gratings{e.order(1)}.visual_grating.value.angle, 0);
            testCase.verifyEqual(gratings{e.order(2)}.visual_grating.value.angle, 90);
            testCase.verifyEqual(gratings{e.order(3)}.visual_grating.value.angle, 180);
        end

        function testFrameTimesAreCarriedThrough(testCase)
            % `frameTimes` is the ONLY surviving stimulus timing on this
            % corpus: the writer moved `presentation_time` into
            % presentation_time.bin, which 11 of 11 presentations DECLARE and
            % 0 of 11 carry, and a struct-level batch pass does not open
            % attached binaries.
            basis = smallBasis();
            bodies = presentationAndCalcs('pres_a', basis, [2.6884 2.7887 2.8891 2.9894]);
            [~, byPres] = ndi.migrate.internal.hartleyBasisGratings(bodies, 'V_eta');
            e = byPres('pres_a');
            testCase.verifyEqual(e.frame_times, ...
                [2.6884 2.7887 2.8891 2.9894], 'AbsTol', 1e-12);
            testCase.verifyEqual(numel(e.frame_times), numel(e.order));
        end

        function testAFrameTimeLengthMismatchIsRefusedNotTruncated(testCase)
            % Two halves describing different runs. Truncating would emit a
            % playlist and a timeline that do not correspond, and nothing
            % downstream could tell.
            basis = smallBasis();
            bodies = presentationAndCalcs('pres_a', basis, [0 0.1]);   % 2 for 4
            [gratings, byPres, report] = ...
                ndi.migrate.internal.hartleyBasisGratings(bodies, 'V_eta');
            testCase.verifyEmpty(gratings);
            testCase.verifyEqual(double(byPres.Count), 0);
            testCase.verifyEqual(report.presentations_with_mismatched_frame_times, 1);
            testCase.verifyEqual(report.presentations_assembled, 0);
        end

        % ================= refusals and denominators =====================

        function testDisagreeingCalculatorsAreRefused(testCase)
            % Measured: the 21 calculators of a presentation always agree,
            % and all 210 agree on the basis. A disagreement is an instrument
            % fault, so it is reported rather than resolved by taking the
            % first.
            bodies = presentationAndCalcs('pres_a', smallBasis(), [0 0.1 0.2 0.3]);
            other = smallBasis();
            other.s = [-1 -1 -1 -1];
            bodies{end+1} = calcBody('calc_x', 'pres_a', other, [0 0.1 0.2 0.3]);
            [gratings, ~, report] = ...
                ndi.migrate.internal.hartleyBasisGratings(bodies, 'V_eta');
            testCase.verifyEmpty(gratings);
            testCase.verifyEqual(report.presentations_with_disagreeing_calcs, 1);
        end

        function testAPresentationWithNoCalculatorIsCountedNotAssembled(testCase)
            bodies = { hartleyPresentation('pres_a') };
            [gratings, ~, report] = ...
                ndi.migrate.internal.hartleyBasisGratings(bodies, 'V_eta');
            testCase.verifyEmpty(gratings);
            testCase.verifyEqual(report.generator_presentations, 1);
            testCase.verifyEqual(report.presentations_without_calc, 1);
        end

        function testAnEnumeratedPresentationIsNotAGeneratorRecipe(testCase)
            % The 225-stimulus oridir run must not be swept in: it enumerates
            % its own stimuli and belongs to the ordinary path.
            pres = hartleyPresentation('pres_a');
            pres.stimulus_presentation.stimuli = struct('parameters', ...
                struct('angle', 45, 'sFrequency', 0.04, 'tFrequency', 2));
            [~, ~, report] = ...
                ndi.migrate.internal.hartleyBasisGratings({pres}, 'V_eta');
            testCase.verifyEqual(report.presentations_read, 1);
            testCase.verifyEqual(report.generator_presentations, 0);
            testCase.verifyNotEmpty(report.reason);
        end

        function testTheReportCarriesItsDenominatorsEvenWhenNothingIsEmitted(testCase)
            % Operating Rule 5: a refusal prints the same SHAPE as a success,
            % so "fell through" is never inferable only by subtracting two
            % other counters.
            expected = {'bodies_read'; 'presentations_read'; ...
                'generator_presentations'; 'hartley_calcs_read'; ...
                'calcs_without_presentation'; 'calcs_matched'; ...
                'presentations_without_calc'; ...
                'presentations_with_disagreeing_calcs'; ...
                'presentations_without_enumeration'; ...
                'presentations_with_ragged_enumeration'; ...
                'presentations_with_mismatched_frame_times'; ...
                'presentations_with_disagreeing_properties'; ...
                'presentations_without_M'; 'presentations_assembled'; ...
                'frames_assembled'; 'distinct_gratings_minted'; 'reason'};

            [~, ~, empty] = ndi.migrate.internal.hartleyBasisGratings({}, 'V_eta');
            testCase.verifyEqual(fieldnames(empty), expected);
            testCase.verifyEqual(empty.bodies_read, 0);
            testCase.verifyNotEmpty(empty.reason);

            bodies = presentationAndCalcs('pres_a', smallBasis(), [0 0.1 0.2 0.3]);
            [~, ~, ok] = ndi.migrate.internal.hartleyBasisGratings(bodies, 'V_eta');
            testCase.verifyEqual(fieldnames(ok), expected);
            testCase.verifyEqual(ok.bodies_read, numel(bodies));
            testCase.verifyEqual(ok.hartley_calcs_read, 2);
            testCase.verifyEqual(ok.calcs_matched, 2);
            testCase.verifyEmpty(ok.reason);
        end

        function testACalculatorRestatingMAndFpsDifferentlyIsCounted(testCase)
            % M and fps are stated TWICE -- on the generator spec and on the
            % calculator's `stimulus_properties`. Measured: they agree on all
            % 210 documents. A disagreement is counted rather than silently
            % resolved.
            bodies = presentationAndCalcs('pres_a', smallBasis(), [0 0.1 0.2 0.3]);
            bodies{2}.hartley_reverse_correlation.stimulus_properties.M = 999;
            [~, ~, report] = ...
                ndi.migrate.internal.hartleyBasisGratings(bodies, 'V_eta');
            testCase.verifyEqual(report.presentations_with_disagreeing_properties, 1);
            % and the PRESENTATION still wins -- it is the source document
            % for the stimulus, so the basis is assembled, not dropped
            testCase.verifyEqual(report.presentations_assembled, 1);
        end

    end
end

% ===================== fixtures, from real 20211116 documents =============

function basis = smallBasis()
%SMALLBASIS Four entries with the real structure in miniature: two (kx,ky)
%   pairs, each appearing twice with opposite signs.
basis = struct('kx', [3 -4 3 -4], 'ky', [4 3 4 3], 's', [1 1 -1 -1], ...
    'order', [1 2 3 4]);
end

function bodies = presentationAndCalcs(presId, basis, frameTimes)
%PRESENTATIONANDCALCS One Hartley presentation plus TWO calculators for it.
%   Two rather than one because the real corpus has 21 per presentation and
%   the agreement check only exists because there is more than one.
bodies = { hartleyPresentation(presId), ...
    calcBody([presId '_calc_1'], presId, basis, frameTimes), ...
    calcBody([presId '_calc_2'], presId, basis, frameTimes) };
end

function b = hartleyPresentation(id)
%HARTLEYPRESENTATION The shape 10 of the 11 20211116 presentations have: ONE
%   stimulus, the generator recipe, and a `presentation_order` of scalar 1.
%   Parameters verbatim from 4126943ebbdd014f_40c471eb4e8ea86d.json, with
%   `randState` elided to three entries (nothing here turns on its length).
b = struct();
b.document_class = struct('class_name', 'stimulus_presentation');
b.depends_on = struct('name', {'stimulus_element_id'}, ...
    'value', {'4126943ebaa51186_40d4b41387c4b1a3'});
b.base = struct('id', id, ...
    'session_id', '4126943eba883b79_40dfd8222e0301f0', ...
    'name', '', 'datestamp', '2025-09-11T12:48:21.932Z');
b.epochid = struct('epochid', 't00001');
b.files = struct('file_list', {{'presentation_time.bin'}});
b.stimulus_presentation = struct();
b.stimulus_presentation.presentation_order = 1;
b.stimulus_presentation.stimuli = struct('parameters', struct( ...
    'rect', [-7 -138 793 662], 'windowShape', 0, 'distance', 30, ...
    'M', 200, 'K_absmax', 20, 'L_absmax', 20, 'sfmax', 5, 'contrast', 1, ...
    'chromhigh', [255 255 255], 'chromlow', [0 0 0], ...
    'background', 0.5, 'backdrop', 0.5, 'reps', 1, 'fps', 10, ...
    'randState', [0.8301061479240671 0.6704957765200832 0.08449867537860833], ...
    'dispprefs', {{'BGposttime', 3}}));
end

function b = calcBody(id, presId, basis, frameTimes)
%CALCBODY A `hartley_calc` carrying the enumeration for PRESID.
%   Block names verbatim from the corpus: the enumeration is
%   `hartley_reverse_correlation.hartley_numbers` {S, KXV, KYV, ORDER} and the
%   timing is `hartley_reverse_correlation.frameTimes`.
b = struct();
b.document_class = struct('class_name', 'hartley_calc');
deps = struct('name', {}, 'value', {});
deps(end+1) = struct('name', 'element_id', 'value', 'elem_9');
deps(end+1) = struct('name', 'stimulus_presentation_id', 'value', presId);
b.depends_on = deps;
b.base = struct('id', id, ...
    'session_id', '4126943eba883b79_40dfd8222e0301f0', ...
    'name', '', 'datestamp', '2025-09-11T12:48:21.932Z');
b.hartley_reverse_correlation = struct();
b.hartley_reverse_correlation.frameTimes = frameTimes(:);
b.hartley_reverse_correlation.hartley_numbers = struct( ...
    'S', basis.s(:), 'KXV', basis.kx(:), 'KYV', basis.ky(:), ...
    'ORDER', basis.order(:));
b.hartley_reverse_correlation.stimulus_properties = struct( ...
    'M', 200, 'L_max', 20, 'K_max', 20, 'sf_max', 5, 'fps', 10, ...
    'rect', [-7 -138 793 662]);
end
