classdef removeHiddenFileGroupsTest < matlab.unittest.TestCase
    % REMOVEHIDDENFILEGROUPSTEST - Unit tests for ndi.util.removehiddenfilegroups
    %
    % Description:
    %   Tests that ndi.util.removehiddenfilegroups removes file groups containing
    %   hidden files or macOS AppleDouble ('._') shadow files, while preserving
    %   genuine groups. This is the filter that prevents a shadow file such as
    %   '._Epoch6_g0_t0.imec0.ap.bin' from producing a spurious duplicate epoch.
    %

    methods (Test)

        function testRemovesAppleDoubleGroup(testCase)
            % The shadow-file group is dropped; the real group is kept.
            groups = { {'/data/Epoch6_g0/Epoch6_g0_t0.imec0.ap.bin'}; ...
                       {'/data/Epoch6_g0/._Epoch6_g0_t0.imec0.ap.bin'} };
            out = ndi.util.removehiddenfilegroups(groups);
            testCase.verifyEqual(numel(out), 1, 'Exactly one group should remain.');
            testCase.verifyEqual(out{1}{1}, '/data/Epoch6_g0/Epoch6_g0_t0.imec0.ap.bin', ...
                'The genuine file group must be the one retained.');
        end

        function testRemovesDotHiddenGroup(testCase)
            % A plain hidden file (begins with '.') group is dropped.
            groups = { {'/d/.DS_Store'}; {'/d/real.bin'} };
            out = ndi.util.removehiddenfilegroups(groups);
            testCase.verifyEqual(numel(out), 1, 'The hidden-file group should be removed.');
            testCase.verifyEqual(out{1}{1}, '/d/real.bin', 'The real group should remain.');
        end

        function testLeadingDotNoNameIsHidden(testCase)
            % A dotfile with no stem (e.g. '.gitignore', '.DS_Store') is all
            % "extension" to fileparts; the basename, not the fileparts name,
            % must be checked so these are still recognized as hidden.
            groups = { {'/d/.gitignore'}; {'/d/keep.bin'} };
            out = ndi.util.removehiddenfilegroups(groups);
            testCase.verifyEqual(numel(out), 1, ...
                'A leading-dot file with no stem must be treated as hidden.');
            testCase.verifyEqual(out{1}{1}, '/d/keep.bin', 'The real group should remain.');
        end

        function testKeepsAllVisibleGroups(testCase)
            % Nothing is removed when no group contains a hidden file.
            groups = { {'/d/a.bin'}; {'/d/b.bin'}; {'/d/c.bin'} };
            out = ndi.util.removehiddenfilegroups(groups);
            testCase.verifyEqual(numel(out), 3, 'All visible groups should be kept.');
            testCase.verifyEqual(out, groups, 'Groups should be returned unchanged.');
        end

        function testMultiFileGroupWithOneHiddenIsRemoved(testCase)
            % If any file in a group is hidden, the whole group is dropped.
            groups = { {'/d/a.ap.bin', '/d/._a.ap.meta'}; ...
                       {'/d/b.ap.bin', '/d/b.ap.meta'} };
            out = ndi.util.removehiddenfilegroups(groups);
            testCase.verifyEqual(numel(out), 1, ...
                'A group containing any hidden file should be removed.');
            testCase.verifyEqual(out{1}, {'/d/b.ap.bin', '/d/b.ap.meta'}, ...
                'The fully visible group should remain.');
        end

        function testAllHiddenReturnsEmpty(testCase)
            % If every group is hidden, the result is empty.
            groups = { {'/d/._x.bin'}; {'/d/.y.bin'} };
            out = ndi.util.removehiddenfilegroups(groups);
            testCase.verifyEmpty(out, 'All-hidden input should return an empty result.');
        end

        function testEmptyInput(testCase)
            % An empty input returns empty without error.
            out = ndi.util.removehiddenfilegroups({});
            testCase.verifyEmpty(out, 'Empty input should return empty.');
        end

        function testDotPrefixOnlyMatchesBasename(testCase)
            % A '.' earlier in the path (e.g. a dotted directory) must not cause
            % a visible file to be treated as hidden; only the file's own name
            % (basename) is checked.
            groups = { {'/.config/data/real.bin'} };
            out = ndi.util.removehiddenfilegroups(groups);
            testCase.verifyEqual(numel(out), 1, ...
                'A dot in a parent directory name should not hide a visible file.');
        end

    end
end
