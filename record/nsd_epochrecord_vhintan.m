classdef nsd_epochrecord_vhintan < nsd_epochrecord
	properties
	end % properties
	methods
		function obj = nsd_epochrecord_vhintan(filename)
			% NSD_EPOCHRECORD_VHINTAN - Create a new nsd_epochrecord object derived from the vh lab intan implementation
			% 
			%   MYNSD_EPOCHRECORD = NSD_EPOCHRECORD_VHINTAN(FILENAME)
			% 
			% Here, FILENAME is assumed to be a (full path) tab-delimitted text file in the style of 
			% 'vhintan_channelgrouping.txt' (see HELP VHINTAN_CHANNELGROUPING) 
			% that has entries 'name<tab>ref<tab>channel_list<tab>'.
			%
			% The device type of each channel is assumed to be 'extracellular_electrode-n', where n is 
			% set to be the number of channels in the channel_list for each name/ref pair.
			%
			% The NSD device name for this device must be 'vhintan'.
			%

			if nargin==1,
				nsd_struct = loadStructArray(filename);
				fn = fieldnames(nsd_struct);
				if ~eqlen(fn,{'name','ref','channel_list'}),
					error(['fields must be (case-sensitive match): name, ref, channel_list, devicestring. See HELP VHINTAN_CHANNELGROUPING.']);
				end;
				obj = [];
				for i=1:length(nsd_struct),
					
					nextentry = obj@nsd_epochrecord(nsd_struct(i).name,...
							nsd_struct(i).ref,...
							['extracellular_electrode-' int2str(numel(nsd(i).channel_list)) ] , ...  % type
							[]);  % device string
					obj(i) = nextentry;
				end;
				return;
			end;
		end;
        
		function savetofile(obj, filename)
		%  SAVETOFILE - Write nsd_epochrecord object array to disk
		%    
                %    SAVETOFILE(OBJ, FILENAME)
		% 
		%  Writes the NSD_EPOCHRECORD_VHINTAN object to disk in filename FILENAME (full path).
		%
		%  
		
			error(['Sorry, I only know how to read these files, I don't write (yet? ever?).']);
		end;
	end  % methods
end


