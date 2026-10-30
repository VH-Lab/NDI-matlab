classdef TestBathAssembly < matlab.unittest.TestCase
%TESTBATHASSEMBLY Unit tests for ndi.migrate.internal.stimulusBathToBath (pure
%   struct assembly with a mock resolver; no database, schema, or toolbox needed).
%
%   Under V_eta the bath / pharmacological_manipulation family is retired (D8): a
%   deferred stimulus_bath assembles into a `manipulation` whose value is the
%   bath's `formulation`, through `value_id` -- not a dose: "A bath is a
%   manipulation whose value is the formulation (pointed at through
%   `value_id`), not a dose; a dose always has an amount" (Jess Haley,
%   2026-10-21) -- on the resolved subject over the stimulator's epoch,
%   mirroring did2.convert.resolveDeferredBaths.makeBathVEta (DID-matlab
%   ff6d542). Older targets still assemble a `bath`.
%
%   Run with:  runtests('ndi.unittest.migrate.TestBathAssembly')

    methods (Test)

        function testVetaIsAManipulationValuedByItsFormulation(testCase)
            % did-schema #88: the `manipulation` direction + the `formulation`
            % kind, its value the formulation document through `value_id`
            % (Jess Haley, 2026-10-21: a bath is not a dose),
            % the mixture as a standalone `formulation` of `chemical`s, and a
            % VALID "during the session" anchor whose epoch rides in anchorInfo
            v1 = stimulusBathDoc('stim_1', 't00001');
            r  = mockResolver('animal_1', 'dev_local_time');
            [dose, timeRef, extra, anchorInfo] = ...
                ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_eta');

            testCase.verifyEqual(dose.document_class.class_name, 'manipulation');
            testCase.verifyEqual({dose.document_class.superclasses.class_name}, ...
                {'interaction', 'statement', 'base', 'formulation', 'value', 'data'});
            testCase.verifyEqual(dose.base.id, 'bath_1');          % source id preserved
            testCase.verifyEqual(depValue(dose, 'entity_id'), 'animal_1');
            testCase.verifyEmpty(depValue(dose, 'subject_id'));
            % [bath is two statements] / [bath solution minted] (Jess Haley,
            % 2026-10-26 / 2026-10-27): the variable is the general bath-
            % solution term, not the first mixture row (muscimol here)
            testCase.verifyEqual(dose.statement.variable.node, 'EMPTY:0000409');
            testCase.verifyEqual(dose.statement.variable.name, 'bath solution');

            % the formulation and its one chemical
            classes = cellfun(@(b) b.document_class.class_name, extra, ...
                'UniformOutput', false);
            % + the site observation: the fixture's location is CNS, an
            % anatomical region (see testAnAnatomicalBathLocationIsACoAnchoredSite)
            testCase.verifyEqual(sort(classes), {'chemical', 'formulation', 'observation'});
            f = extra{strcmp(classes, 'formulation')};
            c = extra{strcmp(classes, 'chemical')};
            testCase.verifyEqual(depValue(dose, 'value_id'), f.base.id);
            testCase.verifyEmpty(depValue(dose, 'formulation_id'));
            % its own value stays empty: the formulation document holds it
            testCase.verifyFalse(isfield(dose, 'formulation'));
            testCase.verifyFalse(isfield(dose, 'dose'));
            testCase.verifyEqual(depValue(f, 'ingredient_id'), c.base.id);
            testCase.verifyEqual(c.chemical.value.substance.name, 'muscimol');
            testCase.verifyEqual(c.chemical.value.substance.node, 'chebi:6904');
            % a struct array, as the schema declares it (a cell reads as blank
            % to the value rule and quarantined the formulation)
            testCase.verifyClass(f.formulation.value.ingredients, 'struct');
            testCase.verifyNumElements(f.formulation.value.ingredients, 1);
            conc = f.formulation.value.ingredients(1).concentration;
            testCase.verifyEqual(conc.source_value, 5);
            testCase.verifyEqual(conc.source_unit.name, 'mg/ml');

            % the anchor: valid on #88, during the session, epoch handed over
            testCase.verifyEqual(timeRef.document_class.class_name, ...
                'relative_time_reference');
            testCase.verifyEqual(depValue(timeRef, 'referent_id'), 'sess_09');
            testCase.verifyEqual(depValue(dose, 'time_reference_id'), timeRef.base.id);
            testCase.verifyEqual(anchorInfo.anchor_id, timeRef.base.id);
            testCase.verifyEqual(anchorInfo.epoch_string, 't00001');
            testCase.verifyEqual(anchorInfo.epoch_clock, 'dev_local_time');
            testCase.verifyEqual(anchorInfo.session_id, 'sess_09');

            testCase.verifyFalse(isfield(dose, 'bath'));
            testCase.verifyFalse(isfield(dose, 'pharmacological_manipulation'));
            testCase.verifyFalse(isfield(dose, 'subject_statement'));
        end
        % ---- WHERE THE BATH IS (Jess Haley, 2026-10-21) ------------------
        % "Any statement about an anatomical region of a subject ... targets
        % that region's part entity ... A statement about the whole subject (a
        % whole-prep or whole-slice bath, i.e. the generic 'bath' location
        % NCIm:C0179246) targets the subject." The assembler hands
        % pathSPromotion a co-anchored site for an anatomical location and
        % nothing for the generic bath.

        function testAnAnatomicalBathLocationIsACoAnchoredSite(testCase)
            % a Marder compartment bath ('lower', marder_bathtargets.json)
            v1 = stimulusBathDoc('stim_1', 't00001');
            v1.stimulus_bath.location = struct('ontologyNode', 'UBERON:8910010', ...
                'name', 'lower compartment');
            r  = mockResolver('prep_1', 'dev_local_time');
            [dose, timeRef, extra] = ...
                ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_eta');
            site = siteOf(extra);
            testCase.verifyNumElements(site, 1);
            site = site{1};
            testCase.verifyEqual(site.statement.variable.node, 'NCIT:C13717');
            testCase.verifyEqual(site.statement.variable.name, 'Anatomic Site');
            testCase.verifyEqual(site.term.value.node, 'UBERON:8910010');
            testCase.verifyEqual(depValue(site, 'entity_id'), 'prep_1');
            testCase.verifyEqual(depValue(site, 'time_reference_id'), timeRef.base.id);
            testCase.verifyEqual(depValue(dose, 'time_reference_id'), timeRef.base.id);

            % and Path S puts the bath on the compartment's part
            [kept, minted, changed] = ndi.migrate.internal.pathSPromotion( ...
                [{dose, timeRef}, extra], 'Mode', 'sites');
            testCase.verifyTrue(changed);
            part = minted{cellfun(@(b) strcmp(b.document_class.class_name, 'entity'), minted)};
            testCase.verifyTrue(ndi.v2.vocabIs('entity_type', part.entity.type, 'tissue'));
            bath = kept{cellfun(@(b) strcmp(b.base.id, 'bath_1'), kept)};
            testCase.verifyEqual(depValue(bath, 'entity_id'), part.base.id);
            testCase.verifyEmpty(siteOf(kept), 'the site is superseded by the part');
        end

        function testTheGenericBathTargetsTheWholeSubject(testCase)
            % Dabrowska's every bath, and Marder's 'bath': no site, so Path S
            % leaves the bath on the subject (which is what sliceTetanus reads)
            for loc = {struct('ontologyNode', 'NCIm:C0179246', 'name', 'Baths, Water, Laboratory'), ...
                       struct('ontologyNode', 'ncim:C0179246', 'name', ''), ...
                       struct('ontologyNode', '', 'name', 'bath')}
                v1 = stimulusBathDoc('stim_1', 't00001');
                v1.stimulus_bath.location = loc{1};
                r  = mockResolver('slice_animal', 'dev_local_time');
                [dose, timeRef, extra] = ...
                    ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_eta');
                testCase.verifyEmpty(siteOf(extra));
                [kept, minted, changed] = ndi.migrate.internal.pathSPromotion( ...
                    [{dose, timeRef}, extra]);
                testCase.verifyFalse(changed);
                testCase.verifyEmpty(minted);
                bath = kept{cellfun(@(b) strcmp(b.base.id, 'bath_1'), kept)};
                testCase.verifyEqual(depValue(bath, 'entity_id'), 'slice_animal');
            end
        end

        function testABathWithNoAnchorGetsNoSite(testCase)
            % nothing to co-anchor on: the bath stays on the subject (a gap)
            v1 = stimulusBathDoc('stim_1', 't00001');
            r  = mockResolver('animal_1', 'no_time');
            [~, ~, extra] = ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_eta');
            testCase.verifyEmpty(siteOf(extra));
        end

        function testVetaCarriesTheStimulatorAsInstrument(testCase)
            % T7: the instrument of an interaction is an edge on the
            % interaction. This is what keeps the stimulator's identity when
            % ndi.migrate.internal.epochAnchorFold drops the anchor's
            % `element_id` -- `relative_reference` declares only `relative_to`,
            % so without this edge the fold would LOSE which element's epoch the
            % bath sat in. The stimulator is an element, and migrators_j.element
            % promotes an element to a `subject` with its id PRESERVED.
            v1 = stimulusBathDoc('stim_1', 't00001');
            r  = mockResolver('animal_1', 'dev_local_time');
            dose = ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_eta');
            testCase.verifyEqual(depValue(dose, 'instrument_id'), 'stim_1');
        end

        % ---- NO TIMES => NO REFERENCE (V_eta only) ----------------------
        % The signed plan's rule. A reference that cannot name a time is a
        % hollow document: it validates, it is counted, and it says nothing.

        function testVetaEmitsNoAnchorForANoTimeClock(testCase)
            v1 = stimulusBathDoc('stim_1', 't00001');
            r  = mockResolver('animal_1', 'no_time');
            [dose, timeRef, ~, anchorInfo] = ...
                ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_eta');
            testCase.verifyEmpty(timeRef);
            testCase.verifyEmpty(anchorInfo);
            testCase.verifyEmpty(depValue(dose, 'time_reference_id'));
            testCase.verifyEqual(depValue(dose, 'entity_id'), 'animal_1');
        end
        function testVetaEmitsNoAnchorWhenThereIsNoEpochString(testCase)
            v1 = stimulusBathDoc('stim_1', 't00001');
            v1.epochid = struct('epochid', '');
            r  = mockResolver('animal_1', 'dev_local_time');
            [dose, timeRef] = ...
                ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_eta');
            testCase.verifyEmpty(timeRef);
            testCase.verifyEmpty(depValue(dose, 'time_reference_id'));
        end

        function testVetaReadsTheWritersMixtureTable(testCase)
            % NDI writes a HEADER row and double-quotes a name holding commas;
            % pH is a property of the whole mixture, not an ingredient
            v1 = stimulusBathDoc('stim_1', 't00001');
            v1.stimulus_bath.mixture_table = sprintf(['ontologyName,name,value,ontologyUnit,unitName\n' ...
                'CHEBI:1,"sodium phosphate, monobasic",0.0012,UO:0000062,Molar\n' ...
                'CHEBI:2,pH,7.4,,\n']);
            r  = mockResolver('animal_1', 'dev_local_time');
            [~, ~, extra] = ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_eta');
            classes = cellfun(@(b) b.document_class.class_name, extra, ...
                'UniformOutput', false);
            testCase.verifyEqual(sum(strcmp(classes, 'chemical')), 1);
            c = extra{strcmp(classes, 'chemical')};
            testCase.verifyEqual(c.chemical.value.substance.name, ...
                'sodium phosphate, monobasic');
            f = extra{strcmp(classes, 'formulation')};
            testCase.verifyEqual(f.formulation.value.ph.ph, 7.4);
            conc = f.formulation.value.ingredients(1).concentration;
            testCase.verifyEqual(conc.molar, 0.0012);
            testCase.verifyEqual(conc.source_unit.node, 'UO:0000062');
        end
        function testTheFormulationPassesTheValueRule(testCase)
            % e2e run 39668356516: the formulation was quarantined by
            % value_inline_or_body ("its `value` is empty") because its
            % ingredients were a cell. A row with an amount and a row without
            % one must both survive, and the document must validate.
            testCase.assumeTrue(~isempty(which('did2.convert.v1_to_v2')) ...
                && ~isempty(getenv('DID_SCHEMA_PATH')), ...
                'needs DID-matlab and a V_eta schema set (DID_SCHEMA_PATH)');
            v1 = stimulusBathDoc('stim_1', 't00001');
            v1.stimulus_bath.mixture_table = sprintf(['ontologyName,name,value,ontologyUnit,unitName\n' ...
                'chebi:6904,muscimol,5,,mg/ml\n' ...
                'chebi:26710,sodium chloride,,,\n']);
            r  = mockResolver('animal_1', 'dev_local_time');
            [~, ~, extra] = ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_eta');
            classes = cellfun(@(b) b.document_class.class_name, extra, ...
                'UniformOutput', false);
            f = extra{strcmp(classes, 'formulation')};
            testCase.verifyNumElements(f.formulation.value.ingredients, 2);
            testCase.verifyEqual(f.formulation.value.ingredients(1).concentration.source_value, 5);
            testCase.verifyEqual(numel(depValues(f, 'ingredient_id')), 2);
            % folded as ndi.migrate.local folds it: nothing may quarantine
            % (the old shape quarantined with did2:validation:valueNowhere)
            res = did2.convert.v1_to_v2({f}, 'TargetVersion', 'V_eta', 'Verbose', false);
            testCase.verifyEmpty(res.quarantine, 'the formulation was quarantined');
            testCase.verifyNumElements(res.migrated, 1);
        end

        function testTheGuardIsVetaOnlyAndOlderTargetsAreUntouched(testCase)
            % The retirement is a V_eta decision. V_zeta/V_epsilon keep the
            % behaviour they are green with, no_time clock included.
            v1 = stimulusBathDoc('stim_1', 't00001');
            r  = mockResolver('animal_1', 'no_time');
            [bath, timeRef] = ...
                ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_zeta');
            testCase.verifyNotEmpty(timeRef);
            testCase.verifyEqual(timeRef.document_class.class_name, ...
                'epoch_bounded_reference');
            testCase.verifyEqual(depValue(bath, 'time_reference_1'), ...
                timeRef.base.id);
        end

        function testZetaStillEmitsBath(testCase)
            % the older target is unchanged: a `bath` (pharmacological_manipulation)
            v1 = stimulusBathDoc('stim_1', 't00001');
            r  = mockResolver('animal_1', 'dev_local_time');
            bath = ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_zeta');
            testCase.verifyEqual(bath.document_class.class_name, 'bath');
            testCase.verifyTrue(isfield(bath, 'pharmacological_manipulation'));
        end

    end
