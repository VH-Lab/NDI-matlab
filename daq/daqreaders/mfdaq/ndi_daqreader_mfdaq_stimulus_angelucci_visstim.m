% NDI_DAQREADER_MFDAQ_STIMULUS_ANGELUCCI_VISSTIM2 - Device object for Angelucci lab visual stimulus system
%
% This device reads the 'stimData.mat' to obtain stimulus parameters and a *.ns4 file (digital events on ai1).
%
% Channel name:   | Signal description:
% ----------------|------------------------------------------
% m1              | stimulus on/off
% m2              | stimid 
%

classdef ndi_daqreader_mfdaq_stimulus_angelucci_visstim < ndi_daqreader_mfdaq_blackrock 
	properties (GetAcces=public,SetAccess=protected)

	end
	properties (Access=private) % potential private variables
	end

	methods
		function obj = ndi_daqreader_mfdaq_stimulus_angelucci_visstim(varargin)
			% NDI_DAQREADER_MFDAQ_STIMULUS_ANGELUCCI_VISSTIM2 - Create a new multifunction DAQ object
			%
			%  D = NDI_DAQREADER_MFDAQ_STIMULUS_ANGELUCCI_VISSTIM2(NAME, THEFILENAVIGATOR, DAQREADER)
			%
			%  Creates a new NDI_DAQSYSTEM_MFDAQ object with NAME, and FILENAVIGATOR.
			%  This is an abstract class that is overridden by specific devices.
				obj = obj@ndi_daqreader_mfdaq(varargin{:});
		end; % ndi_daqreader_mfdaq_stimulus_angelucci_visstim()

		function channels = getchannelsepoch(thedev, epochfiles)
			% FUNCTION GETCHANNELS - List the channels that are available on this device
			%
			%  CHANNELS = GETCHANNELSEPOCH(THEDEV, EPOCHFILES)
			%
			% This device produces the following channels in each epoch:
			% Channel name:   | Signal description:
			% ----------------|------------------------------------------
			% mk1             | stimulus on/off
			% mk2             | stimid 
			%
				channels        = struct('name','mk1','type','marker');  
				channels(end+1) = struct('name','mk2','type','marker');  
		end; % getchannelsepoch()

		function data = readevents_epochsamples(ndi_daqreader_mfdaq_stimulus_angelucci_visstim_obj, channeltype, channel, epochfiles, t0, t1)
			%  READEVENTS_EPOCHSAMPLES - read events or markers of specified channels for a specified epoch
			%
			%  DATA = READEVENTS_EPOCHSAMPLES(SELF, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
			%
			%  SELF is the NDI_DAQSYSTEM_MFDAQ_STIMULUS_ANGELUCCI_VISSTIM object.
			%
			%  CHANNELTYPE is a cell array of strings describing the the type(s) of channel(s) to read
			%  ('event','marker', etc)
			%  
			%  CHANNEL is a vector with the identity of the channel(s) to be read.
			%  
			%  EPOCH is the cell array of file names associated with an epoch
			%
			%  DATA is a two-column vector; the first column has the time of the event. The second
			%  column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
			%  is requested, DATA is returned as a cell array, one entry per channel.
			% 
				 
				data = {};
				md_reader = ndi_daqmetadatareader_AngelucciStims();

				[parameters,stimid,stimtimes] = md_reader.readmetadatafromfile(FILENAME);

				stimtimes = (stimtimes(:)-1) / 30000;
				stimofftimes = = stimontimes + parameters{1}.stimOnDuration / 30000;

				for i=1:numel(channel),
					switch (ndi_daqsystem_mfdaq.mfdaq_prefix(channeltype{i})),
						case 'mk',
							% put them together, alternating stimtimes and stimofftimes in the final product
							time1 = [stimtimes(:)' ; stimofftimes(:)'];
							data1 = [ones(size(stimtimes(:)')) ; -1*ones(size(stimofftimes(:)'))];
							time1 = reshape(time1,numel(time1),1);
							data1 = reshape(data1,numel(data1),1);
							ch{1} = [time1 data1];
							
							time2 = [stimtimes(:)];
							data2 = [stimid(:)];
							ch{2} = [time2 data2];

							data{i} = ch{channel(i)};
						case 'md',
							
						otherwise,
							error(['Unknown channel.']);
					end
				end

				if numel(data)==1,% if only 1 channel entry to return, make it non-cell
					data = data{1};
				end; 

		end % readevents_epochsamples()

	end; % methods

	methods (Static)  % helper functions
	end % static methods
end

