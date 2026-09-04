classdef TestRayoLabStims < matlab.unittest.TestCase
    % TESTRAYOLABSTIMS - Unit tests for ndi.daq.metadatareader.RayoLabStims

    methods (Test)
        function testReadMetadataReturnsConstant(testCase)
            % RayoLabStims describes a single stimulus (stimid == 1) and
            % does not read per-stimulus content from disk, so readmetadata
            % must return {struct('stimid',1)} regardless of the epochfiles.
            mdr = ndi.daq.metadatareader.RayoLabStims();
            params = mdr.readmetadata({'anything.rhd'});
            testCase.verifyClass(params, 'cell');
            testCase.verifyEqual(numel(params), 1);
            testCase.verifyEqual(params{1}, struct('stimid', 1));
        end

        function testReadMetadataDoesNotRequireMatchingFile(testCase)
            % Regression test: even when constructed with a
            % tab_separated_file_parameter regular expression that matches
            % none of the epochfiles, readmetadata must still return the
            % constant parameter set rather than erroring with
            % "No epochfiles match regular expression ...". This reproduces
            % the RayoLab ingest failure caused by the file-navigator '#'
            % wildcard being stored as a raw regexp for the metadata reader.
            mdr = ndi.daq.metadatareader.RayoLabStims('#_\d{6}_\d{6}\._epochprobemap\.txt\>');
            epochfiles = { ...
                '/data/EST_VISUAL_PREDROGA_251121_201438.rhd', ...
                '/data/EST_VISUAL_PREDROGA_251121_201438._epochprobemap.txt'};
            params = mdr.readmetadata(epochfiles);
            testCase.verifyEqual(numel(params), 1);
            testCase.verifyEqual(params{1}, struct('stimid', 1));
        end

        function testReadMetadataFromFileIgnoresFile(testCase)
            % readmetadatafromfile ignores its file argument and returns the
            % constant parameter set.
            mdr = ndi.daq.metadatareader.RayoLabStims();
            params = mdr.readmetadatafromfile([]);
            testCase.verifyEqual(params, {struct('stimid', 1)});
        end
    end
end
