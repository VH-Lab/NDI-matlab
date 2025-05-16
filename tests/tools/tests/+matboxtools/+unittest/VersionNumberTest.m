classdef VersionNumberTest < matlab.unittest.TestCase

    methods (Test)
        
        % Test case for the constructor with numeric input
        function testConstructorWithNumericInput(testCase)
            version = matbox.VersionNumber({[1, 2, 3]});
            testCase.verifyEqual(version.Major, uint8(1));
            testCase.verifyEqual(version.Minor, uint8(2));
            testCase.verifyEqual(version.Patch, uint8(3));
        end
        
        % Test case for the constructor with string input
        function testConstructorWithStringInput(testCase)
            version = matbox.VersionNumber({'1.2.3'});
            testCase.verifyEqual(version.Major, uint8(1));
            testCase.verifyEqual(version.Minor, uint8(2));
            testCase.verifyEqual(version.Patch, uint8(3));
        end

        % Test case for setting format and string representation
        function testSetFormatAndStringRepresentation(testCase)
            version = matbox.VersionNumber({'1.2.3'});
            version.Format = '%d.%d';
            versionStr = string(version);
            testCase.verifyEqual(versionStr, "1.2");
        end

        % Test bumpMajor method
        function testBumpMajor(testCase)
            version = matbox.VersionNumber({[1, 2, 3]});
            version.bumpMajor();
            testCase.verifyEqual(version.Major, uint8(2));
            testCase.verifyEqual(version.Minor, uint8(0));
            testCase.verifyEqual(version.Patch, uint8(0));
            testCase.verifyEqual(version.Build, uint8(0));
        end

        % Test bumpMinor method
        function testBumpMinor(testCase)
            version = matbox.VersionNumber({[1, 2, 3]});
            version.bumpMinor();
            testCase.verifyEqual(version.Major, uint8(1));
            testCase.verifyEqual(version.Minor, uint8(3));
            testCase.verifyEqual(version.Patch, uint8(0));
            testCase.verifyEqual(version.Build, uint8(0));
        end
        
        % Test bumpPatch method
        function testBumpPatch(testCase)
            version = matbox.VersionNumber({[1, 2, 3]});
            version.bumpPatch();
            testCase.verifyEqual(version.Major, uint8(1));
            testCase.verifyEqual(version.Minor, uint8(2));
            testCase.verifyEqual(version.Patch, uint8(4));
            testCase.verifyEqual(version.Build, uint8(0));
        end
        
        % Test bumpBuild method
        function testBumpBuild(testCase)
            version = matbox.VersionNumber({[1, 2, 3, 4]});
            version.bumpBuild();
            testCase.verifyEqual(version.Build, uint8(5));
        end

        % Test comparison operators
        function testComparisonOperators(testCase)
            v1 = matbox.VersionNumber({'1.2.3'});
            v2 = matbox.VersionNumber({'2.0.0'});
            v3 = matbox.VersionNumber({'1.2.3'});
            
            % Test equality
            testCase.verifyTrue(v1 == v3);
            testCase.verifyFalse(v1 == v2);
            
            % Test inequality
            testCase.verifyTrue(v1 ~= v2);
            testCase.verifyFalse(v1 ~= v3);
            
            % Test greater than
            testCase.verifyTrue(v2 > v1);
            testCase.verifyFalse(v1 > v2);
            
            % Test less than
            testCase.verifyTrue(v1 < v2);
            testCase.verifyFalse(v2 < v1);
        end
        
        % Test IsLatest property
        function testIsLatestProperty(testCase)
            version = matbox.VersionNumber({'latest'});
            testCase.verifyTrue(version.IsLatest);
            testCase.verifyEqual(version.Major, uint8(255));
        end

        % Test validateVersion method
        function testValidateVersion(testCase)
            v1 = matbox.VersionNumber({'1.2.3'});
            v2 = matbox.VersionNumber({'2.0.0'});
            validVersions = {v1, v2};
            
            % No error for valid version
            testCase.verifyWarningFree(@() matbox.VersionNumber.validateVersion(v1, validVersions{:}));
            
            % Error for invalid version
            invalidVersion = matbox.VersionNumber({'3.0.0'});
            testCase.verifyError(@() matbox.VersionNumber.validateVersion(invalidVersion, validVersions{:}), ...
                "MatBox:InvalidVersionNumber");
        end
    end
end
