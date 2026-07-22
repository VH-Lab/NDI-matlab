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
    % nextBytes fills a full-length primitive byte[], and that two draws differ.
    % If this canary fails, the profile IV generation is compromised.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

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
            % The reflection-allocated byte[] must actually be filled in place.
            b = ndi.unittest.cloud.SecureRandomIVTest.secureRandomBytes(16);
            testCase.verifyFalse(all(b == 0), ...
                'nextBytes must fill the buffer (not leave it zeroed).');
        end

    end

    methods (Static, Access = private)
        function bytes = secureRandomBytes(n)
            % Mirror of ndi.cloud.profile.randomBytes (which is private).
            sr   = java.security.SecureRandom();
            jbuf = java.lang.reflect.Array.newInstance(java.lang.Byte.TYPE, n);
            sr.nextBytes(jbuf);
            bytes = reshape(int8(jbuf), 1, n);
        end
    end

end
