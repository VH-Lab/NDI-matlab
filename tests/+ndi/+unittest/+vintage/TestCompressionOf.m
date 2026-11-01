classdef TestCompressionOf < matlab.unittest.TestCase
%TESTCOMPRESSIONOF ndi.v2.compressionOf reads a body's `compression` in both
%   shapes: the codec name (char), and the {term, parameters} block.
%
%   [compression block and empty levels] (1) (Decided by Jess Haley,
%   2026-10-26, did-schema V_eta_go_forward_class_audit.md; did-schema issue
%   #137): `data_body.compression` becomes a {term, parameters} block, the
%   shape `method` uses -- the codec as a term, its settings as parameters.
%   NDI's readers (ndi.v2.readBody, ndi.vintage.lightsheetLevel) read it
%   through ndi.v2.compressionOf before did-schema declares it (siblings
%   first). The values are written by hand, as a stored document holds them:
%   no schema, session or database is needed.
%
%   UNVERIFIED: written without MATLAB (none in the authoring environment);
%   CI is the first place these run. The local-reading cases were run on a
%   standalone copy of compressionOf.m under Octave before they were added.

    methods (Test)
        function testACodecNameIsReadAsItIs(testCase)
            [c, s] = ndi.v2.compressionOf('gzip');
            testCase.verifyEqual(c, 'gzip');
            testCase.verifyEmpty(fieldnames(s));
            [c, s] = ndi.v2.compressionOf('blosc');
            testCase.verifyEqual(c, 'blosc');
            testCase.verifyEmpty(fieldnames(s));
            testCase.verifyEqual(ndi.v2.compressionOf(''), '');
            testCase.verifyEqual(ndi.v2.compressionOf([]), '');
        end

        function testABlockIsReadAsItsCodecAndSettings(testCase)
            [c, s] = ndi.v2.compressionOf(bloscBlock());
            testCase.verifyEqual(c, 'blosc-zstd', ...
                'Blosc with inner compressor zstd is v1''s blosc-zstd');
            testCase.verifyEqual(fieldnames(s)', {'cname', 'clevel', 'shuffle', 'blocksize'});
            testCase.verifyEqual(jsonencode(s), ...
                '{"cname":"zstd","clevel":5,"shuffle":1,"blocksize":0}', ...
                'the settings read back as makePyramid.m codecParamsJSON writes them');
            [c, s] = ndi.v2.compressionOf(struct('term', struct('node', '', 'name', 'gzip')));
            testCase.verifyEqual(c, 'gzip');
            testCase.verifyEmpty(fieldnames(s));
        end

        function testAnUnknownCodecTermIsReadByItsName(testCase)
            c = ndi.v2.compressionOf(struct('term', struct('node', '', 'name', 'bzip2')));
            testCase.verifyEqual(c, 'bzip2');
        end

        % The local reading: what NDI reads with a DID-matlab that predates
        % did2.build.compressionCodec. V2 CI always has it on the path, so
        % these tests take DID-matlab's +did2 off the path for the test only.

        function testLocalReadingOfACodecName(testCase)
            withoutDid2(testCase);
            [c, s] = ndi.v2.compressionOf('gzip');
            testCase.verifyEqual(c, 'gzip');
            testCase.verifyEmpty(fieldnames(s));
            testCase.verifyEqual(ndi.v2.compressionOf(""), '');
            testCase.verifyEqual(ndi.v2.compressionOf(' lzw '), 'lzw');
        end

        function testLocalReadingOfTheApprovedNames(testCase)
            % [compression term definitions approved] (Jess Haley,
            % 2026-11-01): the settings by their approved labels, the codec
            % and the inner compressor as registered terms
            withoutDid2(testCase);
            [c, s] = ndi.v2.compressionOf(approvedBlock());
            testCase.verifyEqual(c, 'blosc-zstd');
            testCase.verifyEqual(jsonencode(s), ...
                '{"cname":"zstd","clevel":5,"shuffle":1,"blocksize":0}');
        end

        function testLocalReadingOfTheNamesWrittenBefore(testCase)
            withoutDid2(testCase);
            [c, s] = ndi.v2.compressionOf(bloscBlock());
            testCase.verifyEqual(c, 'blosc-zstd');
            testCase.verifyEqual(jsonencode(s), ...
                '{"cname":"zstd","clevel":5,"shuffle":1,"blocksize":0}');
        end

        function testLocalReadingOfARegisteredCodecTerm(testCase)
            % [compression terms registered]: the registry's name differs
            % from the spelling, so the node says which codec it is
            withoutDid2(testCase);
            testCase.verifyEqual(ndi.v2.compressionOf(struct('term', ...
                struct('node', 'EDAM:format_3989', 'name', 'GZIP format'))), 'gzip');
            testCase.verifyEqual(ndi.v2.compressionOf( ...
                struct('node', 'wikidata:Q2681', 'name', 'Lempel-Ziv-Welch')), 'lzw');
        end

        function testLocalReadingOfAnUnknownCodec(testCase)
            withoutDid2(testCase);
            testCase.verifyEqual(ndi.v2.compressionOf(struct('term', ...
                struct('node', '', 'name', 'bzip2'))), 'bzip2');
            testCase.verifyEqual(ndi.v2.compressionOf(struct('term', ...
                struct('node', 'EX:1', 'name', ''))), 'EX:1');
            [c, s] = ndi.v2.compressionOf(struct('term', struct('node', '', 'name', 'Blosc'), ...
                'parameters', {{struct('variable', 'inner compressor', 'text', 'lz4')}}));
            testCase.verifyEqual(c, 'blosc-lz4');
            testCase.verifyEqual(s.cname, 'lz4');
            testCase.verifyError(@() ndi.v2.compressionOf(42), 'ndi:v2:compressionOf:badValue');
        end
    end
end

function withoutDid2(testCase)
% Take DID-matlab's +did2 off the path for this test; the whole path is
% restored when the test ends.
saved = path;
testCase.addTeardown(@() path(saved));
p = which('did2.build.compressionCodec');
while ~isempty(p)
    k = strfind(p, [filesep '+did2' filesep]);
    if isempty(k), break; end
    rmpath(p(1:k(1)-1));
    before = p;
    p = which('did2.build.compressionCodec');
    if strcmp(p, before), break; end
end
testCase.assertEmpty(which('did2.build.compressionCodec'), ...
    'did2.build.compressionCodec is still on the path; the local reading is not reached');
end

function b = approvedBlock()
b = struct('term', struct('node', 'EMPTY:0000426', 'name', 'Blosc'), 'parameters', {{ ...
    struct('variable', struct('node', 'EMPTY:0000430', 'name', 'inner compressor'), ...
        'term', struct('node', 'wikidata:Q26737171', 'name', 'Zstandard')), ...
    struct('variable', struct('node', 'EMPTY:0000427', 'name', 'compression level'), 'count', 5), ...
    struct('variable', struct('node', 'EMPTY:0000429', 'name', 'shuffle filter'), 'count', 1), ...
    struct('variable', struct('node', 'EMPTY:0000428', 'name', 'compression block size'), 'count', 0)}});
end

function b = bloscBlock()
b = struct('term', struct('node', '', 'name', 'Blosc'), 'parameters', {{ ...
    struct('variable', struct('node', '', 'name', 'inner compressor'), 'text', 'zstd'), ...
    struct('variable', struct('node', '', 'name', 'compression level'), 'count', 5), ...
    struct('variable', struct('node', '', 'name', 'shuffle'), 'count', 1), ...
    struct('variable', struct('node', '', 'name', 'block size'), 'count', 0)}});
end
