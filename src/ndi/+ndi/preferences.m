classdef preferences < matlab.mixin.CustomDisplay & handle
    % NDI.PREFERENCES - singleton holding NDI-matlab user preferences.
    %
    % Preferences are organised into Category / Subcategory / Name groups.
    % Each item carries a default value, a human-readable description and
    % an expected MATLAB type, so categories and documentation travel with
    % the value (which makes a future preference editor straightforward).
    %
    % The first call to ndi.preferences.getSingleton (directly or via the
    % static get/set/reset helpers) loads the stored values from a JSON
    % file in MATLAB's prefdir. Subsequent calls return the same in-memory
    % instance. Any change made through `set` or `reset` is written back
    % to disk immediately.
    %
    % Examples:
    %
    %   v = ndi.preferences.get('Cloud.Upload.Max_Document_Batch_Count');
    %   ndi.preferences.set('Cloud.Upload.Max_Document_Batch_Count', 50000);
    %   ndi.preferences.reset('Cloud.Upload.Max_Document_Batch_Count');
    %   info  = ndi.preferences.list();          % struct array of all items
    %   prefs = ndi.preferences.getSingleton();  % the underlying object
    %
    % See also: prefdir, jsonencode, jsondecode

    properties (Constant, Access = private)
        Filename = fullfile(prefdir, 'NDI_Preferences.json')
    end

    properties (SetAccess = private)
        % Items - struct array of preference items.
        % Fields: Category, Subcategory, Name, Value, DefaultValue,
        %         Description, Type.
        Items struct
    end

    methods (Access = private)

        function obj = preferences()
            obj.Items = struct( ...
                'Category',     {}, ...
                'Subcategory',  {}, ...
                'Name',         {}, ...
                'Value',        {}, ...
                'DefaultValue', {}, ...
                'Description',  {}, ...
                'Type',         {});
            obj.registerDefaults();
            obj.loadFromDisk();
        end

        function registerDefaults(obj)
            % Built-in NDI preferences. Add new items here.
            obj.addItem('Cloud', 'Download', 'Max_Document_Batch_Count', ...
                10000, 'double', ...
                'Maximum number of documents downloaded per batch.');
            obj.addItem('Cloud', 'Upload', 'Max_Document_Batch_Count', ...
                100000, 'double', ...
                'Maximum number of documents uploaded per batch.');
            obj.addItem('Cloud', 'Upload', 'Max_File_Batch_Size', ...
                500e6, 'double', ...
                'Maximum size of file batch upload in bytes (default 500 MB).');
        end

        function addItem(obj, category, subcategory, name, defaultValue, type, description)
            arguments
                obj
                category     (1,1) string
                subcategory  (1,1) string
                name         (1,1) string
                defaultValue
                type         (1,1) string
                description  (1,1) string
            end
            item = struct( ...
                'Category',     char(category), ...
                'Subcategory',  char(subcategory), ...
                'Name',         char(name), ...
                'Value',        defaultValue, ...
                'DefaultValue', defaultValue, ...
                'Description',  char(description), ...
                'Type',         char(type));
            obj.Items(end+1) = item;
        end

        function loadFromDisk(obj)
            if ~isfile(obj.Filename)
                return
            end
            try
                txt = fileread(obj.Filename);
                if isempty(strtrim(txt))
                    return
                end
                S = jsondecode(txt);
                for i = 1:numel(obj.Items)
                    key = ndi.preferences.itemKey(obj.Items(i));
                    if isfield(S, key)
                        obj.Items(i).Value = ndi.preferences.coerceType( ...
                            S.(key), obj.Items(i).Type);
                    end
                end
            catch ME
                warning('NDI:preferences:loadFailed', ...
                    'Could not load preferences from %s: %s', ...
                    obj.Filename, ME.message);
            end
        end

        function saveToDisk(obj)
            S = struct();
            for i = 1:numel(obj.Items)
                key = ndi.preferences.itemKey(obj.Items(i));
                S.(key) = obj.Items(i).Value;
            end
            try
                txt = jsonencode(S, 'PrettyPrint', true);
                fid = fopen(obj.Filename, 'w');
                if fid < 0
                    error('NDI:preferences:saveFailed', ...
                        'Could not open %s for writing.', obj.Filename);
                end
                cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
                fwrite(fid, txt, 'char');
            catch ME
                warning('NDI:preferences:saveFailed', ...
                    'Could not save preferences to %s: %s', ...
                    obj.Filename, ME.message);
            end
        end

        function idx = findItem(obj, category, subcategory, name)
            mask = strcmp({obj.Items.Category},    category) & ...
                   strcmp({obj.Items.Subcategory}, subcategory) & ...
                   strcmp({obj.Items.Name},        name);
            idx = find(mask, 1, 'first');
            if isempty(idx)
                if isempty(subcategory)
                    pathStr = sprintf('%s.%s', category, name);
                else
                    pathStr = sprintf('%s.%s.%s', category, subcategory, name);
                end
                error('NDI:preferences:unknownPreference', ...
                    'Unknown preference "%s".', pathStr);
            end
        end

    end

    methods (Static, Access = private)

        function key = itemKey(item)
            % Flatten Category[/Subcategory]/Name into a single struct field
            % name so jsonencode/jsondecode round-trips cleanly.
            if isempty(item.Subcategory)
                key = sprintf('%s__%s', item.Category, item.Name);
            else
                key = sprintf('%s__%s__%s', ...
                    item.Category, item.Subcategory, item.Name);
            end
        end

        function [category, subcategory, name] = parsePath(pathStr)
            parts = split(string(pathStr), ".");
            switch numel(parts)
                case 2
                    category    = char(parts(1));
                    subcategory = '';
                    name        = char(parts(2));
                case 3
                    category    = char(parts(1));
                    subcategory = char(parts(2));
                    name        = char(parts(3));
                otherwise
                    error('NDI:preferences:invalidPath', ...
                        ['Preference path must be Category.Name or ' ...
                         'Category.Subcategory.Name (got "%s").'], pathStr);
            end
        end

        function value = coerceType(rawValue, typeName)
            % Coerce decoded JSON values back to the expected MATLAB type.
            % Falls through to the raw value on any conversion failure.
            if isempty(typeName) || strcmp(typeName, 'any')
                value = rawValue;
                return
            end
            try
                switch typeName
                    case 'logical'
                        value = logical(rawValue);
                    case {'double', 'single'}
                        value = cast(rawValue, typeName);
                    case 'string'
                        value = string(rawValue);
                    case 'char'
                        if isstring(rawValue) || iscellstr(rawValue)
                            value = char(rawValue);
                        else
                            value = rawValue;
                        end
                    otherwise
                        value = rawValue;
                end
            catch
                value = rawValue;
            end
        end

    end

    methods (Static)

        function obj = getSingleton()
            % GETSINGLETON - return the shared ndi.preferences instance.
            persistent objStore
            if isempty(objStore) || ~isvalid(objStore)
                objStore = ndi.preferences();
            end
            obj = objStore;
        end

        function value = get(pathStr)
            % GET - return the value of a preference by dotted path.
            %
            %   value = ndi.preferences.get('Cloud.Upload.Max_File_Batch_Size')
            arguments
                pathStr (1,1) string
            end
            obj = ndi.preferences.getSingleton();
            [category, subcategory, name] = ndi.preferences.parsePath(pathStr);
            idx = obj.findItem(category, subcategory, name);
            value = obj.Items(idx).Value;
        end

        function set(pathStr, value)
            % SET - assign a value to a preference and persist it to disk.
            %
            %   ndi.preferences.set('Cloud.Upload.Max_File_Batch_Size', 1e9)
            arguments
                pathStr (1,1) string
                value
            end
            obj = ndi.preferences.getSingleton();
            [category, subcategory, name] = ndi.preferences.parsePath(pathStr);
            idx = obj.findItem(category, subcategory, name);
            obj.Items(idx).Value = value;
            obj.saveToDisk();
        end

        function reset(pathStr)
            % RESET - revert a preference, or all preferences, to defaults.
            %
            %   ndi.preferences.reset()                        % reset all
            %   ndi.preferences.reset('Cloud.Download.Max_Document_Batch_Count')
            arguments
                pathStr string = string.empty
            end
            obj = ndi.preferences.getSingleton();
            if isempty(pathStr)
                for i = 1:numel(obj.Items)
                    obj.Items(i).Value = obj.Items(i).DefaultValue;
                end
            else
                [category, subcategory, name] = ndi.preferences.parsePath(pathStr);
                idx = obj.findItem(category, subcategory, name);
                obj.Items(idx).Value = obj.Items(idx).DefaultValue;
            end
            obj.saveToDisk();
        end

        function info = list()
            % LIST - return the struct array of all preference items.
            obj = ndi.preferences.getSingleton();
            info = obj.Items;
        end

        function tf = has(pathStr)
            % HAS - true if the given preference path is registered.
            arguments
                pathStr (1,1) string
            end
            try
                [category, subcategory, name] = ndi.preferences.parsePath(pathStr);
            catch
                tf = false;
                return
            end
            obj = ndi.preferences.getSingleton();
            mask = strcmp({obj.Items.Category},    category) & ...
                   strcmp({obj.Items.Subcategory}, subcategory) & ...
                   strcmp({obj.Items.Name},        name);
            tf = any(mask);
        end

        function path = filename()
            % FILENAME - return the path to the on-disk preferences JSON file.
            path = ndi.preferences.getSingleton().Filename;
        end

    end

    methods (Access = protected)

        function str = getHeader(obj) %#ok<MANU>
            link = sprintf('<a href="matlab:help ndi.preferences" style="font-weight:bold">%s</a>', 'ndi.preferences');
            str = sprintf('NDI preferences (%s):\n', link);
        end

        function groups = getPropertyGroups(obj)
            % Group items by Category for a tidy command-window display.
            groups = matlab.mixin.util.PropertyGroup.empty;
            if isempty(obj.Items)
                return
            end
            cats = unique({obj.Items.Category}, 'stable');
            for ci = 1:numel(cats)
                cat   = cats{ci};
                mask  = strcmp({obj.Items.Category}, cat);
                items = obj.Items(mask);
                s = struct();
                for i = 1:numel(items)
                    if isempty(items(i).Subcategory)
                        fname = items(i).Name;
                    else
                        fname = sprintf('%s_%s', items(i).Subcategory, items(i).Name);
                    end
                    s.(fname) = items(i).Value;
                end
                groups(end+1) = matlab.mixin.util.PropertyGroup(s, cat); %#ok<AGROW>
            end
        end

    end
end
