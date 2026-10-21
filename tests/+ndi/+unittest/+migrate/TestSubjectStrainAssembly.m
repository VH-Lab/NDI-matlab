classdef TestSubjectStrainAssembly < matlab.unittest.TestCase
%TESTSUBJECTSTRAINASSEMBLY Unit tests for the V_eta subject-attached strain
%   second pass, #78 (pure struct logic; no database, schema, or toolbox).
%
%   ndi.migrate.internal.subjectStrainAssembly takes the did_v1 bodies AND the
%   migrated bodies, because everything it adds lives in a document other than
%   the one that needs it. On did-schema #88's shape
%   (V_eta_entity_composition_plan.md secs. 1, 4, 5) it mints one DEDUPLICATED
%   strain ENTITY (`entity`, type `strain`) per distinct strain with its
%   species / genetic strain type as ASSERTIONS about it, REPLACES the
%   subject's own `strain` assertion by an `instance_of` relation (subject ->
%   strain, keeping the assertion's id), wires the pedigree as `derived_from`
%   relations, moves the `genetic strain type` assertion onto the strain and
%   drops the duplicate `species` assertion.
%
%   ---------------------------------------------------------------------
%   WHERE THE FIXTURES COME FROM -- the WRITER, never a DID-side schema
%   ---------------------------------------------------------------------
%   The did_v1 half is what `openMINDSobj2ndi_document(strainObj, sessionId,
%   'subject', subjectId)` produces, read from NDI origin/main:
%
%     +ndi/+database/+fun/openMINDSobj2struct.m
%         every child object becomes its OWN document and the parent's field
%         becomes {'ndi://<childNdiId>'} -- a CELL, which is why
%         `fields.species` and `fields.backgroundStrain` are cellstr here
%     +ndi/+database/+fun/openMINDSobj2ndi_document.m
%         for i=1:numel(s)                          <- parent AND every child
%         add_dependency_value_n(...,'openminds',id_here,'ErrorIfNotFound',0)
%         set_dependency_value(d{i},'openminds','','ErrorIfNotFound',0)
%                                                   <- a leaf gets an EMPTY dep
%         if ~isempty(dependency_name)
%             d{i} = d{i}.set_dependency_value(dependency_name,dependency_value);
%                                    <- subject_id on EVERY document, parent
%                                       and children alike. That one line is
%                                       why a subject ends up with a `species`,
%                                       a `genetic strain type` and one
%                                       `strain` assertion PER ANCESTOR.
%
%   The strain objects themselves are the four production
%   SubjectInformationCreators:
%
%     +setup/+conv/+dabrowska/SubjectInformationCreator.m getStrain (:160-186)
%         st_sd = Strain('name',"SD",'species',sp,'ontologyIdentifier',
%                        "RRID:RGD_70508",'geneticStrainType',"wildtype")
%         st_trans.name = 'OTR-IRES-Cre'; st_trans.backgroundStrain = st_sd;
%         -- all three objects are constructed INSIDE the method, so every
%            table row mints fresh documents. That is the duplication this
%            pass exists to collapse.
%     +setup/+conv/+hunsberger/SubjectInformationCreator.m :70-107
%         strain.backgroundStrain = [ArcCreERT2,eYFP];   <- a real F1 cross,
%         ArcCreERT2.backgroundStrain = SvEv;               a DAG, not a tree
%         eYFP.backgroundStrain       = SvEv;
%     +setup/+NDIMaker/subjectMaker.m :265-274
%         species / strain / biologicalSex are THREE SEPARATE calls, so the
%         species object serialised inside the strain graph and the standalone
%         species document are two documents with two ids. That is the
%         duplicate `species` assertion.
%
%   The migrated half is what did2.convert.migrators_j.openminds_subject emits
%   on #88 (DID-matlab port-88: `jStatement(preBody, 'term_assertion', ...,
%   'Id', preBody.base.id)` through did2.build.statement): ONE `assertion`
%   with the `term` value kind per source document, the source id PRESERVED
%   (what this pass joins on), an `entity_id` edge to the subject and nothing
%   else (the openminds_# links are gone by then), the variable from the
%   openMINDS type on the `statement` block and the value on the `term` block.
%   The subject is an `entity` of type `organism` (migrators_j.subject).
%   testPreEightyEightAssertionsAreStillRead feeds the pre-#88 spelling too.
%
%   Run with:  runtests('ndi.unittest.migrate.TestSubjectStrainAssembly')
%
%   Fixtures/accessors are LOCAL FUNCTIONS below the classdef, as in
%   TestStrainAssembly and TestPathSPromotion.

    methods (Test)

        % ---------------- minting and dedup ----------------------------

        function testOneStrainEntityPerDistinctStrain(testCase)
            % Two rats, same genotype: dabrowska's getStrain built OTR-IRES-Cre
            % and its SD background TWICE, so four Strain documents describe
            % two strains.
            [v1, mig] = twoRatsSameGenotype();
            [~, minted, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);

            testCase.verifyTrue(report.changed);
            testCase.verifyEqual(report.strain_docs_seen, 4);
            testCase.verifyEqual(report.strains_candidate, 4);
            testCase.verifyEqual(report.distinct_strains, 2);
            testCase.verifyEqual(report.strains_minted, 2);
            testCase.verifyEqual(report.strain_docs_collapsed, 2);
            e = strainEntities(minted);
            testCase.verifyEqual(numel(e), 2);
            names = sort(cellfun(@(b) b.entity.name, e, 'UniformOutput', false));
            testCase.verifyEqual(names, {'OTR-IRES-Cre', 'SD'});
        end

        function testMintedStrainIsAnEntityOfTypeStrain(testCase)
            [~, minted, ~] = runOn(@twoRatsSameGenotype);
            sd = strainNamed(minted, 'SD');
            testCase.verifyEqual(sd.document_class.class_name, 'entity');
            testCase.verifyEqual(sd.document_class.schema_version, 'V_eta');
            testCase.verifyEqual({sd.document_class.superclasses.class_name}, {'base'});
            testCase.verifyEqual(sd.entity.type.name, 'strain');
            testCase.verifyEqual(sd.entity.name, 'SD');
            testCase.verifyFalse(isfield(sd, 'strain'));
            testCase.verifyFalse(isfield(sd.base, 'name'), ...
                'V_eta documents never write base.name (#73 item 54)');
            testCase.verifyNotEmpty(sessionOf(sd));
        end

        function testSpeciesAndGeneticStrainTypeAreAssertedOfTheStrain(testCase)
            [~, minted, report] = runOn(@twoRatsSameGenotype);
            sd = strainNamed(minted, 'SD');
            sp = assertionsAbout(minted, sd.base.id, 'Species');
            testCase.verifyNumElements(sp, 1);
            testCase.verifyEqual(sp{1}.statement.variable.node, 'NCIT:C45293');
            testCase.verifyEqual({sp{1}.document_class.superclasses.class_name}, ...
                {'statement', 'base', 'term', 'value', 'data'});
            testCase.verifyEqual(sp{1}.term.value.node, 'NCBITaxon:10116');
            testCase.verifyEqual(sp{1}.term.value.name, 'Rattus norvegicus');
            g = assertionsAbout(minted, sd.base.id, 'genetic strain type');
            testCase.verifyNumElements(g, 1);
            testCase.verifyEqual(g{1}.statement.variable.node, 'EMPTY:0000347');
            testCase.verifyEqual(g{1}.term.value.name, 'wildtype');
            % 2 strains x (species + genetic strain type)
            testCase.verifyEqual(report.strain_assertions_minted, 4);
        end

        function testIdIsNotPreservedOnTheStrainButKeptByTheRelation(testCase)
            [v1, mig] = twoRatsSameGenotype();
            [~, minted, ~] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            sourceIds = cellfun(@(b) b.base.id, v1, 'UniformOutput', false);
            e = strainEntities(minted);
            for k = 1:numel(e)
                testCase.verifyFalse(any(strcmp(sourceIds, e{k}.base.id)), ...
                    'a minted strain reused a source id that is still in use');
            end
            r = docWithId(minted, 'rat1_strain');
            testCase.verifyEqual(r.document_class.class_name, 'directed_relation');
        end

        function testTheSubjectIsAnInstanceOfItsStrain(testCase)
            % #88 sec. 5: the subject's own strain assertion becomes an
            % instance_of relation subject -> strain, and two rows share one
            % strain
            [kept, minted, report] = runOn(@twoRatsSameGenotype);
            testCase.verifyEqual(report.instance_of_minted, 2);
            r1 = relations(minted, 'rat1', 'instance_of');
            r2 = relations(minted, 'rat2', 'instance_of');
            testCase.verifyNumElements(r1, 1);
            testCase.verifyNumElements(r2, 1);
            cre = strainNamed(minted, 'OTR-IRES-Cre');
            testCase.verifyEqual(depValue(r1{1}, 'parent_id'), cre.base.id);
            testCase.verifyEqual(depValue(r2{1}, 'parent_id'), cre.base.id);
            testCase.verifyEqual(r1{1}.base.id, 'rat1_strain');
            testCase.verifyFalse(anyId(kept, 'rat1_strain'), ...
                'the replaced strain assertion must not survive beside its relation');
            testCase.verifyFalse(anyId(kept, 'rat2_strain'));
        end

        function testInstanceOfNamesADocumentThatExists(testCase)
            [~, minted, ~] = runOn(@twoRatsSameGenotype);
            mintedIds = cellfun(@(b) b.base.id, minted, 'UniformOutput', false);
            for k = 1:numel(minted)
                if ~strcmp(minted{k}.document_class.class_name, 'directed_relation')
                    continue;
                end
                testCase.verifyTrue(any(strcmp(mintedIds, depValue(minted{k}, 'parent_id'))));
            end
        end

        % ---------------- pedigree --------------------------------------

        function testPedigreeBecomesDerivedFromRelation(testCase)
            [~, minted, report] = runOn(@twoRatsSameGenotype);
            cre = strainNamed(minted, 'OTR-IRES-Cre');
            sd  = strainNamed(minted, 'SD');
            r = relations(minted, cre.base.id, 'derived_from');
            testCase.verifyNumElements(r, 1);
            testCase.verifyEqual(depValue(r{1}, 'parent_id'), sd.base.id);
            testCase.verifyEqual(r{1}.directed_relation.relation.node, 'RO:0001000');
            testCase.verifyEmpty(relations(minted, sd.base.id, 'derived_from'));
            testCase.verifyEqual(report.background_edges, 1);
            testCase.verifyEqual(report.background_unresolved, 0);
            testCase.verifyEqual(report.background_refs_seen, 2);
        end

        function testTwoParentCrossKeepsTheWriterSOrder(testCase)
            [~, minted, ~] = runOn(@hunsbergerCross);
            cross = strainNamed(minted, 'ArcCreERT2 x eYFP');
            arc   = strainNamed(minted, 'ArcCreERT2');
            eyfp  = strainNamed(minted, 'eYFP');
            r = relations(minted, cross.base.id, 'derived_from');
            testCase.verifyNumElements(r, 2);
            testCase.verifyEqual(depValue(r{1}, 'parent_id'), arc.base.id);
            testCase.verifyEqual(depValue(r{2}, 'parent_id'), eyfp.base.id);
        end

        function testSharedBackgroundIsStoredOnceAsADag(testCase)
            [~, minted, report] = runOn(@hunsbergerCross);
            testCase.verifyEqual(report.distinct_strains, 4);
            svev = strainNamed(minted, '129S/SvEv');
            arc  = strainNamed(minted, 'ArcCreERT2');
            eyfp = strainNamed(minted, 'eYFP');
            ra = relations(minted, arc.base.id, 'derived_from');
            re = relations(minted, eyfp.base.id, 'derived_from');
            testCase.verifyEqual(depValue(ra{1}, 'parent_id'), svev.base.id);
            testCase.verifyEqual(depValue(re{1}, 'parent_id'), svev.base.id);
            testCase.verifyEqual(report.pedigree_cycles, 0);
        end

        function testUnresolvableParentProducesNoRelation(testCase)
            [v1, mig] = twoRatsSameGenotype();
            [v1, mig] = dropDocument(v1, mig, 'rat1_sd');
            [v1, mig] = dropDocument(v1, mig, 'rat2_sd');
            [~, minted, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            cre = strainNamed(minted, 'OTR-IRES-Cre');
            testCase.verifyEmpty(relations(minted, cre.base.id, 'derived_from'));
            testCase.verifyEqual(report.background_edges, 0);
            testCase.verifyEqual(report.background_unresolved, 2);
        end

        function testPedigreeCycleIsCountedNotRecursedForever(testCase)
            [v1, mig] = cyclicPedigree();
            [~, minted, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyGreaterThanOrEqual(report.pedigree_cycles, 1);
            testCase.verifyEqual(report.distinct_strains, 2);
            testCase.verifyEqual(numel(strainEntities(minted)), 2);
        end

        % ---------------- genetic strain type ----------------------------

        function testGeneticStrainTypeAssertionMovesOntoTheStrain(testCase)
            % each rat's OWN strain is OTR-IRES-Cre, so its `knockin` moves;
            % SD is an ancestor reachable through derived_from, so its
            % `wildtype` assertion leaves the rat too (Jess Haley, 2026-10-21)
            [kept, minted, report] = runOn(@twoRatsSameGenotype);
            testCase.verifyEqual(report.gst_fragments_seen, 4);
            testCase.verifyEqual(report.gst_assertions_removed, 4);
            testCase.verifyEqual(report.gst_kept_not_the_subjects_strain, 0);
            testCase.verifyFalse(anyId(kept, 'rat1_gst_cre'));
            testCase.verifyFalse(anyId(kept, 'rat1_gst_sd'));
            sd = strainNamed(minted, 'SD');
            gsd = assertionsAbout(minted, sd.base.id, 'genetic strain type');
            testCase.verifyEqual(gsd{1}.term.value.name, 'wildtype');
            cre = strainNamed(minted, 'OTR-IRES-Cre');
            g = assertionsAbout(minted, cre.base.id, 'genetic strain type');
            testCase.verifyEqual(g{1}.term.value.name, 'knockin');
        end

        function testTheSubjectCanStillReachTheGeneticStrainType(testCase)
            [~, minted, ~] = runOn(@twoRatsSameGenotype);
            r = relations(minted, 'rat1', 'instance_of');
            target = depValue(r{1}, 'parent_id');
            g = assertionsAbout(minted, target, 'genetic strain type');
            testCase.verifyNumElements(g, 1);
            testCase.verifyEqual(g{1}.term.value.name, 'knockin');
        end

        function testGeneticStrainTypeAssertionIsKeptWhenTheValueDisagrees(testCase)
            [v1, mig] = twoRatsSameGenotype();
            mig = retermAssertion(mig, 'rat1_gst_cre', '', 'something else');
            [kept, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.gst_kept_value_not_on_strain, 1);
            testCase.verifyTrue(anyId(kept, 'rat1_gst_cre'));
        end

        function testGeneticStrainTypeAssertionIsKeptWhenPinned(testCase)
            [v1, mig] = twoRatsSameGenotype();
            mig{end+1} = relationDoc('rel_1', 'sess_A', 'rat1_gst_cre');
            [kept, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.gst_kept_pinned, 1);
            testCase.verifyTrue(anyId(kept, 'rat1_gst_cre'));
        end

        function testGeneticStrainTypeSharedWithAnUnassembledStrainIsKept(testCase)
            [v1, mig] = twoRatsSameGenotype();
            [v1, mig] = addStrainSharingGst(v1, mig);
            [kept, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.strains_incomplete, 1);
            testCase.verifyEqual(report.gst_kept_shared_with_unassembled, 1);
            testCase.verifyTrue(anyId(kept, 'rat1_gst_cre'));
        end

        function testInlineGeneticStrainTypeLeavesNothingToMove(testCase)
            [kept, minted, report] = runOn(@inlineGeneticStrainType);
            testCase.verifyEqual(report.gst_fragments_seen, 0);
            testCase.verifyEqual(report.gst_assertions_removed, 0);
            % the subject and its species stay; the strain assertion became
            % the instance_of relation
            testCase.verifyEqual(numel(kept), 2);
            n2 = strainNamed(minted, 'N2');
            g = assertionsAbout(minted, n2.base.id, 'genetic strain type');
            testCase.verifyEqual(g{1}.term.value.name, 'wildtype');
            testCase.verifyEqual(g{1}.term.value.node, '');
        end

        % ---------------- species -----------------------------------------

        function testDuplicateSpeciesAssertionIsDeduped(testCase)
            [kept, ~, report] = runOn(@twoRatsSameGenotype);
            testCase.verifyEqual(report.species_fragments_seen, 2);
            testCase.verifyEqual(report.species_duplicate_groups, 2);
            testCase.verifyEqual(report.species_assertions_removed, 2);
            testCase.verifyTrue(anyId(kept, 'rat1_species'));
            testCase.verifyFalse(anyId(kept, 'rat1_species_child'));
        end

        function testNonDuplicateSpeciesAssertionIsNeverTouched(testCase)
            [v1, mig] = twoRatsSameGenotype();
            mig = retermAssertion(mig, 'rat1_species_child', ...
                'NCBITaxon:10090', 'Mus musculus');
            [kept, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.species_assertions_removed, 1);
            testCase.verifyTrue(anyId(kept, 'rat1_species'));
            testCase.verifyTrue(anyId(kept, 'rat1_species_child'));
        end

        function testDuplicateSpeciesWithNoStrainFragmentIsOnlyCounted(testCase)
            [v1, mig] = twoRatsSameGenotype();
            mig{end+1} = assertionDoc('rat1_species_extra', 'sess_A', 'rat1', ...
                'species', 'NCBITaxon:10116', 'Rattus norvegicus');
            [kept, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.duplicate_species_groups_out_of_scope, 0);
            testCase.verifyFalse(anyId(kept, 'rat1_species_extra'));

            [v1b, migb] = duplicateSpeciesWithNoStrainFragment();
            [keptb, ~, reportb] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1b, migb);
            testCase.verifyEqual(reportb.duplicate_species_groups_out_of_scope, 1);
            testCase.verifyEqual(reportb.species_assertions_removed, 0);
            testCase.verifyTrue(anyId(keptb, 'other_species_a'));
            testCase.verifyTrue(anyId(keptb, 'other_species_b'));
        end

        function testSubjectlessSpeciesAssertionsAreNeverGrouped(testCase)
            [v1, mig] = twoRatsSameGenotype();
            mig = resubject(mig, 'rat1_species', '');
            mig = resubject(mig, 'rat1_species_child', '');
            [kept, ~, ~] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyTrue(anyId(kept, 'rat1_species'));
            testCase.verifyTrue(anyId(kept, 'rat1_species_child'));
        end

        % ---------------- what is left alone -------------------------------

        function testNamelessStrainIsLeftExactlyAsPassOneEmittedIt(testCase)
            % a strain entity requires `name` (entity_type_bindings)
            [v1, mig] = strainWithNoName();
            [kept, minted, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyFalse(report.changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(report.strains_incomplete, 1);
            testCase.verifyEqual(numel(report.incomplete_reasons), 1);
            testCase.verifyEqual(report.instance_of_minted, 0);
            testCase.verifyTrue(anyId(kept, 'lone_strain'));
        end

        function testStrainWithNoSpeciesStillAssembles(testCase)
            % species was a required FIELD of the pre-#88 `strain` class; on
            % #88 it is an assertion, so its absence leaves no species
            % assertion rather than refusing the strain
            [v1, mig] = strainWithNoSpecies();
            [~, minted, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.strains_minted, 1);
            x = strainNamed(minted, 'X');
            testCase.verifyEmpty(assertionsAbout(minted, x.base.id, 'Species'));
            testCase.verifyNumElements( ...
                assertionsAbout(minted, x.base.id, 'genetic strain type'), 1);
            testCase.verifyEqual(report.instance_of_minted, 1);
        end

        function testStrainAlreadyTurnedIntoAnEntityIsSkipped(testCase)
            [v1, mig] = twoRatsSameGenotype();
            mig = reclass(mig, 'rat1_strain', 'entity');
            [~, ~, report] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.strain_docs_not_a_term_assertion, 1);
            testCase.verifyEqual(report.strains_candidate, 3);
        end

        function testStrainAbsentFromTheMigratedSetIsCounted(testCase)
            [v1, mig] = twoRatsSameGenotype();
            mig = dropMigrated(mig, 'rat2_strain');
            [~, ~, report] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.strain_docs_not_in_migrated_set, 1);
            testCase.verifyEqual(report.strains_candidate, 3);
        end

        function testBareOpenmindsStrainBelongsToTheOtherPass(testCase)
            [v1, mig] = bareOpenmindsStrain();
            [kept, minted, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.strain_under_other_openminds_class, 1);
            testCase.verifyEqual(report.strain_docs_seen, 0);
            testCase.verifyFalse(report.changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(numel(kept), numel(mig));
        end

        % ---------------- ancestor strain assertions -----------------------
        % Decided by Jess Haley, 2026-10-21: "A subject keeps only its
        % `instance_of` link to its own strain; the ancestor-strain assertions
        % on the subject are dropped wherever the pedigree resolved into
        % `derived_from` links between strains (an unresolved parent's
        % assertion stays)."

        function testAncestorAssertionsAreDroppedWhereThePedigreeResolved(testCase)
            % the mouse is an instance of the CROSS only; its three ancestors
            % are reached cross -> arc/eyfp -> svev, so their assertions go
            [kept, minted, report] = runOn(@hunsbergerCross);
            testCase.verifyEqual(report.background_strain_assertions_on_subject, 3);
            testCase.verifyEqual(report.background_strain_assertions_removed, 3);
            testCase.verifyEqual(report.background_kept_unreachable, 0);
            testCase.verifyEqual(report.background_kept_pinned, 0);
            testCase.verifyFalse(anyId(kept, 'm1_svev'));
            testCase.verifyFalse(anyId(kept, 'm1_arc'));
            testCase.verifyFalse(anyId(kept, 'm1_eyfp'));
            testCase.verifyFalse(anyId(kept, 'm1_cross'));
            r = relations(minted, 'm1', 'instance_of');
            testCase.verifyNumElements(r, 1);
            cross = strainNamed(minted, 'ArcCreERT2 x eYFP');
            testCase.verifyEqual(depValue(r{1}, 'parent_id'), cross.base.id);
            testCase.verifyEqual(report.instance_of_minted, 1);
            % no `strain` assertion about the mouse is left at all
            testCase.verifyEmpty(assertionsAbout(kept, 'm1', 'strain'));
            % and both genetic strain types left the mouse with them
            testCase.verifyFalse(anyId(kept, 'm1_gst'));
            testCase.verifyFalse(anyId(kept, 'm1_gst_wt'));
        end

        function testTheDroppedAncestorIsStillReachableFromTheSubject(testCase)
            [~, minted, ~] = runOn(@hunsbergerCross);
            r = relations(minted, 'm1', 'instance_of');
            here = {depValue(r{1}, 'parent_id')};
            reached = here;
            while ~isempty(here)
                nxt = {};
                for k = 1:numel(here)
                    rr = relations(minted, here{k}, 'derived_from');
                    for q = 1:numel(rr)
                        nxt{end+1} = depValue(rr{q}, 'parent_id'); %#ok<AGROW>
                    end
                end
                here = setdiff(unique(nxt), reached);
                reached = [reached, here]; %#ok<AGROW>
            end
            svev = strainNamed(minted, '129S/SvEv');
            testCase.verifyTrue(any(strcmp(reached, svev.base.id)));
        end

        function testAnUnresolvedParentKeepsItsAncestorsAssertion(testCase)
            % eYFP cannot be assembled (no name), so cross -> eYFP is not a
            % derived_from link; 129S/SvEv is still reached through ArcCreERT2,
            % so only eYFP's own assertion stays -- and it is not a candidate
            % at all, so it is left by construction.
            [v1, mig] = hunsbergerCross();
            v1 = renameStrain(v1, 'm1_eyfp', '');
            [kept, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.background_unresolved, 1);
            testCase.verifyTrue(anyId(kept, 'm1_eyfp'));
            testCase.verifyFalse(anyId(kept, 'm1_arc'));
            testCase.verifyFalse(anyId(kept, 'm1_svev'));
            testCase.verifyEqual(report.background_strain_assertions_removed, 2);
        end

        function testAnAncestorBehindAnUnresolvedLinkStays(testCase)
            % Arc and eYFP both unassembled: svev is still an ancestor
            % candidate, but no derived_from chain reaches it from the cross
            [v1, mig] = hunsbergerCross();
            v1 = renameStrain(v1, 'm1_arc', '');
            v1 = renameStrain(v1, 'm1_eyfp', '');
            [kept, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyTrue(anyId(kept, 'm1_arc'));
            testCase.verifyTrue(anyId(kept, 'm1_eyfp'));
            testCase.verifyTrue(anyId(kept, 'm1_svev'));
            testCase.verifyEqual(report.background_strain_assertions_removed, 0);
        end

        function testAPinnedAncestorAssertionStays(testCase)
            [v1, mig] = hunsbergerCross();
            mig{end+1} = relationDoc('rel_1', 'sess_H', 'm1_arc');
            [kept, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.background_kept_pinned, 1);
            testCase.verifyTrue(anyId(kept, 'm1_arc'));
            testCase.verifyFalse(anyId(kept, 'm1_svev'));
        end

        function testACyclicPedigreeLosesNoStrainAssertion(testCase)
            % both strains are each other's ancestor, so the subject has no
            % own strain and nothing is reachable from one: both stay
            [v1, mig] = cyclicPedigree();
            [kept, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.instance_of_minted, 0);
            testCase.verifyEqual(report.background_kept_unreachable, 2);
            testCase.verifyTrue(anyId(kept, 'c_a'));
            testCase.verifyTrue(anyId(kept, 'c_b'));
        end

        function testEveryAncestorAssertionIsAccountedFor(testCase)
            [v1, mig] = hunsbergerCross();
            mig{end+1} = relationDoc('rel_1', 'sess_H', 'm1_arc');
            [~, ~, report] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.background_strain_assertions_on_subject, ...
                report.background_strain_assertions_removed ...
                + report.background_kept_unreachable ...
                + report.background_kept_pinned);
        end

        % ---------------- measured, not acted on ---------------------------

        function testCrossSessionMergeIsMeasuredAndNotPerformed(testCase)
            [~, minted, report] = runOn(@sameStrainTwoSessions);
            testCase.verifyEqual(report.distinct_strains, 2);
            e = strainEntities(minted);
            testCase.verifyEqual(numel(e), 2);
            testCase.verifyEqual(report.cross_session_groups, 1);
            testCase.verifyEqual(report.cross_session_collapsible, 1);
            sessions = sort(cellfun(@(b) sessionOf(b), e, 'UniformOutput', false));
            testCase.verifyEqual(sessions, {'sess_A', 'sess_B'});
        end

        function testInADatasetOneStrainIsOneEntityAtTheDatasetLevel(testCase)
            % Decided by Jess Haley, 2026-10-21: shared entities move to the
            % dataset level when a dataset is migrated; one entity per
            % distinct thing; session documents point at it.
            [v1, mig] = sameStrainTwoSessions();
            mig{end+1} = datasetEntity('ds_1');
            [~, minted, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.scope, 'dataset');
            testCase.verifyEqual(report.dataset_id, 'ds_1');
            testCase.verifyEqual(report.distinct_strains, 1);
            testCase.verifyEqual(report.cross_session_collapsible, 1);
            testCase.verifyEqual(report.cross_session_merged, 1);
            e = strainEntities(minted);
            testCase.verifyEqual(numel(e), 1);
            testCase.verifyEqual(sessionOf(e{1}), 'ds_1');
            % its assertions live with it
            g = assertionsAbout(minted, e{1}.base.id, 'species');
            testCase.verifyEqual(sessionOf(g{1}), 'ds_1');
            % each worm, in its own session, is an instance_of the one strain
            for w = {'worm_sess_A', 'worm_sess_B'}
                r = relations(minted, w{1}, 'instance_of');
                testCase.verifyNumElements(r, 1);
                testCase.verifyEqual(depValue(r{1}, 'parent_id'), e{1}.base.id);
                testCase.verifyEqual(sessionOf(r{1}), strrep(w{1}, 'worm_', ''));
            end
        end

        function testWithTwoDatasetEntitiesTheScopeStaysTheSession(testCase)
            [v1, mig] = sameStrainTwoSessions();
            mig{end+1} = datasetEntity('ds_1');
            mig{end+1} = datasetEntity('ds_2');
            [~, ~, report] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.scope, 'session');
            testCase.verifyEqual(report.distinct_strains, 2);
            testCase.verifyEqual(report.cross_session_merged, 0);
        end

        % ---------------- identifiers --------------------------------------

        function testGlobalIdentifierIsACurie(testCase)
            [~, minted, ~] = runOn(@twoRatsSameGenotype);
            sd = strainNamed(minted, 'SD');
            testCase.verifyEqual(sd.entity.global_identifier, {'RRID:RGD_70508'});
            [~, minted2, ~] = runOn(@inlineGeneticStrainType);
            n2 = strainNamed(minted2, 'N2');
            testCase.verifyEqual(n2.entity.global_identifier, {'WormBase:WBStrain00000001'});
        end

        function testIdentifierlessStrainStillAssembles(testCase)
            [~, minted, ~] = runOn(@twoRatsSameGenotype);
            cre = strainNamed(minted, 'OTR-IRES-Cre');
            testCase.verifyFalse(isfield(cre.entity, 'global_identifier'));
        end

        % ---------------- denominators ------------------------------------

        function testReportStatesItsDenominatorsFirst(testCase)
            [v1, mig] = twoRatsSameGenotype();
            [~, ~, report] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            fn = fieldnames(report);
            testCase.verifyEqual(fn{1}, 'v1_bodies_inspected');
            testCase.verifyEqual(fn{2}, 'documents_inspected');
            testCase.verifyEqual(report.v1_bodies_inspected, numel(v1));
            testCase.verifyEqual(report.documents_inspected, numel(mig));
            testCase.verifyEqual(report.strain_docs_seen, ...
                report.strains_candidate + report.strains_incomplete ...
                + report.strain_docs_not_in_migrated_set ...
                + report.strain_docs_not_a_term_assertion);
            testCase.verifyEqual(report.strains_candidate, ...
                report.instance_of_minted ...
                + report.background_strain_assertions_on_subject ...
                + report.strain_assertions_without_subject);
        end

        function testEveryGeneticStrainTypeFragmentIsAccountedFor(testCase)
            [v1, mig] = twoRatsSameGenotype();
            mig{end+1} = relationDoc('rel_1', 'sess_A', 'rat1_gst_cre');
            mig = retermAssertion(mig, 'rat2_gst_cre', '', 'disagrees');
            [~, ~, report] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.gst_fragments_seen, ...
                report.gst_assertions_removed ...
                + report.gst_kept_value_not_on_strain ...
                + report.gst_kept_shared_with_unassembled ...
                + report.gst_kept_wrong_subject ...
                + report.gst_kept_not_the_subjects_strain ...
                + report.gst_kept_pinned ...
                + report.gst_kept_not_a_term_assertion);
            testCase.verifyEqual(report.gst_kept_pinned, 1);
            testCase.verifyEqual(report.gst_kept_value_not_on_strain, 1);
            % the two SD fragments leave with the SD assertions they belong to
            testCase.verifyEqual(report.gst_kept_not_the_subjects_strain, 0);
            testCase.verifyEqual(report.gst_assertions_removed, 2);
        end

        function testEmptyInputIsInertAndStillReports(testCase)
            [kept, minted, report] = ...
                ndi.migrate.internal.subjectStrainAssembly({}, {});
            testCase.verifyEmpty(kept);
            testCase.verifyEmpty(minted);
            testCase.verifyFalse(report.changed);
            testCase.verifyEqual(report.v1_bodies_inspected, 0);
            testCase.verifyEqual(report.documents_inspected, 0);
            testCase.verifyEqual(report.strain_docs_seen, 0);
        end

        function testNoOpenmindsBodyIsNotTheSameZeroAsNoStrain(testCase)
            [~, mig] = twoRatsSameGenotype();
            [~, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly({subjectDoc('rat1')}, mig);
            testCase.verifyEqual(report.v1_openminds_bodies, 0);
            testCase.verifyEqual(report.strain_docs_seen, 0);

            [v1b, migb] = speciesOnlySubject();
            [~, ~, r2] = ndi.migrate.internal.subjectStrainAssembly(v1b, migb);
            testCase.verifyEqual(r2.v1_openminds_subject_bodies, 1);
            testCase.verifyEqual(r2.strain_docs_seen, 0);
        end

        function testSnakeCaseFieldKeysAlsoResolve(testCase)
            [v1, mig] = twoRatsSameGenotype();
            for k = 1:numel(v1)
                v1{k} = snakeifyFields(v1{k});
            end
            [~, minted, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.strains_minted, 2);
            cre = strainNamed(minted, 'OTR-IRES-Cre');
            sd  = strainNamed(minted, 'SD');
            r = relations(minted, cre.base.id, 'derived_from');
            testCase.verifyEqual(depValue(r{1}, 'parent_id'), sd.base.id);
        end

        function testEbrainsAndOmiTypeIrisBothMatch(testCase)
            [v1, mig] = twoRatsSameGenotype();
            for k = 1:numel(v1)
                v1{k}.openminds.openminds_type = strrep( ...
                    v1{k}.openminds.openminds_type, ...
                    'openminds.om-i.org/types', 'openminds.ebrains.eu/core');
                v1{k}.openminds.matlab_type = '';
            end
            [~, ~, report] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.strain_docs_seen, 4);
            testCase.verifyEqual(report.strains_minted, 2);
        end

        function testPreEightyEightAssertionsAreStillRead(testCase)
            % pass-1 output from a pre-#88 DID-matlab: term_assertion,
            % subject_id, subject_statement. Read the same way; written #88.
            [v1, mig] = twoRatsSameGenotype();
            for k = 1:numel(mig)
                if strcmp(mig{k}.document_class.class_name, 'assertion')
                    mig{k}.document_class.class_name = 'term_assertion';
                    mig{k}.document_class.superclasses = struct( ...
                        'class_name', 'subject_assertion', 'class_version', '1.0.0');
                    mig{k}.depends_on = dep('subject_id', depValue(mig{k}, 'entity_id'));
                    mig{k}.subject_statement = mig{k}.statement;
                    mig{k} = rmfield(mig{k}, 'statement');
                end
            end
            [~, minted, report] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.strains_minted, 2);
            testCase.verifyEqual(report.instance_of_minted, 2);
            testCase.verifyEqual(report.species_assertions_removed, 2);
            r = relations(minted, 'rat1', 'instance_of');
            testCase.verifyNumElements(r, 1);
        end

    end
end


function [kept, minted, report] = runOn(fixtureFcn)
%RUNON Run the pass over a fixture. Takes a FUNCTION HANDLE, not the fixture's
%   output: `runOn(fixture())` would pass only the first of the two returns,
%   silently handing the pass an empty migrated set.
[v1, mig] = fixtureFcn();
[kept, minted, report] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
end

function [v1, mig] = twoRatsSameGenotype()
% dabrowska, two OTR-IRES-Cre rats in one session. getStrain
% (SubjectInformationCreator.m:160-186) constructs st_sd and st_trans INSIDE
% the method, so each row mints its own documents:
%   st_trans 'OTR-IRES-Cre', geneticStrainType "knockin", backgroundStrain st_sd
%   st_sd    'SD', ontologyIdentifier "RRID:RGD_70508", geneticStrainType "wildtype"
% subjectMaker.m:265-274 writes the species in a SEPARATE call, so the species
% object appears twice per subject under two ids.
v1 = {};
mig = {};
for r = 1:2
    p   = sprintf('rat%d', r);
    sub = p;
    sess = 'sess_A';

    % --- did_v1 -------------------------------------------------------
    v1{end+1} = omDoc([p '_species'], sess, sub, 'Species', ...
        struct('name', 'Rattus norvegicus', ...
               'preferredOntologyIdentifier', 'NCBITaxon:10116'), {});
    v1{end+1} = omDoc([p '_species_child'], sess, sub, 'Species', ...
        struct('name', 'Rattus norvegicus', ...
               'preferredOntologyIdentifier', 'NCBITaxon:10116'), {});
    v1{end+1} = omDoc([p '_gst_cre'], sess, sub, 'GeneticStrainType', ...
        struct('name', 'knockin'), {});
    v1{end+1} = omDoc([p '_gst_sd'], sess, sub, 'GeneticStrainType', ...
        struct('name', 'wildtype'), {});
    v1{end+1} = omDoc([p '_sd'], sess, sub, 'Strain', ...
        struct('name', 'SD', ...
               'species', {{['ndi://' p '_species_child']}}, ...
               'geneticStrainType', {{['ndi://' p '_gst_sd']}}, ...
               'ontologyIdentifier', 'RRID:RGD_70508'), ...
        {[p '_species_child'], [p '_gst_sd']});
    v1{end+1} = omDoc([p '_strain'], sess, sub, 'Strain', ...
        struct('name', 'OTR-IRES-Cre', ...
               'species', {{['ndi://' p '_species_child']}}, ...
               'geneticStrainType', {{['ndi://' p '_gst_cre']}}, ...
               'backgroundStrain', {{['ndi://' p '_sd']}}), ...
        {[p '_species_child'], [p '_gst_cre'], [p '_sd']});

    % --- what pass 1 made of them -------------------------------------
    mig{end+1} = subjectDoc(sub);
    mig{end+1} = assertionDoc([p '_species'], sess, sub, 'species', ...
        'NCBITaxon:10116', 'Rattus norvegicus');
    mig{end+1} = assertionDoc([p '_species_child'], sess, sub, 'species', ...
        'NCBITaxon:10116', 'Rattus norvegicus');
    mig{end+1} = assertionDoc([p '_gst_cre'], sess, sub, ...
        'genetic strain type', '', 'knockin');
    mig{end+1} = assertionDoc([p '_gst_sd'], sess, sub, ...
        'genetic strain type', '', 'wildtype');
    mig{end+1} = assertionDoc([p '_sd'], sess, sub, 'strain', ...
        'RRID:RGD_70508', 'SD');
    mig{end+1} = assertionDoc([p '_strain'], sess, sub, 'strain', '', ...
        'OTR-IRES-Cre');
end
end

function [v1, mig] = hunsbergerCross()
% hunsberger/SubjectInformationCreator.m:70-107 -- the real F1 cross.
sess = 'sess_H'; sub = 'm1';
spec = struct('name', 'Mus musculus', ...
    'preferredOntologyIdentifier', 'NCBITaxon:10090');
v1 = { ...
    omDoc('m1_species_child', sess, sub, 'Species', spec, {}), ...
    omDoc('m1_gst', sess, sub, 'GeneticStrainType', ...
        struct('name', 'transgenic'), {}), ...
    omDoc('m1_gst_wt', sess, sub, 'GeneticStrainType', ...
        struct('name', 'wildtype'), {}), ...
    omDoc('m1_svev', sess, sub, 'Strain', ...
        struct('name', '129S/SvEv', ...
               'species', {{'ndi://m1_species_child'}}, ...
               'geneticStrainType', {{'ndi://m1_gst_wt'}}, ...
               'ontologyIdentifier', 'NCIT:C37334'), ...
        {'m1_species_child', 'm1_gst_wt'}), ...
    omDoc('m1_arc', sess, sub, 'Strain', ...
        struct('name', 'ArcCreERT2', ...
               'species', {{'ndi://m1_species_child'}}, ...
               'geneticStrainType', {{'ndi://m1_gst'}}, ...
               'ontologyIdentifier', 'EMPTY:00000284', ...
               'backgroundStrain', {{'ndi://m1_svev'}}), ...
        {'m1_species_child', 'm1_gst', 'm1_svev'}), ...
    omDoc('m1_eyfp', sess, sub, 'Strain', ...
        struct('name', 'eYFP', ...
               'species', {{'ndi://m1_species_child'}}, ...
               'geneticStrainType', {{'ndi://m1_gst'}}, ...
               'ontologyIdentifier', 'EMPTY:00000287', ...
               'backgroundStrain', {{'ndi://m1_svev'}}), ...
        {'m1_species_child', 'm1_gst', 'm1_svev'}), ...
    omDoc('m1_cross', sess, sub, 'Strain', ...
        struct('name', 'ArcCreERT2 x eYFP', ...
               'species', {{'ndi://m1_species_child'}}, ...
               'geneticStrainType', {{'ndi://m1_gst'}}, ...
               'ontologyIdentifier', 'EMPTY:00000288', ...
               'backgroundStrain', {{'ndi://m1_arc', 'ndi://m1_eyfp'}}), ...
        {'m1_species_child', 'm1_gst', 'm1_arc', 'm1_eyfp'})};

mig = { ...
    subjectDoc(sub), ...
    assertionDoc('m1_species_child', sess, sub, 'species', ...
        'NCBITaxon:10090', 'Mus musculus'), ...
    assertionDoc('m1_gst', sess, sub, 'genetic strain type', '', 'transgenic'), ...
    assertionDoc('m1_gst_wt', sess, sub, 'genetic strain type', '', 'wildtype'), ...
    assertionDoc('m1_svev', sess, sub, 'strain', 'NCIT:C37334', '129S/SvEv'), ...
    assertionDoc('m1_arc', sess, sub, 'strain', 'EMPTY:00000284', 'ArcCreERT2'), ...
    assertionDoc('m1_eyfp', sess, sub, 'strain', 'EMPTY:00000287', 'eYFP'), ...
    assertionDoc('m1_cross', sess, sub, 'strain', 'EMPTY:00000288', ...
        'ArcCreERT2 x eYFP')};
end

function [v1, mig] = sameStrainTwoSessions()
% The same N2 strain written under two sessions -- haley writes one strain
% object per session (doImport.m runs per session).
v1 = {}; mig = {};
sessions = {'sess_A', 'sess_B'};
for s = 1:2
    sess = sessions{s};
    sub  = ['worm_' sess];
    p    = ['w' num2str(s)];
    v1{end+1} = omDoc([p '_species_child'], sess, sub, 'Species', ...
        struct('name', 'Caenorhabditis elegans', ...
               'preferredOntologyIdentifier', 'NCBITaxon:6239'), {});
    v1{end+1} = omDoc([p '_strain'], sess, sub, 'Strain', ...
        struct('name', 'N2', ...
               'species', {{['ndi://' p '_species_child']}}, ...
               'geneticStrainType', 'wild type', ...
               'ontologyIdentifier', 'WBStrain:00000001'), ...
        {[p '_species_child']});
    mig{end+1} = subjectDoc(sub);
    mig{end+1} = assertionDoc([p '_species_child'], sess, sub, 'species', ...
        'NCBITaxon:6239', 'Caenorhabditis elegans');
    mig{end+1} = assertionDoc([p '_strain'], sess, sub, 'strain', ...
        'WBStrain:00000001', 'N2');
end
end

function [v1, mig] = inlineGeneticStrainType()
% haley/SubjectInformationCreator.m:80 assigns the CHAR 'wild type'; dabrowska
% assigns "wildtype". Inline means no fragment document at all.
sess = 'sess_A'; sub = 'w1';
v1 = { ...
    omDoc('w1_species_child', sess, sub, 'Species', ...
        struct('name', 'Caenorhabditis elegans', ...
               'preferredOntologyIdentifier', 'NCBITaxon:6239'), {}), ...
    omDoc('w1_strain', sess, sub, 'Strain', ...
        struct('name', 'N2', ...
               'species', {{'ndi://w1_species_child'}}, ...
               'geneticStrainType', 'wildtype', ...
               'ontologyIdentifier', 'WBStrain:00000001'), ...
        {'w1_species_child'})};
mig = { ...
    subjectDoc(sub), ...
    assertionDoc('w1_species_child', sess, sub, 'species', ...
        'NCBITaxon:6239', 'Caenorhabditis elegans'), ...
    assertionDoc('w1_strain', sess, sub, 'strain', 'WBStrain:00000001', 'N2')};
end

function [v1, mig] = speciesOnlySubject()
% An openminds_subject batch with no Strain in it at all.
sess = 'sess_A'; sub = 'r1';
v1  = {omDoc('r1_species', sess, sub, 'Species', ...
    struct('name', 'Rattus norvegicus', ...
           'preferredOntologyIdentifier', 'NCBITaxon:10116'), {})};
mig = {subjectDoc(sub), assertionDoc('r1_species', sess, sub, 'species', ...
    'NCBITaxon:10116', 'Rattus norvegicus')};
end

function [v1, mig] = strainWithNoSpecies()
sess = 'sess_A'; sub = 'r1';
v1  = {omDoc('lone_strain', sess, sub, 'Strain', ...
    struct('name', 'X', 'geneticStrainType', 'wildtype'), {})};
mig = {subjectDoc(sub), ...
    assertionDoc('lone_strain', sess, sub, 'strain', '', 'X')};
end

function [v1, mig] = strainWithNoName()
sess = 'sess_A'; sub = 'r1';
v1  = {omDoc('lone_strain', sess, sub, 'Strain', ...
    struct('geneticStrainType', 'wildtype'), {})};
mig = {subjectDoc(sub), ...
    assertionDoc('lone_strain', sess, sub, 'strain', '', 'X')};
end

function [v1, mig] = bareOpenmindsStrain()
% haley/doImport.m:87 -- the BARE call, no dependency_type. These belong to
% ndi.migrate.internal.strainAssembly and are still `openminds` passthroughs.
b = omDoc('op50_doc', 'sess_A', '', 'Strain', ...
    struct('name', 'Escherichia coli OP50', ...
           'geneticStrainType', 'wild type', ...
           'ontologyIdentifier', 'NCBITaxon:637912'), {});
b.document_class.class_name = 'openminds';
b.depends_on = dep('openminds', '');
v1 = {b};

m = b;
m.document_class.schema_version = 'V_eta';
mig = {m};
end

function [v1, mig] = cyclicPedigree()
% Not a shape any writer produces -- a guard, so a malformed graph cannot make
% the key recursion run forever.
sess = 'sess_A'; sub = 'r1';
spec = struct('name', 'Rattus norvegicus', ...
    'preferredOntologyIdentifier', 'NCBITaxon:10116');
v1 = { ...
    omDoc('c_species', sess, sub, 'Species', spec, {}), ...
    omDoc('c_a', sess, sub, 'Strain', ...
        struct('name', 'A', 'species', {{'ndi://c_species'}}, ...
               'geneticStrainType', 'wildtype', ...
               'backgroundStrain', {{'ndi://c_b'}}), {'c_species', 'c_b'}), ...
    omDoc('c_b', sess, sub, 'Strain', ...
        struct('name', 'B', 'species', {{'ndi://c_species'}}, ...
               'geneticStrainType', 'wildtype', ...
               'backgroundStrain', {{'ndi://c_a'}}), {'c_species', 'c_a'})};
mig = { ...
    subjectDoc(sub), ...
    assertionDoc('c_species', sess, sub, 'species', 'NCBITaxon:10116', ...
        'Rattus norvegicus'), ...
    assertionDoc('c_a', sess, sub, 'strain', '', 'A'), ...
    assertionDoc('c_b', sess, sub, 'strain', '', 'B')};
end

function [v1, mig] = duplicateSpeciesWithNoStrainFragment()
% Two identical species assertions on one subject with NO strain anywhere --
% a duplicate this family did not cause. Counted, untouched. A Strain is
% present on a DIFFERENT subject so the pass has work to do at all.
[v1, mig] = inlineGeneticStrainType();
sess = 'sess_A';
v1{end+1}  = omDoc('other_species_a', sess, 'w2', 'Species', ...
    struct('name', 'Caenorhabditis elegans', ...
           'preferredOntologyIdentifier', 'NCBITaxon:6239'), {});
v1{end+1}  = omDoc('other_species_b', sess, 'w2', 'Species', ...
    struct('name', 'Caenorhabditis elegans', ...
           'preferredOntologyIdentifier', 'NCBITaxon:6239'), {});
mig{end+1} = subjectDoc('w2');
mig{end+1} = assertionDoc('other_species_a', sess, 'w2', 'species', ...
    'NCBITaxon:6239', 'Caenorhabditis elegans');
mig{end+1} = assertionDoc('other_species_b', sess, 'w2', 'species', ...
    'NCBITaxon:6239', 'Caenorhabditis elegans');
end

function [v1, mig] = addStrainSharingGst(v1, mig)
% A Strain that references rat1's GeneticStrainType fragment but cannot be
% assembled itself (no name -- the one field a strain entity requires), so
% the fragment must be retained.
sess = 'sess_A'; sub = 'rat1';
v1{end+1}  = omDoc('shared_strain', sess, sub, 'Strain', ...
    struct('geneticStrainType', {{'ndi://rat1_gst_cre'}}), ...
    {'rat1_gst_cre'});
mig{end+1} = assertionDoc('shared_strain', sess, sub, 'strain', '', 'Y');
end

% ===================== document builders ==================================

function b = omDoc(id, sessionId, subjectId, typeName, fields, childRefs)
%OMDOC A did_v1 `openminds_subject` body, exactly as
%   openMINDSobj2ndi_document writes one: the `openminds` mixin block, an
%   `openminds_1..n` dependency per ndi:// child (or ONE EMPTY `openminds` dep
%   for a leaf), and `subject_id` on every document of the flattened graph.
b = struct();
b.document_class = dc('openminds_subject', {'base', 'openminds'});
deps = struct('name', {}, 'value', {});
if isempty(childRefs)
    deps(end+1) = dep('openminds', '');
else
    for k = 1:numel(childRefs)
        deps(end+1) = dep(sprintf('openminds_%d', k), childRefs{k}); %#ok<AGROW>
    end
end
deps(end+1) = dep('subject_id', subjectId);
b.depends_on = deps;
b.base = base(id, sessionId);
b.openminds = struct( ...
    'openminds_type', ['https://openminds.om-i.org/types/' typeName], ...
    'matlab_type', matlabTypeFor(typeName), ...
    'openminds_id', ['https://openminds.om-i.org/instances/' id], ...
    'fields', fields);
b.openminds_subject = struct();
end

function t = matlabTypeFor(typeName)
switch typeName
    case 'Strain'
        t = 'openminds.core.research.Strain';
    otherwise
        t = ['openminds.controlledterms.' typeName];
end
end

function b = assertionDoc(id, sessionId, subjectId, variableName, node, name)
%ASSERTIONDOC What did2.convert.migrators_j.openminds_subject emits on
%   did-schema #88: an `assertion` with the `term` value kind, the source id
%   PRESERVED (the join this pass depends on), ONE `entity_id` edge to the
%   subject, the variable on the `statement` block and the value on the `term`
%   block.
b = struct();
b.document_class = dc('assertion', {'statement', 'base', 'term', 'value', 'data'});
b.document_class.schema_version = 'V_eta';
b.depends_on = dep('entity_id', subjectId);
b.base = struct('id', id, 'session_id', sessionId, ...
    'creation_timestamp', '2024-06-01T12:00:00.000Z');
b.statement = struct('variable', struct('node', '', 'name', variableName));
b.term = struct('value', struct('node', node, 'name', name));
end

function d = datasetEntity(id)
%DATASETENTITY A did-schema #88 `entity` of type dataset (its id is the
%   dataset's session id).
d = struct();
d.document_class = dc('entity', {'base'});
d.document_class.schema_version = 'V_eta';
d.depends_on = struct('name', {}, 'value', {});
d.base = struct('id', id, 'session_id', id, ...
    'creation_timestamp', '2024-06-01T12:00:00.000Z');
d.entity = struct('type', struct('node', '', 'name', 'dataset'), 'name', 'ds');
end

function b = subjectDoc(id)
%SUBJECTDOC What did2.convert.migrators_j.subject emits on #88: an `entity`
%   of type `organism`, id preserved.
b = struct();
b.document_class = dc('entity', {'base'});
b.document_class.schema_version = 'V_eta';
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', id, 'session_id', 'sess_A', ...
    'creation_timestamp', '2024-06-01T12:00:00.000Z');
b.entity = struct('type', struct('node', '', 'name', 'organism'), ...
    'local_identifier', id);
end

function b = relationDoc(id, sessionId, targetId)
%RELATIONDOC Any document with an inbound edge onto TARGETID -- the "pinned"
%   case. Nothing is removed that anything points at.
b = struct();
b.document_class = dc('directed_relation', {'relation', 'base'});
b.depends_on = [dep('child_id', targetId), dep('parent_id', 'someone_else')];
b.base = struct('id', id, 'session_id', sessionId, ...
    'creation_timestamp', '2024-06-01T12:00:00.000Z');
b.directed_relation = struct('relation', ...
    struct('node', 'BFO:0000050', 'name', 'part_of'));
end

function d = dep(name, value)
d = struct('name', name, 'value', value);
end

function x = base(id, sessionId)
x = struct('id', id, 'session_id', sessionId, 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
end

function x = dc(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
x = struct('class_name', name, 'class_version', '1.0.0', 'superclasses', sc);
end

% ===================== fixture mutators ===================================

function s = snakeifyFields(s)
map = {'geneticStrainType', 'genetic_strain_type'; ...
       'backgroundStrain',  'background_strain'; ...
       'ontologyIdentifier', 'ontology_identifier'; ...
       'preferredOntologyIdentifier', 'preferred_ontology_identifier'};
if ~isfield(s, 'openminds') || ~isstruct(s.openminds) ...
        || ~isfield(s.openminds, 'fields') || ~isstruct(s.openminds.fields)
    return;
end
f = s.openminds.fields;
for k = 1:size(map, 1)
    if isfield(f, map{k,1})
        f.(map{k,2}) = f.(map{k,1});
        f = rmfield(f, map{k,1});
    end
end
s.openminds.fields = f;
end

function mig = retermAssertion(mig, id, node, name)
for k = 1:numel(mig)
    if strcmp(mig{k}.base.id, id)
        mig{k}.term.value = struct('node', node, 'name', name);
        return;
    end
end
error('fixture has no document %s', id);
end

function v1 = renameStrain(v1, id, name)
%RENAMESTRAIN Set a did_v1 Strain's `fields.name`; '' makes it unassemblable
%   (a strain entity requires a name), i.e. an unresolved parent.
for k = 1:numel(v1)
    if strcmp(v1{k}.base.id, id)
        v1{k}.openminds.fields.name = name;
        return;
    end
end
error('fixture has no document %s', id);
end

function mig = resubject(mig, id, subjectId)
for k = 1:numel(mig)
    if strcmp(mig{k}.base.id, id)
        mig{k}.depends_on = dep('entity_id', subjectId);
        return;
    end
end
error('fixture has no document %s', id);
end

function mig = reclass(mig, id, className)
for k = 1:numel(mig)
    if strcmp(mig{k}.base.id, id)
        mig{k}.document_class.class_name = className;
        return;
    end
end
error('fixture has no document %s', id);
end

function mig = dropMigrated(mig, id)
keep = true(1, numel(mig));
for k = 1:numel(mig)
    if strcmp(mig{k}.base.id, id); keep(k) = false; end
end
mig = mig(keep);
end

function [v1, mig] = dropDocument(v1, mig, id)
keep = true(1, numel(v1));
for k = 1:numel(v1)
    if strcmp(v1{k}.base.id, id); keep(k) = false; end
end
v1 = v1(keep);
mig = dropMigrated(mig, id);
end

% ===================== accessors ==========================================

function out = strainEntities(minted)
out = {};
for k = 1:numel(minted)
    m = minted{k};
    if strcmp(m.document_class.class_name, 'entity') ...
            && strcmp(m.entity.type.name, 'strain')
        out{end+1} = m; %#ok<AGROW>
    end
end
end

function b = strainNamed(minted, name)
b = [];
e = strainEntities(minted);
for k = 1:numel(e)
    if strcmp(e{k}.entity.name, name)
        b = e{k};
        return;
    end
end
error('no minted strain named %s', name);
end

function out = assertionsAbout(list, entityId, variableName)
out = {};
for k = 1:numel(list)
    b = list{k};
    if strcmp(b.document_class.class_name, 'assertion') ...
            && strcmp(depValue(b, 'entity_id'), entityId) ...
            && strcmpi(b.statement.variable.name, variableName)
        out{end+1} = b; %#ok<AGROW>
    end
end
end

function out = relations(list, childId, relationName)
out = {};
for k = 1:numel(list)
    b = list{k};
    if strcmp(b.document_class.class_name, 'directed_relation') ...
            && strcmp(depValue(b, 'child_id'), childId) ...
            && strcmp(b.directed_relation.relation.name, relationName)
        out{end+1} = b; %#ok<AGROW>
    end
end
end

function sid = sessionOf(b)
if isfield(b.base, 'session_id')
    sid = b.base.session_id;
else
    sid = depValue(b, 'session_id');
end
end

function b = docWithId(list, id)
b = [];
for k = 1:numel(list)
    if strcmp(list{k}.base.id, id)
        b = list{k};
        return;
    end
end
error('no document with id %s', id);
end

function tf = anyId(list, id)
tf = false;
for k = 1:numel(list)
    if strcmp(list{k}.base.id, id)
        tf = true;
        return;
    end
end
end

function v = depValue(b, name)
v = '';
if isempty(b) || ~isstruct(b) || ~isfield(b, 'depends_on') ...
        || ~isstruct(b.depends_on)
    return;
end
for k = 1:numel(b.depends_on)
    d = b.depends_on(k);
    if ~isfield(d, 'name') || ~strcmp(d.name, name); continue; end
    if isfield(d, 'value')
        v = d.value;
    elseif isfield(d, 'document_id')
        v = d.document_id;
    end
    return;
end
end
