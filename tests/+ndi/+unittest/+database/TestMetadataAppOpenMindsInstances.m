classdef TestMetadataAppOpenMindsInstances < matlab.unittest.TestCase
    % TestMetadataAppOpenMindsInstances - Read openMINDS controlled instances for the metadata app.
    %
    % Description:
    %   The metadata app lists openMINDS controlled instances (e.g. species,
    %   licenses) and reads each instance document from the local openMINDS
    %   instance library. This test checks that the documents are found and
    %   decoded with the installed openMINDS_MATLAB version.

    methods (Test)
        function testGetOpenMindsInstances(testCase)
            [names, labels] = ndi.database.metadata_app.fun.getOpenMindsInstances('BiologicalSex');

            testCase.verifyNotEmpty(names, ...
                'Diagnostic: Expected controlled instances of BiologicalSex.');
            testCase.verifyNumElements(labels, numel(names), ...
                'Diagnostic: Expected one label per instance name.');
            testCase.verifyTrue(all(strlength(string(labels)) > 0), ...
                'Diagnostic: Every instance document should have a name.');
        end

        function testGetCCByLicences(testCase)
            [names, shortNames] = ndi.database.metadata_app.fun.getCCByLicences();

            testCase.verifyNotEmpty(names, ...
                'Diagnostic: Expected CC BY licenses in the instance library.');
            testCase.verifyTrue(all(contains(string(names), 'CC-BY')), ...
                'Diagnostic: Only CC BY licenses should be returned.');
            testCase.verifyNumElements(shortNames, numel(names), ...
                'Diagnostic: Expected one short name per license.');
            testCase.verifyTrue(all(strlength(shortNames) > 0), ...
                'Diagnostic: Every license document should have a short name.');
        end
    end
end
