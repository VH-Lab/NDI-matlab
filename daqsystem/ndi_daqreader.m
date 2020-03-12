classdef ndi_daqreader < ndi_base
% NDI_DAQREADER - A class for objects that read samples for NDI_DAQSYSTEM objects
%
%
	properties (GetAccess=public, SetAccess=protected)
	end

	methods

		function obj = ndi_daqreader(varargin)
		% NDI_DAQREADER - create a new NDI_DAQREADER object
		%
		%  OBJ = NDI_DAQREADER()
		%
		%  Creates an NDI_DAQREADER.
		%
		%  NDI_DAQREADER is an abstract class, and a specific implementation must be used.
		%

			loadfromfile = 0;

			if nargin>=2,
				if ischar(varargin{2}), % it is a command
					loadfromfile = 1;
					filename = varargin{1};
					if ~strcmp(lower(varargin{2}), lower('OpenFile')),
						error(['Unknown command.']);
					end
				end;
			end;

			obj = obj@ndi_base();
			if loadfromfile,
				obj = obj.readobjectfile(filename);
			end
		end % ndi_daqreader

		% DBLEAF functions...

		function [data, fieldnames] = stringdatatosave(ndi_daqreader_obj)
			% STRINGDATATOSAVE - Returns a set of strings to write to file to save object information
			%
			% [DATA,FIELDNAMES] = STRINGDATATOSAVE(NDI_DAQREADER_OBJ)
			%
			% Return a cell array of strings to save to the objectfilename.
			%
			% FIELDNAMES is a set of names of the fields/properties of the object
			% that are being stored.
			%
				[data,fieldnames] = stringdatatosave@ndi_base(ndi_daqreader_obj);
		end % stringdatatosave

		function [obj,properties_set] = setproperties(ndi_daqreader_obj, properties, values)
			% SETPROPERTIES - set the properties of an NDI_DAQREADER object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NDI_DAQREADER_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NDI_DAQREADER_OBJ and returns the result in OBJ.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
				fn = fieldnames(ndi_daqreader_obj);
				obj = ndi_daqreader_obj;
				properties_set = {};
				for i=1:numel(properties),
					if any(strcmp(properties{i},fn)) | any (strcmp(properties{i}(2:end),fn)),
						if properties{i}(1)~='$',
							eval(['obj.' properties{i} '= values{i};']);
							properties_set{end+1} = properties{i};
						end
					end
				end
		end % setproperties()

		% EPOCHSET functions, although this object is NOT an EPOCHSET object

		function ec = epochclock(ndi_daqreader_obj, epochfiles)
			% EPOCHCLOCK - return the NDI_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NDI_DAQREADER_OBJ, EPOCHFILES)
			%
			% Return the clock types available for this epoch as a cell array
			% of NDI_CLOCKTYPE objects (or sub-class members).
			%
			% For the generic NDI_DAQREADER, this returns a single clock
			% type 'no_time';
			%
			% See also: NDI_CLOCKTYPE
			%
				ec = {ndi_clocktype('no_time')};
		end % epochclock

		function t0t1 = t0_t1(ndi_epochset_obj, epochfiles)
			% EPOCHCLOCK - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCH_NUMBER)
			%
			% Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
			% in the same units as the NDI_CLOCKTYPE objects returned by EPOCHCLOCK.
			%
			% The abstract class always returns {[NaN NaN]}.
			%
			% See also: NDI_CLOCKTYPE, EPOCHCLOCK
			%
				t0t1 = {[NaN NaN]};
		end % t0t1

		function [b,msg] = verifyepochprobemap(ndi_daqreader_obj, epochprobemap, epochfiles)
			% VERIFYEPOCHPROBEMAP - Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk
			%
			%   B = VERIFYEPOCHPROBEMAP(NDI_DAQREADER_OBJ, EPOCHPROBEMAP, NUMBER)
			%
			% Examines the NDI_EPOCHPROBEMAP_DAQSYSTEM EPOCHPROBEMAP and determines if it is valid for the given device
			% epoch NUMBER.
			%
			% For the abstract class NDI_DAQREADER, EPOCHPROBEMAP is always valid as long as
			% EPOCHPROBEMAP is an NDI_EPOCHPROBEMAP_DAQSYSTEM object.
			%
			% See also: NDI_DAQREADER, NDI_EPOCHPROBEMAP_DAQSYSTEM
				msg = '';
				b = isa(epochprobemap, 'ndi_epochprobemap_daqsystem');
				if ~b,
					msg = 'epochprobemap is not a member of the class NDI_EPOCHPROBEMAP_DAQSYSTEM; it must be.';
					return;
				end;

				for i=1:numel(epochprobemap),
					try,
						thedevicestring = ndi_daqreaderstring(epochprobemap(i).devicestring);
					catch,
						b = 0;
						msg = ['Error evaluating devicestring ' epochprobemap(i).devicestring '.'];
                                        end
                                end
		end % verifyepochprobemap
		
		%% functions that override ndi_documentservice
       		function ndi_document_obj = newdocument(ndi_document_obj)
            		ndi_document_obj = ndi_document('ndi_document_daqreader.json');
        	 end

	end % methods
		
end % ndi_daqreader classdef

