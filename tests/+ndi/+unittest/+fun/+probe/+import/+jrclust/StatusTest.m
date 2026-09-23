classdef StatusTest < matlab.unittest.TestCase
    % STATUSTEST - Tests for ndi.fun.probe.import.jrclust.paths and .status.
    %
    % These run headless and do not need JRCLUST: they build the files each
    % pipeline step produces and check that the reported state follows.

    properties
        WorkDir string = ""
        S
        P
    end

    methods (TestMethodSetup)
        function makeSession(testCase)
            testCase.WorkDir = string(tempname);
            mkdir(testCase.WorkDir);
            testCase.addTeardown(@() rmdir(testCase.WorkDir,'s'));
            testCase.S = ndi.unittest.fun.probe.import.jrclust.MockSession(char(testCase.WorkDir));
            testCase.P = ndi.unittest.fun.probe.import.jrclust.MockProbe();
        end
    end

    methods (Access = private)
        function st = statusNow(testCase)
            st = ndi.fun.probe.import.jrclust.status(testCase.S, testCase.P, ...
                'checkDatabase', false);
        end
    end

    methods (Test)
        function testPathsFollowJRCLUSTLayout(testCase)
            p = ndi.fun.probe.import.jrclust.paths(testCase.S, testCase.P);

            % spaces in the element string become underscores, as in JRCLUST's
            % own jrc('bootstrap','ndi',...)
            testCase.verifyEqual(p.elementString,'mockctx_|_1');
            testCase.verifyEqual(p.directory, ...
                fullfile(char(testCase.WorkDir),'.JRCLUST','mockctx_|_1'));
            testCase.verifyEqual(p.prmFile, fullfile(p.directory,'jrclust.prm'));
            testCase.verifyEqual(p.resFile, fullfile(p.directory,'jrclust_res.mat'));
            % JRCLUST's intermediate files, named from the same session name
            testCase.verifyEqual(p.rawFile, fullfile(p.directory,'jrclust_raw.jrc'));
            testCase.verifyEqual(p.filtFile, fullfile(p.directory,'jrclust_filt.jrc'));
            testCase.verifyEqual(p.featuresFile, ...
                fullfile(p.directory,'jrclust_features.jrc'));
            testCase.verifyEqual(p.histFile, fullfile(p.directory,'jrclust_hist.jrc'));
        end

        function testFeatureFileIsReportedSeparately(testCase)
            % 'jrc sort' reads the features detection wrote; a probe whose
            % intermediate files were cleaned up is detected but not sortable
            p = ndi.fun.probe.import.jrclust.paths(testCase.S, testCase.P);
            mkdir(p.directory);
            fclose(fopen(p.prmFile,'w'));
            res = struct('spikeTimes',int32([1;2;3]));
            save(p.resFile,'-struct','res');

            st = testCase.statusNow();
            testCase.verifyTrue(st.detected);
            testCase.verifyFalse(st.features);

            fclose(fopen(p.featuresFile,'w'));
            st = testCase.statusNow();
            testCase.verifyTrue(st.features);
        end

        function testStatusFollowsThePipeline(testCase)
            p = ndi.fun.probe.import.jrclust.paths(testCase.S, testCase.P);

            % nothing done yet
            st = testCase.statusNow();
            testCase.verifyFalse(st.bootstrapped);
            testCase.verifyFalse(st.detected);
            testCase.verifyFalse(st.sorted);
            testCase.verifyFalse(st.curated);

            % the parameter file has been written
            mkdir(p.directory);
            fclose(fopen(p.prmFile,'w'));
            st = testCase.statusNow();
            testCase.verifyTrue(st.bootstrapped);
            testCase.verifyFalse(st.detected);

            % spikes detected
            res = struct('spikeTimes',int32([1;2;3]));
            save(p.resFile,'-struct','res');
            st = testCase.statusNow();
            testCase.verifyTrue(st.detected);
            testCase.verifyFalse(st.sorted);

            % spikes sorted. JRCLUST's sort step commits the clustering, which
            % creates an empty note for every unit - so clusterNotes exists here
            % without anybody having curated anything.
            res.spikeClusters = int32([1;1;2]);
            res.spikesByCluster = {[1;2], 3};
            res.clusterNotes = cell(2,1);
            res.sortedOn = 738000;
            save(p.resFile,'-struct','res');
            st = testCase.statusNow();
            testCase.verifyTrue(st.sorted);
            testCase.verifyFalse(st.curated);
            testCase.verifyFalse(st.annotated);

            % saved from the curator, but still nothing labelled
            res.curatedOn = 738001;
            save(p.resFile,'-struct','res');
            st = testCase.statusNow();
            testCase.verifyTrue(st.curated);
            testCase.verifyFalse(st.annotated);

            % units annotated in the curator
            res.clusterNotes = {'single','multi'};
            save(p.resFile,'-struct','res');
            st = testCase.statusNow();
            testCase.verifyTrue(st.curated);
            testCase.verifyTrue(st.annotated);
        end

        function testDatabaseIsNotConsultedWhenSwitchedOff(testCase)
            st = testCase.statusNow();
            testCase.verifyFalse(st.imported);
            testCase.verifyEmpty(st.upToDate);
            testCase.verifyEqual(st.checksum,'');
        end
    end
end
