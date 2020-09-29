classdef ndi_epochprobemap_daqsystem < ndi_epochprobemap
	properties
		name          % Name of the contents; can by any string that begins with a letter and contains no whitespace
		reference     % A non-negative scalar integer reference number that uniquely identifies data records that can be combined
		type          % The type of recording that is present in the data
		devicestring  % An ndi.daq.daqsystemstring that indicates the device and channels that comprise the data
		subjectstring % A string describing the local_id or unique document ID of the subject of the probe
	end % properties
	methods
		function obj = ndi.epoch.epochprobemap_daqsystem(name_, reference_, type_, devicestring_, subjectstring_)
			% ndi.epoch.epochprobemap_daqsystem - Create a new ndi.epoch.epochprobemap_daqsystem object
			%
			% MYNDI_EPOCHPROBEMAP_DAQSYSTEM = ndi.epoch.epochprobemap(NAME, REFERENCE, TYPE, DEVICESTRING, SUBJECTSTRING)
			%
			% Creates a new ndi.epoch.epochprobemap_daqsystem with name NAME, reference REFERENCE, type TYPE,
			% and devicestring DEVICESTRING.
			%
			% NAME can be any string that begins with a letter and contains no whitespace. It
			% is CASE SENSITIVE.
			% REFERENCE must be a non-negative scalar integer.
			% TYPE is the type of recording.
			% DEVICESTRING is a string that indicates the channels that were used to acquire
			% this record.
			% SUBJECTSTRING describes the subject of the probe, either using the unique local identifier
			%   or the document unique identifier (ID) of the ndi.document that describes the subject.
			%
			% The function has an alternative form:
			%
			%   MYNDI_EPOCHPROBEMAP_DAQSYSTEM = ndi.epoch.epochprobemap(FILENAME)
			%
			% Here, FILENAME is assumed to be a tab-delimitted text file with a header row
			% that has entries 'name<tab>reference<tab>type<tab>devicestring<tab><subjectstring>', with
			% one line per ndi.epoch.epochprobemap_daqsystem entry.
			%

			if nargin==0, % undocumented 0 input constructor
				name_='a';
				reference_=0;
				type_='a';
				devicestring_='a';
				subjectstring_ = 'nothing@nosuchlab.org';
			end

			if nargin==1,
				% name_ should be a filename
				ndi_struct = [];
				if exist(name_,'file'),
					ndi_struct= vlt.file.loadStructArray(name_);
				end;
				if isempty(ndi_struct),
					ndi_struct = vlt.data.emptystruct('name','reference','type','devicestring','subjectstring');
				end
				fn = fieldnames(ndi_struct);
				if ~vlt.data.eqlen(fn,{'name','reference','type','devicestring','subjectstring'}');
					error(['fields must be (case-sensitive match): name, reference, type, devicestring, subjectstring; fields were ' ...
						vlt.data.cell2str(fn) '.']);
				end;
				obj = [];
				for i=1:length(ndi_struct),
					nextentry = ndi.epoch.epochprobemap_daqsystem(ndi_struct(i).name,...
							ndi_struct(i).reference,...
							ndi_struct(i).type, ...
							ndi_struct(i).devicestring,...
							ndi_struct(i).subjectstring);
					obj = cat(1,obj,nextentry);
				end;
				if isempty(obj),
					obj = ndi.epoch.epochprobemap_daqsystem;
					obj = obj([]);
				end
				return;
			end;

			%name, check for errors
			[b,errormsg] = vlt.data.islikevarname(name_);
			if ~b,
				error(['Error in name field: ' errormsg ]);
			end;

			obj.name = name_;

			% reference, check for errors

			if reference_ < 0 | ~vlt.data.isint(reference_) | ~vlt.data.eqlen(size(reference_),[1 1]),
				error(['reference of ndi.epoch.epochprobemap_daqsystem must be a non-negative scalar integer, got ' int2str(reference_)]);
			end;
			obj.reference = fix(reference_);

			[b,errormsg] = vlt.data.islikevarname(type_);
			if ~b,
				error(['Error in type field: ' errormsg ]);
			end;
			obj.type = type_;

			[b,errormsg] = vlt.data.islikevarname(devicestring_);
			if ~b,
				error(['Error in devicestring field: ' errormsg ]);
			end;
			obj.devicestring = devicestring_;

			obj.subjectstring = subjectstring_;
		end;

		function savetofile(ndi_epochprobemap_daqsystem_obj, filename)
		%  SAVETOFILE - Write ndi.epoch.epochprobemap_daqsystem object array to disk
		%
                %  SAVETOFILE(NDI_EPOCHPROBEMAP_DAQSYSTEM_OBJ, FILENAME)
		%
		%  Writes the ndi.epoch.epochprobemap_daqsystem object to disk in filename FILENAME (full path).
		%
		%
			fn = {'name','reference','type','devicestring','subjectstring'};
			mystruct = vlt.data.emptystruct(fn{:});
			for i=1:length(ndi_epochprobemap_daqsystem_obj),
				mynewstruct = struct;
				for j=1:length(fn),
					mynewstruct = setfield(mynewstruct,fn{j},getfield(ndi_epochprobemap_daqsystem_obj(i),fn{j}));
				end;
				mystruct(i) = mynewstruct;
			end;
			vlt.file.saveStructArray(filename, mystruct);
		end;
	end  % methods
end
