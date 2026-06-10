classdef vhPrairie2pTest < matlab.unittest.TestCase
    % VHPRAIRIE2PTEST - tests for the vhlab Prairie 2-photon file navigator
    %
    %   Synthesizes a session whose epochs are <BASE> / <BASE>-NNN directory
    %   pairs and checks that ndi.setup.file.navigator.vhPrairie2p assembles
    %   each epoch's file group correctly: the reference/frametrigger index
    %   files from <BASE> plus the non-TIFF config of each <BASE>-NNN
    %   acquisition directory, with the epoch id equal to <BASE>.

    methods (Test)

        function testDirectoryPairGrouping(testCase)
            dirname = tempname();
            mkdir(dirname);
            cleaner = onCleanup(@() vhPrairie2pTest.removeDir(dirname));

            % epoch A: a single acquisition directory (the common case)
            vhPrairie2pTest.writeText(fullfile(dirname,'expA','reference.txt'), 'index');
            vhPrairie2pTest.writeText(fullfile(dirname,'expA','frametrigger.txt'), '0 1 2');
            vhPrairie2pTest.writeText(fullfile(dirname,'expA-001','expA-001.xml'), '<PVScan/>');
            vhPrairie2pTest.writeText(fullfile(dirname,'expA-001','expA-001_Cycle001_Ch1_000001.tif'), 'tiffbytes');

            % epoch B: several acquisition directories -> still ONE epoch (rare)
            vhPrairie2pTest.writeText(fullfile(dirname,'expB','reference.txt'), 'index');
            vhPrairie2pTest.writeText(fullfile(dirname,'expB','frametrigger.txt'), '0 1');
            vhPrairie2pTest.writeText(fullfile(dirname,'expB-001','expB.xml'), '<PVScan/>');
            vhPrairie2pTest.writeText(fullfile(dirname,'expB-002','expB.xml'), '<PVScan/>');
            vhPrairie2pTest.writeText(fullfile(dirname,'expB-003','expB.xml'), '<PVScan/>');

            % a distractor directory with no reference.txt -> not an epoch
            vhPrairie2pTest.writeText(fullfile(dirname,'misc','notes.txt'), 'ignore me');

            E = ndi.session.dir('prairieexp', dirname);
            nav = ndi.setup.file.navigator.vhPrairie2p(E, {'reference.txt'});

            groups = nav.selectfilegroups_disk();
            testCase.verifyEqual(numel(groups), 2, 'Expected exactly two epochs (expA, expB).');

            gA = vhPrairie2pTest.groupForBase(groups, 'expA');
            gB = vhPrairie2pTest.groupForBase(groups, 'expB');
            testCase.assertNotEmpty(gA, 'Did not find the expA epoch.');
            testCase.assertNotEmpty(gB, 'Did not find the expB epoch.');

            % epoch A contents
            testCase.verifyTrue(vhPrairie2pTest.has(gA,'expA/reference.txt'), 'expA missing reference.txt.');
            testCase.verifyTrue(vhPrairie2pTest.has(gA,'expA/frametrigger.txt'), 'expA missing frametrigger.txt.');
            testCase.verifyTrue(vhPrairie2pTest.has(gA,'expA-001/expA-001.xml'), 'expA missing the acquisition .xml.');
            testCase.verifyFalse(any(~cellfun(@isempty, regexp(gA,'\.tif$','once'))), ...
                'TIFF frames should NOT be listed in the epoch file group.');

            % epoch B spans -001/-002/-003 as one epoch
            testCase.verifyTrue(vhPrairie2pTest.has(gB,'expB-001/expB.xml'), 'expB missing -001 xml.');
            testCase.verifyTrue(vhPrairie2pTest.has(gB,'expB-002/expB.xml'), 'expB missing -002 xml.');
            testCase.verifyTrue(vhPrairie2pTest.has(gB,'expB-003/expB.xml'), 'expB missing -003 xml.');

            % epoch id is the BASE directory name
            testCase.verifyEqual(nav.epochid(1, gA), 'expA', 'expA epoch id mismatch.');
            testCase.verifyEqual(nav.epochid(1, gB), 'expB', 'expB epoch id mismatch.');
        end

        function testBaseWithoutAcquisitionIsSkipped(testCase)
            % a <BASE> with reference.txt but no <BASE>-NNN directory is not an epoch
            dirname = tempname();
            mkdir(dirname);
            cleaner = onCleanup(@() vhPrairie2pTest.removeDir(dirname));

            vhPrairie2pTest.writeText(fullfile(dirname,'lonely','reference.txt'), 'index');
            vhPrairie2pTest.writeText(fullfile(dirname,'good','reference.txt'), 'index');
            vhPrairie2pTest.writeText(fullfile(dirname,'good-001','good.xml'), '<PVScan/>');

            E = ndi.session.dir('prairieexp2', dirname);
            nav = ndi.setup.file.navigator.vhPrairie2p(E, {'reference.txt'});
            groups = nav.selectfilegroups_disk();
            testCase.verifyEqual(numel(groups), 1, 'Only the paired <BASE> should yield an epoch.');
            testCase.verifyEqual(nav.epochid(1, groups{1}), 'good', 'Wrong epoch id.');
        end

    end % methods (Test)

    methods (Static)
        function writeText(filepath, contents)
            [p,~,~] = fileparts(filepath);
            if ~isfolder(p), mkdir(p); end
            fid = fopen(filepath,'w');
            c = onCleanup(@() fclose(fid));
            fprintf(fid,'%s\n', contents);
        end

        function tf = has(group, relpath)
            relpath = strrep(relpath, '/', filesep);
            tf = any(~cellfun(@isempty, strfind(group, relpath)));
        end

        function g = groupForBase(groups, B)
            g = {};
            for i=1:numel(groups)
                if vhPrairie2pTest.has(groups{i}, [B filesep 'reference.txt'])
                    g = groups{i};
                    return;
                end
            end
        end

        function removeDir(dirname)
            if isfolder(dirname)
                try, rmdir(dirname,'s'); catch, end
            end
        end
    end % methods (Static)

end % classdef
