classdef ndi_cache < handle
% NDI_CACHE - Cache class for NDI
%
% 

	properties (SetAccess=protected,GetAccess=public)
		maxMemory % The maximum memory, in bytes, that can be consumed by an NDI_CACHE before it is emptied
		replacement_rule % The rule to be used to replace entries when memory is exceeded ('FIFO','LIFO','error', etc)
		table  % The variable that has the data and metadata for the cache
	end % properties

	properties (SetAccess=protected,GetAccess=private)
	end


	methods
		
		function ndi_cache_obj = ndi_cache(varargin)
			% NDI_CACHE - create a new NDI cache handle
			%
			% NDI_CACHE_OBJ = NDI_CACHE(...)
			%
			% Creates a new NDI_CACHE object. Additional arguments can be specified as
			% name value pairs:
			%
			% Parameter (default)         | Description
			% ------------------------------------------------------------
			% maxMemory (100e6)           | Max memory for cache, in bytes (100MB default)
			% replacement_rule ('fifo')   | Replacement rule (see NDI_CACHE/SET_REPLACEMENT_RULE
			%
			% Note that the cache is not 'secure', any function can query the data added.
			%
			% See also: NAMEVALUEPAIR

				maxMemory = 100e6; % 100 MB
				replacement_rule = 'fifo';

				assign(varargin{:});

				if nargin==0,
					ndi_cache_obj.maxMemory = maxMemory;
					ndi_cache_obj.replacement_rule = replacement_rule;
					ndi_cache_obj.table = emptystruct('key','type','timestamp','priority','bytes','data');
					return;
				end;

				ndi_cache_obj = ndi_cache();

				ndi_cache_obj.maxMemory = maxMemory;
				ndi_cache_obj = set_replacement_rule(ndi_cache_obj,replacement_rule);

		end % ndi_cache creator

		function ndi_cache_obj = set_replacement_rule(ndi_cache_obj, rule)
			% SET_REPLACEMENT_RULE - set the replacement rule for an NDI_CACHE object
			%
			% NDI_CACHE_OBJ = SET_REPLACEMENT_RULE(NDI_CACHE_OBJ, RULE)
			%
			% Sets the replacement rule for an NDI_CACHE to be used when a new entry
			% would exceed the allowed memory. The rule may be one of the following strings
			% (case is insensitive and will be stored lower case):
			%
			% Rule            | Description
			% ---------------------------------------------------------
			% 'fifo'          | First in, first out; discard oldest entries first.
			% 'lifo'          | Last in, first out; discard newest entries first.
			% 'error'         | Don't discard anything, just produce an error saying cache is full

				therules = {'fifo','lifo','error'};
				if any(strcmpi(rule,therules)),
					ndi_cache_obj.replacement_rule = lower(rule);
				else,
					error(['Unknown replacement rule requested: ' rule '.']);
				end
		end % set_replacement_rule

		function ndi_cache_obj = add(ndi_cache_obj, key, type, data, priority)
			% ADD - add data to an NDI_CACHE
			%
			% NDI_CACHE_OBJ = ADD(NDI_CACHE_OBJ, KEY, TYPE, DATA, [PRIORITY])
			%
			% Adds DATA to the NDI_CACHE_OBJ that is referenced by a KEY and TYPE.
			% If desired, a PRIORITY can be added; items with greatest PRIORITY will be
			% deleted last.
			%
				if nargin < 5,
					priority = 0;
				end

				% before we reorganize anything, make sure it will fit
				s = whos('data');
				if s.bytes > ndi_cache_obj.maxMemory,
					error(['This variable is too large to fit in the cache; cache''s maxMemory exceeded.']);
				end

				total_memory = ndi_cache_obj.bytes() + s.bytes;
				if total_memory > ndi_cache_obj.maxMemory, % it doesn't fit
					if strcmpi(ndi_cache_obj.replacement_rule,'error'),
						error(['Cache is too full too accommodate the new data; error was requested rather than replacement.']);
					end
					freespaceneeded = total_memory - ndi_cache_obj.maxMemory;
					ndi_cache_obj.freebytes(freespaceneeded);
				end

				% now there's room
				newentry = emptystruct('key','type','timestamp','priority','bytes','data');
				newentry(1).key = key;
				newentry(1).type = type;
				newentry(1).timestamp = now; % serial date number
				newentry(1).priority = priority;
				newentry(1).bytes = s.bytes;
				newentry(1).data = data;

				ndi_cache_obj.table(end+1) = newentry;
		end % add

		function ndi_cache_obj = remove(ndi_cache_obj, index_or_key, type, varargin)
			% REMOVE - remove data from an NDI_CACHE
			%
			% NDI_CACHE_OBJ = REMOVE(NDI_CACHE_OBJ, KEY, TYPE, ...)
			%   or
			% NDI_CACHE_OBJ = REMOVE(NDI_CACHE_OBJ, INDEX, [],  ...)
			%
			% Removes the data at table index INDEX or data with KEY and TYPE.
			% INDEX can be a single entry or an array of entries.
			%
			% If the data entry to be removed is a handle, the handle
			% will be deleted from memory unless the setting is altered with a NAME/VALUE pair.
			%
			% This function can be modified by name/value pairs:
			% Parameter (default)         | Description
			% ----------------------------------------------------------------
			% leavehandle (0)             | If the 'data' field of a cache entry is a handle,
			%                             |   leave it in memory.
			%
			% See also: NAMEVALUEPAIR

				leavehandle = 0;	
				assign(varargin{:});
			
				if isnumeric(index_or_key),
					index = index_or_key;
				else,
					key = index_or_key;
					index = find ( strcmp(key,{ndi_cache_obj.table.key}) & strcmp(type,{ndi_cache_obj.table.type}) );
				end

				% delete handles if needed
				if ~leavehandle, 
					for i=1:numel(index),
						if ishandle(ndi_cache_obj.table(index(i)).data)
							delete(ndi_cache_obj.table(index(i)).data);
						end;
					end
				end;
				ndi_cache_obj.table = ndi_cache_obj.table(setdiff(1:numel(ndi_cache_obj.table),index));

		end % remove

		function ndi_cache_obj = clear(ndi_cache_obj)
			% CLEAR - clear data from an NDI_CACHE
			%
			% NDI_CACHE_OBJ = CLEAR(NDI_CACHE_OBJ)
			%
			% Clears all entries from the NDI_CACHE object NDI_CACHE_OBJ.
			%
				ndi_cache_obj = ndi_cache_obj.remove(1:numel(ndi_cache_obj.table),[]);
		end % clear

		function ndi_cache_obj = freebytes(ndi_cache_obj, freebytes)
			% FREEBYTES - remove the lowest priority entries from the cache to free a certain amount of memory
			%
			% NDI_CACHE_OBJ = FREEBYTES(NDI_CACHE_OBJ, FREEBYTES)
			%
			% Remove entries to free at least FREEBYTES memory. Entries will be removed, first by PRIORITY and then by
			% the replacement_rule parameter.
			%
			% See also: NDI_CACHE/ADD, NDI_CACHE/SET_REPLACEMENT_RULE
			%
				stats = [ [ndi_cache_obj.table.priority]' [ndi_cache_obj.table.timestamp]' [ndi_cache_obj.table.bytes]' ];
				thesign = 1;
				if strcmpi(ndi_cache_obj.replacement_rule,'lifo'), 
					thesign = -1;
				end
				[y,i] = sortrows(stats,[1 thesign*2]);
				cumulative_memory_saved = cumsum([ndi_cache_obj.table(i).bytes]);
				spot = find(cumulative_memory_saved>=freebytes,1,'first'),
				if isempty(spot),
					error(['did not expect to be here.']);
				end;
				ndi_cache_obj.remove(i(1:spot),[]);
		end

		function tableentry = lookup(ndi_cache_obj, key, type)
			% LOOKUP - retrieve the NDI_CACHE data table corresponding to KEY and TYPE
			%
			% TABLEENTRY = LOOKUP(NDI_CACHE_OBJ, KEY, TYPE)
			%
			% Performs a case-sensitive lookup of the NDI_CACHE entry whose key and type
			% match KEY and TYPE. The table entry is returned. The table has fields:
			%
			% Fieldname         | Description
			% -----------------------------------------------------
			% key               | The key string
			% type              | The type string
			% timestamp         | The Matlab date stamp (serial date number, see NOW) when data was stored
			% priority          | The priority of maintaining the data (higher is better)
			% bytes             | The size of the data in this entry (bytes)
			% data              | The data stored

				index = find ( strcmp(key,{ndi_cache_obj.table.key}) & strcmp(type,{ndi_cache_obj.table.type}) );
				tableentry = ndi_cache_obj.table(index);
		end % tableentry

		function b = bytes(ndi_cache_obj)
			% BYTES - memory size of an NDI_CACHE object in bytes
			%
			% B = BYTES(NDI_CACHE_OBJ)
			%
			% Return the current memory that is occupied by the table of NDI_CACHE_OBJ.
			%
			%
				b = 0;
				if numel(ndi_cache_obj.table) > 0,
					b = sum([ndi_cache_obj.table.bytes]);
				end
		end % bytes

	end % methods
end % ndi_cache
