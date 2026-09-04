classdef InstallTest < matlab.unittest.TestCase
    % INSTALLTEST - Tests for ndi.fun.probe.import.jrclust.install.
    %
    % These run headless and do not need JRCLUST: they build folders that look
    % like JRCLUST working copies (with and without the NDI support, on and off
    % the expected branch) and check what NDI reports about them.

    properties
        WorkDir string = ""
    end

    methods (TestMethodSetup)
        function makeWorkDir(testCase)
            testCase.WorkDir = string(tempname);
            mkdir(testCase.WorkDir);
            testCase.addTeardown(@() rmdir(testCase.WorkDir,'s'));
        end
    end

    methods (Access = private)
        function root = makeFakeJRCLUST(testCase, options)
            arguments
                testCase
                options.ndiSupport (1,1) logical = true
                options.branch (1,:) char = 'ndi_import'
                options.git (1,1) logical = true
                options.remote (1,:) char = 'https://github.com/VH-Lab/JRCLUST.git'
            end
            root = fullfile(char(testCase.WorkDir), ['JRCLUST_' char(matlab.lang.makeValidName( ...
                [options.branch num2str(options.ndiSupport)]))]);
            mkdir(fullfile(root,'@JRC'));
            mkdir(fullfile(root,'+jrclust','+detect'));
            fclose(fopen(fullfile(root,'jrc.m'),'w'));
            if options.ndiSupport
                fclose(fopen(fullfile(root,'@JRC','bootstrapNDI.m'),'w'));
                fclose(fopen(fullfile(root,'+jrclust','+detect','ndiRecording.m'),'w'));
            end
            if options.git
                mkdir(fullfile(root,'.git','refs','heads'));
                fid = fopen(fullfile(root,'.git','HEAD'),'w');
                fprintf(fid,'ref: refs/heads/%s\n',options.branch);
                fclose(fid);
                fid = fopen(fullfile(root,'.git','refs','heads',options.branch),'w');
                fprintf(fid,'%s\n',repmat('a',1,40));
                fclose(fid);
                fid = fopen(fullfile(root,'.git','config'),'w');
                fprintf(fid,'[core]\n\tbare = false\n[remote "origin"]\n\turl = %s\n', ...
                    options.remote);
                fclose(fid);
            end
        end
    end

    methods (Test)
        function testGoodInstallation(testCase)
            root = testCase.makeFakeJRCLUST();

            info = ndi.fun.probe.import.jrclust.install('jrclustPath',root);

            testCase.verifyTrue(info.installed);
            testCase.verifyTrue(info.hasNdiSupport);
            testCase.verifyTrue(info.ok);
            testCase.verifyEmpty(info.missingFiles);
            testCase.verifyTrue(info.isGit);
            testCase.verifyEqual(info.branch,'ndi_import');
            testCase.verifyTrue(info.onExpectedBranch);
            testCase.verifyTrue(info.isVHLabFork);
            testCase.verifyNotEmpty(info.summary);
        end

        function testWrongBranchStillUsableButFlagged(testCase)
            % The pipeline needs the NDI files, not the branch name, so ok stays
            % true - but the branch mismatch is reported.
            root = testCase.makeFakeJRCLUST('branch','main');

            info = ndi.fun.probe.import.jrclust.install('jrclustPath',root);

            testCase.verifyTrue(info.ok);
            testCase.verifyEqual(info.branch,'main');
            testCase.verifyFalse(info.onExpectedBranch);
            testCase.verifyTrue(contains(info.summary,'ndi_import'));
        end

        function testStockJRCLUSTIsNotUsable(testCase)
            root = testCase.makeFakeJRCLUST('ndiSupport',false,'branch','master', ...
                'remote','https://github.com/JaneliaSciComp/JRCLUST.git');

            info = ndi.fun.probe.import.jrclust.install('jrclustPath',root);

            testCase.verifyTrue(info.installed);
            testCase.verifyFalse(info.hasNdiSupport);
            testCase.verifyFalse(info.ok);
            testCase.verifyNumElements(info.missingFiles,2);
            testCase.verifyFalse(info.isVHLabFork);
        end

        function testNonGitWorkingCopy(testCase)
            root = testCase.makeFakeJRCLUST('git',false);

            info = ndi.fun.probe.import.jrclust.install('jrclustPath',root);

            testCase.verifyTrue(info.ok);
            testCase.verifyFalse(info.isGit);
            testCase.verifyEqual(info.branch,'');
        end

        function testMissingInstallation(testCase)
            info = ndi.fun.probe.import.jrclust.install( ...
                'jrclustPath', fullfile(char(testCase.WorkDir),'no_such_folder'));

            testCase.verifyFalse(info.installed);
            testCase.verifyFalse(info.ok);
            testCase.verifyTrue(contains(info.summary,'not found'));
        end

        function testExpectedBranchIsConfigurable(testCase)
            root = testCase.makeFakeJRCLUST('branch','my_branch');

            info = ndi.fun.probe.import.jrclust.install('jrclustPath',root, ...
                'expectedBranch','my_branch');

            testCase.verifyTrue(info.onExpectedBranch);
        end
    end
end
