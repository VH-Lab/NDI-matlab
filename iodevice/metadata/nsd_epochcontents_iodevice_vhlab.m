classdef nsd_epochconents_iodevice_vhlab < nsd_epochcontents
	properties
	end % properties
	methods
		function obj = nsd_epochconents_iodevice_vhlab(name_, reference_, type_, devicestring_)
			% NSD_EPOCHCONTENTS_VHLAB - Create a new nsd_epochconents_iodevice object derived from the vhlab device implementation
			%
			% MYNSD_EPOCHCONTENTS = NSD_EPOCHCONTENTS_VHLAB(NAME, REFERENCE, TYPE, DEVICESTRING)
			%
			% Creates a new NSD_EPOCHCONTENTS with name NAME, reference REFERENCE, type TYPE,
			% and devicestring DEVICESTRING.
			%
			% NAME can be any string that begins with a letter and contains no whitespace. It
			% is CASE SENSITIVE.
			% REFERENCE must be a non-negative scalar integer.
			% TYPE is the type of recording.
			% DEVICESTRING is a string that indicates the channels that were used to acquire
			% this record.
			% 
			%   MYNSD_EPOCHCONTENTS = NSD_EPOCHCONTENTS_VHLAB(FILENAME)
			% 
			% Here, FILENAME is assumed to be a (full path) tab-delimitted text file in the style of 
			% 'vhintan_channelgrouping.txt' (see HELP VHINTAN_CHANNELGROUPING) 
			% that has entries 'name<tab>ref<tab>channel_list<tab>'.
			%
			% The device type of each channel is assumed to be 'n-trode', where n is 
			% set to be the number of channels in the channel_list for each name/ref pair.
			%
			% The NSD device name for this device must be 'vhintan' (VH Intan RHD device), 'vhlv' (VH Lab Labview custom
			% acqusition code), 'vhspike2', or 'vhwillow'. The device name will be taken from the filename,
			% following [VHDEVICENAME '_channelgrouping.txt']
			%

			if nargin==0,
				name_ = 'a';
			end
			if nargin==1,
				filename = name_;
				name_ = 'a';
			end
			if nargin<4,
				reference_ = 0;
				type_ = 'a';
				devicestring_ = 'a';
			end

			obj = obj@nsd_epochconents_iodevice(name_, reference_, type_, devicestring_);

			if nargin==1,
				[filepath, localfile, ext] = fileparts(filename);
				if strcmp([localfile ext],'stimtimes.txt'), % vhvis_spike2
					mylist = {'mk1','mk2','mk3','e1','e2','e3'};
					for i=1:numel(mylist),
						nextentry = nsd_epochconents_iodevice_vhlab('vhvis_spike2',...
							1,...
							['stimulator'  ] , ...  % type
							['vhvis_spike2' ':' mylist{i}]);  % device string
						obj(i) = nextentry;
					end
					return;
				end
				vhdevice_string = regexp(lower([localfile ext]),'(\w*)_channelgrouping.txt','tokens');
				if isempty(vhdevice_string),
					error(['File name not of expected form VHDEVICENAME_channelgrouping.txt']);
				end
				vhdevice_string = vhdevice_string{1}{1};
				valid_vhdevice_strings = {'vhspike2','vhintan','vhlv','vhwillow'};
				vhdevice_string = intersect(vhdevice_string, valid_vhdevice_strings);
				if isempty(vhdevice_string)
					error(['VHDEVICENAME must be one of ' strjoin(valid_vhdevice_strings,', ') ]);
				end	
				vhdevice_string = vhdevice_string{1}; 
	
				nsd_struct = loadStructArray(filename);
				fn = fieldnames(nsd_struct);
				if ~eqlen(fn,{'name','ref','channel_list'}'),
					error(['fields must be (case-sensitive match): name, ref, channel_list. See HELP VHINTAN_CHANNELGROUPING.']);
				end;

				% now pull reference.txt file to determine type
				[myfilepath,myfilename] = fileparts(filename);
				ref_struct = loadStructArray([myfilepath filesep 'reference.txt']);

				nsd_globals;

				for i=1:length(nsd_struct),
					tf_name = strcmp(nsd_struct(i).name,{ref_struct.name});
					tf_ref = [nsd_struct(i).ref == [ref_struct.ref]];
					index = intersect(tf_name,tf_ref);
					if numel(index)~=1, error(['Cannot find exclusive match for name/ref in reference.txt file.']); end;
					ec_type = ref_struct(index).type;
					if isempty(intersect({nsd_probetype2object.type},ec_type)),
						error(['Unknown type ' ec_type '.']);
					end
					nextentry = nsd_epochconents_iodevice_vhlab(nsd_struct(i).name,...
							nsd_struct(i).ref,...
							ec_type, ...  % type
							[vhdevice_string ':ai' intseq2str(nsd_struct(i).channel_list)]);  % device string
							%['extracellular_electrode-' int2str(numel(nsd_struct(i).channel_list)) ] , ...  % type
					obj(i) = nextentry;
				end;
			end

		end;
        
		function savetofile(obj, filename)
		%  SAVETOFILE - Write nsd_epochconents_iodevice object array to disk
		%    
                %    SAVETOFILE(OBJ, FILENAME)
		% 
		%  Writes the NSD_EPOCHCONTENTS_VHLAB object to disk in filename FILENAME (full path).
		%
		%  
			error(['Sorry, I only know how to read these files, I don''t write (yet? ever?).']);
		end;
	end  % methods
end


