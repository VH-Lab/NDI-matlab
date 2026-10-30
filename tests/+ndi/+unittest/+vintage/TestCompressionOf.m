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
%   CI is the first place these run.

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
    end
end

function b = bloscBlock()
b = struct('term', struct('node', '', 'name', 'Blosc'), 'parameters', {{ ...
    struct('variable', struct('node', '', 'name', 'inner compressor'), 'text', 'zstd'), ...
    struct('variable', struct('node', '', 'name', 'compression level'), 'count', 5), ...
    struct('variable', struct('node', '', 'name', 'shuffle'), 'count', 1), ...
    struct('variable', struct('node', '', 'name', 'block size'), 'count', 0)}});
end
