classdef TestPathSPromotion < matlab.unittest.TestCase
%TESTPATHSPROMOTION Unit tests for the V_eta Path-S second pass (pure struct
%   logic; no database, schema, or MATLAB toolbox needed).
%
%   ndi.migrate.internal.pathSPromotion promotes an ATTRIBUTED anatomical locus
%   (a site term_observation co-anchored with a manipulation -- the intervention
%   -target pattern) to a Path-S part-`subject` + a `term_assertion` of its
%   anatomical kind + a `part_of` `directed_relation`, retargeting the co-anchored
%   manipulation onto the part. A merely-located site (no co-anchored
%   manipulation, e.g. a probe location) is left untouched. Promotion is deduped
%   per (animal, site).
%
%   Run with:  runtests('ndi.unittest.migrate.TestPathSPromotion')
%
%   The fixtures/accessors are LOCAL FUNCTIONS (below the classdef), called
%   unqualified from the Test methods. They were previously static methods called
%   as `TestPathSPromotion.helper(...)`, but that class-qualified reference failed
%   to resolve in the packaged class ("Unable to resolve the name ..."), so the
%   tests never actually ran. Local functions need no class-name resolution.
%
%   STATUS 2026-08-11: `testAttributedSitePromoted` ERRORED on its first real
%   execution (test-eta-migrate.yml run 31463051482, af840428f, and identically
%   on the parent run 31460488423 / e3795c2f7):
%
%       Error ID: 'MATLAB:nonExistentField'
%       Unrecognized field name "term_assertion".
%       Error in .../testAttributedSitePromoted (line 47)
%           testCase.verifyEqual(assertion.term_assertion.value.node, ...
%
%   THE TEST WAS STALE, NOT THE CODE, and it is INVERTED here rather than
%   deleted. `term_assertion` is `subject_assertion` x `term` and declares NO
%   fields of its own -- `value` is inherited from `term`, so it rides the
%   `term` BLOCK. Positive evidence, three ways:
%
%     DID-schema/schemas/V_eta/stable/term_assertion.json
%         superclasses = [subject_assertion, term];  "fields": []
%     DID-schema/schemas/V_eta/stable/term.json
%         declares the `value` (ontology_term) field
%     DID-matlab, every migrator under src/:
%         16 sites write `<body>.term = struct('value', ...)`
%          0 sites write a `term_assertion` block
%         -- including probe_geometry.m:124, which mints a term_assertion
%            document and puts its value on `.term`.
%
%   NDI-matlab commit d03a42bdf ("pathSPromotion: term_assertion pairs with the
%   `term` composite", 2026-07-28) made that move in pathSPromotion.m; this file
%   was written at 6108689dc, before it, and the two commits that touched it
%   since were about static-method resolution. The assertion below now reads
%   `.term.value`, additionally pins the superclass chain the same commit
%   changed, and pins the ABSENCE of a stale `term_assertion` block (an
%   undeclared top-level block quarantines -- the same regression the
%   `subject_relation` assertion further down exists for).

    methods (Test)

        function testAttributedSitePromoted(testCase)
            structs = treatmentWithSite('anch_1', 'animal_1', ...
                'uberon:0002436', 'primary visual cortex');
            [kept, minted, changed] = ndi.migrate.internal.pathSPromotion(structs);

            testCase.verifyTrue(changed);
            % the located site observation is superseded (removed from kept)
            testCase.verifyFalse(anyClass(kept, 'term_observation'));
            % minted: a part-subject + its kind assertion + a part_of relation
            testCase.verifyTrue(anyClass(minted, 'subject'));
            testCase.verifyTrue(anyClass(minted, 'term_assertion'));
            testCase.verifyTrue(anyClass(minted, 'directed_relation'));

            partId = idOfClass(minted, 'subject');
            % the manipulation is retargeted from the animal onto the part
            dose = firstOfClass(kept, 'dose_manipulation');
            testCase.verifyEqual(depValue(dose, 'subject_id'), partId);
            % the part_of relation points part -> animal
            rel = firstOfClass(minted, 'directed_relation');
            testCase.verifyEqual(depValue(rel, 'child'), partId);
            testCase.verifyEqual(depValue(rel, 'parent'), 'animal_1');
            testCase.verifyEqual(rel.directed_relation.relation.name, 'part_of');
            % the part carries the site term as its anatomical kind. The value
            % rides the inherited `term` block (term_assertion = subject_assertion
            % x term, and term_assertion declares no fields of its own), NOT a
            % `term_assertion` block -- see the header for the evidence.
            assertion = firstOfClass(minted, 'term_assertion');
            testCase.verifyEqual(assertion.term.value.node, 'uberon:0002436');
            testCase.verifyEqual(depValue(assertion, 'subject_id'), partId);
            % the stale block must be GONE, not merely unused: an undeclared
            % top-level block quarantines the document.
            testCase.verifyFalse(isfield(assertion, 'term_assertion'));
            % ... and the declared chain must match the schema, class name by
            % class name (did2:validation:superclassesChainMismatch).
            aSupers = {assertion.document_class.superclasses.class_name};
            testCase.verifyTrue(any(strcmp(aSupers, 'subject_assertion')));
            testCase.verifyTrue(any(strcmp(aSupers, 'term')));
            % regression: subject_relation was renamed to `relation` in V_eta. The
            % relation must carry NO stale subject_relation block (an undeclared
            % top-level block quarantines -- the JH 163k-orphan regression) and must
            % descend from `relation`, not `subject_relation`.
            testCase.verifyFalse(isfield(rel, 'subject_relation'));
            supers = {rel.document_class.superclasses.class_name};
            testCase.verifyTrue(any(strcmp(supers, 'relation')));
            testCase.verifyFalse(any(strcmp(supers, 'subject_relation')));
            % the part-subject carries a non-empty (required) local_identifier
            part = firstOfClass(minted, 'subject');
            testCase.verifyNotEmpty(part.subject.local_identifier);
        end

        function testLegacyTermObservationShapeStillResolves(testCase)
            % pathSPromotion/siteValue PREFERS the `term` block and FALLS BACK to
            % the pre-composite `term_observation` block, deliberately
            % (d03a42bdf: "so a body migrated before this change still
            % resolves"). The main fixture now carries the writer's current
            % shape, so this test is what keeps that fallback branch covered --
            % flipping the fixture must not silently retire a live branch.
            structs = withPreCompositeSite(treatmentWithSite('anch_1', ...
                'animal_1', 'uberon:0002436', 'primary visual cortex'));
            [~, minted, changed] = ndi.migrate.internal.pathSPromotion(structs);

            testCase.verifyTrue(changed);
            assertion = firstOfClass(minted, 'term_assertion');
            % read from the OLD block, emitted onto the NEW one
            testCase.verifyEqual(assertion.term.value.node, 'uberon:0002436');
            testCase.verifyEqual(assertion.term.value.name, ...
                'primary visual cortex');
        end

        function testMerelyLocatedSiteUntouched(testCase)
            % a probe location: a site term_observation with NO co-anchored
            % manipulation -> left located-by-default, nothing minted.
            structs = probeWithSite('anch_2', 'probe_9', ...
                'uberon:0000955', 'brain');
            [kept, minted, changed] = ndi.migrate.internal.pathSPromotion(structs);

            testCase.verifyFalse(changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(numel(kept), numel(structs));
            testCase.verifyTrue(anyClass(kept, 'term_observation'));
        end

        function testDedupPerAnimalSite(testCase)
            % two treatments on the same animal targeting the same site -> a
            % single shared part-subject (find-or-create keyed on animal+site).
            a = treatmentWithSite('anch_1', 'animal_1', ...
                'uberon:0002436', 'primary visual cortex');
            b = treatmentWithSite('anch_3', 'animal_1', ...
                'uberon:0002436', 'primary visual cortex');
            [~, minted, ~] = ndi.migrate.internal.pathSPromotion([a, b]);

            nSubjects = 0;
            for k = 1:numel(minted)
                if strcmp(minted{k}.document_class.class_name, 'subject')
                    nSubjects = nSubjects + 1;
                end
            end
            testCase.verifyEqual(nSubjects, 1);
        end

        function testDistinctSitesGetDistinctParts(testCase)
            a = treatmentWithSite('anch_1', 'animal_1', ...
                'uberon:0002436', 'V1');
            b = treatmentWithSite('anch_3', 'animal_1', ...
                'uberon:0001950', 'neocortex');
            [~, minted, ~] = ndi.migrate.internal.pathSPromotion([a, b]);
            nSubjects = 0;
            for k = 1:numel(minted)
                if strcmp(minted{k}.document_class.class_name, 'subject')
                    nSubjects = nSubjects + 1;
                end
            end
            testCase.verifyEqual(nSubjects, 2);
        end

    end
end

% ===================== fixtures + accessors (test-only) ====================
% Local functions of the class-definition file: visible to the Test methods
% above, called unqualified (no class-name resolution).

function s = treatmentWithSite(anchorId, animalId, siteNode, siteName)
manip = struct();
manip.document_class = dc('dose_manipulation', {'subject_manipulation', 'dose'});
manip.depends_on = [dep('subject_id', animalId), ...
    dep('time_reference_1', anchorId)];
manip.base = base(['manip_' anchorId]);
manip.subject_statement = struct('variable', ...
    term('chebi:1', 'muscimol'), 'storage_mode', 'inline');
manip.subject_interaction = struct('method', term('', ''), ...
    'sample_time', struct('kind', 'point'));
manip.subject_manipulation = struct('notes', '');
manip.dose = struct('value', struct());

site = siteObs(anchorId, animalId, siteNode, siteName, ['site_' anchorId]);
anchor = makeAnchor(anchorId);
s = {manip, site, anchor};
end

function s = probeWithSite(anchorId, probeId, siteNode, siteName)
site = siteObs(anchorId, probeId, siteNode, siteName, ['site_' anchorId]);
anchor = makeAnchor(anchorId);
s = {site, anchor};
end

function site = siteObs(anchorId, subjectId, siteNode, siteName, baseId)
site = struct();
site.document_class = dc('term_observation', {'subject_observation'});
site.depends_on = [dep('subject_id', subjectId), ...
    dep('time_reference_1', anchorId)];
site.base = base(baseId);
site.subject_statement = struct('variable', ...
    term('', 'anatomical location'), 'storage_mode', 'inline');
site.subject_interaction = struct('method', term('', ''), ...
    'sample_time', struct('kind', 'point'));
site.subject_observation = struct();
% THE WRITER'S SHAPE, not a DID-side schema's: did2.convert.migrators_j
% .probe_location:28-30 mints exactly this document -- class term_observation,
% variable 'anatomical location' -- and puts the value on `obs.term`. This
% fixture said `site.term_observation` until 2026-08-11, i.e. it exercised only
% pathSPromotion/siteValue's LEGACY fallback branch and never the branch
% production takes. testLegacyTermObservationShapeStillResolves keeps the
% fallback covered.
site.term = struct('value', term(siteNode, siteName));
end

function structs = withPreCompositeSite(structs)
%WITHPRECOMPOSITESITE Rewrite the site observation to the shape a
%   term_observation had BEFORE NDI-matlab d03a42bdf moved the value onto the
%   inherited `term` block. Bodies migrated before that change still look like
%   this, which is why siteValue() still reads it.
for k = 1:numel(structs)
    if strcmp(structs{k}.document_class.class_name, 'term_observation')
        structs{k}.term_observation = struct('value', structs{k}.term.value);
        structs{k} = rmfield(structs{k}, 'term');
    end
end
end

function anchor = makeAnchor(anchorId)
anchor = struct();
anchor.document_class = dc('session_relative_reference', {'time_reference'});
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = base(anchorId);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');
end

function x = dc(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
x = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'V_eta');
end

function x = dep(name, value)
x = struct('name', name, 'value', value);
end

function x = base(id)
x = struct('id', id, 'session_id', 'sess_1', 'name', 'n', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
end

function x = term(node, name)
x = struct('node', node, 'name', name);
end

function tf = anyClass(bodies, className)
tf = false;
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, className)
        tf = true; return;
    end
end
end

function b = firstOfClass(bodies, className)
b = [];
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, className)
        b = bodies{k}; return;
    end
end
end

function id = idOfClass(bodies, className)
b = firstOfClass(bodies, className);
id = b.base.id;
end

function v = depValue(s, name)
v = '';
for k = 1:numel(s.depends_on)
    if strcmp(s.depends_on(k).name, name)
        v = s.depends_on(k).value; return;
    end
end
end
