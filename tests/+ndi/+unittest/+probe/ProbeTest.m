classdef ProbeTest < ndi.unittest.session.buildSession
    methods (Test)
        function testProbe(testCase)
             probes = testCase.Session.getprobes();

             % Check if probes are found
             testCase.verifyNotEmpty(probes);

             if ~isempty(probes)
                 % sr = probes{1}.samplerate(1);
                 % It seems samplerate takes 2 arguments: epoch and index?
                 % Based on build_intan_flat_exp: sr_d = samplerate(dev1,1,{'digital_in'},1);
                 % But here we are calling it on a probe, not a daqsystem.
                 % The user instruction said:
                 % probes = S.getprobes();
                 % sr = probes{1}.samplerate(1);
                 % [data,time] = probes{1}.read_epochsamples(1,0,10);

                 sr = probes{1}.samplerate(1);
                 testCase.verifyGreaterThan(sr, 0);

                 [data,time] = probes{1}.read_epochsamples(1,0,10);
                 testCase.verifyNotEmpty(data);
                 testCase.verifyNotEmpty(time);
             end
        end
    end
end
