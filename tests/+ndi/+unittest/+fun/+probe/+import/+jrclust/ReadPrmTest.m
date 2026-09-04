classdef ReadPrmTest < matlab.unittest.TestCase
    % READPRMTEST - Tests for ndi.fun.probe.import.jrclust.readprm.
    %
    % These run headless and do not need JRCLUST: they write small JRCLUST
    % parameter files and check that NDI reads them the way JRCLUST does.

    properties
        WorkDir string = ""
    end

    methods (TestMethodSetup)
        function makeWorkDir(testCase)
            testCase.WorkDir = string(tempname);
            mkdir(testCase.WorkDir);
            testCase.addTeardown(@() rmdir(testCase.WorkDir,'s'));
        end
    end

    methods (Access = private)
        function f = writePrm(testCase, lines)
            f = fullfile(char(testCase.WorkDir),'jrclust.prm');
            fid = fopen(f,'w');
            fprintf(fid,'%s\n',lines{:});
            fclose(fid);
        end
    end

    methods (Test)
        function testReadsNdiParameters(testCase)
            f = testCase.writePrm({ ...
                '% JRCLUST parameters', ...
                'recordingFormat = ''ndi''; % the NDI reader', ...
                'sampleRate = 30000; % Hz', ...
                'nChans = 4;', ...
                'rawRecordings = {''t00001'', ''t00002''};', ...
                'evtWindow = [-0.25, 0.75];', ...
                '% USER-DEFINED PARAMETERS', ...
                'ndiPath = ''/data/2024-01-01'';', ...
                'ndiElementName = ''ctx'';', ...
                'ndiElementReference = 1;'});

            P = ndi.fun.probe.import.jrclust.readprm(f);

            testCase.verifyEqual(P.recordingFormat,'ndi');
            testCase.verifyEqual(P.sampleRate,30000);
            testCase.verifyEqual(P.nChans,4);
            testCase.verifyEqual(P.rawRecordings,{'t00001','t00002'});
            testCase.verifyEqual(P.ndiElementName,'ctx');
            testCase.verifyEqual(P.ndiElementReference,1);
            testCase.verifyEqual(P.sessionName,'jrclust');
            testCase.verifyEqual(P.resFile, ...
                fullfile(char(testCase.WorkDir),'jrclust_res.mat'));
            % JRCLUST computes evtWindowSamp as round(evtWindow*sampleRate/1000)
            testCase.verifyEqual(P.evtWindowSamp, round([-0.25 0.75]*30000/1000));
        end

        function testIntermediateVariablesAreEvaluated(testCase)
            % .prm files are MATLAB scripts: the documented way to build a site map
            % uses intermediate variables, which must be evaluated, not just parsed.
            f = testCase.writePrm({ ...
                'sampleRate = 25000;', ...
                'nChans = 4;', ...
                'rawRecordings = {''t00001''};', ...
                'depths = 0:50:150;', ...
                'siteLoc = [zeros(4,1) depths(:)];', ...
                'siteMap = [3 4 1 2];'});

            P = ndi.fun.probe.import.jrclust.readprm(f);

            testCase.verifyEqual(size(P.params.siteLoc),[4 2]);
            testCase.verifyEqual(P.params.siteLoc(:,2)',[0 50 100 150]);
            testCase.verifyEqual(P.params.siteMap,[3 4 1 2]);
        end

        function testDefaultEventWindow(testCase)
            % A file that does not set evtWindow gets JRCLUST's default of
            % [-0.25 0.75] ms.
            f = testCase.writePrm({ ...
                'sampleRate = 20000;', ...
                'nChans = 2;', ...
                'rawRecordings = {''t00001''};'});

            P = ndi.fun.probe.import.jrclust.readprm(f);

            testCase.verifyEqual(P.evtWindow,[-0.25 0.75]);
            testCase.verifyEqual(P.evtWindowSamp, round([-0.25 0.75]*20000/1000));
        end

        function testRecordingPathsAreReducedToNames(testCase)
            % Directory parts are stripped, and a single (non-cell) entry is
            % returned as a one-element cell array.
            f = testCase.writePrm({ ...
                'sampleRate = 30000;', ...
                'nChans = 1;', ...
                'rawRecordings = ''/data/2024-01-01/t00003'';'});

            P = ndi.fun.probe.import.jrclust.readprm(f);

            testCase.verifyEqual(P.rawRecordings,{'t00003'});
        end

        function testMissingSampleRateErrors(testCase)
            f = testCase.writePrm({'nChans = 4;'});
            testCase.verifyError(@() ndi.fun.probe.import.jrclust.readprm(f), ...
                'ndi:fun:probe:import:jrclust:readprm:noSampleRate');
        end
    end
end
