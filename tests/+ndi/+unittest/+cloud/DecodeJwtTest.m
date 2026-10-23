classdef DecodeJwtTest < matlab.unittest.TestCase
    % DECODEJWTTEST - offline tests for ndi.cloud.internal.decodeJwt
    %
    % decodeJwt used javax.xml.bind.DatatypeConverter to Base64-decode the JWT
    % payload. That class is gone from the Java shipped with recent MATLAB
    % releases, so every cloud login failed in getTokenExpiration. It now uses
    % matlab.net.base64decode. These tests build a JWT locally from a known
    % JSON payload, so they need no network or credentials.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    methods (Test)

        function testPayloadWithoutPadding(testCase)
            % Payload byte count is a multiple of 3: no '=' to restore.
            payload = ndi.unittest.cloud.DecodeJwtTest.examplePayload();
            [token, payloadSegment] = ...
                ndi.unittest.cloud.DecodeJwtTest.makeJwt(payload, 0);
            testCase.verifyEqual(mod(numel(payloadSegment), 4), 0);

            decoded = ndi.cloud.internal.decodeJwt(token);
            ndi.unittest.cloud.DecodeJwtTest.verifyPayload(testCase, decoded, payload);
        end

        function testPayloadNeedingOnePadCharacter(testCase)
            % Payload byte count mod 3 == 2: one '=' was stripped.
            payload = ndi.unittest.cloud.DecodeJwtTest.examplePayload();
            [token, payloadSegment] = ...
                ndi.unittest.cloud.DecodeJwtTest.makeJwt(payload, 2);
            testCase.verifyEqual(mod(numel(payloadSegment), 4), 3);

            decoded = ndi.cloud.internal.decodeJwt(token);
            ndi.unittest.cloud.DecodeJwtTest.verifyPayload(testCase, decoded, payload);
        end

        function testPayloadNeedingTwoPadCharacters(testCase)
            % Payload byte count mod 3 == 1: two '=' were stripped.
            payload = ndi.unittest.cloud.DecodeJwtTest.examplePayload();
            [token, payloadSegment] = ...
                ndi.unittest.cloud.DecodeJwtTest.makeJwt(payload, 1);
            testCase.verifyEqual(mod(numel(payloadSegment), 4), 2);

            decoded = ndi.cloud.internal.decodeJwt(token);
            ndi.unittest.cloud.DecodeJwtTest.verifyPayload(testCase, decoded, payload);
        end

        function testReturnsTokenExpiration(testCase)
            % The real caller: getTokenExpiration reads the 'exp' claim.
            payload = ndi.unittest.cloud.DecodeJwtTest.examplePayload();
            token = ndi.unittest.cloud.DecodeJwtTest.makeJwt(payload, 0);

            decoded = ndi.cloud.internal.decodeJwt(token);
            testCase.verifyTrue(isfield(decoded, 'exp'));
            testCase.verifyEqual(decoded.exp, 1893456000);
        end

    end

    methods (Static, Access = private)

        function payload = examplePayload()
            % A JWT-like payload. The name includes non-ASCII characters
            % (e-acute and the euro sign) to exercise the UTF-8 decode.
            payload = struct( ...
                'exp', 1893456000, ...
                'email', 'test.user@example.com', ...
                'name', ['Ren', char(233), ' ', char(8364)], ...
                'nonce', '');
        end

        function [token, payloadSegment] = makeJwt(payload, targetMod3)
            % Build HEADER.PAYLOAD.SIGNATURE with Base64Url segments. The
            % 'nonce' field is lengthened until the UTF-8 payload byte count
            % mod 3 equals targetMod3, which fixes how much padding the
            % decoder has to restore.
            arguments
                payload (1,1) struct
                targetMod3 (1,1) {mustBeNumeric}
            end
            payloadBytes = unicode2native(jsonencode(payload), 'UTF-8');
            while mod(numel(payloadBytes), 3) ~= targetMod3
                payload.nonce = [payload.nonce, 'x'];
                payloadBytes = unicode2native(jsonencode(payload), 'UTF-8');
            end

            headerBytes = unicode2native('{"alg":"HS256","typ":"JWT"}', 'UTF-8');
            headerSegment = ndi.unittest.cloud.DecodeJwtTest.base64UrlEncode(headerBytes);
            payloadSegment = ndi.unittest.cloud.DecodeJwtTest.base64UrlEncode(payloadBytes);
            token = [headerSegment, '.', payloadSegment, '.', 'dummySignature'];
        end

        function encoded = base64UrlEncode(bytes)
            arguments
                bytes {mustBeNumeric}
            end
            encoded = char(matlab.net.base64encode(uint8(bytes)));
            encoded = strrep(encoded, '+', '-');
            encoded = strrep(encoded, '/', '_');
            encoded = strrep(encoded, '=', '');
        end

        function verifyPayload(testCase, decoded, payload)
            arguments
                testCase (1,1) ndi.unittest.cloud.DecodeJwtTest
                decoded % checked to be a struct by the first verification
                payload (1,1) struct
            end
            testCase.verifyClass(decoded, 'struct');
            testCase.verifyEqual(decoded.exp, payload.exp);
            testCase.verifyEqual(decoded.email, payload.email);
            testCase.verifyEqual(decoded.name, payload.name);
        end

    end

end
