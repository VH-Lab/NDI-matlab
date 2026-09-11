classdef TestLightsheetZarrManager < matlab.unittest.TestCase
    % TestLightsheetZarrManager - non-GUI paths of the manager.
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

        function testLauncherPathFallsBackToDefault(testCase)
            % Without a preference set, the launcher is the class's
            % declared default. Should be an absolute path ending in
            % 'napariViewLightsheet'.
            p = ndi.gui.app.LightsheetZarrManager.launcherPath();
            testCase.verifyClass(p, 'char');
            testCase.verifyNotEmpty(p);
            [~, name] = fileparts(p);
            testCase.verifyEqual(name, 'napariViewLightsheet');
        end

        function testDeletionPlanCollectsLevelsAndParent(testCase)
            % Deletion is a cascade; the plan enumerates everything
            % the manager will remove so the UI can name the counts
            % before doing it.
            pys = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.twoPyramidsWithSharedLevel0();
            [pdoc, lds, ~] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, pys, {'mean','max'}, ...
                'subjectID', testCase.subjectID);
            plan = ndi.gui.app.LightsheetZarrManager.deletionPlan( ...
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
            plan = ndi.gui.app.LightsheetZarrManager.deletionPlan( ...
                testCase.session, ...
                '00000000-0000-0000-0000-000000000000');
            testCase.verifyEqual(plan.nLevels, 0);
            testCase.verifyEmpty(plan.docsToRemove);
        end

    end
end
