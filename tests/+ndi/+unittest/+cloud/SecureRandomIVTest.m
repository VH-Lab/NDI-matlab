classdef SecureRandomIVTest < matlab.unittest.TestCase
    % SECURERANDOMIVTEST - canary for the AES-CBC IV entropy source
    %
    % ndi.cloud.profile.randomBytes (private static) now draws the AES-CBC IV
    % from java.security.SecureRandom instead of MATLAB's deterministic,
    % fixed-seed RNG, so IVs do not repeat across a fresh session (IV reuse
    % under the fixed key would make identical passwords encrypt to identical
    % ciphertext blocks).
    %
    % randomBytes is private, so this test exercises the exact SecureRandom
    % idiom the fix depends on: it confirms the platform/JVM supports it, that
    % a full-length buffer of real entropy comes back, and that two draws differ.
    % If this canary fails, the profile IV generation is compromised.
    %
    % It earned its keep: the original nextBytes-into-a-reflected-byte[] idiom
    % returned all zeros, because MATLAB converts a Java primitive array at the
    % boundary and so passed nextBytes a copy it then discarded.

    methods (Test)

        function testReturnsRequestedLength(testCase)
            b = ndi.unittest.cloud.SecureRandomIVTest.secureRandomBytes(16);
            testCase.verifyEqual(numel(b), 16);
            testCase.verifyEqual(class(b), 'int8');
        end

        function testTwoDrawsDiffer(testCase)
            % A deterministic fixed-seed RNG would make these identical at the
            % start of a session; a CSPRNG must not.
            a = ndi.unittest.cloud.SecureRandomIVTest.secureRandomBytes(16);
            b = ndi.unittest.cloud.SecureRandomIVTest.secureRandomBytes(16);
            testCase.verifyFalse(isequal(a, b), ...
                'Two SecureRandom IVs must not be identical.');
        end

        function testNotAllZero(testCase)
            % Real entropy must come back, not a zeroed buffer -- the failure
            % mode that a fill-in-place idiom produces across the MATLAB/Java
            % by-value boundary.
            b = ndi.unittest.cloud.SecureRandomIVTest.secureRandomBytes(16);
            testCase.verifyFalse(all(b == 0), ...
                'SecureRandom must return real entropy, not a zeroed buffer.');
        end

    end

    methods (Static, Access = private)
        function bytes = secureRandomBytes(n)
            % Mirror of ndi.cloud.profile.randomBytes (which is private).
            % Must be kept identical to it -- this mirror is the only thing
            % under test, so a divergence here silently stops testing the
            % production idiom.
            sr = java.security.SecureRandom();
            bytes = reshape(int8(sr.generateSeed(n)), 1, n);
        end
    end

end
