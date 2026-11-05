classdef TestFindCalcDirectories < matlab.unittest.TestCase
    % TestFindCalcDirectories - ndi.fun.find_calc_directories finds
    % NDIcalc-*-matlab folders on the MATLAB path as well as next to
    % NDI-matlab (for example, ones that ndi_setup / MatBox installed into
    % a separate add-ons folder).
    %
    % Hermetic: fake calculator folders in a temp folder, added to the path
    % with a PathFixture, which restores the path afterwards.

    properties
        Root
    end

    methods (TestMethodSetup)
        function setUp(testCase)
            testCase.Root = string(tempname);
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
        end
    end

    methods (Test)
        function testReturnsColumnOfExistingFolders(testCase)
            d = ndi.fun.find_calc_directories();
            testCase.verifyClass(d, 'cell');
            testCase.verifyTrue(isempty(d) || iscolumn(d));
            testCase.verifyTrue(all(cellfun(@isfolder, d)));
            testCase.verifyEqual(numel(unique(d)), numel(d));
        end

        function testFindsCalculatorOnPath(testCase)
            calc = testCase.makeCalc("NDIcalc-pathtest-matlab");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(char(calc)));
            d = string(ndi.fun.find_calc_directories());
            testCase.verifyEqual(nnz(d == calc), 1);
        end

        function testFindsCalculatorFromSubfolderOnPath(testCase)
            % A path entry inside the calculator gives the calculator's root,
            % listed once however many of its folders are on the path.
            calc = testCase.makeCalc("NDIcalc-subtest-matlab");
            sub = fullfile(calc, "code");
            mkdir(sub);
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(char(calc)));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(char(sub)));
            d = string(ndi.fun.find_calc_directories());
            testCase.verifyEqual(nnz(d == calc), 1);
            testCase.verifyFalse(any(d == sub));
        end

        function testIgnoresOtherFoldersOnPath(testCase)
            other = fullfile(testCase.Root, "NDIcalc-pathtest-matlabextra");
            mkdir(other);
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(char(other)));
            d = string(ndi.fun.find_calc_directories());
            testCase.verifyFalse(any(startsWith(d, testCase.Root)));
        end
    end

    methods (Access = private)
        function calc = makeCalc(testCase, name)
            calc = fullfile(testCase.Root, name);
            mkdir(fullfile(calc, "ndi_common", "database_documents"));
        end
    end
end
