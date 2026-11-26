classdef TestReaderTimeChannels < matlab.unittest.TestCase
    % TESTREADERTIMECHANNELS - every time_channel a reader lists names a listed time channel
    %
    % A channel's time_channel is the number of the time channel `t<n>`
    % that times its samples; NaN means it has none. ingest_epochfiles
    % copies each reader's GETCHANNELSEPOCH rows into the epoch's
    % `channel_list.bin` unchanged (ndi.file.type.mfdaq_epoch_channel/
    % create_properties). VH-Lab/NDI-matlab#1249 found two readers naming
    % time channels their lists never hold:
    %
    %   item 2  ndi.daq.reader.mfdaq.intan gave auxiliary inputs
    %           time_channel 2; the list holds only t1.
    %   item 3  ndi.daq.reader.mfdaq.cedspike2 gave every channel its own
    %           Spike2 number, but lists t<n> only for analog inputs, so
    %           event, marker and text channels named missing channels.
    %
    % Each reader is run on a real file: Intan on the example file NDI
    % ships (ndi_common/example_sessions/exp1_eg_saved/
    % Intan_160317_125049_short.rhd, the file
    % TestReadTimeseriesEquivalence ingests), Spike2 on NDR's example.smr
    % (NDR-matlab example_data, as mfdaqIntanTest finds NDR's example
    % files). Each test also states its denominator, keeps the pointers
    % that were right (the control), and shows that the check flags the
    % list the old code wrote (a check that cannot fail proves nothing).
    %
    % Filtered (never passed) when a fixture file or its header reader is
    % not on the path.

    methods (Test)

        function testIntanAuxiliaryInputsNameNoMissingTimeChannel(testCase)
            filename = fullfile(ndi.common.PathConstants.ExampleDataFolder, ...
                'exp1_eg_saved', 'Intan_160317_125049_short.rhd');
            testCase.assumeTrue(isfile(filename), ['no Intan example file at ' filename]);
            testCase.assumeFalse(isempty(which('read_Intan_RHD2000_header')), ...
                'read_Intan_RHD2000_header is not on the path');
            reader = ndi.daq.reader.mfdaq.intan();
            epochfiles = {filename};
            ch = reader.getchannelsepoch(epochfiles);

            % the denominator: the file's 32 amplifier, 3 auxiliary and 1
            % digital input channels, and its one time channel
            types = {ch.type};
            testCase.verifyEqual(nnz(strcmp(types, 'analog_in')), 32);
            testCase.verifyEqual(nnz(strcmp(types, 'auxiliary_in')), 3);
            testCase.verifyEqual(nnz(strcmp(types, 'digital_in')), 1);
            testCase.verifyEqual({ch(strcmp(types, 'time')).name}, {'t1'});

            testCase.verifyEmpty(danglingTimeChannels(ch), ...
                'a channel names a time channel the list does not hold');
            ax = ch(strcmp(types, 'auxiliary_in'));
            testCase.verifyTrue(all(isnan([ax.time_channel])), ...
                'the auxiliary inputs are not sampled with t1, so they name no time channel');

            % the control: the analog and digital inputs still name t1,
            % and they are sampled at t1's rate, so the time row a
            % migration rebuilds from them ([time channel row is notation])
            % has t1's rate
            named = ch(strcmp(types, 'analog_in') | strcmp(types, 'digital_in'));
            testCase.verifyEqual(unique([named.time_channel]), 1);
            tRate = reader.samplerate(epochfiles, 'time', 1);
            for i = 1:numel(named)
                [~, n] = ndi.fun.channelname2prefixnumber(named(i).name);
                testCase.verifyEqual(reader.samplerate(epochfiles, named(i).type, n), tRate, ...
                    [named(i).name ' is not sampled at t1''s rate']);
            end
            [~, n] = ndi.fun.channelname2prefixnumber(ax(1).name);
            testCase.verifyLessThan(reader.samplerate(epochfiles, 'auxiliary_in', n), tRate, ...
                'the auxiliary inputs are sampled more slowly than t1');

            % the list the old code wrote fails the check
            old = ch;
            [old(strcmp(types, 'auxiliary_in')).time_channel] = deal(2);
            testCase.verifyEqual(sort(danglingTimeChannels(old)), sort({ax.name}));

            % and the rows reach the channel list unchanged
            info = ndi.file.type.mfdaq_epoch_channel(withIngestFields(ch)).channel_information;
            infoAx = info(strcmp({info.type}, 'auxiliary_in'));
            testCase.verifyNumElements(infoAx, 3);
            testCase.verifyTrue(all(isnan([infoAx.time_channel])));
            testCase.verifyEmpty(danglingTimeChannels(info));
        end

        function testSpike2EventMarkerTextChannelsNameNoMissingTimeChannel(testCase)
            testCase.assumeFalse(isempty(which('ndr.fun.ndrpath')), 'NDR-matlab is not on the path');
            filename = fullfile(ndr.fun.ndrpath, 'example_data', 'example.smr');
            testCase.assumeTrue(isfile(filename), ['no Spike2 example file at ' filename]);
            reader = ndi.daq.reader.mfdaq.cedspike2();
            ch = reader.getchannelsepoch({filename});

            % the denominator: example.smr holds Spike2 channels 1 and 21
            % (waveforms), 22-29 (events), 20, 31 and 32 (markers) and 30
            % (text)
            types = {ch.type};
            isEmt = ismember(types, {'event', 'marker', 'text'});
            testCase.verifyEqual(sort({ch(strcmp(types, 'analog_in')).name}), {'ai1', 'ai21'});
            testCase.verifyEqual(sort({ch(strcmp(types, 'time')).name}), {'t1', 't21'});
            testCase.verifyEqual(nnz(isEmt), 12);
            testCase.verifyEqual(nnz(strcmp(types, 'text')), 1);

            testCase.verifyEmpty(danglingTimeChannels(ch), ...
                'a channel names a time channel the list does not hold');
            testCase.verifyTrue(all(isnan([ch(isEmt).time_channel])), ...
                'event, marker and text channels have no time channel');

            % the control: each analog input still names its own time
            % channel, and each time channel itself
            for i = find(ismember(types, {'analog_in', 'time'}))
                [~, n] = ndi.fun.channelname2prefixnumber(ch(i).name);
                testCase.verifyEqual(double(ch(i).time_channel), double(n), ch(i).name);
            end

            % the list the old code wrote fails the check
            old = ch;
            for i = find(isEmt)
                [~, n] = ndi.fun.channelname2prefixnumber(old(i).name);
                old(i).time_channel = n;
            end
            testCase.verifyEqual(sort(danglingTimeChannels(old)), sort({ch(isEmt).name}));
        end

    end
end

function names = danglingTimeChannels(ch)
    % the names of the channels whose time_channel is a number that names
    % no time channel `t<n>` in CH (NaN names none, so never dangles)
    isTime = strcmp({ch.type}, 'time');
    timeNumbers = [];
    for i = find(isTime)
        [~, n] = ndi.fun.channelname2prefixnumber(ch(i).name);
        timeNumbers(end+1) = n; %#ok<AGROW>
    end
    names = {};
    for i = 1:numel(ch)
        v = double(ch(i).time_channel);
        if isempty(v) || isnan(v); continue; end
        if ~any(timeNumbers == v)
            names{end+1} = ch(i).name; %#ok<AGROW>
        end
    end
end

function ch = withIngestFields(ch)
    % the fields ingest_epochfiles adds before it builds the channel list
    [ch.sample_rate] = deal(NaN);
    [ch.offset] = deal(0);
    [ch.scale] = deal(1);
end
