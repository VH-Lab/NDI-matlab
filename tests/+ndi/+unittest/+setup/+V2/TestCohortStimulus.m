classdef TestCohortStimulus < matlab.unittest.TestCase
%TESTCOHORTSTIMULUS A stimulus shown to several animals, asked about from
%   one animal's side.
%
%   Jess Haley, 2026-10-21: a stimulus presentation that resolves to several
%   animals in its session is one cohort entity per session (the animals
%   recorded together, each `member_of` it) and ONE item manipulation of the
%   cohort with `distributive` true. A single-animal presentation names its
%   animal directly. This test is the reader half: asking an animal "what did
%   you receive?" finds the cohort's distributive manipulation, through
%   member_of, and an animal outside the cohort does not.
%
%   The migration pass writes this shape (a429e60): the stimulus fold
%   (ndi.migrate.internal.stimulusPresentationToItem; the cohort minted by
%   ndi.migrate.internal.sessionCohort, called from ndi.migrate.local) makes
%   one manipulation of the
%   session's cohort, a group entity with member_of edges, marked
%   distributive (TestStimulusPresentationCohort is the writer half). The
%   documents here are built with did2.build on the #88 schema, as the Haley
%   import builds its cohorts.
%
%   UNVERIFIED: written without MATLAB; test-import-v2.yml is the first run.

    properties
        Dir
    end

    methods (TestClassSetup)
        function needV2(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'item.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `entity` and `item` (did-schema #88)');
            % the stimulus words are this test's own, not a dataset's
            if ~isempty(which('did2.schema.termIndex'))
                prev = did2.schema.cache.strictMode('TermRegistry', false);
                testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
            end
        end
    end

    methods (TestMethodSetup)
        function makeDir(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
        end
    end

    methods (Test)
        function testAnAnimalFindsTheCohortsDistributiveManipulation(testCase)
            [S, id] = testCase.readerSession();
            a = ndi.entity.fromDocument(S, id.a);
            m = a.manipulations();
            testCase.verifyNumElements(m, 1, ...
                'animal A received the stimulus shown to its cohort');
            testCase.verifyEqual(m{1}.document_id, id.stim);
            testCase.verifyEqual(m{1}.via(), 'member_of');
            testCase.verifyTrue(m{1}.distributive());
            % B, the other cohort member, finds the same one manipulation
            b = ndi.entity.fromDocument(S, id.b);
            mb = b.manipulations();
            testCase.verifyNumElements(mb, 1);
            testCase.verifyEqual(mb{1}.document_id, id.stim);
        end

        function testAnAnimalOutsideTheCohortReceivesNothing(testCase)
            [S, id] = testCase.readerSession();
            c = ndi.entity.fromDocument(S, id.c);
            testCase.verifyEmpty(c.manipulations(), ...
                'C is in the session but not in the cohort');
        end

        function testWithoutInheritanceTheAnimalHasNoManipulationOfItsOwn(testCase)
            [S, id] = testCase.readerSession();
            a = ndi.entity.fromDocument(S, id.a);
            testCase.verifyEmpty(a.manipulations('inherited', false), ...
                'the manipulation is stated once, on the cohort');
            cohort = ndi.entity.fromDocument(S, id.cohort);
            own = cohort.manipulations('inherited', false);
            testCase.verifyNumElements(own, 1);
            testCase.verifyEqual(own{1}.via(), 'own');
        end
    end

    methods
        function [S, id] = readerSession(testCase)
            % one session: animals A and B recorded together (their cohort),
            % animal C recorded alone; one grating shown to the cohort
            sid = ndi.ido.unique_id();
            id = struct();
            for n = {'a', 'b', 'c', 'cohort', 'grating', 'stim'}
                id.(n{1}) = ndi.ido.unique_id();
            end
            c = {'SessionId', sid};
            subj = @(key, name, type) ndi.setup.V2.entityDocuments('subject', ...
                struct('local_identifier', name, 'type', did2.build.term('', type)), ...
                struct(), c{:}, 'Id', id.(key));
            grating = did2.build.method('drifting sinusoidal grating', [], c{:}, ...
                'Id', id.grating);
            ref = did2.build.relativeTimeReference(sid, 'Clock', 'dev_local_time', ...
                'Start', 0, 'Duration', 10, c{:});
            stim = did2.build.statement('manipulation', id.cohort, ...
                did2.build.term('', 'visual stimulus'), ...
                struct('item', [0 0 0]), 'ValueKind', 'item', ...
                'Dimensions', did2.build.dimension(did2.build.label('presentation'), 3), ...
                'Covariates', did2.build.covariate(did2.build.label('offset time'), 0, ...
                    'Value', [0 2 4], 'Unit', 'second'), ...
                'Edges', struct('item_id', {{id.grating}}), ...
                'TimeReferenceIds', {ref.base.id}, ...
                'Fields', struct('distributive', true), c{:}, 'Id', id.stim);
            docs = [subj('a', 'animal_a', 'organism'), subj('b', 'animal_b', 'organism'), ...
                subj('c', 'animal_c', 'organism'), subj('cohort', 'session_cohort', 'group'), ...
                {grating, ref, stim, ...
                 did2.build.directedRelation(id.a, id.cohort, 'member_of', c{:}), ...
                 did2.build.directedRelation(id.b, id.cohort, 'member_of', c{:})}];
            folder = fullfile(testCase.Dir, 'cohort');
            mkdir(folder);
            S = ndi.setup.V2.createSession(folder, 'cohort reader', 'SessionId', sid, ...
                'Documents', docs);
        end
    end
end
