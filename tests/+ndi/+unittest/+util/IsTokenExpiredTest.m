classdef IsTokenExpiredTest < matlab.unittest.TestCase
% IsTokenExpiredTest - Unit tests for ndi.cloud.internal.isTokenExpired.
%
% These tests construct fake JWTs with arbitrary `exp` claims so the
% expiration logic can be exercised without touching the network.

    methods (Test)
        function expiredTokenReportsExpired(testCase)
            jwt = makeJwt(struct('exp', posixNowOffset(-3600)));
            testCase.verifyTrue(ndi.cloud.internal.isTokenExpired(jwt));
        end

        function comfortablyValidTokenReportsNotExpired(testCase)
            jwt = makeJwt(struct('exp', posixNowOffset(3600)));
            testCase.verifyFalse(ndi.cloud.internal.isTokenExpired(jwt));
        end

        function tokenInsideSkewWindowReportsExpired(testCase)
            % 30 s of validity left, default skew of 60 s -> treat as expired.
            jwt = makeJwt(struct('exp', posixNowOffset(30)));
            testCase.verifyTrue(ndi.cloud.internal.isTokenExpired(jwt));
        end

        function tokenOutsideSkewWindowReportsNotExpired(testCase)
            % 5 minutes of validity left, well outside the default skew.
            jwt = makeJwt(struct('exp', posixNowOffset(300)));
            testCase.verifyFalse(ndi.cloud.internal.isTokenExpired(jwt));
        end

        function customSkewIsRespected(testCase)
            % 90 s of validity left: expired with skew=120, not with skew=30.
            jwt = makeJwt(struct('exp', posixNowOffset(90)));
            testCase.verifyTrue(ndi.cloud.internal.isTokenExpired(jwt, 'SkewSeconds', 120));
            testCase.verifyFalse(ndi.cloud.internal.isTokenExpired(jwt, 'SkewSeconds', 30));
        end

        function opaqueTokenIsNotReportedExpired(testCase)
            % Not a JWT at all -- decoder will throw; defer to server.
            testCase.verifyFalse(ndi.cloud.internal.isTokenExpired('not-a-jwt'));
        end

        function jwtWithoutExpClaimIsNotReportedExpired(testCase)
            jwt = makeJwt(struct('email', 'someone@example.com'));
            testCase.verifyFalse(ndi.cloud.internal.isTokenExpired(jwt));
        end
    end
end

function jwt = makeJwt(payloadStruct)
    headerJson = '{"alg":"none","typ":"JWT"}';
    payloadJson = jsonencode(payloadStruct);
    jwt = [b64UrlEncode(headerJson) '.' b64UrlEncode(payloadJson) '.sig'];
end

function s = b64UrlEncode(str)
    bytes = typecast(unicode2native(str, 'UTF-8'), 'int8');
    enc = java.util.Base64.getEncoder();
    s = char(enc.encodeToString(bytes));
    s = strrep(s, '+', '-');
    s = strrep(s, '/', '_');
    s = regexprep(s, '=+$', '');
end

function p = posixNowOffset(deltaSeconds)
    p = posixtime(datetime('now', 'TimeZone', 'UTC')) + deltaSeconds;
end
