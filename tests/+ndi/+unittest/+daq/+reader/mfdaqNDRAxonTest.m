classdef mfdaqNDRAxonTest < matlab.unittest.TestCase
    methods (Test)
        function testNDRAxonReader(testCase)
            % testNDRAxonReader - Verify reading of Axon ABF files using NDR reader

            if isempty(which('ndr.fun.ndrpath'))
                return;
            end

            ndr_path = ndr.fun.ndrpath;
            example_data_path = fullfile(ndr_path, 'example_data');

            if ~isfolder(example_data_path)
                return;
            end

            files = dir(fullfile(example_data_path, '*.abf'));

            for i = 1:numel(files)
                filename = fullfile(files(i).folder, files(i).name);

                % Create NDR reader
                reader = ndi.daq.reader.mfdaq.ndr('axon');

                epochfiles = {filename};
                channels = reader.getchannelsepoch(epochfiles);

                analog_channels = channels(strcmp({channels.type}, 'analog_in'));
                if isempty(analog_channels)
                    continue;
                end

                test_channel = analog_channels(1);
                [~, chan_num] = ndi.fun.channelname2prefixnumber(test_channel.name);

                s0 = 1;
                s1 = 1000;

                % Test reading samples
                data_read = reader.readchannels_epochsamples(test_channel.type, chan_num, epochfiles, s0, s1);

                testCase.verifyNotEmpty(data_read, 'Data read should not be empty');
                testCase.verifySize(data_read, [1000 1], 'Data read size mismatch');

                % Test time conversion consistency
                t_calc = reader.epochsamples2times(test_channel.type, chan_num, epochfiles, s0);
                s_calc = reader.epochtimes2samples(test_channel.type, chan_num, epochfiles, t_calc);

                testCase.verifyEqual(s_calc, s0, 'AbsTol', 1e-10, 'Time conversion consistency failed');

                % Vectorized check
                s_vec = [1, 1000];
                t_vec = reader.epochsamples2times(test_channel.type, chan_num, epochfiles, s_vec);
                s_vec_back = reader.epochtimes2samples(test_channel.type, chan_num, epochfiles, t_vec);
                testCase.verifyEqual(s_vec_back, s_vec, 'AbsTol', 1e-10, 'Vectorized conversion failed');
            end
        end
    end
end
