classdef TestAllTypes < matlab.unittest.TestCase
    % TestAllTypes - A test for the ndi.fun.doc.allTypes function.
    %

    methods (Test)
        function testAllTypes(testCase)
            % This test method is executed for each 'docType' parameter.
            % It verifies that ndi.document(docType) can be called without error
            % and that it returns an object of the correct class.

            % 1. Execute the constructor. If this throws an error, the test
            %    will automatically fail here, which is the desired behavior.
            all_types = ndi.fun.doc.allTypes();

            % 2. Verify that the created object is of the correct class.
            %    This confirms the constructor returned the right thing.
            testCase.verifyClass(all_types, 'cell', 'Did not return a cell array.');
            testCase.verifyNotEmpty(all_types, 'The returned cell array was empty.');
            testCase.verifyClass(all_types{1}, 'char', 'The first element was not a char array.');
        end
    end
end
