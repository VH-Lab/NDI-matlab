classdef mfdaqIntanTest < matlab.unittest.TestCase
    methods (Test)
        function testIntanReader(testCase)
            % testIntanReader - Verify reading of Intan RHD files

            % 1. Locate example data
            % Check if ndr package is available
            if isempty(which('ndr.fun.ndrpath'))
                % If ndr is not on path, we cannot run this test.
                return;
            end

            ndr_path = ndr.fun.ndrpath;
            example_data_path = fullfile(ndr_path, 'example_data');

            if ~isfolder(example_data_path)
                return; % Skip if no data found
            end

            files = dir(fullfile(example_data_path, '*.rhd'));

            for i = 1:numel(files)
                filename = fullfile(files(i).folder, files(i).name);

                % 2. Create reader
                reader = ndi.daq.reader.mfdaq.intan();

                % 3. Read channels
                epochfiles = {filename};
                channels = reader.getchannelsepoch(epochfiles);

                % Test first analog channel found
                analog_channels = channels(strcmp({channels.type}, 'analog_in'));
                if isempty(analog_channels)
                    continue;
                end

                test_channel = analog_channels(1);
                [~, chan_num] = ndi.fun.channelname2prefixnumber(test_channel.name);

                s0 = 1;
                s1 = 1000;

                % Call reader
                data_read = reader.readchannels_epochsamples(test_channel.type, chan_num, epochfiles, s0, s1);

                % 4. Read using ndr direct function for comparison
                sr = reader.samplerate(epochfiles, test_channel.type, chan_num);
                t0 = (s0-1)/sr;
                t1 = (s1-1)/sr;

                % Intan specific type mapping
                intan_type = 'amp'; % for analog_in

                data_expected = ndr.format.intan.read_Intan_RHD2000_datafile(filename, '', intan_type, chan_num, t0, t1);

                % Verify data equality
                testCase.verifyEqual(data_read, data_expected, 'Data read mismatch between reader and direct NDR call');

                % 5. Test new time conversion methods
                % epochsamples2times
                t_calc = reader.epochsamples2times(test_channel.type, chan_num, epochfiles, s0);
                testCase.verifyEqual(t_calc, t0, 'epochsamples2times mismatch');

                % epochtimes2samples
                s_calc = reader.epochtimes2samples(test_channel.type, chan_num, epochfiles, t_calc);
                testCase.verifyEqual(s_calc, s0, 'epochtimes2samples mismatch');

                % Test vectorization
                s_vec = [s0, s1];
                t_vec = reader.epochsamples2times(test_channel.type, chan_num, epochfiles, s_vec);
                testCase.verifyEqual(t_vec, [t0, t1], 'Vectorized epochsamples2times mismatch');

                s_vec_back = reader.epochtimes2samples(test_channel.type, chan_num, epochfiles, t_vec);
                testCase.verifyEqual(s_vec_back, s_vec, 'Vectorized epochtimes2samples mismatch');

            end
        end
    end
end
