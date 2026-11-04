classdef TestLightsheetManager < matlab.unittest.TestCase
    % TestLightsheetManager - non-GUI paths of the manager.
    %
    % The GUI (uifigure construction, callbacks) is not exercised here;
    % headless CI cannot open a figure. What is testable is the
    % launcherPath resolver (preference fallback) and deletionPlan (a
    % pure query wrapper used before database_rm cascades).

    properties
        session
        subjectID
    end

    methods (TestMethodSetup)
        function build(testCase)
            d = fullfile(tempname, 'lszmgr');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            S = ndi.session.dir('lszmgr', d);
            sub = ndi.document('subject', 'base.session_id', S.id(), ...
                'subject.local_identifier', 'lightsheet@vhlab');
            S.database_add(sub);
            testCase.session = S;
            testCase.subjectID = sub.id();
        end
    end

    methods (Test)

        function testLauncherPathIsFoundAutomatically(testCase)
            % Without a preference set, the launcher is wherever
            % ndi.python.findCommand finds napariViewLightsheet; here a
            % dummy in a temp folder named by NDI_PYTHON_BIN.
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            binDir = tempname;
            mkdir(binDir);
            testCase.addTeardown(@() rmdir(binDir, 's'));
            fake = fullfile(binDir, 'napariViewLightsheet');
            if ispc, fake = [fake '.exe']; end
            fclose(fopen(fake, 'w'));
            testCase.applyFixture(EnvironmentVariableFixture('NDI_PYTHON_BIN', binDir));
            old = ndi.preferences.get('GUI.LightsheetManager.ViewerLauncher');
            testCase.addTeardown(@() ndi.preferences.set( ...
                'GUI.LightsheetManager.ViewerLauncher', old));
            ndi.preferences.set('GUI.LightsheetManager.ViewerLauncher', "");
            ndi.python.clearCommandCache();
            testCase.addTeardown(@() ndi.python.clearCommandCache());

            p = ndi.gui.app.LightsheetManager.launcherPath();
            testCase.verifyClass(p, 'char');
            testCase.verifyEqual(p, fake);
            testCase.verifyEqual( ...
                ndi.gui.app.LightsheetManager.resolveLauncher('/my/viewer'), ...
                '/my/viewer', 'an explicit launcher always wins');
        end

        function testTheDefaultLauncherMeansFindIt(testCase)
            testCase.verifyEqual( ...
                char(ndi.gui.app.LightsheetManager.DefaultViewerLauncher), '');
        end

        function testDeletionPlanCollectsLevelsAndParent(testCase)
            % Deletion is a cascade; the plan enumerates everything
            % the manager will remove so the UI can name the counts
            % before doing it.
            pys = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.twoPyramidsWithSharedLevel0();
            [pdoc, lds, ~] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, pys, {'mean','max'}, ...
                'subjectID', testCase.subjectID);
            plan = ndi.gui.app.LightsheetManager.deletionPlan( ...
                testCase.session, pdoc.id());
            testCase.verifyEqual(plan.pyramidID, pdoc.id());
            testCase.verifyEqual(plan.nLevels, numel(lds));
            testCase.verifyEqual(numel(plan.docsToRemove), ...
                numel(lds) + 1, ...
                'plan should include every level plus the parent');
        end

        function testDeletionPlanOnAbsentPyramidReportsZero(testCase)
            % A never-created id has no children and no parent; the
            % plan should return an empty removal list.
            plan = ndi.gui.app.LightsheetManager.deletionPlan( ...
                testCase.session, ...
                '00000000-0000-0000-0000-000000000000');
            testCase.verifyEqual(plan.nLevels, 0);
            testCase.verifyEmpty(plan.docsToRemove);
        end

        function testDeletionMessageNamesTheCounts(testCase)
            % The confirmation must distinguish 1 from many. The pyramid
            % counts as 1, plus every level.
            plan = struct('pyramidID','abcd','nLevels',7,'docsToRemove',{{}});
            msg = ndi.gui.app.LightsheetManager.deletionMessage( ...
                plan, 'my-pyramid');
            testCase.verifySubstring(msg, '8 document');
            testCase.verifySubstring(msg, '7 level');
            testCase.verifySubstring(msg, 'my-pyramid');
        end

        function testSubjectNameMapUsesLocalIdentifier(testCase)
            % pyramidRows shows the subject's local_identifier, not its
            % raw id. subjectNameMap is where that lookup lives; a
            % subject with a local_identifier should be findable by its
            % document id.
            m = ndi.gui.app.LightsheetManager.subjectNameMap( ...
                testCase.session);
            testCase.verifyTrue(isKey(m, testCase.subjectID));
            testCase.verifyEqual(m(testCase.subjectID), 'lightsheet@vhlab');
        end

        function testPyramidRowsCarriesSubjectNameAndDoc(testCase)
            % One row per pyramid parent. Subject is the local_identifier
            % (not the raw id), and the row keeps the raw doc alongside
            % the id so the delete/view callbacks can act on it.
            pys = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.twoPyramidsWithSharedLevel0();
            [pdoc, ~, ~] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, pys, {'mean','max'}, ...
                'subjectID', testCase.subjectID);
            rows = ndi.gui.app.LightsheetManager.pyramidRows( ...
                testCase.session);
            testCase.verifyNotEmpty(rows);
            match = find(strcmp({rows.id}, pdoc.id()), 1);
            testCase.verifyNotEmpty(match);
            r = rows(match);
            testCase.verifyEqual(r.subject, 'lightsheet@vhlab');
            testCase.verifyEqual(r.subjectID, testCase.subjectID);
            testCase.verifyNotEmpty(r.doc);
        end

        % -- the Add dialog's decisions ---------------------------------

        function testAddPlanListsEverythingMissingAtOnce(testCase)
            c = ndi.gui.app.LightsheetManager.addChoices();
            plan = ndi.gui.app.LightsheetManager.addPlan(c);
            testCase.verifyNumElements(plan.errors, 2, ...
                'no subject and no folder: both are reported, not the first');
            msg = ndi.gui.app.LightsheetManager.addMessage(plan);
            testCase.verifySubstring(msg, 'subject');
            testCase.verifySubstring(msg, 'image folder');

            c.destination = 'cloud';
            plan = ndi.gui.app.LightsheetManager.addPlan(c);
            testCase.verifyNumElements(plan.errors, 4, ...
                'the cloud also needs a dataset and a session');
            testCase.verifyTrue(any(contains(plan.errors, 'not into the dataset')));
        end

        function testAddPlanForACompleteChoice(testCase)
            c = testCase.completeChoices('smartspim');
            plan = ndi.gui.app.LightsheetManager.addPlan(c);
            testCase.verifyEmpty(plan.errors);
            testCase.verifyEqual(plan.ingest, 'fromSPIM');
            testCase.verifyEqual(plan.where, 'this session');
            msg = ndi.gui.app.LightsheetManager.addMessage(plan);
            testCase.verifySubstring(msg, 'lightsheet@vhlab');
            testCase.verifySubstring(msg, '"acq42"', ...
                'an empty label is shown as the folder name it defaults to');

            c.sourceKind = 'omezarr';
            plan = ndi.gui.app.LightsheetManager.addPlan(c);
            testCase.verifyEqual(plan.ingest, 'fromOMEZarr');
        end

        function testAFolderOfNeitherKindIsAnError(testCase)
            c = testCase.completeChoices('');
            plan = ndi.gui.app.LightsheetManager.addPlan(c);
            testCase.verifyNumElements(plan.errors, 1);
            testCase.verifySubstring(plan.errors{1}, 'not a SmartSPIM');
        end

        function testVoxelSizeMustBeThreePositiveNumbers(testCase)
            c = testCase.completeChoices('smartspim');
            c.voxelSizeUm = [2 1];
            testCase.verifyNotEmpty(ndi.gui.app.LightsheetManager.addPlan(c).errors);
            c.voxelSizeUm = NaN;
            testCase.verifyNotEmpty(ndi.gui.app.LightsheetManager.addPlan(c).errors, ...
                'text the dialog could not read is refused, not ignored');
            c.voxelSizeUm = [4 1.8 1.8];
            testCase.verifyEmpty(ndi.gui.app.LightsheetManager.addPlan(c).errors);
        end

        function testSubjectProblems(testCase)
            P = @ndi.gui.app.LightsheetManager.subjectProblems;
            testCase.verifyNotEmpty(P('  ', {}));
            testCase.verifyNotEmpty(P('mouse1@lab', {'mouse1@lab'}), ...
                'a second subject with the same identifier is refused');
            testCase.verifyEmpty(P('mouse2@lab', {'mouse1@lab'}));
        end

        function testSourceKindRecognisesAnOMEZarrStore(testCase)
            testCase.assumeNotEmpty(which('ndr.format.omezarr.isOMEZarr'), ...
                'NDR-matlab is not on the path.');
            testCase.assumeNotEmpty(which('ndr.format.smartspim.hasAllChannels'), ...
                'NDR-matlab without SmartSPIM All_Channels support.');
            parent = tempname;
            mkdir(parent);
            testCase.addTeardown(@() rmdir(parent, 's'));
            zp = ndi.test.lightsheet.makeBlobFixture(parent, 'Shape', [16 16 16], ...
                'NumChannels', 1, 'NumLevels', 2, 'ChunkShape', [8 8 8]);
            testCase.verifyEqual(ndi.gui.app.LightsheetManager.sourceKind(zp), 'omezarr');
            [kind, why] = ndi.gui.app.LightsheetManager.sourceKind(parent);
            testCase.verifyEqual(kind, '');
            testCase.verifySubstring(why, 'Not a SmartSPIM');
            [kind, why] = ndi.gui.app.LightsheetManager.sourceKind(fullfile(parent, 'nope'));
            testCase.verifyEqual(kind, '');
            testCase.verifySubstring(why, 'no folder');
        end

        % -- what Add does ----------------------------------------------

        function testAddSubjectToThisSession(testCase)
            c = ndi.gui.app.LightsheetManager.addChoices();
            id = ndi.gui.app.LightsheetManager.addSubject(testCase.session, c, ...
                'mouse7@vhlab', 'a new animal');
            subs = ndi.gui.app.LightsheetManager.targetSubjects(testCase.session, c);
            testCase.verifyTrue(any(strcmp({subs.id}, id)));
            testCase.verifyError(@() ndi.gui.app.LightsheetManager.addSubject( ...
                testCase.session, c, 'mouse7@vhlab'), ...
                'NDI:gui:LightsheetManager:badSubject');
        end

        function testAddSubjectToACloudSession(testCase)
            cloud = ndi.test.helper.FakeCloudDataset();
            sid = cloud.addSession('exp1');
            c = ndi.gui.app.LightsheetManager.addChoices();
            c.destination = 'cloud';
            c.datasetId = cloud.DatasetId;
            c.sessionId = sid;
            testCase.verifyEmpty(ndi.gui.app.LightsheetManager.targetSubjects( ...
                [], c, 'Api', cloud.api()));
            id = ndi.gui.app.LightsheetManager.addSubject([], c, 'ferret3@vhlab', '', ...
                'Api', cloud.api());
            subs = ndi.gui.app.LightsheetManager.targetSubjects([], c, 'Api', cloud.api());
            testCase.verifyEqual({subs.id}, {id});
            stored = cloud.docsOfClass('subject');
            testCase.verifyEqual(stored{1}.base.session_id, sid, ...
                'the subject goes into the chosen session');
        end

        function testRunAddRefusesAnIncompleteChoice(testCase)
            c = ndi.gui.app.LightsheetManager.addChoices();
            testCase.verifyError(@() ndi.gui.app.LightsheetManager.runAdd( ...
                testCase.session, c), 'NDI:gui:LightsheetManager:cannotAdd');
        end

        function testRunAddStoresTheChunksOfAnOMEZarrStore(testCase)
            testCase.assumeNotEmpty(which('ndr.format.omezarr.listPyramids'), ...
                'NDR-matlab is not on the path.');
            parent = tempname;
            mkdir(parent);
            testCase.addTeardown(@() rmdir(parent, 's'));
            zp = ndi.test.lightsheet.makeBlobFixture(parent, 'Shape', [32 32 32], ...
                'NumChannels', 1, 'NumLevels', 2, 'ChunkShape', [16 16 16]);
            c = ndi.gui.app.LightsheetManager.addChoices();
            c.subjectID = testCase.subjectID;
            c.subjectName = 'lightsheet@vhlab';
            c.sourcePath = zp;
            c.sourceKind = 'omezarr';
            c.label = 'blob';
            [P, L] = ndi.gui.app.LightsheetManager.runAdd(testCase.session, c, ...
                'ingestArgs', {'progressFcn', [], 'numWorkers', 0});
            testCase.verifyEqual(P.document_properties.lightsheetZarrPyramid.label, 'blob');
            for k = 1:numel(L)
                lv = L{k}.document_properties.lightsheetZarrLevel;
                testCase.verifyEqual(double(lv.n_chunks_stored), prod(double(lv.chunk_grid)), ...
                    'Add stores the chunks: the viewer draws nothing without them');
            end
            rows = ndi.gui.app.LightsheetManager.pyramidRows(testCase.session);
            testCase.verifyTrue(any(strcmp({rows.id}, P.id())));
        end

        function testRunAddIntoACloudSession(testCase)
            testCase.assumeNotEmpty(which('ndr.format.omezarr.listPyramids'), ...
                'NDR-matlab is not on the path.');
            parent = tempname;
            mkdir(parent);
            testCase.addTeardown(@() rmdir(parent, 's'));
            zp = ndi.test.lightsheet.makeBlobFixture(parent, 'Shape', [16 16 16], ...
                'NumChannels', 1, 'NumLevels', 2, 'ChunkShape', [8 8 8]);
            cloud = ndi.test.helper.FakeCloudDataset();
            sid = cloud.addSession('exp1');
            subj = cloud.addSubject(sid, 'blob@vhlab');
            c = ndi.gui.app.LightsheetManager.addChoices();
            c.destination = 'cloud';
            c.datasetId = cloud.DatasetId;
            c.sessionId = sid;
            c.subjectID = subj;
            c.sourcePath = zp;
            c.sourceKind = 'omezarr';
            [P, ~, info] = ndi.gui.app.LightsheetManager.runAdd([], c, ...
                'Api', cloud.api(), 'ingestArgs', {'progressFcn', [], 'numWorkers', 0});
            testCase.verifyGreaterThan(info.cloud.files, 0);
            pyr = cloud.docsOfClass('lightsheetZarrPyramid');
            testCase.verifyNumElements(pyr, 1);
            testCase.verifyEqual(pyr{1}.base.id, P.id());
            testCase.verifyEqual(pyr{1}.base.session_id, sid);
            testCase.verifyEmpty(ndi.gui.app.LightsheetManager.pyramidRows(testCase.session), ...
                'nothing is added to the local session');
        end

    end

    methods
        function c = completeChoices(testCase, kind)
            c = ndi.gui.app.LightsheetManager.addChoices();
            c.subjectID = testCase.subjectID;
            c.subjectName = 'lightsheet@vhlab';
            c.sourcePath = fullfile(tempdir, 'acq42');
            c.sourceKind = kind;
        end
    end
end
