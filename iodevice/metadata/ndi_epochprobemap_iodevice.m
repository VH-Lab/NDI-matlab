classdef ndi_epochprobemap_iodevice < ndi_epochprobemap
	properties
		name          % Name of the contents; can by any string that begins with a letter and contains no whitespace
		reference     % A non-negative scalar integer reference number that uniquely identifies data records that can be combined
		type          % The type of recording that is present in the data
		devicestring  % An NDI_IODEVICESTRING that indicates the device and channels that comprise the data
	end % properties
	methods
		function obj = ndi_epochprobemap_iodevice(name_, reference_, type_, devicestring_)
			% NDI_EPOCHPROBEMAP_IODEVICE - Create a new ndi_epochprobemap_iodevice object
			%
			% MYNDI_EPOCHPROBEMAP_IODEVICE = NDI_EPOCHPROBEMAP(NAME, REFERENCE, TYPE, DEVICESTRING)
			%
			% Creates a new NDI_EPOCHPROBEMAP_IODEVICE with name NAME, reference REFERENCE, type TYPE,
			% and devicestring DEVICESTRING.
			%
			% NAME can be any string that begins with a letter and contains no whitespace. It
			% is CASE SENSITIVE.
			% REFERENCE must be a non-negative scalar integer.
			% TYPE is the type of recording.
			% DEVICESTRING is a string that indicates the channels that were used to acquire
			% this record.
			%
			% The function has an alternative form:
			%
			%   MYNDI_EPOCHPROBEMAP_IODEVICE = NDI_EPOCHPROBEMAP(FILENAME)
			%
			% Here, FILENAME is assumed to be a tab-delimitted text file with a header row
			% that has entries 'name<tab>reference<tab>type<tab>devicestring<tab>', with
			% one line per NDI_EPOCHPROBEMAP_IODEVICE entry.
			%

			if nargin==0, % undocumented 0 input constructor
				name_='a';
				reference_=0;
				type_='a';
				devicestring_='a';
			end

			if nargin==1,
				% name_ should be a filename
				ndi_struct = [];
				if exist(name_,'file'),
					ndi_struct= loadStructArray(name_);
				end;
				if isempty(ndi_struct),
					ndi_struct = emptystruct('name','reference','type','devicestring');
				end
				fn = fieldnames(ndi_struct);
				if ~eqlen(fn,{'name','reference','type','devicestring'}');
					error(['fields must be (case-sensitive match): name, reference, type, devicestring.']);
				end;
				obj = [];
				for i=1:length(ndi_struct),
					nextentry = ndi_epochprobemap_iodevice(ndi_struct(i).name,...
							ndi_struct(i).reference,...
							ndi_struct(i).type, ...
							ndi_struct(i).devicestring);
					obj = cat(1,obj,nextentry);
				end;
				if isempty(obj),
					obj = ndi_epochprobemap_iodevice;
					obj = obj([]);
				end
				return;
			end;

			%name, check for errors
			[b,errormsg] = islikevarname(name_);
			if ~b,
				error(['Error in name field: ' errormsg ]);
			end;

			obj.name = name_;

			% reference, check for errors

			if reference_ < 0 | ~isint(reference_) | ~eqlen(size(reference_),[1 1]),
				error(['reference of ndi_epochprobemap_iodevice must be a non-negative scalar integer, got ' int2str(reference_)]);
			end;
			obj.reference = fix(reference_);

			[b,errormsg] = islikevarname(type_);
			if ~b,
				error(['Error in type field: ' errormsg ]);
			end;
			obj.type = type_;

			[b,errormsg] = islikevarname(devicestring_);
			if ~b,
				error(['Error in devicestring field: ' errormsg ]);
			end;
			obj.devicestring = devicestring_;
		end;

		function savetofile(ndi_epochprobemap_iodevice_obj, filename)
		%  SAVETOFILE - Write ndi_epochprobemap_iodevice object array to disk
		%
                %  SAVETOFILE(NDI_EPOCHPROBEMAP_IODEVICE_OBJ, FILENAME)
		%
		%  Writes the NDI_EPOCHPROBEMAP_IODEVICE object to disk in filename FILENAME (full path).
		%
		%
			fn = {'name','reference','type','devicestring'};
			mystruct = emptystruct(fn{:});
			for i=1:length(obj),
				mynewstruct = struct;
				for j=1:length(fn),
					mynewstruct = setfield(mynewstruct,fn{j},getfield(obj(i),fn{j}));
				end;
				mystruct(i) = mynewstruct;
			end;
			saveStructArray(filename, mystruct);
		end;
	end  % methods
end
