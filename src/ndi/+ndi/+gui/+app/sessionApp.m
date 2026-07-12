classdef sessionApp < handle
%NDI.GUI.APP.SESSIONAPP Interface for GUI apps that operate on a session.
%
%   A class marks itself as a session GUI app - one that can be launched
%   from the ndi.gui.navigator per-session "Apps" menu - by inheriting
%   from this interface and defining the constant Name property.
%
%   Contract:
%     * The class must be a handle class (this interface is a handle).
%     * The constructor must take the ndi.session as its first input:
%           obj = MyApp(sessionObj, ...)
%       Opening the app is therefore uniform: feval(className, session),
%       or ndi.gui.app.sessionApp.launch(className, session).
%     * The constant Name property supplies the menu label.
%
%   Example:
%       classdef myViewer < ndi.gui.app.sessionApp
%           properties (Constant)
%               Name = "My Viewer"
%           end
%           methods
%               function obj = myViewer(sessionObj)
%                   arguments
%                       sessionObj (1,1) ndi.session
%                   end
%                   % ... build the window ...
%               end
%           end
%       end
%
%   Discovery:
%       ndi.gui.app.sessionApp.list() scans the ndi.gui.app and ndi.app
%       packages (recursively) for concrete subclasses of this interface
%       and returns their Name and class. The navigator uses this to
%       build the Apps menu, so a new app appears automatically once it
%       adopts the interface and is on the MATLAB path - no changes to
%       the navigator are needed.
%
%   See also: ndi.gui.navigator, ndi.gui.nav.datasetsPane,
%             ndi.gui.app.spikeSorterImporter

    properties (Abstract, Constant)
        Name    % (1,1) string label shown in the session "Apps" menu
    end

    methods (Static)
        function apps = list(packages)
            %LIST Discover concrete session GUI apps on the path.
            %
            %   APPS = NDI.GUI.APP.SESSIONAPP.LIST() returns a struct array
            %   with fields:
            %       Name  - the app's display label (string)
            %       Class - the fully-qualified class name (string)
            %   for every concrete subclass of ndi.gui.app.sessionApp found
            %   in the default packages.
            %
            %   APPS = NDI.GUI.APP.SESSIONAPP.LIST(PACKAGES) scans the given
            %   packages (string array) instead of the defaults.
            arguments
                packages (1,:) string = ["ndi.gui.app", "ndi.app"]
            end

            apps  = struct('Name', {}, 'Class', {});
            names = ndi.gui.app.sessionApp.classesInPackages(packages);
            for i = 1:numel(names)
                cls = names(i);
                mc  = meta.class.fromName(char(cls));
                if isempty(mc) || mc.Abstract
                    continue;
                end
                if ~ndi.gui.app.sessionApp.isSessionApp(mc)
                    continue;
                end
                apps(end+1) = struct( ...
                    'Name',  ndi.gui.app.sessionApp.readName(mc, cls), ...
                    'Class', cls); %#ok<AGROW>
            end
        end

        function obj = launch(className, session)
            %LAUNCH Construct a session GUI app uniformly from its name.
            %
            %   NDI.GUI.APP.SESSIONAPP.LAUNCH(CLASSNAME, SESSION) calls the
            %   CLASSNAME constructor with SESSION as its first argument.
            obj = feval(char(className), session);
            if nargout == 0
                clear obj
            end
        end
    end

    methods (Static, Access = private)
        function names = classesInPackages(packages)
            %CLASSESINPACKAGES Class names in PACKAGES and their subpackages.
            names = string.empty(1, 0);
            for i = 1:numel(packages)
                try
                    mp = meta.package.fromName(char(packages(i)));
                catch
                    mp = [];
                end
                if isempty(mp)
                    continue;
                end
                if ~isempty(mp.ClassList)
                    names = [names, string({mp.ClassList.Name})]; %#ok<AGROW>
                end
                for j = 1:numel(mp.PackageList)
                    names = [names, ndi.gui.app.sessionApp.classesInPackages( ...
                        string(mp.PackageList(j).Name))]; %#ok<AGROW>
                end
            end
            names = unique(names, 'stable');
        end

        function tf = isSessionApp(mc)
            %ISSESSIONAPP True if MC derives from ndi.gui.app.sessionApp.
            tf = false;
            supers = mc.SuperclassList;
            for i = 1:numel(supers)
                if strcmp(supers(i).Name, 'ndi.gui.app.sessionApp')
                    tf = true;
                    return;
                end
                if ndi.gui.app.sessionApp.isSessionApp(supers(i))
                    tf = true;
                    return;
                end
            end
        end

        function name = readName(mc, cls)
            %READNAME Read the constant Name default without instantiating.
            name = cls;   % fallback: the class name itself
            props = mc.PropertyList;
            for i = 1:numel(props)
                if strcmp(props(i).Name, 'Name') && props(i).HasDefault
                    try
                        name = string(props(i).DefaultValue);
                    catch
                        name = cls;
                    end
                    return;
                end
            end
        end
    end
end
