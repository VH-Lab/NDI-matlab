classdef test_isunix_sv < matlab.unittest.TestCase
    methods(Test)
        function test_isunix_sv_return_type(testCase)
            % This test is designed to work in any environment
            out = vlt.data.isunix_sv();
            testCase.verifyThat(out, matlab.unittest.constraints.IsA('logical') | matlab.unittest.constraints.IsA('double'));
            if isa(out,'double'),
                testCase.verifyTrue(out==0 | out==1);
            end
        end
    end
end
