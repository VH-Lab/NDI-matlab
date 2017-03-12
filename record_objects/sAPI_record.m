classdef sAPI_record
	properties
		name
		reference
		type
		devicestring
	end % properties
	methods
		function obj = sAPI_record(name_, reference_, type_, devicestring_)
			% SAPI_RECORD - Create a new sAPI_record object
			% 
			%   MYSAPI_RECORD = SAPI_RECORD(NAME, REFERENCE, TYPE, DEVICESTRING)
			% 
			% Creates a new SAPI_RECORD with name NAME, reference REFERENCE, type TYPE,
                        % and devicestring DEVICESTRING.
                        %
                        % NAME can be any string that begins with a letter and contains no whitespace. It
			% is CASE SENSITIVE.
			% REFERENCE must be a non-negative scalar integer.
			% TYPE is the type of recording. 
			% DEVICESTRING is a string that indicates the channels that were used to acquire
			% this record.
			%
			% The function has an alteranative form:
			%
			%   MYSAPI_RECORD = SAPI_RECORD(FILENAME)
			%   
			% Here, FILENAME is assumed to be a tab-delimitted text file with a header row
			% that has entries 'name<tab>reference<tab>type<tab>devicestring<tab>', with 
			% one line per SAPI_RECORD entry.
			%

			if nargin==1,
				sapi_struct= loadStructArray(name_);
				fn = fieldnames(sapi_struct);
				if ~eqlen(fn,{'name','reference','type','devicestring'}),
					error(['fields must be (case-sensitive match): name, reference, type, devicestring.']);
				end;
				obj = [];
				for i=1:length(sapi_struct),
					nextentry = sAPI_record(sapi_struct(i).name,...
							sapi_struct(i).reference,...
							sapi_struct(i).type, ...
							sapi_struct(i).devicestring);
					obj(i) = nextentry;
				end;
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
				error(['reference of sAPI_record must be a non-negative scalar integer, got ' int2str(reference_)]);
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
		function savetofile(obj, filename)
		%  SAVETOFILE - Write sAPI_record object array to disk
		%    
                %    SAVETOFILE(OBJ, FILENAME)
		% 
		%  Writes the SAPI_RECORD object to disk in filename FILENAME (full path).
		%
		%  
			fn = {'name','reference','type','devicestring'};
			mystruct = emptystruct(fn);
			for i=1:length(obj),
				mynewstruct = emptystruct(fn{:});
				for j=1:length(fn),
					mynewstruct = setfield(mynewstruct,fn{j},getfield(obj(i),fn{j}));
				end;
				mystruct(i) = mynewstruct;
			end;
			saveStructArray(filename, mystruct);
		end;
	end  % methods
end


