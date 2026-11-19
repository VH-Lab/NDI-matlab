classdef TestMfdaqEpochChannelDataclass < matlab.unittest.TestCase
    % TESTMFDAQEPOCHCHANNELDATACLASS - every channel type gets its dataclass
    %
    % ndi.file.type.mfdaq_epoch_channel/create_properties names each
    % channel's dataclass by evaluating <type>_dataclass. It set
    % digital_in_dataclass twice and never digital_out_dataclass, so a
    % channel list holding a digital_out channel failed with an undefined
    % variable (NDI-matlab #1249, item 1).

    methods (Test)

        function testDigitalOutChannelsAreDigital(testCase)
            ch = [ ...
                channelRow('ai1', 'analog_in', 1), ...
                channelRow('di1', 'digital_in', 1), ...
                channelRow('do1', 'digital_out', 1), ...
                channelRow('do2', 'digital_out', 1), ...
                channelRow('t1', 'time', NaN)];
            info = ndi.file.type.mfdaq_epoch_channel(ch).channel_information;

            testCase.verifyNumElements(info, numel(ch));
            want = struct('ai1','ephys', 'di1','digital', 'do1','digital', ...
                'do2','digital', 't1','time');
            for i=1:numel(info)
                testCase.verifyEqual(info(i).dataclass, want.(info(i).name), ...
                    ['dataclass of ' info(i).name]);
            end
            isOut = strcmp({info.type}, 'digital_out');
            testCase.verifyEqual(sort({info(isOut).name}), {'do1','do2'});
            testCase.verifyEqual([info(isOut).number], [1 2]);
            testCase.verifyEqual([info(isOut).group], [1 1]);
        end

        function testDigitalOutDataclassCanBeGiven(testCase)
            ch = channelRow('do1', 'digital_out', 1);
            obj = ndi.file.type.mfdaq_epoch_channel();
            obj = obj.create_properties(ch, 'digital_out_dataclass', 'custom');
            testCase.verifyEqual(obj.channel_information(1).dataclass, 'custom');
        end

    end
end

function row = channelRow(name, type, time_channel)
    row = struct('name', name, 'type', type, 'time_channel', time_channel, ...
        'sample_rate', 20000, 'offset', 0, 'scale', 1);
end
