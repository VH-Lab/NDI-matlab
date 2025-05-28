% Give use cases including example for doImport and example for tracking
% something more granular where you could use did.ido.unique tag and make
% sure the Bar is set to Auto close
classdef ProgressBarWindow < matlab.apps.AppBase
    %UNTITLED5 Summary of this class goes here
    %   Detailed explanation goes here

    properties (Access = private)
        ScreenFrac = 0.025 % Each progress bar will be ~2.5% of the screen height
        IconClose = fullfile(ndi.common.PathConstants.RootFolder,'+ndi','+gui','close_icon.svg');
        IconPause = fullfile(ndi.common.PathConstants.RootFolder,'+ndi','+gui','pause_icon.svg');
        IconPlay = fullfile(ndi.common.PathConstants.RootFolder,'+ndi','+gui','play_icon.svg');
        ProgressFigureListener
        ProgressGridListener
        ProgressBarListener
        Timeout = minutes(1)
    end

    properties (SetObservable)
        ProgressFigure matlab.ui.Figure
        ProgressGrid matlab.ui.container.GridLayout
        ProgressBars struct
    end

    methods
        function app = ProgressBarWindow(title,options)

            % Input argument validation
            arguments
                title (1,:) char = '';
                options.Overwrite logical = true
            end

            % Close any matching progress bars (if overwriting)
            openFigs = findall(groot,'Type','figure');
            if ~isempty(openFigs)
                ind = strcmpi({openFigs.Name},title) & ...
                    strcmpi({openFigs.Tag},'progressbar');
                if options.Overwrite
                    delete(openFigs(ind))
                end
            end

            if ~isempty(openFigs) && ~options.Overwrite && any(ind)
                % If not overwriting, use guidata from current figure
                app = guidata(openFigs(ind));
                figure(app.ProgressFigure);
            else
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
                    'Tag', 'progressbar');

                % Initiliaze progress bar grid
                app.ProgressGrid = uigridlayout(app.ProgressFigure,...
                    'ColumnWidth',{'17.5x','1.5x','1x'},'RowHeight',{},...
                    'RowSpacing',0);
                app = app.setFigureSize(1);
                app = app.setFigureTitle(title);

                % Initialize progress bar struct
                app.ProgressBars = struct('Tag',{},'Progress',{},'Status',{},...
                    'Auto',{},'Panel',{},'Patch',{},'Percent',{},'Button',{},...
                    'Label',{},'Clock',{},'Timer',{});
            end

        end % PROGRESSBARWINDOW

        function app = addBar(app,options)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            % Can use did.ido.unique_id to create a unique tag

            % Input argument validation
            arguments
                app
                options.Label {mustBeTextScalar(options.Label)} = ''
                options.Tag {mustBeTextScalar(options.Tag)} = ''
                options.Color (1,3) double {mustBeInRange(options.Color,0,1)} = [1 1 1]
                options.Auto logical = false
            end

            % Bring figure to front
            figure(app.ProgressFigure);

            % Check if tag already exists (if it does, set progress to 0)
            if isempty(options.Tag)
                options.Tag = options.Label;
            end
            barNum = app.getBarNum(options.Tag);
            if ~isempty(barNum)
                warning('ProgressBarWindow:addBar:InvalidTag',...
                    'Tag "%s" already used. Resetting.',options.Tag)

                if strcmpi(app.ProgressBars(barNum).Status,'Closed')
                    app.ProgressBars(barNum) = [];
                else
                    app.updateBar(options.Tag,0);
                    return
                end
            end

            % Replace color if default (white)
            if all(options.Color == 1)
                while (sum(options.Color) < 1.5) || (sum(options.Color) > 2.8)
                    options.Color = rand(1, 3);
                end
            end

            % Get current barNum
            barNum = numel(app.ProgressBars) + 1;

            % Get status, tag, and auto flag
            app.ProgressBars(barNum).Status = 'Open';
            app.ProgressBars(barNum).Tag = options.Tag;
            app.ProgressBars(barNum).Auto = options.Auto;

            % Add rows to ProgressGrid
            if isempty(options.Label)
                app.ProgressGrid.RowHeight{end+1} = '0.25x';
                app.ProgressGrid.RowHeight{end+1} = '1x';
                rowNum = numel(app.ProgressGrid.RowHeight);

            else
                app.ProgressGrid.RowHeight{end+1} = '0.75x';
                app.ProgressGrid.RowHeight{end+1} = '1x';
                rowNum = numel(app.ProgressGrid.RowHeight);
            end

            % Adjust figure size
            rowHeight = cellfun(@(rh) str2double(replace(rh,'x','')),...
                app.ProgressGrid.RowHeight);
            app = app.setFigureSize(sum(rowHeight));

            % Add label
            app.ProgressBars(barNum).Label = uilabel(app.ProgressGrid,...
                'Text',options.Label,'FontSize',12,...
                'VerticalAlignment','bottom','HorizontalAlignment','left');
            app.ProgressBars(barNum).Label.Layout.Row = rowNum - 1;
            app.ProgressBars(barNum).Label.Layout.Column = 1:2;

            % Add countdown timer
            app.ProgressBars(barNum).Timer = uilabel(app.ProgressGrid,...
                'Text','Estimated time: calculating',...
                'FontSize',12,'FontColor',0.7*ones(1,3),...
                'VerticalAlignment','bottom','HorizontalAlignment','right');
            app.ProgressBars(barNum).Timer.Layout.Row = rowNum - 1;
            app.ProgressBars(barNum).Timer.Layout.Column = 1:2;

            % Add bar background
            app.ProgressBars(barNum).Panel = uiaxes(app.ProgressGrid,...
                'XLim',[0 1],'YLim',[0 1],'XTick',[],'YTick',[],'Box','off',...
                'XColor','none','YColor','none','Color','w','Interactions',[]);
            app.ProgressBars(barNum).Panel.Toolbar.Visible = 'off';
            app.ProgressBars(barNum).Panel.Layout.Row = rowNum;
            app.ProgressBars(barNum).Panel.Layout.Column = 1;

            % Add bar foreground
            app.ProgressBars(barNum).Patch = patch(app.ProgressBars(barNum).Panel, ...
                [0 0 0 0], [0 1 1 0], options.Color,'EdgeColor','none');

            % Add progress text
            app.ProgressBars(barNum).Percent = uilabel(app.ProgressGrid,...
                'Text','0%','FontSize',10);
            app.ProgressBars(barNum).Percent.Layout.Row = rowNum;
            app.ProgressBars(barNum).Percent.Layout.Column = 2;
            app.ProgressBars(barNum).Progress = 0;

            % Add clock
            app.ProgressBars(barNum).Clock(1:2) = {datetime('now')};

            % Add close button
            app.ProgressBars(barNum).Button = uibutton(app.ProgressGrid,...
                'Icon',app.IconPause,'IconAlignment','center','text','');
            app.ProgressBars(barNum).Button.Layout.Row = rowNum;
            app.ProgressBars(barNum).Button.Layout.Column = 3;
            app.ProgressBars(barNum).Button.Tag = options.Tag;
            app.ProgressBars(barNum).Button.ButtonPushedFcn = @app.handleButtonPress;

        end % ADDBAR

        function [app,status] = updateBar(app,barID,progress)
            % Input argument validation
            arguments
                app
                barID {mustBeA(barID,{'numeric','char','str'})}
                progress (1,1) {mustBeInRange(progress,0,1)}
            end

            % Get bar number
            [barNum,status] = app.getBarNum(barID);
            if ~isempty(status.identifier)
                disp(status.message)
                return
            end

            % Save progress
            app.ProgressBars(barNum).Progress = progress;

            % Set progress bar
            set(app.ProgressBars(barNum).Patch,'XData',[0 0 progress progress]);

            % Set percent label
            set(app.ProgressBars(barNum).Percent,...
                'Text',sprintf('%.0f%%', progress * 100));

            % Add current time
            app.ProgressBars(barNum).Clock{2} = datetime('now');

            % Update timer
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
            set(app.ProgressBars(barNum).Button,'Icon',app.IconPause);

            % Check for bars that have timed out or completed
            app.checkTimeout;
            app.checkComplete;

            % Auto close if complete or timeout
            barDelete = find((strcmpi({app.ProgressBars.Status},'Timeout') | ...
                strcmpi({app.ProgressBars.Status},'Complete')) & ...
                [app.ProgressBars.Auto]);
            for i = 1:numel(barDelete)
                app = app.removeBar(barDelete);
            end

        end % UPDATEBAR

        function app = removeBar(app,barID)

            % Input argument validation
            arguments
                app
                barID {mustBeA(barID,{'numeric','char','str'})}
            end

            % Get bar number
            [barNum,status] = app.getBarNum(barID);
            if ~isempty(status.identifier)
                warning(status.identifier,status.message)
            end
            
            % Remove progress bar appects
            delete([app.ProgressBars(barNum).Panel,...
                app.ProgressBars(barNum).Percent,...
                app.ProgressBars(barNum).Button,...
                app.ProgressBars(barNum).Label,...
                app.ProgressBars(barNum).Timer]);

            % Set status to closed
            app.ProgressBars(barNum).Status = 'Closed';

            % Adjust position of other bars
            openBars = find(~strcmpi({app.ProgressBars.Status},'Closed'));
            for i = 1:numel(openBars)
                app.ProgressBars(openBars(i)).Label.Layout.Row = 2*i - 1;
                app.ProgressBars(openBars(i)).Timer.Layout.Row = 2*i - 1;
                app.ProgressBars(openBars(i)).Panel.Layout.Row = 2*i;
                app.ProgressBars(openBars(i)).Percent.Layout.Row = 2*i;
                app.ProgressBars(openBars(i)).Button.Layout.Row = 2*i;
            end

            % Adjust figure size
            app.ProgressGrid.RowHeight(2 * barNum + [-1 0]) = [];
            rowHeight = cellfun(@(rh) str2double(replace(rh,'x','')),...
                app.ProgressGrid.RowHeight);
            app = app.setFigureSize(sum(rowHeight));

        end % REMOVEBAR

        function app = setFigureSize(app,numBar)

            % Get screen size
            % set(0,'units','pixels');
            % screenResolution = get(0,'screensize');
            
            % Define figure size
            vpad = sum(app.ProgressGrid.Padding([2,4]));
            height = app.ScreenFrac * (numBar * 25 + vpad)/25;
            width = app.ScreenFrac * 13;
            left = app.ProgressFigure.Position(1);
            hdiff = height - app.ProgressFigure.Position(4);
            bottom = app.ProgressFigure.Position(2) - hdiff;

            % Update figure size
            app.ProgressFigure.Position = [left bottom width height];

        end % SETFIGURESIZE

        function app = setFigureTitle(app,titleName)
            % Assign figure title
            app.ProgressFigure.Name = titleName;

        end % SETFIGURETITLE

        function barNum = checkTimeout(app)
            % Input argument validation
            arguments
                app
            end

            timeout = [];
            for i = 1:numel(app.ProgressBars)
                timeout = cat(2,timeout,datetime('now') - app.ProgressBars(i).Clock{2});
            end

            barNum = find(timeout >= app.Timeout & ...
                ~strcmpi({app.ProgressBars.Status},'Closed') & ...
                ~strcmpi({app.ProgressBars.Status},'Complete'));

            for i = 1:numel(barNum)
                if app.ProgressBars(barNum(i)).Progress < 1
                    set(app.ProgressBars(barNum(i)).Button,'Icon','error');
                    app.ProgressBars(barNum(i)).Status = 'Timeout';
                end
            end

        end % CHECKTIMEOUT

        function barNum = checkComplete(app)
            % Input argument validation
            arguments
                app
            end

            barNum = find(~strcmpi({app.ProgressBars.Status},'Closed'));

            for i = 1:numel(barNum)
                if app.ProgressBars(barNum(i)).Progress == 1
                    set(app.ProgressBars(barNum(i)).Button,'Icon','success');
                    app.ProgressBars(barNum(i)).Status = 'Complete';
                end
            end

        end % CHECKCOMPLETE

        function [barNum,status] = getBarNum(app,barID)
            % Handle bar id types
            if isnumeric(barID)
                barNum = barID;
            else
                tags = {app.ProgressBars.Tag};
                barNum = find(strcmpi(tags,barID));
            end

            if isempty(barNum)
                status.identifier = 'Invalid';
                status.message = sprintf('BarID "%s" does not match any of the tags: "%s"',...
                    barID,strjoin(tags,'", "'));
            elseif numel(barNum) > 1
                status.identifier = 'Duplicate';
                status.message = sprintf('BarID "%s" matches %i of the tags: "%s"',barID,numel(barNum),strjoin(tags,'", "'));
            elseif strcmpi(app.ProgressBars(barNum).Status,'Closed')
                status.identifier = 'Closed';
                status.message = sprintf('BarID "%s" matches a deleted progress bar.',barID);
            else
                status.identifier = '';
                status.message = '';
            end
        end

        function handleButtonPress(app,source,~)

            % Remove progress bar
            barNum = app.getBarNum(source.Tag);
            if contains(app.ProgressBars(barNum).Button.Icon,'pause')
                set(app.ProgressBars(barNum).Button,'Icon',app.IconPlay);
                drawnow nocallbacks
                disp('pause')
                app.ProgressBars(barNum).Status = 'Pause';
            elseif contains(app.ProgressBars(barNum).Button.Icon,'play')
                set(app.ProgressBars(barNum).Button,'Icon',app.IconPause);
                disp('play')
                app.ProgressBars(barNum).Status = 'Open';
                uiresume(app.ProgressFigure)
            else
                app.removeBar(source.Tag);
            end
        end

        function handleAppChange(app,~,~)

            % Save guidata to figure
            guidata(app.ProgressFigure,app);

            % Update figure
            drawnow
        end

        function status = getStatus(app,barID)
            barNum = getBarNum(app,barID);
            status = app.ProgressBars(barNum).Status;
            if strcmpi(status,'Pause')
                set(app.ProgressBars(barNum).Button,'Icon',app.IconPlay);
                drawnow
            end
        end
    end
end