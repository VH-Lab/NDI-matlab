classdef preferences < matlab.mixin.CustomDisplay & handle
%NDI.PREFERENCES Singleton store of NDI-matlab user preferences.
%
%   ndi.preferences manages a session-wide collection of user-editable
%   preferences for NDI-matlab. The class follows the singleton pattern:
%   the first reference creates the instance and loads any persisted
%   values; every subsequent reference returns the same in-memory
%   object.
%
%   Each preference is represented by an item struct with the fields:
%
%       Category     - top-level grouping (e.g. 'Cloud')
%       Subcategory  - optional second-level grouping (e.g. 'Upload'),
%                      empty char if unused
%       Name         - leaf identifier (e.g. 'Max_File_Batch_Size')
%       Value        - current value
%       DefaultValue - value used on first run and after reset()
%       Description  - human-readable explanation; the preferences
%                      editor uses this as a tooltip and ndi.preferences
%                      surfaces it via list()
%       Type         - expected MATLAB type used to coerce values when
%                      reloading from JSON. One of 'double', 'single',
%                      'logical', 'string', 'char', or 'any'.
%
%   PERSISTENCE
%       Values are stored as JSON in MATLAB's preferences directory:
%
%           fullfile(prefdir, 'NDI_Preferences.json')
%
%       The file is read once on first access and rewritten by
%       ndi.preferences.set and ndi.preferences.reset. A missing or
%       corrupt file is tolerated: defaults are used and a warning is
%       issued so the session can continue.
%
%   ACCESS
%       Most callers should use the static convenience methods rather
%       than the singleton directly:
%
%           value = ndi.preferences.get('Cloud.Upload.Max_File_Batch_Size');
%           ndi.preferences.set('Cloud.Upload.Max_File_Batch_Size', 1e9);
%           ndi.preferences.reset('Cloud.Upload.Max_File_Batch_Size');
%           ndi.preferences.reset();             % reset every preference
%           items = ndi.preferences.list();      % struct array of items
%           tf    = ndi.preferences.has('Cloud.Upload.Foo');
%           f     = ndi.preferences.filename();  % path of JSON file
%
%       The underlying object is exposed by ndi.preferences.getSingleton.
%
%   CONVENTIONS
%       Preference paths are dotted strings of the form 'Category.Name'
%       or 'Category.Subcategory.Name'. Lookups are case-sensitive.
%
%   ADDING A NEW PREFERENCE
%       Edit the private registerDefaults() method and add an
%       obj.addItem(category, subcategory, name, default, type, description)
%       call. The new preference becomes available after the next
%       MATLAB session (or after `clear classes`).
%
%   See also: ndi.gui.preferencesEditor, prefdir, jsonencode, jsondecode

    properties (Constant, Access = private)
        % Filename - absolute path of the JSON file used for persistence.
        Filename = fullfile(prefdir, 'NDI_Preferences.json')
    end

    properties (SetAccess = private)
        % Items - struct array of preference items.
        %
        %   Fields: Category, Subcategory, Name, Value, DefaultValue,
        %           Description, Type. See class help for details.
        Items struct
    end

    methods (Access = private)

        function obj = preferences()
        %PREFERENCES Construct the singleton (called only by getSingleton).
        %
        %   OBJ = PREFERENCES() initialises an empty Items array,
        %   registers the built-in defaults via registerDefaults, then
        %   overlays any values found in the on-disk JSON file via
        %   loadFromDisk. The constructor is private; external code
        %   must obtain the instance through
        %   ndi.preferences.getSingleton.
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
        %REGISTERDEFAULTS Populate Items with the built-in NDI preferences.
        %
        %   This is the canonical place to add new preferences. Each
        %   call to obj.addItem registers one item with its category,
        %   subcategory, name, default value, expected type and a
        %   short description used by ndi.preferences.list and the
        %   preferences editor.
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
        %ADDITEM Append one preference item to the Items struct array.
        %
        %   ADDITEM(OBJ, CATEGORY, SUBCATEGORY, NAME, DEFAULTVALUE, TYPE, DESCRIPTION)
        %   appends an item to OBJ.Items with both Value and
        %   DefaultValue set to DEFAULTVALUE.
        %
        %   Inputs:
        %       CATEGORY     - top-level group, scalar string
        %       SUBCATEGORY  - second-level group, scalar string
        %                      (use "" for items that have no
        %                      subcategory)
        %       NAME         - leaf identifier, scalar string
        %       DEFAULTVALUE - any value; assigned to both Value and
        %                      DefaultValue
        %       TYPE         - expected MATLAB type used by
        %                      coerceType when reloading from JSON.
        %                      One of 'double', 'single', 'logical',
        %                      'string', 'char', 'any'.
        %       DESCRIPTION  - one-line human-readable description
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
        %LOADFROMDISK Overlay persisted values onto registered defaults.
        %
        %   Called once during construction. Reads the JSON file at
        %   obj.Filename, decodes it, and copies the value of every key
        %   that matches a registered item back into Items(i).Value
        %   (after type coercion). Items not present in the file keep
        %   their default value.
        %
        %   A missing file is silently ignored (this is the first-run
        %   case). Any other error is reported via warning with
        %   identifier 'NDI:preferences:loadFailed' and defaults remain
        %   in effect.
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
        %SAVETODISK Write the current values to the JSON file.
        %
        %   Builds a flat struct keyed by ndi.preferences.itemKey and
        %   writes it to obj.Filename using jsonencode with PrettyPrint.
        %   Failures are reported via warning with identifier
        %   'NDI:preferences:saveFailed'; the in-memory state is
        %   unaffected.
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
        %FINDITEM Locate a preference by category / subcategory / name.
        %
        %   IDX = FINDITEM(OBJ, CATEGORY, SUBCATEGORY, NAME) returns the
        %   index into obj.Items of the matching item. The lookup is
        %   case-sensitive on all three fields.
        %
        %   If no item matches, an error with identifier
        %   'NDI:preferences:unknownPreference' is thrown; its message
        %   shows the dotted path that was requested.
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
        %ITEMKEY Build the JSON struct field name for an item.
        %
        %   KEY = ITEMKEY(ITEM) returns 'Category__Name' for items
        %   with no subcategory and 'Category__Subcategory__Name'
        %   otherwise. The double-underscore separator keeps the
        %   resulting name a legal MATLAB struct field, so jsonencode
        %   and jsondecode round-trip cleanly.
            if isempty(item.Subcategory)
                key = sprintf('%s__%s', item.Category, item.Name);
            else
                key = sprintf('%s__%s__%s', ...
                    item.Category, item.Subcategory, item.Name);
            end
        end

        function [category, subcategory, name] = parsePath(pathStr)
        %PARSEPATH Split a dotted preference path into its components.
        %
        %   [CATEGORY, SUBCATEGORY, NAME] = PARSEPATH(PATHSTR) splits
        %   PATHSTR on '.'. Two-part paths return SUBCATEGORY = ''.
        %   Three-part paths return all three components.
        %
        %   Any other shape raises an error with identifier
        %   'NDI:preferences:invalidPath'.
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
        %COERCETYPE Convert a JSON-decoded value back to its declared type.
        %
        %   VALUE = COERCETYPE(RAWVALUE, TYPENAME) attempts to cast
        %   RAWVALUE to TYPENAME ('double', 'single', 'logical',
        %   'string', or 'char'). 'any' or an empty TYPENAME passes
        %   the value through unchanged. Any conversion failure also
        %   returns RAWVALUE unchanged so a corrupt or unexpected JSON
        %   payload does not break the session.
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
        %NDI.PREFERENCES.GETSINGLETON Return the shared preferences object.
        %
        %   OBJ = NDI.PREFERENCES.GETSINGLETON() returns the one and
        %   only ndi.preferences instance for the current MATLAB
        %   session. The first call constructs the object (which
        %   loads the JSON file from disk); later calls reuse it.
        %
        %   Most code should prefer the static get/set/reset/list/has
        %   helpers; use getSingleton when you need direct access to
        %   the Items struct array (for example to drive a UI).
        %
        %   See also: ndi.preferences.get, ndi.preferences.set,
        %             ndi.preferences.list
            persistent objStore
            if isempty(objStore) || ~isvalid(objStore)
                objStore = ndi.preferences();
            end
            obj = objStore;
        end

        function value = get(pathStr)
        %NDI.PREFERENCES.GET Return the value of a preference.
        %
        %   VALUE = NDI.PREFERENCES.GET(PATHSTR) returns the current
        %   value of the preference identified by the dotted path
        %   PATHSTR.
        %
        %   PATHSTR must have the form 'Category.Name' or
        %   'Category.Subcategory.Name'. The lookup is case-sensitive.
        %
        %   Errors:
        %       'NDI:preferences:invalidPath'       - path is not
        %                                             two- or
        %                                             three-part
        %       'NDI:preferences:unknownPreference' - no matching
        %                                             item is
        %                                             registered
        %
        %   Example:
        %       v = ndi.preferences.get('Cloud.Upload.Max_File_Batch_Size');
        %
        %   See also: ndi.preferences.set, ndi.preferences.has,
        %             ndi.preferences.list
            arguments
                pathStr (1,1) string
            end
            obj = ndi.preferences.getSingleton();
            [category, subcategory, name] = ndi.preferences.parsePath(pathStr);
            idx = obj.findItem(category, subcategory, name);
            value = obj.Items(idx).Value;
        end

        function set(pathStr, value)
        %NDI.PREFERENCES.SET Update a preference and persist the change.
        %
        %   NDI.PREFERENCES.SET(PATHSTR, VALUE) assigns VALUE to the
        %   preference identified by the dotted path PATHSTR and
        %   immediately rewrites the JSON file on disk so the change
        %   survives the next MATLAB session.
        %
        %   No type validation is performed: the value is stored
        %   verbatim. (The Type field on the item is metadata used
        %   only when reloading the file.) Validation can be added in
        %   the future without changing the public signature.
        %
        %   Errors:
        %       'NDI:preferences:invalidPath'       - path is not
        %                                             two- or
        %                                             three-part
        %       'NDI:preferences:unknownPreference' - no matching
        %                                             item is
        %                                             registered
        %       'NDI:preferences:saveFailed'        - issued as a
        %                                             warning if the
        %                                             JSON file
        %                                             cannot be
        %                                             written
        %
        %   Example:
        %       ndi.preferences.set('Cloud.Upload.Max_File_Batch_Size', 1e9);
        %
        %   See also: ndi.preferences.get, ndi.preferences.reset
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
        %NDI.PREFERENCES.RESET Restore preference defaults.
        %
        %   NDI.PREFERENCES.RESET() restores every preference to its
        %   registered DefaultValue and rewrites the JSON file.
        %
        %   NDI.PREFERENCES.RESET(PATHSTR) restores only the single
        %   preference identified by PATHSTR ('Category.Name' or
        %   'Category.Subcategory.Name').
        %
        %   Errors:
        %       'NDI:preferences:invalidPath'       - path is not
        %                                             two- or
        %                                             three-part
        %       'NDI:preferences:unknownPreference' - no matching
        %                                             item is
        %                                             registered
        %
        %   Example:
        %       ndi.preferences.reset();
        %       ndi.preferences.reset('Cloud.Download.Max_Document_Batch_Count');
        %
        %   See also: ndi.preferences.set, ndi.preferences.list
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
        %NDI.PREFERENCES.LIST Return all registered preference items.
        %
        %   INFO = NDI.PREFERENCES.LIST() returns the full struct
        %   array of preference items (a copy of the singleton's
        %   Items property). See the class help for the field
        %   layout. The result is a snapshot; modifying it does not
        %   change the underlying preferences.
        %
        %   Use this method to drive a UI (for example
        %   ndi.gui.preferencesEditor) or to enumerate every
        %   preference and its description.
        %
        %   See also: ndi.preferences.has, ndi.preferences.get
            obj = ndi.preferences.getSingleton();
            info = obj.Items;
        end

        function tf = has(pathStr)
        %NDI.PREFERENCES.HAS True if a preference path is registered.
        %
        %   TF = NDI.PREFERENCES.HAS(PATHSTR) returns true if PATHSTR
        %   identifies a registered preference and false otherwise.
        %   Unlike NDI.PREFERENCES.GET this method never errors:
        %   malformed paths simply return false.
        %
        %   Example:
        %       if ndi.preferences.has('Cloud.Upload.Max_File_Batch_Size')
        %           ...
        %       end
        %
        %   See also: ndi.preferences.get, ndi.preferences.list
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
        %NDI.PREFERENCES.FILENAME Path of the on-disk preferences file.
        %
        %   PATH = NDI.PREFERENCES.FILENAME() returns the absolute
        %   path of the JSON file used to persist the preferences,
        %   typically fullfile(prefdir, 'NDI_Preferences.json').
        %   The file may not yet exist on first run.
        %
        %   See also: prefdir, ndi.preferences.getSingleton
            path = ndi.preferences.getSingleton().Filename;
        end

    end

    methods (Access = protected)

        function str = getHeader(obj) %#ok<MANU>
        %GETHEADER Custom header for the command-window display.
        %
        %   Overrides matlab.mixin.CustomDisplay/getHeader to render
        %   a clickable link to `help ndi.preferences` above the
        %   property groups produced by getPropertyGroups.
            link = sprintf('<a href="matlab:help ndi.preferences" style="font-weight:bold">%s</a>', 'ndi.preferences');
            str = sprintf('NDI preferences (%s):\n', link);
        end

        function groups = getPropertyGroups(obj)
        %GETPROPERTYGROUPS Group preference items by Category for display.
        %
        %   Overrides matlab.mixin.CustomDisplay/getPropertyGroups so
        %   `disp(ndi.preferences.getSingleton())` renders one
        %   PropertyGroup per Category, with each item shown as
        %   either Name or Subcategory_Name = Value. This is the
        %   command-window companion to ndi.gui.preferencesEditor.
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
