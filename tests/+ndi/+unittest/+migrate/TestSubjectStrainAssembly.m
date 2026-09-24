classdef TestSubjectStrainAssembly < matlab.unittest.TestCase
%TESTSUBJECTSTRAINASSEMBLY Unit tests for the V_eta subject-attached strain
%   second pass, #78 (pure struct logic; no database, schema, or toolbox).
%
%   ndi.migrate.internal.subjectStrainAssembly takes the did_v1 bodies AND the
%   migrated bodies, because everything it adds lives in a document other than
%   the one that needs it. It mints one DEDUPLICATED `strain` entity per
%   distinct strain, puts `strain_id` back on the `term_assertion` pass 1 left
%   bare, wires `background_strain_#`, moves the `genetic strain type`
%   assertion onto the strain and drops the duplicate `species` assertion.
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
%   The migrated half is what did2.convert.migrators_j.openminds_subject emits:
%   ONE `term_assertion` per source document, `base` kept VERBATIM (:54, so the
%   id is preserved and is what this pass joins on), `depends_on` ASSIGNED to
%   just subject_id (:52 jCarrySubject -- which is why the openminds_# links
%   are gone by then), variable from the openMINDS type (:64-80) and the value
%   on the `term` block (:57).
%
%   A NOTE ON THE SUPERCLASS BLOCK IN THE FIXTURES: openminds_subject.m:48
%   writes a SINGLE superclass (`subject_assertion`) although V_eta's
%   term_assertion is subject_assertion x term; ensureClassBlocks rebuilds the
%   chain during the re-fold. The fixtures copy what the migrator writes, not
%   what the schema declares, because that is what this pass is handed.
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
            testCase.verifyEqual(numel(minted), 2);
            names = sort(cellfun(@(b) b.strain.name, minted, ...
                'UniformOutput', false));
            testCase.verifyEqual(names, {'OTR-IRES-Cre', 'SD'});
        end

        function testMintedStrainCarriesTheRequiredFields(testCase)
            [~, minted, ~] = runOn(@twoRatsSameGenotype);
            sd = strainNamed(minted, 'SD');
            testCase.verifyEqual(sd.document_class.class_name, 'strain');
            testCase.verifyEqual(sd.document_class.schema_version, 'V_eta');
            supers = {sd.document_class.superclasses.class_name};
            testCase.verifyTrue(any(strcmp(supers, 'entity')));
            % the three mustBeNonEmpty fields of V_eta/stable/strain.json
            testCase.verifyEqual(sd.strain.name, 'SD');
            testCase.verifyEqual(sd.strain.species.node, 'NCBITaxon:10116');
            testCase.verifyEqual(sd.strain.species.name, 'Rattus norvegicus');
            testCase.verifyEqual(sd.strain.genetic_strain_type.name, 'wildtype');
            testCase.verifyNotEmpty(sd.base.session_id);
        end

        function testIdIsNotPreservedAndTheAssertionKeepsIt(testCase)
            % Forced, not chosen: pass 1 kept `base` verbatim, so the
            % term_assertion already carries the source document's id.
            [v1, mig] = twoRatsSameGenotype();
            [kept, minted, ~] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            sourceIds = cellfun(@(b) b.base.id, v1, 'UniformOutput', false);
            for k = 1:numel(minted)
                testCase.verifyFalse(any(strcmp(sourceIds, minted{k}.base.id)), ...
                    'a minted strain reused a source id that is still in use');
            end
            % and the assertion is still there, under its own id
            testCase.verifyTrue(anyId(kept, 'rat1_strain'));
        end

        function testStrainIdIsAttachedAndTwoRowsShareOneStrain(testCase)
            [kept, minted, report] = runOn(@twoRatsSameGenotype);
            testCase.verifyEqual(report.strain_id_edges_attached, 4);
            a = depValue(docWithId(kept, 'rat1_strain'), 'strain_id');
            b = depValue(docWithId(kept, 'rat2_strain'), 'strain_id');
            testCase.verifyNotEmpty(a);
            testCase.verifyEqual(a, b);
            testCase.verifyEqual(a, strainNamed(minted, 'OTR-IRES-Cre').base.id);
        end

        function testStrainIdNamesADocumentThatExists(testCase)
            % No edge may name nobody: did2/+validate/references.m:90 skips an
            % empty edge, so an invented one validates clean and means nothing.
            [kept, minted, ~] = runOn(@twoRatsSameGenotype);
            mintedIds = cellfun(@(b) b.base.id, minted, 'UniformOutput', false);
            for k = 1:numel(kept)
                v = depValue(kept{k}, 'strain_id');
                if isempty(v); continue; end
                testCase.verifyTrue(any(strcmp(mintedIds, v)));
            end
        end

        % ---------------- pedigree ---------------------------------------

        function testPedigreeBecomesBackgroundStrainEdge(testCase)
            [~, minted, report] = runOn(@twoRatsSameGenotype);
            cre = strainNamed(minted, 'OTR-IRES-Cre');
            sd  = strainNamed(minted, 'SD');
            testCase.verifyEqual(depValue(cre, 'background_strain_1'), sd.base.id);
            testCase.verifyEmpty(sd.depends_on);
            % one edge per MINTED strain, not per source document
            testCase.verifyEqual(report.background_edges, 1);
            testCase.verifyEqual(report.background_unresolved, 0);
            % both rows' Strain documents named a background
            testCase.verifyEqual(report.background_refs_seen, 2);
        end

        function testTwoParentCrossKeepsTheWriterSOrder(testCase)
            % hunsberger: strain.backgroundStrain = [ArcCreERT2,eYFP]. The
            % ORDER is a fact from the writer and lives only in
            % `fields.backgroundStrain` -- the openminds_# edges are appended
            % in fieldnames order and name no roles at all.
            [~, minted, report] = runOn(@hunsbergerCross);
            cross = strainNamed(minted, 'ArcCreERT2 x eYFP');
            arc   = strainNamed(minted, 'ArcCreERT2');
            eyfp  = strainNamed(minted, 'eYFP');
            testCase.verifyEqual(depValue(cross, 'background_strain_1'), arc.base.id);
            testCase.verifyEqual(depValue(cross, 'background_strain_2'), eyfp.base.id);
            testCase.verifyEqual(report.background_over_max, 0);
        end

        function testSharedBackgroundIsStoredOnceAsADag(testCase)
            % SvEv is reached by two distinct paths. The repeatable edge stores
            % it ONCE; a nested background block would have duplicated it and
            % the two copies could then disagree.
            [~, minted, report] = runOn(@hunsbergerCross);
            testCase.verifyEqual(report.distinct_strains, 4);
            svev = strainNamed(minted, '129S/SvEv');
            arc  = strainNamed(minted, 'ArcCreERT2');
            eyfp = strainNamed(minted, 'eYFP');
            testCase.verifyEqual(depValue(arc,  'background_strain_1'), svev.base.id);
            testCase.verifyEqual(depValue(eyfp, 'background_strain_1'), svev.base.id);
            testCase.verifyEqual(report.pedigree_cycles, 0);
        end

        function testUnresolvableParentProducesNoEmptyEdge(testCase)
            [v1, mig] = twoRatsSameGenotype();
            [v1, mig] = dropDocument(v1, mig, 'rat1_sd');
            [v1, mig] = dropDocument(v1, mig, 'rat2_sd');
            [~, minted, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            cre = strainNamed(minted, 'OTR-IRES-Cre');
            testCase.verifyEmpty(cre.depends_on);
            testCase.verifyEqual(report.background_edges, 0);
            testCase.verifyEqual(report.background_unresolved, 2);
        end

        function testPedigreeCycleIsCountedNotRecursedForever(testCase)
            [v1, mig] = cyclicPedigree();
            [~, minted, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyGreaterThanOrEqual(report.pedigree_cycles, 1);
            % a cycle must not silently fuse the two strains
            testCase.verifyEqual(report.distinct_strains, 2);
            testCase.verifyEqual(numel(minted), 2);
        end

        % ---------------- the genetic strain type move --------------------

        function testGeneticStrainTypeAssertionMovesOntoTheStrain(testCase)
            [kept, minted, report] = runOn(@twoRatsSameGenotype);
            testCase.verifyEqual(report.gst_fragments_seen, 4);
            testCase.verifyEqual(report.gst_assertions_removed, 4);
            testCase.verifyFalse(anyId(kept, 'rat1_gst_cre'));
            testCase.verifyFalse(anyId(kept, 'rat1_gst_sd'));
            % the fact is on the strain, which is the condition for removing it
            testCase.verifyEqual( ...
                strainNamed(minted, 'OTR-IRES-Cre').strain.genetic_strain_type.name, ...
                'knockin');
            testCase.verifyEqual( ...
                strainNamed(minted, 'SD').strain.genetic_strain_type.name, ...
                'wildtype');
        end

        function testTheSubjectCanStillReachTheGeneticStrainType(testCase)
            % subject -> strain assertion -> strain_id -> strain. If that chain
            % does not close, the removal above is a data loss.
            [kept, minted, ~] = runOn(@twoRatsSameGenotype);
            assertion = docWithId(kept, 'rat1_strain');
            testCase.verifyEqual(depValue(assertion, 'subject_id'), 'rat1');
            target = depValue(assertion, 'strain_id');
            hit = strainWithId(minted, target);
            testCase.verifyNotEmpty(hit);
            testCase.verifyEqual(hit.strain.genetic_strain_type.name, 'knockin');
        end

        function testGeneticStrainTypeAssertionIsKeptWhenTheValueDisagrees(testCase)
            % The removal is conditional on the fact being READABLE afterwards,
            % never on the sentence in the plan document.
            [v1, mig] = twoRatsSameGenotype();
            mig = retermAssertion(mig, 'rat1_gst_cre', '', 'something else');
            [kept, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.gst_kept_value_not_on_strain, 1);
            testCase.verifyTrue(anyId(kept, 'rat1_gst_cre'));
        end

        function testGeneticStrainTypeAssertionIsKeptWhenPinned(testCase)
            % Nothing is removed that anything points at.
            [v1, mig] = twoRatsSameGenotype();
            mig{end+1} = relationDoc('rel_1', 'sess_A', 'rat1_gst_cre');
            [kept, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.gst_kept_pinned, 1);
            testCase.verifyTrue(anyId(kept, 'rat1_gst_cre'));
        end

        function testGeneticStrainTypeSharedWithAnUnassembledStrainIsKept(testCase)
            % A fragment may only go when EVERY Strain referencing it was
            % assembled -- the rule strainAssembly states for the same reason.
            [v1, mig] = twoRatsSameGenotype();
            [v1, mig] = addStrainSharingGst(v1, mig);
            [kept, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.strains_incomplete, 1);
            testCase.verifyEqual(report.gst_kept_shared_with_unassembled, 1);
            testCase.verifyTrue(anyId(kept, 'rat1_gst_cre'));
        end

        function testInlineGeneticStrainTypeLeavesNothingToMove(testCase)
            % dabrowska/haley ASSIGN A CHAR ('wildtype', 'wild type'). Whether
            % openMINDS coerces it into its own document was never read here,
            % so both shapes must work; inline means there is no fragment
            % document and therefore no assertion to move.
            [kept, minted, report] = runOn(@inlineGeneticStrainType);
            testCase.verifyEqual(report.gst_fragments_seen, 0);
            testCase.verifyEqual(report.gst_assertions_removed, 0);
            testCase.verifyEqual(numel(kept), 3);
            testCase.verifyEqual(minted{1}.strain.genetic_strain_type.name, 'wildtype');
            testCase.verifyEqual(minted{1}.strain.genetic_strain_type.node, '');
        end

        % ---------------- the species dedup -------------------------------

        function testDuplicateSpeciesAssertionIsDeduped(testCase)
            % subjectMaker.m:265-270 makes two calls, so the species object
            % inside the strain graph and the standalone species document are
            % two documents saying one thing about one subject.
            [kept, ~, report] = runOn(@twoRatsSameGenotype);
            testCase.verifyEqual(report.species_fragments_seen, 2);
            testCase.verifyEqual(report.species_duplicate_groups, 2);
            testCase.verifyEqual(report.species_assertions_removed, 2);
            % the SURVIVOR is the subject's own species assertion, not the
            % strain fragment: its provenance does not depend on this pass
            % having read a strain correctly.
            testCase.verifyTrue(anyId(kept, 'rat1_species'));
            testCase.verifyFalse(anyId(kept, 'rat1_species_child'));
        end

        function testNonDuplicateSpeciesAssertionIsNeverTouched(testCase)
            % `species` and `strain` stay SIBLING assertions (the sign-off says
            % so in as many words), so only an EXACT duplicate goes.
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
            % A duplicate this family did not cause is not this pass's to
            % remove. Counted, untouched.
            [v1, mig] = twoRatsSameGenotype();
            mig{end+1} = assertionDoc('rat1_species_extra', 'sess_A', 'rat1', ...
                'species', 'NCBITaxon:10116', 'Rattus norvegicus');
            [kept, ~, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.duplicate_species_groups_out_of_scope, 0);
            % rat1 now has THREE identical species assertions, one of which is
            % the strain fragment -- so the group is in scope and the extra one
            % goes with it. The out-of-scope counter is exercised below.
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
            % An empty subject_id is not a subject. Two subject-less species
            % assertions with the same value are not evidence of being about
            % one thing, and did2/+validate/references.m skips empty edges.
            [v1, mig] = twoRatsSameGenotype();
            mig = resubject(mig, 'rat1_species', '');
            mig = resubject(mig, 'rat1_species_child', '');
            [kept, ~, ~] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyTrue(anyId(kept, 'rat1_species'));
            testCase.verifyTrue(anyId(kept, 'rat1_species_child'));
        end

        % ---------------- refusals ---------------------------------------

        function testIncompleteStrainIsLeftExactlyAsPassOneEmittedIt(testCase)
            % name, species and genetic_strain_type are all mustBeNonEmpty on
            % V_eta/stable/strain.json -- a Strain missing one is never emitted
            % with a vacuous required field.
            [v1, mig] = strainWithNoSpecies();
            [kept, minted, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyFalse(report.changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(report.strains_incomplete, 1);
            testCase.verifyEqual(numel(report.incomplete_reasons), 1);
            testCase.verifyEqual(report.strain_id_edges_attached, 0);
            testCase.verifyEmpty(depValue(docWithId(kept, 'lone_strain'), 'strain_id'));
        end

        function testStrainAlreadyTurnedIntoAnEntityIsSkipped(testCase)
            % The guard that keeps this pass and ndi.migrate.internal.strainAssembly
            % from colliding: only a v1 body whose MIGRATED counterpart is a
            % `term_assertion` is touched.
            [v1, mig] = twoRatsSameGenotype();
            mig = reclass(mig, 'rat1_strain', 'strain');
            [~, ~, report] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.strain_docs_not_a_term_assertion, 1);
            testCase.verifyEqual(report.strains_candidate, 3);
        end

        function testStrainAbsentFromTheMigratedSetIsCounted(testCase)
            % Discovery mode: a subset batch need not contain every document,
            % and that is NOT evidence the document does not exist.
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

        % ---------------- measured, not acted on --------------------------

        function testAncestorAssertionsOnTheSubjectAreMeasuredNotRemoved(testCase)
            % openMINDSobj2ndi_document sets subject_id on EVERY document of
            % the flattened graph, so the mouse is asserted to be a `SvEv` as
            % well as the cross. Whether the ancestor assertions should go is a
            % MODELLING CALL and #78 does not name it.
            [kept, ~, report] = runOn(@hunsbergerCross);
            testCase.verifyEqual(report.background_strain_assertions_on_subject, 3);
            testCase.verifyTrue(anyId(kept, 'm1_svev'));
            testCase.verifyTrue(anyId(kept, 'm1_arc'));
            testCase.verifyTrue(anyId(kept, 'm1_eyfp'));
            % each ancestor assertion still gets its OWN correct strain_id
            testCase.verifyNotEmpty(depValue(docWithId(kept, 'm1_svev'), 'strain_id'));
        end

        function testCrossSessionMergeIsMeasuredAndNotPerformed(testCase)
            % base.session_id is mustBeNonEmpty, so a survivor carries exactly
            % one session; merging across sessions would leave documents in
            % session B pointing at an entity stamped session A. Same call
            % softwareDedup and epochMint make, and for the same reason.
            [~, minted, report] = runOn(@sameStrainTwoSessions);
            testCase.verifyEqual(report.distinct_strains, 2);
            testCase.verifyEqual(numel(minted), 2);
            testCase.verifyEqual(report.cross_session_groups, 1);
            testCase.verifyEqual(report.cross_session_collapsible, 1);
            sessions = sort(cellfun(@(b) b.base.session_id, minted, ...
                'UniformOutput', false));
            testCase.verifyEqual(sessions, {'sess_A', 'sess_B'});
        end

        % ---------------- identifiers --------------------------------------

        function testGlobalIdentifierIsSplitOnItsScheme(testCase)
            [~, minted, ~] = runOn(@twoRatsSameGenotype);
            sd = strainNamed(minted, 'SD');
            testCase.verifyEqual(numel(sd.entity.global_identifier), 1);
            % dabrowska writes 'ontologyIdentifier', "RRID:RGD_70508" -- an
            % RRID in the ontology slot. The scheme comes from the CURIE, not
            % from the field it arrived in.
            testCase.verifyEqual(sd.entity.global_identifier(1).scheme, 'RRID');
            testCase.verifyEqual(sd.entity.global_identifier(1).value, 'RGD_70508');
        end

        function testIdentifierlessStrainStillAssembles(testCase)
            % 115 strains carry no identifier at all (dabrowska's Cre lines set
            % only `name`), which is why the field is optional on the entity.
            [~, minted, ~] = runOn(@twoRatsSameGenotype);
            cre = strainNamed(minted, 'OTR-IRES-Cre');
            testCase.verifyEmpty(cre.entity.global_identifier);
        end

        % ---------------- the instrument itself ---------------------------

        function testReportStatesItsDenominatorsFirst(testCase)
            [v1, mig] = twoRatsSameGenotype();
            [~, ~, report] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            fn = fieldnames(report);
            testCase.verifyEqual(fn{1}, 'v1_bodies_inspected');
            testCase.verifyEqual(fn{2}, 'documents_inspected');
            testCase.verifyEqual(report.v1_bodies_inspected, numel(v1));
            testCase.verifyEqual(report.documents_inspected, numel(mig));
            % every Strain document lands in exactly one bucket
            testCase.verifyEqual(report.strain_docs_seen, ...
                report.strains_candidate + report.strains_incomplete ...
                + report.strain_docs_not_in_migrated_set ...
                + report.strain_docs_not_a_term_assertion);
        end

        function testEveryGeneticStrainTypeFragmentIsAccountedFor(testCase)
            % A removal count with no refusal counts beside it cannot say
            % whether a zero means "nothing to do" or "refused everything".
            [v1, mig] = twoRatsSameGenotype();
            mig{end+1} = relationDoc('rel_1', 'sess_A', 'rat1_gst_cre');
            mig = retermAssertion(mig, 'rat1_gst_sd', '', 'disagrees');
            [~, ~, report] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.gst_fragments_seen, ...
                report.gst_assertions_removed ...
                + report.gst_kept_value_not_on_strain ...
                + report.gst_kept_shared_with_unassembled ...
                + report.gst_kept_wrong_subject ...
                + report.gst_kept_pinned ...
                + report.gst_kept_not_a_term_assertion);
            testCase.verifyEqual(report.gst_kept_pinned, 1);
            testCase.verifyEqual(report.gst_kept_value_not_on_strain, 1);
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
            % 0 of 0 and 0 of many must be different numbers in the output.
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
            % Standing migrator lesson: any NESTED sub-field a migrator reads
            % needs a snake+camelCase fallback. universalRenames snake-cases
            % only one level and `fields` is nested, so these arrive camelCase
            % in the normal path -- the fallback is what makes the
            % already-migrated re-run path behave the same way.
            [v1, mig] = twoRatsSameGenotype();
            for k = 1:numel(v1)
                v1{k} = snakeifyFields(v1{k});
            end
            [~, minted, report] = ...
                ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.strains_minted, 2);
            cre = strainNamed(minted, 'OTR-IRES-Cre');
            sd  = strainNamed(minted, 'SD');
            testCase.verifyEqual(depValue(cre, 'background_strain_1'), sd.base.id);
        end

        function testEbrainsAndOmiTypeIrisBothMatch(testCase)
            % NDI's own reader queries the EBRAINS host
            % (ndidataset2metadataeditorstruct.m:173,
            % 'https://openminds.ebrains.eu/core/Strain') while newer fixtures
            % carry openminds.om-i.org. A disposition that turns on a spelling
            % is how `demo_ndi` went wrong.
            [v1, mig] = twoRatsSameGenotype();
            for k = 1:numel(v1)
                v1{k}.openminds.openminds_type = strrep( ...
                    v1{k}.openminds.openminds_type, ...
                    'openminds.om-i.org/types', 'openminds.ebrains.eu/core');
                % blanked so ONLY the IRI can match -- otherwise matlab_type
                % answers and the IRI path is never exercised
                v1{k}.openminds.matlab_type = '';
            end
            [~, ~, report] = ndi.migrate.internal.subjectStrainAssembly(v1, mig);
            testCase.verifyEqual(report.strain_docs_seen, 4);
            testCase.verifyEqual(report.strains_minted, 2);
        end

    end
end

% ===================== fixtures (test-only) ===============================

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
% assembled itself (no species), so the fragment must be retained.
sess = 'sess_A'; sub = 'rat1';
v1{end+1}  = omDoc('shared_strain', sess, sub, 'Strain', ...
    struct('name', 'Y', 'geneticStrainType', {{'ndi://rat1_gst_cre'}}), ...
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
%ASSERTIONDOC What did2.convert.migrators_j.openminds_subject emits: ONE
%   term_assertion, `base` VERBATIM from the source (:54 -- the id join this
%   pass depends on), depends_on ASSIGNED to just subject_id (:52), the
%   variable from the openMINDS type (:64-80) and the value on the `term`
%   block (:57). The single `subject_assertion` superclass is what the
%   migrator writes (:48); ensureClassBlocks rebuilds the full chain later.
b = struct();
b.document_class = struct('class_name', 'term_assertion', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'subject_assertion', ...
        'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
b.depends_on = dep('subject_id', subjectId);
b.base = base(id, sessionId);
b.subject_statement = struct('variable', ...
    struct('node', '', 'name', variableName), 'storage_mode', 'inline');
b.term = struct('value', struct('node', node, 'name', name));
end

function b = subjectDoc(id)
b = struct();
b.document_class = dc('subject', {'base'});
b.depends_on = struct('name', {}, 'value', {});
b.base = base(id, 'sess_A');
b.subject = struct('local_identifier', id);
end

function b = relationDoc(id, sessionId, targetId)
%RELATIONDOC Any document with an inbound edge onto TARGETID -- the "pinned"
%   case. Nothing is removed that anything points at.
b = struct();
b.document_class = dc('directed_relation', {'relation'});
b.depends_on = [dep('child', targetId), dep('parent', 'someone_else')];
b.base = base(id, sessionId);
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

function mig = resubject(mig, id, subjectId)
for k = 1:numel(mig)
    if strcmp(mig{k}.base.id, id)
        mig{k}.depends_on = dep('subject_id', subjectId);
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

function b = strainNamed(minted, name)
b = [];
for k = 1:numel(minted)
    if isfield(minted{k}, 'strain') && strcmp(minted{k}.strain.name, name)
        b = minted{k};
        return;
    end
end
error('no minted strain named %s', name);
end

function b = strainWithId(minted, id)
b = [];
for k = 1:numel(minted)
    if strcmp(minted{k}.base.id, id)
        b = minted{k};
        return;
    end
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
