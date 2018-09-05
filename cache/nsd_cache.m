classdef nsd_cache < handle
% NSD_CACHE - Cache class for NSD
%
% 

	properties (SetAccess=protected,GetAccess=public)
		maxMemory % The maximum memory, in bytes, that can be consumed by an NSD_CACHE before it is emptied
		replacement_rule % The rule to be used to replace entries when memory is exceeded ('FIFO','LIFO','error', etc)
		table  % The variable that has the data and metadata for the cache
	end % properties

	properties (SetAccess=protected,GetAccess=private)
	end


	methods
		
		function nsd_cache_obj = nsd_cache(varargin)
			% NSD_CACHE - create a new NSD cache handle
			%
			% NSD_CACHE_OBJ = NSD_CACHE(...)
			%
			% Creates a new NSD_CACHE object. Additional arguments can be specified as
			% name value pairs:
			%
			% Parameter (default)         | Description
			% ------------------------------------------------------------
			% maxMemory (1e9)             | Max memory for cache, in bytes
			% replacement_rule ('fifo')   | Replacement rule (see NSD_CACHE/SET_REPLACEMENT_RULE
			%
			% Note that the cache is not 'secure', any function can query the data added.
			%
			% See also: NAMEVALUEPAIR

				maxMemory = 1e9;
				replacement_rule = 'fifo';

				assign(varargin{:});

				if nargin==0,
					nsd_cache_obj.maxMemory = maxMemory;
					nsd_cache_obj.replacement_rule = replacement_rule;
					nsd_cache_obj.table = emptystruct('key','type','timestamp','priority','bytes','data')
					return;
				end;

				nsd_cache_obj = nsd_cache();

				nsd_cache_obj.maxMemory = maxMemory;
				nsd_cache_obj = set_replacement_rule(nsd_cache_obj,replacement_rule);

		end % nsd_cache creator

		function nsd_cache_obj = set_replacement_rule(nsd_cache_obj, rule)
			% SET_REPLACEMENT_RULE - set the replacement rule for an NSD_CACHE object
			%
			% NSD_CACHE_OBJ = SET_REPLACEMENT_RULE(NSD_CACHE_OBJ, RULE)
			%
			% Sets the replacement rule for an NSD_CACHE to be used when a new entry
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
					nsd_cache_obj.replacement_rule = lower(rule);
				else,
					error(['Unknown replacement rule requested: ' rule '.']);
				end
		end % set_replacement_rule

		function nsd_cache_obj = add(nsd_cache_obj, key, type, data, priority)
			% ADD - add data to an NSD_CACHE
			%
			% NSD_CACHE_OBJ = ADD(NSD_CACHE_OBJ, KEY, TYPE, DATA, [PRIORITY])
			%
			% Adds DATA to the NSD_CACHE_OBJ that is referenced by a KEY and TYPE.
			% If desired, a PRIORITY can be added; items with greatest PRIORITY will be
			% deleted last.
			%
				if nargin < 5,
					priority = 0;
				end

				% before we reorganize anything, make sure it will fit
				s = whos('data');
				if s.bytes > nsd_cache_obj.maxMemory,
					error(['This variable is too large to fit in the cache; cache''s maxMemory exceeded.']);
				end

				total_memory = nsd_cache_obj.bytes() + s.bytes;
				if total_memory > nsd_cache_obj.maxMemory, % it doesn't fit
					if strcmpi(nsd_cache_obj.replacement_rule,'error'),
						error(['Cache is too full too accommodate the new data; error was requested rather than replacement.']);
					end
					freespaceneeded = total_memory - nsd_cache_obj.maxMemory;
					nsd_cache_obj.freebytes(freespaceneeded);
				end

				% now there's room
				newentry = emptystruct('key','type','timestamp','priority','bytes','data');
				newentry(1).key = key;
				newentry(1).type = type;
				newentry(1).timestamp = now; % serial date number
				newentry(1).priority = priority;
				newentry(1).bytes = s.bytes;
				newentry(1).data = data;

				nsd_cache_obj.table(end+1) = newentry;
		end % add

		function nsd_cache_obj = remove(nsd_cache_obj, index_or_key, type, varargin)
			% REMOVE - remove data from an NSD_CACHE
			%
			% NSD_CACHE_OBJ = REMOVE(NSD_CACHE_OBJ, KEY, TYPE, ...)
			%   or
			% NSD_CACHE_OBJ = REMOVE(NSD_CACHE_OBJ, INDEX, [],  ...)
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
					index = find ( strcmp(key,{nsd_cache_obj.table.key}) & strcmp(type,{nsd_cache_obj.table.type}) );
				end

				% delete handles if needed
				if ~leavehandle, 
					for i=1:numel(index),
						if ishandle(nsd_cache_obj.table(index(i)).data)
							delete(nsd_cache_obj.table(index(i)).data);
						end;
					end
				end;
				nsd_cache_obj.table = nsd_cache_obj.table(setdiff(1:numel(nsd_cache_obj.table),index));

		end % remove

		function nsd_cache_obj = clear(nsd_cache_obj)
			% CLEAR - clear data from an NSD_CACHE
			%
			% NSD_CACHE_OBJ = CLEAR(NSD_CACHE_OBJ)
			%
			% Clears all entries from the NSD_CACHE object NSD_CACHE_OBJ.
			%
				nsd_cache_obj = nsd_cache_obj.remove(1:numel(nsd_cache_obj.table),[]);
		end % clear

		function nsd_cache_obj = freebytes(nsd_cache_obj, freebytes)
			% FREEBYTES - remove the lowest priority entries from the cache to free a certain amount of memory
			%
			% NSD_CACHE_OBJ = FREEBYTES(NSD_CACHE_OBJ, FREEBYTES)
			%
			% Remove entries to free at least FREEBYTES memory. Entries will be removed, first by PRIORITY and then by
			% the replacement_rule parameter.
			%
			% See also: NSD_CACHE/ADD, NSD_CACHE/SET_REPLACEMENT_RULE
			%
				stats = [ [nsd_cache_obj.table.priority]' [nsd_cache_obj.table.timestamp]' [nsd_cache_obj.table.bytes]' ];
				thesign = 1;
				if strcmpi(nsd_cache_obj.replacement_rule,'lifo'), 
					thesign = -1;
				end
				[y,i] = sortrows(stats,[1 thesign*2]);
				cumulative_memory_saved = cumsum([nsd_cache_obj.table(i).bytes]);
				spot = find(cumulative_memory_saved>=freebytes,1,'first'),
				if isempty(spot),
					error(['did not expect to be here.']);
				end;
				nsd_cache_obj.remove(i(1:spot),[]);
		end

		function tableentry = lookup(nsd_cache_obj, key, type)
			% LOOKUP - retrieve the NSD_CACHE data table corresponding to KEY and TYPE
			%
			% TABLEENTRY = LOOKUP(NSD_CACHE_OBJ, KEY, TYPE)
			%
			% Performs a case-sensitive lookup of the NSD_CACHE entry whose key and type
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

				index = find ( strcmp(key,{nsd_cache_obj.table.key}) & strcmp(type,{nsd_cache_obj.table.type}) );
				tableentry = nsd_cache_obj.table(index);
		end % tableentry

		function b = bytes(nsd_cache_obj)
			% BYTES - memory size of an NSD_CACHE object in bytes
			%
			% B = BYTES(NSD_CACHE_OBJ)
			%
			% Return the current memory that is occupied by the table of NSD_CACHE_OBJ.
			%
			%
				b = 0;
				if numel(nsd_cache_obj.table) > 0,
					b = sum([nsd_cache_obj.table.bytes]);
				end
		end % bytes

	end % methods
end % nsd_cache
