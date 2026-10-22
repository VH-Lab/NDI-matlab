classdef TestModificationSummary < matlab.unittest.TestCase
    % TestModificationSummary - text ndi.update.modificationSummary builds
    % from a check result. Offline; uses hand-made results.

    methods (Test)
        function testNoModificationsGivesEmpty(testCase)
            r = struct('Modifications', struct('Name', {}, 'Path', {}, ...
                'ChangedFiles', {}, 'BlockingFiles', {}, 'CommitsAhead', {}));
            testCase.verifyEqual(ndi.update.modificationSummary(r), "");
        end

        function testListsFilesAndCommits(testCase)
            r.Modifications = struct('Name', "NDI-matlab", 'Path', "/x/NDI-matlab", ...
                'ChangedFiles', {["src/a.m"; "src/b.m"]}, ...
                'BlockingFiles', {"myScript.m"}, 'CommitsAhead', 1);
            txt = ndi.update.modificationSummary(r);
            testCase.verifySubstring(txt, "NDI-matlab (/x/NDI-matlab)");
            testCase.verifySubstring(txt, "2 changed file(s)");
            testCase.verifySubstring(txt, "1 untracked file(s) in the way of new files");
            testCase.verifySubstring(txt, "1 local commit(s)");
            testCase.verifySubstring(txt, "changed:    src/a.m");
            testCase.verifySubstring(txt, "in the way: myScript.m");
            testCase.verifySubstring(txt, "put back after the update");
            testCase.verifySubstring(txt, "git stash list");
            testCase.verifySubstring(txt, "other untracked files are left alone");
        end

        function testMaxFilesCountsTheRest(testCase)
            files = "f" + (1:5)' + ".m";
            r.Modifications = struct('Name', "dep", 'Path', "/x/dep", ...
                'ChangedFiles', {files}, 'BlockingFiles', {strings(0, 1)}, ...
                'CommitsAhead', 0);
            txt = ndi.update.modificationSummary(r, MaxFiles = 2);
            testCase.verifySubstring(txt, "changed:    f2.m");
            testCase.verifyFalse(contains(txt, "f3.m"));
            testCase.verifySubstring(txt, "... and 3 more");
        end
    end
end
