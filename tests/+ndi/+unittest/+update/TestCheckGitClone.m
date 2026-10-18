classdef TestCheckGitClone < matlab.unittest.TestCase
    % TestCheckGitClone - ndi.update.check and ndi.update.install on git
    % clones laid out the way ndi_install leaves them.
    %
    % Hermetic: each test builds bare repositories that stand in for GitHub,
    % plus ndi_install-style clones of them, in a temp folder, and points
    % check/install at the fake NDI-matlab clone with RepoRoot. No network.
    % The fake NDI-matlab has no ndi_install.m, so install can never run
    % the real installer.

    properties
        Root    % temp folder holding everything
        Seeds   % upstream working copies, used to push new commits
        Tools   % the "installed" clones (what ndi_install makes)
        Ndi     % the fake NDI-matlab clone
    end

    properties (Constant)
        % Keep commits independent of the user's git configuration.
        GitIdentity = "-c user.name=ndiTest -c user.email=ndi@example.com -c commit.gpgsign=false"
    end

    methods (TestClassSetup)
        function requireGit(testCase)
            [s, ~] = system('git --version');
            testCase.assumeEqual(s, 0, 'These tests need the git program.');
        end
    end

    methods (TestMethodSetup)
        function buildClones(testCase)
            testCase.Root = string(tempname);
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            testCase.Seeds = fullfile(testCase.Root, "seed");
            testCase.Tools = fullfile(testCase.Root, "tools");
            remotes = fullfile(testCase.Root, "remotes");

            names = ["NDI-matlab", "depA", "vhlab_vhtools"];
            for name = names
                seed = fullfile(testCase.Seeds, name);
                testCase.git(testCase.Root, "init -q -b main """ + seed + """");
                testCase.writeFile(fullfile(seed, "README.md"), "hello");
            end
            testCase.writeFile(fullfile(testCase.Seeds, "NDI-matlab", "requirements.txt"), ...
                strjoin([testCase.remoteUrl("depA"), testCase.remoteUrl("vhlab_vhtools"), ...
                "https://github.com/example/pinned@v1.0.0"], newline));

            for name = names
                seed = fullfile(testCase.Seeds, name);
                bare = fullfile(remotes, name + ".git");
                testCase.commitAll(seed, "initial");
                testCase.git(testCase.Root, "clone -q --bare """ + seed + """ """ + bare + """");
                testCase.git(seed, "remote add origin """ + bare + """");
                testCase.git(testCase.Root, "clone -q """ + bare + """ """ + ...
                    fullfile(testCase.Tools, name) + """");
            end
            testCase.Ndi = fullfile(testCase.Tools, "NDI-matlab");
        end
    end

    methods (Test)
        function testUpToDate(testCase)
            r = testCase.check();
            testCase.verifyEqual(r.InstallType, "git");
            testCase.verifyEqual(r.Status, "upToDate");
            testCase.verifyFalse(r.UpdateAvailable);
            testCase.verifyEqual(r.CommitsBehind, 0);
            testCase.verifyEqual(r.Branch, "main");
            testCase.verifyFalse(r.HasModifications);
            testCase.verifyEqual(r.CurrentVersion, r.LatestVersion);
            testCase.verifyEqual(testCase.depStatus(r, "depA"), "upToDate");
            testCase.verifyEqual(testCase.depStatus(r, "vhlab_vhtools"), "upToDate");
            testCase.verifyEqual(testCase.depStatus(r, "pinned"), "pinned");
        end

        function testBehindMain(testCase)
            testCase.pushUpstream("NDI-matlab", "README.md", "new upstream line");
            r = testCase.check();
            testCase.verifyEqual(r.Status, "updateAvailable");
            testCase.verifyTrue(r.UpdateAvailable);
            testCase.verifyEqual(r.CommitsBehind, 1);
            testCase.verifyNotEqual(r.CurrentVersion, r.LatestVersion);
            testCase.verifySubstring(r.Message, "1 commit(s)");
            testCase.verifySubstring(r.Message, "ndi.update.install()");
        end

        function testDependencyBehind(testCase)
            testCase.pushUpstream("depA", "README.md", "dependency change");
            r = testCase.check();
            testCase.verifyEqual(r.CommitsBehind, 0);
            testCase.verifyEqual(r.Status, "updateAvailable");
            testCase.verifyEqual(testCase.depStatus(r, "depA"), "behind");
            testCase.verifySubstring(r.Message, "depA");
        end

        function testDependenciesCanBeSkipped(testCase)
            testCase.pushUpstream("depA", "README.md", "dependency change");
            r = ndi.update.check(RepoRoot = testCase.Ndi, Verbose = false, ...
                IncludeDependencies = false, IncludePython = false);
            testCase.verifyEmpty(r.Dependencies);
            testCase.verifyEqual(r.Status, "upToDate");
        end

        function testNewDependencyOnMainIsMissing(testCase)
            req = fullfile(testCase.Seeds, "NDI-matlab", "requirements.txt");
            txt = string(fileread(req)) + newline + testCase.remoteUrl("depNew");
            testCase.pushUpstream("NDI-matlab", "requirements.txt", txt, Append = false);
            r = testCase.check();
            testCase.verifyEqual(testCase.depStatus(r, "depNew"), "missing");
        end

        function testLocalCommitsAreAhead(testCase)
            testCase.writeFile(fullfile(testCase.Ndi, "local.m"), "x = 1;");
            testCase.commitAll(testCase.Ndi, "local work");
            r = testCase.check();
            testCase.verifyEqual(r.Status, "ahead");
            testCase.verifyFalse(r.UpdateAvailable);
            testCase.verifyEqual(r.CommitsAhead, 1);
            testCase.verifyTrue(r.HasModifications);
            testCase.verifyEqual(r.Modifications(1).CommitsAhead, 1);
        end

        function testModificationsAreListed(testCase)
            testCase.pushUpstream("NDI-matlab", "README.md", "new upstream line");
            testCase.writeFile(fullfile(testCase.Ndi, "README.md"), "my edit");
            testCase.writeFile(fullfile(testCase.Ndi, "mine.m"), "y = 2;");
            depA = fullfile(testCase.Tools, "depA");
            testCase.writeFile(fullfile(depA, "extra.m"), "z = 3;");
            testCase.commitAll(depA, "local dependency commit");

            r = testCase.check();
            testCase.verifyTrue(r.HasModifications);
            names = [r.Modifications.Name];
            testCase.verifyEqual(sort(names), sort(["NDI-matlab", "depA"]));

            ndiMods = r.Modifications(names == "NDI-matlab");
            testCase.verifyEqual(ndiMods.ChangedFiles, "README.md");
            testCase.verifyEqual(ndiMods.NewFiles, "mine.m");
            testCase.verifyEqual(ndiMods.CommitsAhead, 0);
            testCase.verifyEqual(r.Modifications(names == "depA").CommitsAhead, 1);
            testCase.verifySubstring(r.Message, "changed code in");

            txt = ndi.update.modificationSummary(r);
            testCase.verifySubstring(txt, "changed: README.md");
            testCase.verifySubstring(txt, "new:     mine.m");
            testCase.verifySubstring(txt, "1 local commit(s)");
        end

        function testInstallWithNoUpdateDoesNothing(testCase)
            r = testCase.install();
            testCase.verifyFalse(r.UpdateAvailable);
        end

        function testInstallRefusesModifiedCode(testCase)
            testCase.pushUpstream("NDI-matlab", "README.md", "new upstream line");
            testCase.writeFile(fullfile(testCase.Ndi, "README.md"), "my edit");
            testCase.verifyError(@() testCase.install(), ...
                'ndi:update:install:localModifications');
            % The user's edit is untouched.
            testCase.verifyEqual(strtrim(string(fileread(fullfile(testCase.Ndi, "README.md")))), ...
                "my edit");
        end

        function testInstallAllowModifiedGoesOn(testCase)
            % Past the modification guard, the next step needs ndi_install.m,
            % which the fake clone lacks.
            testCase.pushUpstream("NDI-matlab", "README.md", "new upstream line");
            testCase.writeFile(fullfile(testCase.Ndi, "mine.m"), "y = 2;");
            testCase.verifyError(@() testCase.install(AllowModified = true), ...
                'ndi:update:install:noInstaller');
        end

        function testInstallRefusesOtherBranch(testCase)
            testCase.pushUpstream("NDI-matlab", "README.md", "new upstream line");
            testCase.git(testCase.Ndi, "checkout -q -b myFeature");
            r = testCase.check();
            testCase.verifyEqual(r.Branch, "myFeature");
            testCase.verifySubstring(r.Message, "git checkout main");
            testCase.verifyError(@() testCase.install(), 'ndi:update:install:notOnMain');
        end
    end

    methods (Access = private)
        function r = check(testCase)
            r = ndi.update.check(RepoRoot = testCase.Ndi, Verbose = false, ...
                IncludePython = false);
        end

        function r = install(testCase, options)
            arguments
                testCase
                options.AllowModified (1,1) logical = false
            end
            r = [];
            evalc(['r = ndi.update.install(RepoRoot = testCase.Ndi, Confirm = false, ' ...
                'AllowModified = options.AllowModified, IncludePython = false);']);
        end

        function s = depStatus(testCase, r, name)
            match = [r.Dependencies.Name] == name;
            testCase.assertEqual(nnz(match), 1, "Expected one dependency named " + name);
            s = r.Dependencies(match).Status;
        end

        function url = remoteUrl(testCase, name)
            p = strrep(fullfile(testCase.Root, "remotes", name + ".git"), "\", "/");
            if ~startsWith(p, "/")
                p = "/" + p;    % Windows drive letter: file:///C:/...
            end
            url = "file://" + p;
        end

        function pushUpstream(testCase, name, file, text, options)
            arguments
                testCase
                name (1,1) string
                file (1,1) string
                text (1,1) string
                options.Append (1,1) logical = true
            end
            seed = fullfile(testCase.Seeds, name);
            f = fullfile(seed, file);
            if options.Append
                text = string(fileread(f)) + newline + text;
            end
            testCase.writeFile(f, text);
            testCase.commitAll(seed, "upstream change");
            testCase.git(seed, "push -q origin main");
        end

        function commitAll(testCase, repo, message)
            testCase.git(repo, "add -A");
            testCase.git(repo, testCase.GitIdentity + " commit -q -m """ + message + """");
        end

        function git(testCase, repo, args)
            [s, out] = system(sprintf('git -C "%s" %s', repo, args));
            testCase.assertEqual(s, 0, "git " + args + " failed: " + out);
        end

        function writeFile(~, f, text)
            folder = fileparts(f);
            if ~isfolder(folder)
                mkdir(folder);
            end
            fid = fopen(f, 'w');
            fwrite(fid, char(text));
            fclose(fid);
        end
    end
end
