classdef nsd_document
	%NSD_DOCUMENT - NSD_database storage item, general purpose data and parameter storage
	% The NSD_DOCUMENT datatype for storing results in the NSD_DATABASE
	%
	% The nsd_document_properties field is a structure with properties that are required of all
	% NSD_DOCUMENT objects. These include:
	% Field (default value)           | Description
	% -----------------------------------------------------------------------------------
	% experiment_unique_reference     | The experiment's unique reference ID
	%         (no default)   
	% document_unique_reference       | This document's unique reference id
	% name ('generic')                | The document's name
	% type ('generic')                | The document's type
	% document_version (1)            | The document's version (32-bit unsigned integer numbered from 1)
	% datestamp (current time)        | The document's creation time (for this version) in ISO 8601 (UTC required)
	% database_version (1)            | The version of the database for which the document was created
	% hasbinaryfile (0)               | Should the document have a separate space for storing binary data?
	% validation_schema (no default)  | The validation schema target
	%

	properties (SetAccess=protected,GetAccess=public)
		nsd_document_properties % a struct with the fields for the document
	end

	methods
		function nsd_document_obj = nsd_document(document_type, varargin)
			% NSD_DOCUMENT - create a new NSD_DATABASE object
			%
				experiment_unique_reference = '';
				document_unique_reference = [num2hex(now) '_' num2hex(rand)];
				name = 'generic';
				type = 'generic';
				document_version = uint32(1);
				datestamp = char(datetime('now','TimeZone','UTCLeapSeconds'));
				database_version = 1;
				hasbinaryfile = 0;
				validation_schema = '$NSDSCHEMAROOT/nsd_document_schema.json';

				nsd_document_properties = emptystruct;

				assign(varargin{:});

				nsd_core_properties = var2struct( ...
						'experiment_unique_reference', ...
						'document_unique_reference', ...
						'name', ...
						'type', ...
						'document_version', ...
						'datestamp', ...
						'database_version', ...
						'hasbinaryfile', ...
						'validation_schema' ...
						);

				nsd_document_obj.nsd_document_properties.nsd_core_properties = nsd_core_properties;

		end % nsd_document() creator

		function b = validate(nsd_document_obj)
			% VALIDATE - 0/1 evaluate whether NSD_DOCUMENT object is valid by its schema
			% 
			% B = VALIDATE(NSD_DOCUMENT_OBJ)
			%
			% Checks the fields of the NSD_DOCUMENT object against the schema in 
			% NSD_DOCUMENT_OBJ.nsd_core_properties.validation_schema and returns 1
			% if the object is valid and 0 otherwise.
				b = 1; % for now, skip this
		end % validate()

		function bf = getbinaryfile(nsd_document_obj);
			% GETBINARYFILE - Get the binary file object for an NSD_DOCUMENT_OBJ
			%
				bf = [];
		end % getbinaryfileobj() 
	end % methods
end % classdef

