classdef TestMoveToolsFolder < matlab.unittest.TestCase
    % TestMoveToolsFolder - ndi.update.moveToolsFolder and ndi.update.toolsFolder.
    % Offline. Every test moves a small fake tools folder made in a
    % temporary folder, with its own startup.m (the From and StartupFile
    % options), so the real installation and startup.m are never touched.

    properties
        Root     % temporary folder for the test
        From     % the fake tools folder
        Startup  % the fake startup.m
    end

    methods (TestMethodSetup)
        function makeFakeTools(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.Root = string(fixture.Folder);
            testCase.From = fullfile(testCase.Root, "tools");
            mkdir(fullfile(testCase.From, "NDI-matlab", ".git"));
            mkdir(fullfile(testCase.From, "vhlab_vhtools"));
            writeText(fullfile(testCase.From, "NDI-matlab", "ndi_Init.m"), "% init");
            writeText(fullfile(testCase.From, "NDI-matlab", ".git", "HEAD"), "ref: refs/heads/main");
            writeText(fullfile(testCase.From, "vhlab_vhtools", "vhtools_startup.m"), "% startup");
            testCase.Startup = fullfile(testCase.Root, "startup.m");
            writeText(testCase.Startup, startupText(testCase.From));
        end
    end

    methods (Test)
        function testMovesEverything(testCase)
            to = fullfile(testCase.Root, "new", "ndi-tools");
            r = move(testCase, to);

            testCase.verifyTrue(r.Moved);
            testCase.verifyTrue(r.OldDeleted);
            testCase.verifyFalse(isfolder(testCase.From));
            testCase.verifyTrue(isfile(fullfile(r.To, "NDI-matlab", "ndi_Init.m")));
            testCase.verifyTrue(isfile(fullfile(r.To, "NDI-matlab", ".git", "HEAD")), ...
                'Hidden folders such as .git must be moved too.');
            testCase.verifyTrue(isfile(fullfile(r.To, "vhlab_vhtools", "vhtools_startup.m")));

            txt = string(fileread(testCase.Startup));
            testCase.verifySubstring(txt, fullfile(r.To, "vhlab_vhtools", "vhtools_startup.m"));
            testCase.verifyFalse(contains(txt, testCase.From + filesep));
            testCase.verifySubstring(txt, "addpath('/somewhere/else');", ...
                'Other lines of startup.m must be left alone.');
            testCase.verifyEqual(string(fileread(r.StartupBackup)), startupText(testCase.From));
        end

        function testKeepsOldFolderWhenAsked(testCase)
            to = fullfile(testCase.Root, "ndi-tools");
            r = move(testCase, to, 'DeleteOld', false);
            testCase.verifyTrue(r.Moved);
            testCase.verifyFalse(r.OldDeleted);
            testCase.verifyTrue(isfile(fullfile(testCase.From, "NDI-matlab", "ndi_Init.m")));
            testCase.verifyTrue(isfile(fullfile(r.To, "NDI-matlab", "ndi_Init.m")));
        end

        function testEmptyExistingFolderIsUsed(testCase)
            to = fullfile(testCase.Root, "empty");
            mkdir(to);
            r = move(testCase, to);
            testCase.verifyTrue(isfile(fullfile(r.To, "NDI-matlab", "ndi_Init.m")));
        end

        function testApostropheInNewFolder(testCase)
            to = fullfile(testCase.Root, "Steve's tools");
            r = move(testCase, to);
            txt = string(fileread(testCase.Startup));
            testCase.verifySubstring(txt, strrep(fullfile(r.To, "vhlab_vhtools"), "'", "''"), ...
                'An apostrophe must be doubled inside the MATLAB char in startup.m.');
        end

        function testUpdatesThePath(testCase)
            oldPath = path;
            testCase.addTeardown(@path, oldPath);
            addpath(char(fullfile(testCase.From, "NDI-matlab")));

            to = fullfile(testCase.Root, "ndi-tools");
            r = move(testCase, to, 'UpdatePath', true);

            entries = string(strsplit(path, pathsep));
            testCase.verifyTrue(any(entries == fullfile(r.To, "NDI-matlab")));
            testCase.verifyFalse(any(entries == fullfile(testCase.From, "NDI-matlab")));
        end

        function testRefusesNonEmptyFolder(testCase)
            to = fullfile(testCase.Root, "full");
            mkdir(to);
            writeText(fullfile(to, "mine.txt"), "keep me");
            testCase.verifyError(@() move(testCase, to), ...
                'ndi:update:moveToolsFolder:notEmpty');
            verifyNothingChanged(testCase);
            testCase.verifyEqual(string(fileread(fullfile(to, "mine.txt"))), "keep me");
        end

        function testRefusesFolderInsideOld(testCase)
            testCase.verifyError(@() move(testCase, fullfile(testCase.From, "inside")), ...
                'ndi:update:moveToolsFolder:insideOld');
            verifyNothingChanged(testCase);
        end

        function testRefusesSameFolder(testCase)
            testCase.verifyError(@() move(testCase, testCase.From), ...
                'ndi:update:moveToolsFolder:sameFolder');
            verifyNothingChanged(testCase);
        end

        function testRefusesRelativePath(testCase)
            testCase.verifyError(@() move(testCase, "~/ndi-tools"), ...
                'ndi:update:moveToolsFolder:relativePath');
            testCase.verifyError(@() move(testCase, "ndi-tools"), ...
                'ndi:update:moveToolsFolder:relativePath');
            verifyNothingChanged(testCase);
        end

        function testRefusesStartupWithoutLine(testCase)
            writeText(testCase.Startup, "addpath('/somewhere/else');" + newline);
            to = fullfile(testCase.Root, "ndi-tools");
            testCase.verifyError(@() move(testCase, to), ...
                'ndi:update:moveToolsFolder:noStartupLine');
            testCase.verifyFalse(isfolder(to), 'Nothing may be copied before the checks pass.');
            testCase.verifyTrue(isfile(fullfile(testCase.From, "NDI-matlab", "ndi_Init.m")));
        end

        function testRefusesMissingStartup(testCase)
            delete(testCase.Startup);
            testCase.verifyError(@() move(testCase, fullfile(testCase.Root, "ndi-tools")), ...
                'ndi:update:moveToolsFolder:noStartupFile');
        end

        function testToolsFolderMatchesInstallType(testCase)
            [type, info] = ndi.update.installType();
            folder = ndi.update.toolsFolder();
            if type == "git"
                testCase.verifyEqual(folder, string(fileparts(char(info.RepoRoot))));
                testCase.verifyTrue(isfolder(folder));
            else
                testCase.verifyEqual(folder, "");
            end
        end
    end
end


function r = move(testCase, to, varargin)
    r = ndi.update.moveToolsFolder(to, 'Confirm', false, 'UpdatePath', false, ...
        'From', testCase.From, 'StartupFile', testCase.Startup, varargin{:});
end

function verifyNothingChanged(testCase)
    testCase.verifyEqual(string(fileread(testCase.Startup)), startupText(testCase.From));
    testCase.verifyFalse(isfile(testCase.Startup + ".bak"));
    testCase.verifyTrue(isfile(fullfile(testCase.From, "NDI-matlab", "ndi_Init.m")));
end

function txt = startupText(from)
    % What ndi_install writes, after an unrelated line of the user's own.
    txt = "addpath('/somewhere/else');" + newline + ...
        "run(['" + fullfile(from, "vhlab_vhtools", "vhtools_startup.m") + "']);" + newline;
end

function writeText(file, txt)
    fid = fopen(file, 'w');
    fprintf(fid, '%s', txt);
    fclose(fid);
end
