% NSD_IODEVICE_MFDAQ_SG - Device driver for SpikeGadgets .rec video file format
%
% This class reads data from video files .rec that spikegadgets use
%
% Spike Gadgets: http://spikegadgets.com/
%
%

classdef nsd_iodevice_mfdaq_sg < nsd_device_mfdaq
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here

    properties
    end

    methods
        function obj = nsd_iodevice_mfdaq_sg(varargin)
            % NSD_IODEVICE_MFDAQ_SG - Create a new NSD_DEVICE_MFDAQ_SG object
            %
            %  D = NSD_IODEVICE_MFDAQ_SG(NAME,THEFILETREE)
            %
            %  Creates a new NSD_IODEVICE_MFDAQ_SG object with name NAME and associated
            %  filetree THEFILETREE.
            %
            %

			obj = obj@nsd_iodevice_mfdaq(varargin{:});

        end

        function channels = getchannels(self)
            %Calculate number of epochs in filetree
            N = numepochs(self.filetree);

            fileconfig = [];

            for n=1:N
                filelist = getepochfiles(self.filetree, n);

                filename = filelist{1};

                [fileconfig, channels] = read_SpikeGadgets_config(filename);

                for k=1:length(channels)
                    number = 0;
                    name = '';

                    %Auxiliary
                    if strcmp(channels(k).name(1),'A')
                        %Input
                        if strcmp(channels(k).name(2),'i')
                            channels(k).type = 'auxiliary';
                            number = sscanf(channels(k).name, 'Ain%d'); %number = channels(k).name(4:end);
                            name = strcat('axn',num2str(number));
                            channels(k).number = number;
                        %Output
                        else
                            channels(k).type = 'auxiliary';
                            number = sscanf(channels(k).name, 'Aout%d'); %number = channels(k).name(5:end);
                            name = strcat('axo',num2str(number));
                            channels(k).number = number;
                        end

                    %Digital
                    elseif strcmp(channels(k).name(1),'D')
                        %Input
                        if strcmp(channels(k).name(2),'i')
                            channels(k).type = 'digital_in';
                            number = sscanf(channels(k).name, 'Din%d'); %number = channels(k).name(4:end);
                            name = strcat('di',num2str(number));
                            channels(k).number = number;
                        %Output
                        else
                            channels(k).type = 'digital_out';
                            number = sscanf(channels(k).name, 'Dout%d'); %number = channels(k).name(5:end);
                            name = strcat('do',num2str(number));
                            channels(k).number = number;
                        end
                    %MCU (digital inputs)
                    else
                        channels(k).type = 'digital_in';
                        number = sscanf(channels(k).name, 'MCU_Din%d'); %str2num(channels(k).name(8:end));
                        number = number + 32; % +32 from previous non MCU inputs
                        name = strcat('di',num2str(number));
                        channels(k).number = number;
                    end

                    channels(k).name = name;
                end
            end
            %Adds all nTrodes to the list
            for i=1:length(fileconfig.nTrodes)
                for j=1:4 %argument for 4 channels, variable could be used later to deal with this in a more general way
                    channelNumber = fileconfig.nTrodes(i).channelInfo(j).packetLocation;
                    channels(end+1).name = strcat('ai',num2str(channelNumber+1));
                    channels(end).type = 'analog_in';
                    channels(end).number = channelNumber+1;
                end
            end

            channels = struct2table(channels);
            channels = sortrows(channels,{'type','number'});
            channels = table2struct(channels);

            remove = {'startbyte','bit','number'};

            channels = rmfield(channels, remove);

        end

        function channels = getchannelsdetailed(self)

            N = numepochs(self.filetree);

            fileconfig = [];

            for n=1:N
                filelist = getepochfiles(self.filetree, n);

                filename = filelist{1};

                [fileconfig, channels] = read_SpikeGadgets_config(filename);

                for k=1:length(channels)
                    number = 0;
                    name = '';
                    %
                    %Auxiliary
                    if strcmp(channels(k).name(1),'A')
                        %Input
                        if strcmp(channels(k).name(2),'i')
                            channels(k).type = 'auxiliary';
                            number = sscanf(channels(k).name, 'Ain%d'); %number = channels(k).name(4:end);
                            name = strcat('axn',num2str(number));
                            channels(k).number = number;
                        %Output
                        else
                            channels(k).type = 'auxiliary';
                            number = sscanf(channels(k).name, 'Aout%d'); %number = channels(k).name(5:end);
                            name = strcat('axo',num2str(number));
                            channels(k).number = number;
                        end

                    %Digital
                    elseif strcmp(channels(k).name(1),'D')
                        %Input
                        if strcmp(channels(k).name(2),'i')
                            channels(k).type = 'digital_in';
                            number = sscanf(channels(k).name, 'Din%d'); %number = channels(k).name(4:end);
                            name = strcat('di',num2str(number));
                            channels(k).number = number;
                        %Output
                        else
                            channels(k).type = 'digital_out';
                            number = sscanf(channels(k).name, 'Dout%d'); %number = channels(k).name(5:end);
                            name = strcat('do',num2str(number));
                            channels(k).number = number;
                        end
                    %MCU (digital inputs)
                    else
                        channels(k).type = 'digital_in';
                        number = sscanf(channels(k).name, 'MCU_Din%d'); %str2num(channels(k).name(8:end));
                        number = number + 32; % +32 from previous non MCU inputs
                        name = strcat('di',num2str(number));
                        channels(k).number = number;
                    end

                    channels(k).name = name;
                end
            end
            %Adds all nTrodes to the list
            for i=1:length(fileconfig.nTrodes)
                for j=1:4
                    channelNumber = fileconfig.nTrodes(i).channelInfo(j).packetLocation;
                    channels(end+1).name = strcat('ai',num2str(channelNumber+1));
                    channels(end).type = 'analog_in';
                    channels(end).number = channelNumber;
                end
            end

            channels = struct2table(channels);
            channels = sortrows(channels,{'type','number'});
            channels = table2struct(channels);
        end



        function sr = samplerate(self, epoch, channeltype, channel)
		% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL
		%
		% SR = SAMPLERATE(DEV, EPOCH, CHANNELTYPE, CHANNEL)
		%
		% SR is the list of sample rate from specified channels
        %
        % CHANNELTYPE and CHANNEL not used in this case since it is the
		% same for all channels in this device

			filename = self.filetree.getepochfiles(epoch);
			filename = filename{1}; % don't know how to handle multiple filenames coming back

			fileconfig = read_SpikeGadgets_config(filename);

            %Sampling rate is the same for all channels in Spike Gadgets
            %device so it is returned by checking the file configuration
            sr = str2num(fileconfig.samplingRate);
        end

        function epochcontents = getepochcontents(self, epoch)
            % GETEPOCHCONTENTS returns struct with probe information
            % name, reference, n-trode, channels
            %

            filename = self.filetree.getepochfiles(epoch);
			filename = filename{1}; %no need to adjust for epoch, channels and tetrodes remain the same
            fileconfig = read_SpikeGadgets_config(filename);
            nTrodes = fileconfig.nTrodes;
            %List where epochcontents objects will be stored
            epochcontents = [];

            for i=1:length(nTrodes)
                name = strcat('Tetrode', nTrodes(i).id);
                reference = 1;
                type = 'n-trode';
                channels = [];

                for j=1:length(nTrodes(i).channelInfo) %number of channels per nTrode
                    %Array with channels of trode
                    channels = [channels nTrodes(i).channelInfo(j).packetLocation + 1];
                end
                %Object that deals with channels
                devicestringobject = nsd_iodevicestring('SpikeGadgets',{'ai','ai','ai','ai'}, channels);
                devicestringstring = devicestringobject.devicestring();
                %
                obj = nsd_epochcontents(name,reference,type,devicestringstring);
                %Append each newly made object to end of list
                epochcontents = [epochcontents obj];
            end

        end

        function data = readchannels_epochsamples(self,channeltype, channels, epoch, s0, s1)
            %  FUNCTION READ_CHANNELS - read the data based on specified channels
            %
            %  DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCH ,S0, S1)
            %
            %  CHANNELTYPE is the type of channel to read
            %  'digital_in', 'digital_out', 'analog_in', 'analog_out' or 'auxiliary'
            %
            %  CHANNEL is a vector of the channel numbers to
            %  read beginning from 1 if 'etrodeftrode' is channeltype,
            %  if channeltype is 'analog_in' channel is an array with the
            %  string names of analog channels 'Ain1'through 8
            %
            %  EPOCH is
            %
            %  DATA is the channel data (each column contains data from an indvidual channel)
            %
            filename = self.filetree.getepochfiles(epoch);
			filename = filename{1}; % don't know how to handle multiple filenames coming back

            header = read_SpikeGadgets_config(filename);

            sr = self.samplerate(epoch);

            detailedchannels = self.getchannelsdetailed();

            byteandbit = [];

            %read_SpikeGadgets_trodeChannels(filename,NumChannels, channels,samplingRate,headerSize, configExists)
            %reading from channel 1 in list returned
            %Reads nTrodes
            %WARNING channeltype hard coded, ask Steve
            if (strcmp(nsd_iodevice_mfdaq.mfdaq_type(channeltype{1}),'analog_in') || strcmp(nsd_device_mfdaq.mfdaq_type(channeltype{1}), 'analog_out'))

                data = read_SpikeGadgets_trodeChannels(filename,header.numChannels,channels-1,sr, header.headerSize,s0,s1);

            %Reads analog inputs
            elseif (strcmp(channeltype,'auxiliary'))
                %for every channel in device
                for i=1:length(detailedchannels)
                    %based on every channel to read
                    for j=1:length(channels)
                        %check if channel number and channeltype match
                        if (strcmp(detailedchannels(i).type,'auxiliary') && detailedchannels(i).number == channels(j))
                            %add startbyte to list of channels to read
                            byteandbit(end+1) = str2num(detailedchannels(i).startbyte);
                        end
                    end
                end
                data = read_SpikeGadgets_analogChannels(filename,header.numChannels,byteandbit,sr,header.headerSize,s0,s1);

            %Reads digital inputs
            elseif (strcmp(channeltype,'digital_in') || strcmp(channeltype, 'digital_out'))
                %for every channel in device
                for i=1:length(detailedchannels)
                    %based on every channel to read
                    for j=1:length(channels)
                        %check if channel number and channeltype match
                        if (strcmp(detailedchannels(i).type,channeltype) && detailedchannels(i).number == channels(j))
                            %add startbyte to list of channels to read
                            byteandbit(end+1,1) = str2num(detailedchannels(i).startbyte);
                            byteandbit(end,2) = str2num(detailedchannels(i).bit) + 1;
                        end
                    end
                end

                data = read_SpikeGadgets_digitalChannels(filename,header.numChannels,byteandbit,sr,header.headerSize,s0,s1);
                data = data';

            end
        end
    end
end
