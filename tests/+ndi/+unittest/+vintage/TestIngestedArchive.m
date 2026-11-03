classdef TestIngestedArchive < matlab.unittest.TestCase
%TESTINGESTEDARCHIVE The pieces of the v2 ingested read that need no database.
%
%   ndi.vintage.ingestedSegmentLength and ndi.vintage.ingestedArchiveFile
%   read an archive described by ndi.vintage.ingestedArchive. The whole read,
%   on a migrated session, is TestReadTimeseriesEquivalence
%   (testIngestedChannelsAndSamplesAreTheSame); these pin the rules that
%   decide which v1 segment file a sample is in:
%
%     a sampled_body's time `chunk` is the segment length ([segment length
%       is the time chunk], Jess Haley, 2026-10-29);
%     a body of one member holds the whole epoch;
%     a series with no body (an evenly spaced time channel, [evenly spaced
%       time is a covariate]) is one segment of the epoch's length;
%     a file whose series has no body is an error that names the file.

    methods (Test)

        function testChunkIsTheSegmentLength(testCase)
            A = testCase.archive(struct('series', 'ai_group1_seg.nbf_#', ...
                'kind', 'sampled_body', 'n', 60000, 'chunk', 1e6, 'members', 1));
            testCase.verifyEqual(ndi.vintage.ingestedSegmentLength([], A, ...
                'ai_group1_seg.nbf_#', 60000), 1e6);
        end

        function testOneMemberWithoutChunkIsTheWholeEpoch(testCase)
            A = testCase.archive(struct('series', 'di_group1_seg.nbf_#', ...
                'kind', 'opaque_body', 'n', [], 'chunk', [], 'members', 1));
            testCase.verifyEqual(ndi.vintage.ingestedSegmentLength([], A, ...
                'di_group1_seg.nbf_#', 1234), 1234);
        end

        function testNoBodyIsOneSegment(testCase)
            A = testCase.archive(struct('series', 'ai_group1_seg.nbf_#', ...
                'kind', 'sampled_body', 'n', 60000, 'chunk', 1e6, 'members', 1));
            testCase.verifyEqual(ndi.vintage.ingestedSegmentLength([], A, ...
                'ti_group1_seg.nbf_#', 60000), 60000);
        end

        function testAFileWithNoBodyIsAnError(testCase)
            A = testCase.archive(struct('series', 'ai_group1_seg.nbf_#', ...
                'kind', 'sampled_body', 'n', 60000, 'chunk', 1e6, 'members', 1));
            testCase.verifyError(@() ndi.vintage.ingestedArchiveFile([], A, ...
                'ti_group1_seg.nbf_1', '.nbf.tgz'), 'NDI:daq:reader:ingestedFileNotFound');
            testCase.verifyError(@() ndi.vintage.ingestedArchiveFile([], A, ...
                'evmktx_group1_seg.nbf_1', '.nbf.tgz'), 'NDI:daq:reader:ingestedFileNotFound');
        end

        function testAV1SessionIsNotAV2Database(testCase)
            % a session-like object whose database is not did2sqlite
            S = struct('database', []);
            testCase.verifyFalse(ndi.daq.reader.isv2database(S));
        end

    end

    methods (Static, Access = private)

        function A = archive(varargin)
            bodies = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for k = 1:numel(varargin)
                b = varargin{k};
                bodies(b.series) = struct('doc', [], 'kind', b.kind, 'n', b.n, ...
                    'chunk', b.chunk, 'members', b.members);
            end
            A = struct('vintage', 'v2', 'epoch_id', 'epoch_test', 'bodies', bodies, ...
                'channels', [], 'epochclock', {{}}, 't0_t1', {{}}, 'clock_problem', '');
        end

    end
end