end

% ===================== fixtures / helpers =================================

function v1 = stimulusBathDoc(stimId, epochId)
v1 = struct();
v1.document_class = struct('class_name', 'stimulus_bath', 'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'base',    'class_version', '1.0.0'), ...
        struct('class_name', 'epochid', 'class_version', '1.0.0')]);
v1.depends_on = struct('name', {'stimulus_element_id'}, 'value', {stimId});
v1.base = struct('id', 'bath_1', 'session_id', 'sess_09', ...
    'name', 'bath', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', epochId);
v1.stimulus_bath = struct( ...
    'location', struct('ontologyNode', 'uberon:0001017', 'name', 'CNS'), ...
    'mixture_table', 'chebi:6904,muscimol,5,,mg/ml');
end

function out = siteOf(bodies)
% the `anatomical location` observations among BODIES
out = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if strcmp(b.document_class.class_name, 'observation') && isfield(b, 'statement') ...
            && (strcmpi(b.statement.variable.node, 'NCIT:C13717') ...
                || strcmp(b.statement.variable.name, 'anatomical location'))
        out{end+1} = b; %#ok<AGROW>
    end
end
end

function r = mockResolver(subjectId, epochClock)
% the session-aware lookups ndi.migrate.local supplies; fixed values here.
r = struct( ...
    'subjectOfElement',     @(elementId) subjectId, ...
    'epochClockOfElement',  @(elementId, epochId) epochClock);
end

function v = depValue(body, name)
v = '';
for k = 1:numel(body.depends_on)
    if strcmp(body.depends_on(k).name, name)
        v = body.depends_on(k).value;
        return;
    end
end
end

function v = depValues(body, name)
% every value of the edge NAME (an edge may repeat)
v = {};
for k = 1:numel(body.depends_on)
    if iscell(body.depends_on); d = body.depends_on{k}; else; d = body.depends_on(k); end
    if strcmp(d.name, name)
        if isfield(d, 'value'); v{end+1} = d.value; else; v{end+1} = d.document_id; end %#ok<AGROW>
    end
end
end
