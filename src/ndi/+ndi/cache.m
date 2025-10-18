classdef cache < handle
    % NDI.CACHE - Cache class for NDI
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

        function ndi_cache_obj = cache(options)
            % CACHE - create a new NDI cache handle
            %
            % NDI_CACHE_OBJ = NDI.CACHE(...)
            %
            % Creates a new NDI.CACHE object. Additional arguments can be specified as
            % name value pairs:
            %
            % Parameter (default)         | Description
            % ------------------------------------------------------------
            % maxMemory (10e9)            | Max memory for cache, in bytes (10GB default)
            % replacement_rule ('fifo')   | Replacement rule (see NDI_CACHE/SET_REPLACEMENT_RULE
            %
            % Note that the cache is not 'secure', any function can query the data added.
            %
            % See also: vlt.data.namevaluepair
            arguments
                options.maxMemory (1,1) double = 10e9;
                options.replacement_rule (1,:) char = 'fifo';
            end

            ndi_cache_obj.table = vlt.data.emptystruct('key','type','timestamp','priority','bytes','data');
            ndi_cache_obj.maxMemory = options.maxMemory;
            ndi_cache_obj = set_replacement_rule(ndi_cache_obj,options.replacement_rule);

        end % ndi_cache creator

        function ndi_cache_obj = set_replacement_rule(ndi_cache_obj, rule)
            % SET_REPLACEMENT_RULE - set the replacement rule for an NDI_CACHE object
            %
            % NDI_CACHE_OBJ = SET_REPLACEMENT_RULE(NDI_CACHE_OBJ, RULE)
            %
            % Sets the replacement rule for an NDI.CACHE to be used when a new entry
            % would exceed the allowed memory. The rule may be one of the following strings
            % (case is insensitive and will be stored lower case):
            %
            % Rule            | Description
            % ---------------------------------------------------------
            % 'fifo'          | First in, first out; discard oldest entries first.
            % 'lifo'          | Last in, first out; discard newest entries first.
            % 'error'         | Don't discard anything, just produce an error saying cache is full
            arguments
                ndi_cache_obj (1,1) ndi.cache
                rule (1,:) char
            end
            therules = {'fifo','lifo','error'};
            if ~any(strcmpi(rule,therules))
                error(['Unknown replacement rule requested: ' rule '. Must be one of ' vlt.string.cellstr2str(therules) '.']);
            end
            ndi_cache_obj.replacement_rule = lower(rule);
        end % set_replacement_rule

        function ndi_cache_obj = add(ndi_cache_obj, key, type, data, options)
            % ADD - add data to an NDI.CACHE
            %
            % NDI_CACHE_OBJ = ADD(NDI_CACHE_OBJ, KEY, TYPE, DATA, 'priority', PRIORITY)
            %
            % Adds DATA to the NDI_CACHE_OBJ that is referenced by a KEY and TYPE.
            % If desired, a PRIORITY can be added; items with greatest PRIORITY will be
            % deleted last.
            %
            arguments
                ndi_cache_obj (1,1) ndi.cache
                key (1,:) char
                type (1,:) char
                data
                options.priority (1,1) double = 0
            end

            % before we reorganize anything, make sure it will fit
            s = whos('data');
            if s.bytes > ndi_cache_obj.maxMemory
                error(['This variable is too large to fit in the cache; cache''s maxMemory exceeded.']);
            end

            newentry = vlt.data.emptystruct('key','type','timestamp','priority','bytes','data');
            newentry(1).key = key;
            newentry(1).type = type;
            newentry(1).timestamp = now; % serial date number
            newentry(1).priority = options.priority;
            newentry(1).bytes = s.bytes;
            newentry(1).data = data;

            total_memory = ndi_cache_obj.bytes() + s.bytes;
            if total_memory > ndi_cache_obj.maxMemory % it doesn't fit
                if strcmpi(ndi_cache_obj.replacement_rule,'error')
                    error(['Cache is too full too accommodate the new data; error was requested rather than replacement.']);
                end
                freespaceneeded = total_memory - ndi_cache_obj.maxMemory;
                [inds_to_remove, is_new_item_safe_to_add] = ndi_cache_obj.evaluateItemsForRemoval(freespaceneeded, newentry);
                if is_new_item_safe_to_add,
                    ndi_cache_obj.remove(inds_to_remove,[]);
                    ndi_cache_obj.table(end+1) = newentry;
                end;
            else
                % now there's room
                ndi_cache_obj.table(end+1) = newentry;
            end
        end % add

        function ndi_cache_obj = remove(ndi_cache_obj, index_or_key, type, options)
            % REMOVE - remove data from an NDI.CACHE
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
            % leavehandle (false)         | If the 'data' field of a cache entry is a handle,
            %                             |   leave it in memory.
            %
            arguments
                ndi_cache_obj (1,1) ndi.cache
                index_or_key
                type (1,:) char = ''
                options.leavehandle (1,1) logical = false
            end

            if isnumeric(index_or_key)
                index = index_or_key;
            else
                key = index_or_key;
                if isempty(type)
                    error('The "type" must be provided when removing by key.');
                end
                index = find ( strcmp(key,{ndi_cache_obj.table.key}) & strcmp(type,{ndi_cache_obj.table.type}) );
            end

            % delete handles if needed
            if ~options.leavehandle
                for i=1:numel(index)
                    if ishandle(ndi_cache_obj.table(index(i)).data)
                        delete(ndi_cache_obj.table(index(i)).data);
                    end
                end
            end
            ndi_cache_obj.table = ndi_cache_obj.table(setdiff(1:numel(ndi_cache_obj.table),index));

        end % remove

        function ndi_cache_obj = clear(ndi_cache_obj)
            % CLEAR - clear data from an NDI.CACHE
            %
            % NDI_CACHE_OBJ = CLEAR(NDI_CACHE_OBJ)
            %
            % Clears all entries from the NDI.CACHE object NDI_CACHE_OBJ.
            % Also clears all memoized caches (CLEARALLMEMOIZEDCACHES).
            %
            arguments
                ndi_cache_obj (1,1) ndi.cache
            end
            ndi_cache_obj = ndi_cache_obj.remove(1:numel(ndi_cache_obj.table),[]);
            clearAllMemoizedCaches;
            clear memoize;
        end % clear

        function [inds_to_remove, is_new_item_safe_to_add] = evaluateItemsForRemoval(ndi_cache_obj, freebytes, newitem)
            % EVALUATEITEMSFORREMOVAL - decide which items to remove from the cache to free memory
            %
            % [INDS_TO_REMOVE, IS_NEW_ITEM_SAFE_TO_ADD] = EVALUATEITEMSFORREMOVAL(NDI_CACHE_OBJ, FREEBYTES, [NEWITEM])
            %
            % Decide which entries to remove to free at least FREEBYTES memory. Entries will be removed, first by PRIORITY and then by
            % the replacement_rule parameter.
            %
            % If NEWITEM is provided (a structure with fields 'priority','timestamp','bytes'), it is as if that item
            % is already in the cache for the purposes of deciding what to remove.
            %
            % See also: ndi.cache/add, ndi.cache/set_replacement_rule
            %
            arguments
                ndi_cache_obj (1,1) ndi.cache
                freebytes (1,1) double {mustBePositive}
                newitem (1,1) struct = vlt.data.emptystruct('priority','timestamp','bytes','data','key','type')
            end

            if nargin > 2,
                table_plus_new = cat(2,ndi_cache_obj.table,newitem);
            else,
                table_plus_new = ndi_cache_obj.table;
            end;

            stats = [ [table_plus_new.priority]' [table_plus_new.timestamp]' (1:numel(table_plus_new))' [table_plus_new.bytes]' ];
            thesign = 1;
            if strcmpi(ndi_cache_obj.replacement_rule,'lifo')
                thesign = -1;
            end
            [y,i] = sortrows(stats,[1 thesign*2 thesign*3]);
            cumulative_memory_saved = cumsum([table_plus_new(i).bytes]);
            spot = find(cumulative_memory_saved>=freebytes,1,'first');
            if isempty(spot)
                error(['did not expect to be here.']);
            end;
            inds_to_remove_all = i(1:spot);

            is_new_item_safe_to_add = ~any(inds_to_remove_all==numel(table_plus_new));

            % we can only remove items that are actually in the cache
            inds_to_remove = inds_to_remove_all(find(inds_to_remove_all<=numel(ndi_cache_obj.table)));
        end

        function tableentry = lookup(ndi_cache_obj, key, type)
            % LOOKUP - retrieve the NDI.CACHE data table corresponding to KEY and TYPE
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
            arguments
                ndi_cache_obj (1,1) ndi.cache
                key (1,:) char
                type (1,:) char
            end
            index = find ( strcmp(key,{ndi_cache_obj.table.key}) & strcmp(type,{ndi_cache_obj.table.type}) );
            tableentry = ndi_cache_obj.table(index);
        end % tableentry

        function b = bytes(ndi_cache_obj)
            % BYTES - memory size of an NDI.CACHE object in bytes
            %
            % B = BYTES(NDI_CACHE_OBJ)
            %
            % Return the current memory that is occupied by the table of NDI_CACHE_OBJ.
            %
            %
            arguments
                ndi_cache_obj (1,1) ndi.cache
            end
            b = 0;
            if numel(ndi_cache_obj.table) > 0
                b = sum([ndi_cache_obj.table.bytes]);
            end
        end % bytes

    end % methods
end % ndi.cache