classdef ProgressBarWindow < matlab.apps.AppBase
    %ProgressBarWindow Creates and manages a progress bar figure.
    %
    %   This class provides a graphical user interface (GUI) to display
    %   one or more progress bars in a single figure. It allows for adding,
    %   updating, and removing progress bars dynamically. Each bar displays
    %   progress as a percentage, a visual bar, an estimated time remaining,
    %   and provides a button to close it. The window can be configured to 
    %   automatically close bars upon completion or timeout.
    %
    %   Usage Example 1:
    %       app = ndi.gui.component.ProgressBarWindow('Import Dataset'); % Create a window
    %       app.addBar('Label','Create Session(s)','Tag','session'); % Add a bar
    %       app.updateBar('session',0.5); % Update the bar's progress
    %
    %   Usage Example 2 (auto close, uuid):
    %       app = ndi.gui.component.ProgressBarWindow(); % Create a window
    %       uuid = did.ido.unique;
    %       app.addBar('Label','Save document(s)','Tag',uuid,'Auto',true); % Add a bar
    %       app.updateBar(uuid,0.5) % Update the bar's progress
    %
    %   See also: uifigure, uigridlayout, uiaxes, patch, uilabel, uibutton

    properties (Hidden)
        ScreenFrac double = 0.025 % Fraction of screen height used per bar row.
        IconClose char = fullfile(ndi.common.PathConstants.RootFolder,...
            '+ndi','+gui','close_icon.svg') % Path to the close icon. Update if needed
        ProgressFigureListener % Listens for changes to the figure.
        ProgressGridListener % Listens for changes to the grid layout.
        ProgressBarListener % Listens for changes to the progress bar data.
        Timeout duration = minutes(1) % Time after last update before a bar times out.
        AutoDelete logical = true % Flag to automatically delete the ProgressBarWindow if all bars are closed.
    end

    properties (SetObservable)
        ProgressFigure matlab.ui.Figure  % Handle to the main GUI figure.
        ProgressGrid matlab.ui.container.GridLayout % Handle to the grid managing the layout.
        ProgressBars struct % Array storing data and handles for each progress bar.
    end

    properties (SetAccess=immutable, GetAccess=private)
        Visible (1,1) matlab.lang.OnOffSwitchState = "on"
    end

    methods
        function app = ProgressBarWindow(title,options)
            %ProgressBarWindow Constructor for the progress bar window.
            %
            %   APP = PROGRESSBARWINDOW(TITLE, OPTIONS) creates a new 
            %   progress bar window or returns a handle to an existing one.
            %
            %   Inputs:
            %       title - The title to display on the figure window.
            %                   Defaults to ''.
            %
            %   Optional Name-Value Arguments:
            %       Overwrite - If true, closes any existing progress bar window
            %                   with the same title. If false, returns the handle
            %                   to the existing window. Defaults to false.
            %       GrabMostRecent - If true, will search open figures for the
            %                   most recently created progress bar window. Uses
            %                   this handle if no figure with matching title is
            %                   found or IgnoreTitle is true. Defaults to true.
            %       IgnoreTitle - If true, will return the most recently created
            %                   progress bar window regardless of its title.
            %                   Defaults to false.
            %       AutoDelete - If true, automatically closes the progress bar
            %                   figure and deletes the app handle when there are
            %                   no more progress bars remaining in the window.
            %                   Defaults to true.
            %
            %   Outputs:
            %       app - The handle to the created or existing app instance.

            % Input argument validation
            arguments
                title (1,:) char = ''
                options.Overwrite logical = false
                options.GrabMostRecent logical = true
                options.IgnoreTitle logical = false
                options.AutoDelete logical = true
                options.Visible (1,1) matlab.lang.OnOffSwitchState = "on"
            end


            % Find existing figure with that tag
            openFigs = findall(groot,'Type','figure','tag','progressbar');
            if ~isempty(openFigs)

                % Check for figure with same title
                ind = strcmpi({openFigs.Name},title);

                % If no title (or ignoring it), try most recent figure 
                if options.GrabMostRecent && (~any(ind) || options.IgnoreTitle)
                    for i = numel(openFigs):-1:1
                        if isa(guidata(openFigs(i)), 'ndi.gui.component.ProgressBarWindow')
                            ind(i) = true;
                            continue
                        end
                    end
                end

                if any(ind)
                    % If overwriting, close matching progress bar
                    if options.Overwrite
                        disp(['Closing existing progress bar window: ', title]);
                        delete(openFigs(ind))

                    % If not overwriting, use guidata from current figure
                    else
                        disp(['Using existing progress bar window: ', title]);
                        appExisting = guidata(openFigs(ind));

                        % Check guidata is a ProgressBarWindow
                        if isa(appExisting, 'ndi.gui.component.ProgressBarWindow')
                            app = appExisting;
                            app.bringToFront()
                            return
                        else
                             warning('ProgressBarWindow:ExistingFigureNotApp', 'Existing figure with title "%s" is not a ProgressBarWindow instance. Creating new.', title);
                             delete(openFigs(ind)); % Delete non-app figure to avoid conflict
                        end
                    end
                end
            end

            % Set visible state from input
            app.Visible = options.Visible;

            % Add auto-delete tag
            app.AutoDelete = options.AutoDelete;

            % Add listeners
            app.ProgressFigureListener = addlistener(app,'ProgressFigure','PostSet',@app.handleAppChange);
            app.ProgressGridListener = addlistener(app,'ProgressGrid','PostSet',@app.handleAppChange);
            app.ProgressBarListener = addlistener(app,'ProgressBars','PostSet',@app.handleAppChange);

            % Initialize progress bar figure
            app.ProgressFigure = uifigure(...
                'Units', 'normalized',...
                'NumberTitle', 'off',...
                'Resize', 'off',...
                'MenuBar', 'none',...
                'Tag', 'progressbar', ...
                'Visible', app.Visible);

            % Initialze progress bar grid
            app.ProgressGrid = uigridlayout(app.ProgressFigure,...
                'ColumnWidth',{'17.5x','1.5x','1x'},'RowHeight',{},...
                'RowSpacing',0);

            % Set title and size
            app = app.setFigureTitle(title);
            app = app.setFigureSize(1);
            
            % Initialize progress bar struct
            app.ProgressBars = struct('Tag',{},'Progress',{},'State',{},...
                'Auto',{},'Axes',{},'Patch',{},'Percent',{},'Button',{},...
                'Label',{},'Clock',{},'Timer',{});

        end % PROGRESSBARWINDOW

        function app = addBar(app,options)
            %addBar Adds a new progress bar to the window.
            %
            %   APP = ADDBAR(APP, OPTIONS) adds a new row to the progress
            %   bar window with a new progress bar.
            %
            %   Inputs:
            %       app - The app instance.
            %
            %   Optional Name-Value Arguments:
            %       Label - Text label displayed above the bar. Defaults to ''.
            %       Tag - A unique identifier for this bar. Defaults to the Label if empty.
            %       Color - RGB color for the progress bar. Defaults to a random color.
            %       Auto - If true, automatically removes the bar when complete or timed out.
            %              Defaults to false.
            %
            %   Outputs:
            %       app - The updated app instance.

            % Input argument validation
            arguments
                app
                options.Label {mustBeTextScalar(options.Label)} = ''
                options.Tag {mustBeTextScalar(options.Tag)} = ''
                options.Color (1,3) double {mustBeInRange(options.Color,0,1)} = [1 1 1]
                options.Auto logical = false
            end

            % Bring figure to front
            app.bringToFront()

            % Set tag (if empty)
            if isempty(options.Tag)
                options.Tag = options.Label;
            end

            % Check if tag already exists (if it does, set progress to 0)
            barNum = app.getBarNum(options.Tag);
            if ~isempty(barNum)
                
                % If the existing bar was closed, delete existing        
                if strcmpi(app.ProgressBars(barNum).State,'Closed')
                    app.ProgressBars(barNum) = [];
                else
                    warning('ProgressBarWindow:DuplicateTag',...
                        'BarID "%s" already used. Resetting progress bar.',options.Tag)
                    app.updateBar(options.Tag,0);
                    app.ProgressBars(barNum).Clock(1:2) = {datetime('now')};
                    return
                end
            end

            % Generate color if default (white)
            if all(options.Color == 1)
                while (sum(options.Color) < 1.5) || (sum(options.Color) > 2.8)
                    options.Color = rand(1, 3);
                end
            end

            % Get new barNum (index)
            barNum = numel(app.ProgressBars) + 1;

            % Get state, tag, and auto flag
            app.ProgressBars(barNum).State = 'Open';
            app.ProgressBars(barNum).Tag = options.Tag;
            app.ProgressBars(barNum).Auto = options.Auto;
            app.ProgressBars(barNum).Progress = 0;
            app.ProgressBars(barNum).Clock(1:2) = {datetime('now')};

            % Add rows to ProgressGrid (one for label/timer, one for bar)
            if isempty(options.Label)
                app.ProgressGrid.RowHeight{end+1} = '0.25x'; % Small gap
                app.ProgressGrid.RowHeight{end+1} = '1x';    % Bar row
            else
                app.ProgressGrid.RowHeight{end+1} = '0.75x'; % Label row
                app.ProgressGrid.RowHeight{end+1} = '1x';    % Bar row
            end
            rowNum = numel(app.ProgressGrid.RowHeight); % Row for the bar

            % Adjust figure size based on total row height
            rowHeight = cellfun(@(rh) str2double(replace(rh,'x','')),...
                app.ProgressGrid.RowHeight);
            app = app.setFigureSize(sum(rowHeight));

            % Add label (above the bar)
            app.ProgressBars(barNum).Label = uilabel(app.ProgressGrid,...
                'Text',options.Label,'FontSize',12,...
                'VerticalAlignment','bottom','HorizontalAlignment','left');
            app.ProgressBars(barNum).Label.Layout.Row = rowNum - 1;
            app.ProgressBars(barNum).Label.Layout.Column = 1;

            % Add countdown timer (above the bar, right-aligned)
            app.ProgressBars(barNum).Timer = uilabel(app.ProgressGrid,...
                'Text','Estimated time: calculating',...
                'FontSize',12,'FontColor',0.7*ones(1,3),...
                'VerticalAlignment','bottom','HorizontalAlignment','right');
            app.ProgressBars(barNum).Timer.Layout.Row = rowNum - 1;
            app.ProgressBars(barNum).Timer.Layout.Column = 1:2;

            % Add bar axes (background)
            app.ProgressBars(barNum).Axes = uiaxes(app.ProgressGrid,...
                'XLim',[0 1],'YLim',[0 1],'XTick',[],'YTick',[],'Box','off',...
                'XColor','none','YColor','none','Color','w','Interactions',[]);
            app.ProgressBars(barNum).Axes.Toolbar.Visible = 'off';
            app.ProgressBars(barNum).Axes.Layout.Row = rowNum;
            app.ProgressBars(barNum).Axes.Layout.Column = 1;

            % Add bar patch (foreground)
            app.ProgressBars(barNum).Patch = patch(app.ProgressBars(barNum).Axes, ...
                [0;0;0;0], [0;0;1;1], options.Color,'EdgeColor','none');

            % Add progress percentage text
            app.ProgressBars(barNum).Percent = uilabel(app.ProgressGrid,...
                'Text','0%','FontSize',10);
            app.ProgressBars(barNum).Percent.Layout.Row = rowNum;
            app.ProgressBars(barNum).Percent.Layout.Column = 2;
            
            % Add close button
            app.ProgressBars(barNum).Button = uibutton(app.ProgressGrid,...
                'Icon',app.IconClose,'IconAlignment','center','text','');
            app.ProgressBars(barNum).Button.Layout.Row = rowNum;
            app.ProgressBars(barNum).Button.Layout.Column = 3;
            app.ProgressBars(barNum).Button.Tag = options.Tag;
            app.ProgressBars(barNum).Button.ButtonPushedFcn = @app.handleButtonPress;

        end % ADDBAR

        function app = updateBar(app,barID,progress)
            %updateBar Updates the progress of a specific bar.
            %
            %   APP = UPDATEBAR(APP, BARID, PROGRESS) updates the visual
            %   state and percentage text of the specified progress bar.
            %
            %   Inputs:
            %       app - The app instance.
            %       barID - The index or Tag of the bar to update.
            %       progress - The new progress value, between 0 and 1.
            %
            %   Outputs:
            %       app - The updated app instance.

            % Input argument validation
            arguments
                app
                barID {mustBeA(barID,{'numeric','char','str'})}
                progress (1,1) {mustBeInRange(progress,0,1)}
            end

            % Get bar number
            [barNum,status] = app.getBarNum(barID);

            % If bar does not yet exist, throw warning
            if ~isempty(status.identifier)
                warning(status.identifier,status.message)
                if isempty(barNum)
                    return
                end
            end

            % Catch errors occuring if bar was concurrently deleted via button press
            try
                % Update progress value
                app.ProgressBars(barNum).Progress = progress;

                % Set progress bar width
                set(app.ProgressBars(barNum).Patch,'XData',[0;progress;progress;0]);

                % Set percent label
                set(app.ProgressBars(barNum).Percent,...
                    'Text',sprintf('%.0f%%', progress * 100));

                % Add current time
                app.ProgressBars(barNum).Clock{2} = datetime('now');

                % Update timer (if not yet complete)
                if progress > 0 && progress < 1
                    timeElapsed = app.ProgressBars(barNum).Clock{2} - ...
                        app.ProgressBars(barNum).Clock{1};
                    timeRemaining = timeElapsed * (1 - progress) / progress;
                    if timeRemaining <= minutes(1)
                        timeString = sprintf('%.0f seconds',seconds(timeRemaining));
                    elseif timeRemaining <= hours(2)
                        timeString = sprintf('%.0f minutes',minutes(timeRemaining));
                    elseif timeRemaining > hours(2)
                        timeString = sprintf('%.0f hours',hours(timeRemaining));
                    end
                    set(app.ProgressBars(barNum).Timer,'Text',['Estimated time: ',timeString]);
                    set(app.ProgressBars(barNum).Button,'Icon',app.IconClose);
                end

                % Check for bars that timed out or completed
                app.checkTimeout;
                app.checkComplete;

                % Auto close if complete or timeout
                for i = 1:numel(app.ProgressBars)
                    if (strcmpi(app.ProgressBars(i).State,'Timeout') | ...
                            strcmpi(app.ProgressBars(i).State,'Complete')) & ...
                            app.ProgressBars(i).Auto
                        app = app.removeBar(i);
                    end
                end

            % Handle error occuring if removeBar is triggered while updateBar is still running
            catch ME
                if strcmp(ME.identifier,'MATLAB:class:InvalidHandle')
                    warning('Execution of task %s terminated by user.',...
                        app.ProgressBars(barNum).Tag)
                else
                    rethrow(ME)
                end
            end

        end % UPDATEBAR

        function app = removeBar(app,barID)
            %removeBar Removes a specific progress bar from the window.
            %
            %   APP = REMOVEBAR(APP, BARID) removes the specified bar,
            %   deletes its GUI components, updates the layout, and throws
            %   an error if the task was not complete.
            %
            %   Inputs:
            %       app - The app instance.
            %       barID - The index or Tag of the bar to remove.
            %
            %   Outputs:
            %       app - The updated app instance.

            % Input argument validation
            arguments
                app
                barID {mustBeA(barID,{'numeric','char','str'})}
            end

            % Get bar number
            [barNum,status] = app.getBarNum(barID);
            if ~isempty(status.identifier)
                warning(status.identifier, status.message);
                return
            end

            % Get tag and ProgressGrid row numbers
            rowNum = app.ProgressBars(barNum).Label.Layout.Row + [0 1];

            % Check for state at time of removal
            state = app.ProgressBars(barNum).State;

            % Set state to closed
            app.ProgressBars(barNum).State = 'Closed';
            
            % Remove progress bar
            delete([app.ProgressBars(barNum).Axes,...
                app.ProgressBars(barNum).Percent,...
                app.ProgressBars(barNum).Button,...
                app.ProgressBars(barNum).Label,...
                app.ProgressBars(barNum).Timer]);

            % Adjust position of other bars
            openBars = find(~strcmpi({app.ProgressBars.State},'Closed'));
            for i = 1:numel(openBars)
                app.ProgressBars(openBars(i)).Label.Layout.Row = 2*i - 1;
                app.ProgressBars(openBars(i)).Timer.Layout.Row = 2*i - 1;
                app.ProgressBars(openBars(i)).Axes.Layout.Row = 2*i;
                app.ProgressBars(openBars(i)).Percent.Layout.Row = 2*i;
                app.ProgressBars(openBars(i)).Button.Layout.Row = 2*i;
            end

            % Adjust figure size
            app.ProgressGrid.RowHeight(rowNum) = [];
            rowHeight = cellfun(@(rh) str2double(replace(rh,'x','')),...
                app.ProgressGrid.RowHeight);
            app = app.setFigureSize(sum(rowHeight));

            % Throw error/warning if terminated in the middle of task
            if app.ProgressBars(barNum).Progress < 1
                if strcmpi(state,'Button')
                    error('ProgressBarWindow:UserTermination',...
                        'Execution of task %s terminated by user.',...
                        app.ProgressBars(barNum).Tag)
                elseif strcmpi(state,'Timeout')
                    warning('ProgressBarWindow:AutoCloseOnTimeout',...
                        'Task %s has been inactive for %.f minutes.',...
                        app.ProgressBars(barNum).Tag,...
                        minutes(datetime('now') - app.ProgressBars(barNum).Clock{2}))
                elseif strcmpi(state,'Open')
                    warning('ProgressBarWindow:BarRemoved',...
                        'BarID %s no longer exists.',...
                        app.ProgressBars(barNum).Tag)
                end
            end

            % Check for auto delete
            if app.AutoDelete
                app.deleteIfNoOpenBars;
            end

        end % REMOVEBAR

        function app = setFigureSize(app,totalRowHeight)
            %setFigureSize Adjusts the figure height based on bar content.
            %
            %   APP = SETFIGURESIZE(APP, TOTALROWHEIGHT) calculates and sets
            %   the figure's position and size.
            %
            %   Inputs:
            %       app - The app instance.
            %       totalRowHeight - The sum of the 'x' values from the 
            %                        grid's RowHeight property.
            %
            %   Outputs:
            %       app - The updated app instance.

            % Input argument validation
            arguments
                app
                totalRowHeight (1,1) {mustBeNumeric}
            end

            % Define figure size
            vpad = sum(app.ProgressGrid.Padding([2,4]));
            height = app.ScreenFrac * (totalRowHeight * 25 + vpad)/25;
            width = app.ScreenFrac * 13;
            left = app.ProgressFigure.Position(1);
            hdiff = height - app.ProgressFigure.Position(4);
            bottom = app.ProgressFigure.Position(2) - hdiff;

            % Update figure size
            app.ProgressFigure.Position = [left bottom width height];

        end % SETFIGURESIZE

        function app = setFigureTitle(app,titleName)
            %setFigureTitle Sets the title of the progress bar window.
            %
            %   APP = SETFIGURETITLE(APP, TITLENAME) updates the Name
            %   property of the figure.
            %
            %   Inputs:
            %       app - The app instance.
            %       titleName - The new title.
            %
            %   Outputs:
            %       app - The updated app instance.

            % Input argument validation
            arguments
                app
                titleName (1,:) {mustBeTextScalar}
            end

            % Assign figure title
            app.ProgressFigure.Name = titleName;

        end % SETFIGURETITLE

        function barNum = checkTimeout(app)
            %checkTimeout Checks for and flags bars that have timed out.
            %
            %   BARNUM = CHECKTIMEOUT(APP) finds bars that haven't updated
            %   within the 'Timeout' duration and sets their state and
            %   button icon accordingly.
            %
            %   Inputs:
            %       app - The app instance.
            %
            %   Outputs:
            %       barNum - Indices of bars that have timed out.

            % Initialize
            barNum = [];

            for i = 1:numel(app.ProgressBars)
                % Get duration of time since last update
                timeout = datetime('now') - app.ProgressBars(i).Clock{2};

                if timeout >= app.Timeout & ...
                        ~strcmpi(app.ProgressBars(i).State,'Closed') && ...
                        ~strcmpi(app.ProgressBars(i).State,'Complete') && ...
                        app.ProgressBars(i).Progress < 1
                    
                    % Set icon to error and state to 'Timeout'
                    app.setErrorIconForButton(app.ProgressBars(i).Button)
                    app.ProgressBars(i).State = 'Timeout';
                    barNum(end+1) = i;
                end
            end

        end % CHECKTIMEOUT

        function barNum = checkComplete(app)
            %checkComplete Checks for and flags bars that have reached 100%.
            %
            %   BARNUM = CHECKCOMPLETE(APP) finds bars with Progress == 1
            %   and sets their state, timer text, and button icon.
            %
            %   Inputs:
            %       app - The app instance.
            %
            %   Outputs:
            %       barNum - Indices of complete bars.

            % Initialize
            barNum = [];

            % Check for non-closed progress bars that are complete
            for i = 1:numel(app.ProgressBars)
                if ~strcmpi(app.ProgressBars(i).State,'Closed') && ...
                        app.ProgressBars(i).Progress >= 1
                    
                    % Set icon to success and state to 'Complete'
                    set(app.ProgressBars(i).Timer,'Text','Complete');
                    app.setSuccessIconForButton(app.ProgressBars(i).Button)
                    app.ProgressBars(i).State = 'Complete';
                    barNum(end+1) = i;
                end
            end

        end % CHECKCOMPLETE

        function [barNum,status] = getBarNum(app,barID)
            %getBarNum Finds the index of a bar given its ID (index or Tag).
            %
            %   [BARNUM, STATUS] = GETBARNUM(APP, BARID) searches for a 
            %   progress bar.
            %
            %   Inputs:
            %       app - The app instance.
            %       barID - The index or Tag.
            %
            %   Outputs:
            %       barNum - The index of the found bar. Empty if not found.
            %       status - Contains identifier and message fields.
            %                         Empty if bar found and valid.

            % Input argument validation
            arguments
                app
                barID {mustBeA(barID,{'numeric','char','str'})}
            end

            % Initialize
            barNum = [];
            status = struct('identifier', '', 'message', '');
            
            % Handle empty progress bars
            if isempty(app.ProgressBars)
                status.identifier = 'ProgressBarWindow:NoBarsExist';
                status.message = 'No progress bars have been added yet.';
                return;
            end

            if isnumeric(barID) % barID is a numeric index
                if barID > 0 && barID <= numel(app.ProgressBars)
                    barNum = barID;
                else
                    status.identifier = 'ProgressBarWindow:InvalidBarIndex';
                    status.message = sprintf('Numeric BarID %d is out of bounds (1-%d).', barID, numel(app.ProgressBars));
                end
            else % barID is a char or string tag
                tags = {app.ProgressBars.Tag};
                barNum = find(strcmpi(tags,barID));
                if isempty(barNum)
                    status.identifier = 'ProgressBarWindow:InvalidBarTag';
                    status.message = sprintf('BarID Tag "%s" not found.', string(barID));
                elseif numel(barNum) > 1
                    status.identifier = 'ProgressBarWindow:DuplicateBarID';
                    status.message = sprintf('BarID Tag "%s" matches multiple bars.', string(barID));
                    error(status.identifier,status.message);
                end
            end

        end % GETBARNUM

        function state = getState(app,barID)
            %getState Returns the state of a specific bar.
            %
            %   STATE = GETSTATE(APP, BARID) retrieves the 'State' field
            %   for the specified bar.
            %
            %   Inputs:
            %       app - The app instance.
            %       barID - The index or Tag.
            %
            %   Outputs:
            %       state - The current state ('Open', 'Complete',
            %                     'Timeout', 'Closed') or empty if not found.

            % Input argument validation
            arguments
                app
                barID {mustBeA(barID,{'numeric','char','str'})}
            end

            % Get bar index
            [barNum,status] = getBarNum(app,barID);

            % Retrieve state
            if ~isempty(status.identifier)
                warning(status.identifier, status.message);
                state = '';
            else
                state = app.ProgressBars(barNum).State;
            end

        end % GETSTATUS

        function app = setTimeout(app, newTimeout)
            %setTimeout Sets the timeout duration.
            %
            %   APP = SETTIMEMOUT(APP,NEWTIMEOUT) updates the timeout time.
            %
            %   Inputs:
            %       app - The app instance.
            %       newTimeout - The timeout time.
            %
            %   Outputs:
            %       app - The updated app instance.

            % Input argument validation
            arguments
                app
                newTimeout (1,1) duration
            end

            app.Timeout = newTimeout;
        end % SETTIMEOUT

        function handleButtonPress(app,source,~)
            %handleButtonPress Callback for the close button on each bar.
            %
            %   Inputs:
            %       app - The app instance.
            %       source - The handle to the button that was pressed.

            % Input argument validation
            arguments
                app
                source (1,1) matlab.ui.control.Button
                ~ % event data, unused
            end

            % Set state as Button
            barNum = app.getBarNum(source.Tag);
            app.ProgressBars(barNum).State = 'Button';

            % Remove progress bar
            app.removeBar(source.Tag);

        end % HANDLEBUTTONPRESS

        function handleAppChange(app,~,~)
            %handleAppChange Listener callback for property changes.
            %   Ensures guidata is saved and the figure is redrawn.

            % Save guidata to figure
            guidata(app.ProgressFigure,app);

            % Update figure
            drawnow

        end % HANDLEAPPCHANGE

        function deleteIfNoOpenBars(app)
            %deleteIfNoOpenBars - delete the app if there are no open bars
            %   Deletes (closes the window) if all bars are 'Closed'

            doDelete = false;
            if numel(app.ProgressBars) == 0
                doDelete = true;
            elseif all(strcmpi({app.ProgressBars.State},'Closed'))
                doDelete = true;
            end

            if doDelete
                close(app.ProgressFigure);
                delete(app);
            end
        end
    end

    methods (Access = private)
        function bringToFront(app)
            if app.Visible
                try
                    figure(app.ProgressFigure);
                catch ME
                    if strcmp(ME.identifier, 'MATLAB:UndefinedFunction') && ...
                            startsWith(ME.message, "Undefined function 'bringToFront'")
                        % Ignore. This error occurs on virtual runners (i.e github actions runner)
                    else
                        rethrow(ME)
                    end
                end
            end
        end
    end

    methods (Static, Access = private)
        function setErrorIconForButton(buttonHandle)
            if exist('isMATLABReleaseOlderThan', 'file') && ~isMATLABReleaseOlderThan('R2022b')
                set(buttonHandle,'Icon','error');
            else
                % Todo: need to add custom icon
            end
        end

        function setSuccessIconForButton(buttonHandle)
            if exist('isMATLABReleaseOlderThan', 'file') && ~isMATLABReleaseOlderThan('R2022b')
                set(buttonHandle,'Icon','success');
            else
                % Todo: need to add custom icon
            end
        end
    end
end
