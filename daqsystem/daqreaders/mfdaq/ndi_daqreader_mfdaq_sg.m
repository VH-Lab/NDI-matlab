% NDI_DAQREADER_MFDAQ_SG - Device driver for SpikeGadgets .rec video file format
%
% This class reads data from video files .rec that spikegadgets use
%
% Spike Gadgets: http://spikegadgets.com/
%
%

classdef ndi_daqreader_mfdaq_sg < ndi_daqreader_mfdaq

	properties
	end

	methods
		function obj = ndi_daqreader_mfdaq_sg(varargin)
		% NDI_DAQSYSTEM_MFDAQ_SG - Create a new NDI_DEVICE_MFDAQ_SG object
		%
		%  D = NDI_DAQSYSTEM_MFDAQ_SG(NAME,THEFILENAVIGATOR)
		%
		%  Creates a new NDI_DAQSYSTEM_MFDAQ_SG object with name NAME and associated
		%  filenavigator THEFILENAVIGATOR.
		%
		%
		
			obj = obj@ndi_daqreader_mfdaq(varargin{:});

		end

		function channels = getchannelsepoch(ndi_daqreader_mfdaq_sg_obj, epochfiles)
		% GETCHANNELSEPOCH - GET THE CHANNELS AVAILABLE FROM .REC FILE HEADER
		%
		% CHANNELS = GETCHANNELSEPOCH(NDI_DAQREADER_MFDAQ_SG_OBJ)
		%
		% CHANNELS is a STRUCT
        
			filename = ndi_daqreader_mfdaq_sg_obj.filenamefromepochfiles(epochfiles); 
			fileconfig = [];
			[fileconfig, channels] = read_SpikeGadgets_config(filename);

			for k=1:length(channels)
				number = 0;
				name = '';

				%Auxiliary
				if strcmp(channels(k).name(1),'A')
					%Input
					if strcmp(channels(k).name(2),'i')
						channels(k).type = 'auxiliary';
						number = sscanf(channels(k).name, 'Ain%d'); 
						name = strcat('axn',num2str(number));
						channels(k).number = number;
							%Output
					else
						channels(k).type = 'auxiliary';
						number = sscanf(channels(k).name, 'Aout%d'); 
						name = strcat('axo',num2str(number));
						channels(k).number = number;
					end

				%Digital
				elseif strcmp(channels(k).name(1),'D')
					if strcmp(channels(k).name(2),'i') % Input
						channels(k).type = 'digital_in';
						number = sscanf(channels(k).name, 'Din%d'); 
						name = strcat('di',num2str(number));
						channels(k).number = number;
					else %Output
						channels(k).type = 'digital_out';
						number = sscanf(channels(k).name, 'Dout%d');
						name = strcat('do',num2str(number));
						channels(k).number = number;
					end
				else	%MCU (digital inputs)
					channels(k).type = 'digital_in';
					number = sscanf(channels(k).name, 'MCU_Din%d');
					number = number + 32; % +32 from previous non MCU inputs
					name = strcat('di',num2str(number));
					channels(k).number = number;
				end
				channels(k).name = name;
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

		function channels = getchannelsepochdetailed(ndi_daqreader_mfdaq_sg_obj, epochfiles)
		% GETCHANNELSDETAILED - GET THE CHANNELS AVAILABLE FROM .REC FILE HEADER WITH EXTRA DETAILS
		%
		% CHANNELS = GETCHANNELSEPOCHDETAILED(NDI_DAQREADER_MFDAQ_SG_OBJ)
		%
		% CHANNELS is a STRUCT

			filename = ndi_daqreader_mfdaq_sg_obj.filenamefromepochfiles(epochfiles); 
			fileconfig = [];

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

		function sr = samplerate(ndi_daqreader_mfdaq_sg_obj, epochfiles, channeltype, channel)
		% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL
		%
		% SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
		%
		% SR is the list of sample rate from specified channels
		%
		% CHANNELTYPE and CHANNEL not used in this case since it is the
		% same for all channels in this device

			filename = ndi_daqreader_mfdaq_sg_obj.filenamefromepochfiles(epochfiles); 

			fileconfig = read_SpikeGadgets_config(filename);

			%Sampling rate is the same for all channels in Spike Gadgets
			%device so it is returned by checking the file configuration
			sr = str2num(fileconfig.samplingRate);
		end

		function epochprobemap = getepochprobemap(ndi_daqreader_mfdaq_sg_obj, epochmapfilename, epochfiles)
		% GETEPOCHPROBEMAP returns struct with probe information
		% name, reference, n-trode, channels
		%
			filename = ndi_daqreader_mfdaq_sg_obj.filenamefromepochfiles(epochfiles);
			fileconfig = read_SpikeGadgets_config(filename);
			nTrodes = fileconfig.nTrodes;
			%List where epochprobemap objects will be stored
			epochprobemap = [];

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
				devicestringobject = ndi_daqsystemstring('SpikeGadgets',{'ai','ai','ai','ai'}, channels);
				devicestringstring = devicestringobject.devicestring();
				%
				obj = ndi_epochprobemap_daqsystem(name,reference,type,devicestringstring);
				%Append each newly made object to end of list
				epochprobemap = [epochprobemap obj];
			end
        end

		function data = readchannels_epochsamples(ndi_daqreader_mfdaq_sg_obj,channeltype, channels, epochfiles, s0, s1)
		% FUNCTION READ_CHANNELS - read the data based on specified channels
		%
		% DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES ,S0, S1)
		%
		% CHANNELTYPE is the type of channel to read
		% 'digital_in', 'digital_out', 'analog_in', 'analog_out' or 'auxiliary'
		%
		% CHANNEL is a vector of the channel numbers to
		% read beginning from 1 if 'etrodeftrode' is channeltype,
		% if channeltype is 'analog_in' channel is an array with the
		% string names of analog channels 'Ain1'through 8
		%
		% EPOCH is set of files in the epoch
		%
		% DATA is the channel data (each column contains data from an indvidual channel)
		%
			filename = ndi_daqreader_mfdaq_sg_obj.filenamefromepochfiles(epochfiles); 

			header = read_SpikeGadgets_config(filename);

			sr = ndi_daqreader_mfdaq_sg_obj.samplerate(epochfiles,channeltype,channels);

			detailedchannels = ndi_daqreader_mfdaq_sg_obj.getchannelsepochdetailed(epochfiles);

			byteandbit = [];

			%read_SpikeGadgets_trodeChannels(filename,NumChannels, channels,samplingRate,headerSize, configExists)
			%reading from channel 1 in list returned
			%Reads nTrodes
			%WARNING channeltype hard coded, ask Steve
			if (strcmp(ndi_daqsystem_mfdaq.mfdaq_type(channeltype{1}),'analog_in') || strcmp(ndi_daqsystem_mfdaq.mfdaq_type(channeltype{1}), 'analog_out'))
				data = read_SpikeGadgets_trodeChannels(filename,header.numChannels,channels-1,sr, header.headerSize,s0,s1);

			elseif (strcmp(channeltype,'auxiliary')) %Reads analog inputs
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

			elseif (strcmp(channeltype,'digital_in') || strcmp(channeltype, 'digital_out')), %Reads digital inputs
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
		end % readchannels_epochsamples

		function filename = filenamefromepochfiles(ndi_daqreader_mfdaq_sg_obj, filename)
			s1 = ['.*\.rec\>']; % equivalent of *.ext on the command line
			[tf, matchstring, substring] = strcmp_substitution(s1,filename,'UseSubstituteString',0);
			index = find(tf);
			if numel(index)> 1,
				error(['Need only 1 .rec file per epoch.']);
			elseif numel(index)==0,
				error(['Need 1 .rec file per epoch.']);
			else,
				filename = filename{index};
			end
		end % filenamefromepoch
    end % methods
end % classdef
