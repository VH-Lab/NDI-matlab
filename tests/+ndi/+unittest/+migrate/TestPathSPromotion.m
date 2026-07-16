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

    methods (Test)

        function testAttributedSitePromoted(testCase)
            structs = TestPathSPromotion.treatmentWithSite('anch_1', 'animal_1', ...
                'uberon:0002436', 'primary visual cortex');
            [kept, minted, changed] = ndi.migrate.internal.pathSPromotion(structs);

            testCase.verifyTrue(changed);
            % the located site observation is superseded (removed from kept)
            testCase.verifyFalse(TestPathSPromotion.anyClass(kept, 'term_observation'));
            % minted: a part-subject + its kind assertion + a part_of relation
            testCase.verifyTrue(TestPathSPromotion.anyClass(minted, 'subject'));
            testCase.verifyTrue(TestPathSPromotion.anyClass(minted, 'term_assertion'));
            testCase.verifyTrue(TestPathSPromotion.anyClass(minted, 'directed_relation'));

            partId = TestPathSPromotion.idOfClass(minted, 'subject');
            % the manipulation is retargeted from the animal onto the part
            dose = TestPathSPromotion.firstOfClass(kept, 'dose_manipulation');
            testCase.verifyEqual(TestPathSPromotion.depValue(dose, 'subject_id'), partId);
            % the part_of relation points part -> animal
            rel = TestPathSPromotion.firstOfClass(minted, 'directed_relation');
            testCase.verifyEqual(TestPathSPromotion.depValue(rel, 'child'), partId);
            testCase.verifyEqual(TestPathSPromotion.depValue(rel, 'parent'), 'animal_1');
            testCase.verifyEqual(rel.directed_relation.relation.name, 'part_of');
            % the part carries the site term as its anatomical kind
            assertion = TestPathSPromotion.firstOfClass(minted, 'term_assertion');
            testCase.verifyEqual(assertion.term_assertion.value.node, 'uberon:0002436');
            testCase.verifyEqual(TestPathSPromotion.depValue(assertion, 'subject_id'), partId);
            % regression: subject_relation was renamed to `relation` in V_eta. The
            % relation must carry NO stale subject_relation block (an undeclared
            % top-level block quarantines -- the JH 163k-orphan regression) and must
            % descend from `relation`, not `subject_relation`.
            testCase.verifyFalse(isfield(rel, 'subject_relation'));
            supers = {rel.document_class.superclasses.class_name};
            testCase.verifyTrue(any(strcmp(supers, 'relation')));
            testCase.verifyFalse(any(strcmp(supers, 'subject_relation')));
            % the part-subject carries a non-empty (required) local_identifier
            part = TestPathSPromotion.firstOfClass(minted, 'subject');
            testCase.verifyNotEmpty(part.subject.local_identifier);
        end

        function testMerelyLocatedSiteUntouched(testCase)
            % a probe location: a site term_observation with NO co-anchored
            % manipulation -> left located-by-default, nothing minted.
            structs = TestPathSPromotion.probeWithSite('anch_2', 'probe_9', ...
                'uberon:0000955', 'brain');
            [kept, minted, changed] = ndi.migrate.internal.pathSPromotion(structs);

            testCase.verifyFalse(changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(numel(kept), numel(structs));
            testCase.verifyTrue(TestPathSPromotion.anyClass(kept, 'term_observation'));
        end

        function testDedupPerAnimalSite(testCase)
            % two treatments on the same animal targeting the same site -> a
            % single shared part-subject (find-or-create keyed on animal+site).
            a = TestPathSPromotion.treatmentWithSite('anch_1', 'animal_1', ...
                'uberon:0002436', 'primary visual cortex');
            b = TestPathSPromotion.treatmentWithSite('anch_3', 'animal_1', ...
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
            a = TestPathSPromotion.treatmentWithSite('anch_1', 'animal_1', ...
                'uberon:0002436', 'V1');
            b = TestPathSPromotion.treatmentWithSite('anch_3', 'animal_1', ...
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

    % ===================== fixtures + accessors (test-only) ================

    methods (Static, Access = private)

        function s = treatmentWithSite(anchorId, animalId, siteNode, siteName)
            manip = struct();
            manip.document_class = TestPathSPromotion.dc('dose_manipulation', ...
                {'subject_manipulation', 'dose'});
            manip.depends_on = [TestPathSPromotion.dep('subject_id', animalId), ...
                TestPathSPromotion.dep('time_reference_1', anchorId)];
            manip.base = TestPathSPromotion.base(['manip_' anchorId]);
            manip.subject_statement = struct('variable', ...
                TestPathSPromotion.term('chebi:1', 'muscimol'), 'storage_mode', 'inline');
            manip.subject_interaction = struct('method', TestPathSPromotion.term('', ''), ...
                'sample_time', struct('kind', 'point'));
            manip.subject_manipulation = struct('notes', '');
            manip.dose = struct('value', struct());

            site = TestPathSPromotion.siteObs(anchorId, animalId, siteNode, siteName, ...
                ['site_' anchorId]);
            anchor = TestPathSPromotion.anchor(anchorId);
            s = {manip, site, anchor};
        end

        function s = probeWithSite(anchorId, probeId, siteNode, siteName)
            site = TestPathSPromotion.siteObs(anchorId, probeId, siteNode, siteName, ...
                ['site_' anchorId]);
            anchor = TestPathSPromotion.anchor(anchorId);
            s = {site, anchor};
        end

        function site = siteObs(anchorId, subjectId, siteNode, siteName, baseId)
            site = struct();
            site.document_class = TestPathSPromotion.dc('term_observation', ...
                {'subject_observation'});
            site.depends_on = [TestPathSPromotion.dep('subject_id', subjectId), ...
                TestPathSPromotion.dep('time_reference_1', anchorId)];
            site.base = TestPathSPromotion.base(baseId);
            site.subject_statement = struct('variable', ...
                TestPathSPromotion.term('', 'anatomical location'), 'storage_mode', 'inline');
            site.subject_interaction = struct('method', TestPathSPromotion.term('', ''), ...
                'sample_time', struct('kind', 'point'));
            site.subject_observation = struct();
            site.term_observation = struct('value', ...
                TestPathSPromotion.term(siteNode, siteName));
        end

        function anchor = anchor(anchorId)
            anchor = struct();
            anchor.document_class = TestPathSPromotion.dc('session_relative_reference', ...
                {'time_reference'});
            anchor.depends_on = struct('name', {}, 'value', {});
            anchor.base = TestPathSPromotion.base(anchorId);
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
            b = TestPathSPromotion.firstOfClass(bodies, className);
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

    end
end
