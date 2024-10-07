classdef epochprobemap_daqsystem < ndi.epoch.epochprobemap
	properties
		name          % Name of the contents; can by any string that begins with a letter and contains no whitespace
		reference     % A non-negative scalar integer reference number that uniquely identifies data records that can be combined
		type          % The type of recording that is present in the data
		devicestring  % An ndi.daq.daqsystemstring that indicates the device and channels that comprise the data
		subjectstring % A string describing the local_id or unique document ID of the subject of the probe
	end % properties
	methods
		function obj = epochprobemap_daqsystem(name_, reference_, type_, devicestring_, subjectstring_)
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

			is_struct = 0;
			if nargin>0,
				if numel(find(name_==sprintf('\n')))>0,
					is_struct = 1;
				end;
			end;

			if nargin==1 | is_struct,
				% name_ should be a filename or serialization string
				ndi_struct = [];
				if numel(find(name_==sprintf('\n')))>0,
					ndi_struct = ndi.epoch.epochprobemap_daqsystem.decode(name_);
				elseif isfile(name_),
					ndi_struct= table2struct(readtable(name_,'Delimiter','\t','FileType','text'));
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

		function st = serialization_struct(ndi_epochprobemap_daqsystem_obj)
			% SERIALIZATION_STRUCT - create a Matlab structure for serialization
			%
			% ST = SERIALIZATION_STRUCT(NDI_EPOCHPROBEMAP_DAQSYSTEM_OBJ)
			%
			% Returns a structure of the parameters of an ndi.epoch.epochprobemap_daqsystem
			% object.
			%
				fn = {'name','reference','type','devicestring','subjectstring'};
				st = vlt.data.emptystruct(fn{:});
				for i=1:length(ndi_epochprobemap_daqsystem_obj),
					mynewstruct = struct;
					for j=1:length(fn),
						mynewstruct = setfield(mynewstruct,fn{j},getfield(ndi_epochprobemap_daqsystem_obj(i),fn{j}));
					end;
					st(i) = mynewstruct;
				end;
		end; % serialization_struct()

		function s = serialize(ndi_epochprobemap_daqsystem_obj)
                        % SERIALIZE - Turn the ndi.epoch.epochprobemap object into a string
                        %
                        % S = SERIALIZE(NDI_EPOCHPROBEMAP_OBJ)
                        %
                        % Create a charater array representation of an ndi.epoch.epochprobemap_daqsystem object
                        %
				s = '';
				st = ndi_epochprobemap_daqsystem_obj.serialization_struct();
				fn = fieldnames(st);
				for i=1:numel(fn),
					s=cat(2,s,fn{i});
					if i~=numel(fn),
						s=cat(2,s,sprintf('\t'));
					end;
				end;
				s=cat(2,s,sprintf('\n'));
				for i=1:numel(st),
					for j=1:numel(fn),
						switch(fn{j}),
							case {'name','type','devicestring','subjectstring'},
								s=cat(2,s,getfield(st(i),fn{j}));
							case 'reference',
								s=cat(2,s,int2str(getfield(st(i),fn{j})));
						end;
						if j~=numel(fn),
							s=cat(2,s,sprintf('\t'));
						end;
					end;
					s=cat(2,s,sprintf('\n'));
				end;

		end; % serialize()

		function savetofile(ndi_epochprobemap_daqsystem_obj, filename)
		%  SAVETOFILE - Write ndi.epoch.epochprobemap_daqsystem object array to disk
		%
                %  SAVETOFILE(NDI_EPOCHPROBEMAP_DAQSYSTEM_OBJ, FILENAME)
		%
		%  Writes the ndi.epoch.epochprobemap_daqsystem object to disk in filename FILENAME (full path).
		%
		%
			mystruct = ndi_epochprobemap_daqsystem_obj.serialization_struct();
			vlt.file.saveStructArray(filename, mystruct);
		end;

		
	end  % methods

	methods(Static)

		function st = decode(s)
			% DECODE - decode table information for an ndi.epoch.epochprobemap object from a serialized string
                        %
                        % ST = DECODE(S)
                        %
                        % Return a structure ST that contains decoded information to
                        % build an ndi.epoch.epochprobemap object from a string
                        %
				st = vlt.data.emptystruct('name','reference','type','devicestring','subjectstring');
				c = vlt.data.string2cell(s,sprintf('\n'));
				if numel(c)<1,
					error(['There is no informtion in the serialized string s']);
				end;
				fn = vlt.data.string2cell(c{1},sprintf('\t'));
				for i=2:numel(c),
					line_here = vlt.data.string2cell(c{i},sprintf('\t'));
					if numel(line_here)==numel(fn),
						entry_here = vlt.data.emptystruct('name','reference','type','devicestring','subjectstring');
						entry_here(1).name = '';
						for j=1:numel(fn),
							switch(fn{j}),
								case {'name','type','devicestring','subjectstring'},
									entry_here(1) = setfield(entry_here(1),fn{j},line_here{j});
								case 'reference',
									entry_here(1) = setfield(entry_here(1),fn{j},str2num(line_here{j}));
							end;
						end;
						st(end+1) = entry_here;
					end;
				end;
		end;
	end % methods(Static)
end
