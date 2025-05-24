classdef ProgressBarWindow < matlab.apps.AppBase
    %UNTITLED5 Summary of this class goes here
    %   Detailed explanation goes here

    properties (Access = private, Constant)
        ScreenFrac = 0.02 % Each progress bar will be ~2% of the screen height
    end

    properties
        ProgressFigure matlab.ui.Figure
        ProgressGrid matlab.ui.container.GridLayout
        ProgressBars struct
    end

    methods
        function app = ProgressBarWindow(title)

            % Input argument validation
            arguments
                title (1,:) char = '';
            end

            % Close any matching progress bars 
            openFigs = findall(groot,'Type','figure');
            if ~isempty(openFigs)
                ind = strcmpi({openFigs.Name},title) & ...
                    strcmpi({openFigs.Tag},'progressbar');
                delete(openFigs(ind))
            end

            % Initialize progress bar figure
            app.ProgressFigure = uifigure(...
                'Units', 'normalized',...
                'NumberTitle', 'off',...%'Resize', 'off',...
                'MenuBar', 'none',...
                'Tag', 'progressbar');

            % Initiliaze progress bar grid
            app.ProgressGrid = uigridlayout(app.ProgressFigure,...
                'ColumnWidth',{'17.5x','1.5x','1x'},'RowHeight',{},...
                'RowSpacing',0);

            %
            app = app.setFigureSize(1);
            app = app.setFigureTitle(title);

            % Initialize progress bar struct
            app.ProgressBars = struct('Panel',{},'Patch',{},'Percent',{},'Button',{},...
                'Label',{},'Clock',{},'Timer',{});
        end

        function app = setFigureSize(app,numBar)
            
            % Define figure size
            vpad = sum(app.ProgressGrid.Padding([2,4]));
            height = app.ScreenFrac * (numBar * 25 + vpad)/25;
            width = app.ScreenFrac * 12;
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

        function app = addBar(app,options)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here

            % Input argument validation
            arguments
                app
                options.Label {mustBeTextScalar(options.Label)} = ''
                options.Color (1,3) double {mustBeInRange(options.Color,0,1)} = ndi.gui.component.ProgressBarWindow.randColor
                options.Tag {mustBeTextScalar(options.Tag)} = ''
            end

            % Check if tag already exists
            if isempty(options.Tag)
                options.Tag = options.Label;
            end
            currentBar = app.getBarNum(options.Tag);
            if ~isempty(currentBar)
                error('ProgressBarWindow:addBar:InvalidTag',...
                    'Tag "%s" already used. Please specify a new label or tag.',options.Tag)
            end

            % Get current barNum
            barNum = numel(app.ProgressBars) + 1;

            if isempty(options.Label)
                % Add rows
                app.ProgressGrid.RowHeight{end+1} = '0.25x';
                app.ProgressGrid.RowHeight{end+1} = '1x';
                rowNum = numel(app.ProgressGrid.RowHeight);

            else
                % Add rows
                app.ProgressGrid.RowHeight{end+1} = '0.75x';
                app.ProgressGrid.RowHeight{end+1} = '1x';
                rowNum = numel(app.ProgressGrid.RowHeight);
            end

            % Add label (and tag)
            app.ProgressBars(barNum).Label = uilabel(app.ProgressGrid,...
                'Text',options.Label,'FontSize',12,...
                'VerticalAlignment','bottom','HorizontalAlignment','left');
            app.ProgressBars(barNum).Label.Layout.Row = rowNum - 1;
            app.ProgressBars(barNum).Label.Layout.Column = 1:2;
            app.ProgressBars(barNum).Label.Tag = options.Tag;

            % Add countdown timer
            app.ProgressBars(barNum).Timer = uilabel(app.ProgressGrid,...
                'Text','Estimated time: calculating',...
                'FontSize',12,'FontColor',0.7*ones(1,3),...
                'VerticalAlignment','bottom','HorizontalAlignment','right');
            app.ProgressBars(barNum).Timer.Layout.Row = rowNum - 1;
            app.ProgressBars(barNum).Timer.Layout.Column = 1:2;

            % Adjust figure size
            rowHeight = cellfun(@(rh) str2double(replace(rh,'x','')),...
                app.ProgressGrid.RowHeight);
            app = app.setFigureSize(sum(rowHeight));
            
            % Add panel for bar
            app.ProgressBars(barNum).Panel = uipanel(app.ProgressGrid,...
                'BackgroundColor','w','BorderType','none');
            app.ProgressBars(barNum).Panel.Layout.Row = rowNum;
            app.ProgressBars(barNum).Panel.Layout.Column = 1;

            % Add progress bar
            app.ProgressBars(barNum).Patch = uipanel(app.ProgressBars(barNum).Panel,...
                'Units','normalized','Position',[0 0 0 1],...
                'BackgroundColor',options.Color,'BorderType','none');

            % Add progress text
            app.ProgressBars(barNum).Percent = uilabel(app.ProgressGrid,...
                'Text','0%','FontSize',10);
            app.ProgressBars(barNum).Percent.Layout.Row = rowNum;
            app.ProgressBars(barNum).Percent.Layout.Column = 2;

            % Add close button
            icon = fullfile(ndi.common.PathConstants.RootFolder,'+ndi','+gui','gray_x.svg');
            app.ProgressBars(barNum).Button = uibutton(app.ProgressGrid,...
                'Icon',icon,'IconAlignment','center','text','');
                %'Text',char(10005),'FontSize',8,'HorizontalAlignment','center','VerticalAlignment','center');
            app.ProgressBars(barNum).Button.Layout.Row = rowNum;
            app.ProgressBars(barNum).Button.Layout.Column = 3;
            app.ProgressBars(barNum).Button.Tag = options.Tag;
            app.ProgressBars(barNum).Button.ButtonPushedFcn = @app.handleButtonPress;
            

            % Add clock
            app.ProgressBars(barNum).Clock(1:2) = {datetime('now')};

        end % ADDBAR

        function app = removeBar(app,barID)

            % Input argument validation
            arguments
                app
                barID {mustBeA(barID,{'numeric','char','str'})}
            end

            % Get bar number
            [barNum,status] = app.getBarNum(barID);
            if ~isempty(status.identifier)
                error(status.identifier,status.message)
            end
            
            % Remove progress bar appects
            delete([app.ProgressBars(barNum).Panel,...
                app.ProgressBars(barNum).Percent,...
                app.ProgressBars(barNum).Button,...
                app.ProgressBars(barNum).Label,...
                app.ProgressBars(barNum).Timer])

            % Adjust position of other bars
            totalBars = numel(app.ProgressBars);
            if barNum < totalBars
                for i = (barNum + 1):totalBars
                    app.ProgressBars(i).Panel.Layout.Row = ...
                        app.ProgressBars(i).Panel.Layout.Row - 2;
                    app.ProgressBars(i).Percent.Layout.Row = ...
                        app.ProgressBars(i).Percent.Layout.Row - 2;
                    app.ProgressBars(i).Button.Layout.Row = ...
                        app.ProgressBars(i).Button.Layout.Row - 2;
                    app.ProgressBars(i).Label.Layout.Row = ...
                        app.ProgressBars(i).Label.Layout.Row - 2;
                    app.ProgressBars(i).Timer.Layout.Row = ...
                        app.ProgressBars(i).Timer.Layout.Row - 2;
                end
            end
            app.ProgressBars(barNum) = [];

            % Adjust figure size
            app.ProgressGrid.RowHeight(2 * barNum + [-1 0]) = [];
            rowHeight = cellfun(@(rh) str2double(replace(rh,'x','')),...
                app.ProgressGrid.RowHeight);
            app = app.setFigureSize(sum(rowHeight));
        end % REMOVEBAR

        function app = updateBar(app,barID,progress)
            % Input argument validation
            arguments
                app
                barID {mustBeA(barID,{'numeric','char','str'})}
                progress (1,1) {mustBeInRange(progress,0,1)}
            end

            % Get bar number
            [barNum,status] = app.getBarNum(barID);
            if ~isempty(status.identifier)
                error(status.identifier,status.message)
            end

            % Set progress bar
            set(app.ProgressBars(barNum).Patch,...
                'Position',[0 0 progress 1],'Units','normalized')

            % Set percent label
            set(app.ProgressBars(barNum).Percent,...
                'Text',sprintf('%.0f%%', progress * 100))

            % Add current time
            app.ProgressBars(barNum).Clock{2} = datetime('now');

            % If complete
            if progress == 1
                set(app.ProgressBars(barNum).Timer,'Text','Complete');
                set(app.ProgressBars(barNum).Button,'Icon','success');
            else
                % Update timer
                timeElapsed = app.ProgressBars(barNum).Clock{2} - ...
                    app.ProgressBars(barNum).Clock{1};
                timeRemaining = timeElapsed / progress;
                if timeRemaining <= minutes(1)
                    timeString = sprintf('%.0f seconds',seconds(timeRemaining));
                elseif timeRemaining <= hours(2)
                    timeString = sprintf('%.0f minutes',minutes(timeRemaining));
                elseif timeRemaining > hours(2)
                    timeString = sprintf('%.0f hours',hours(timeRemaining));
                end
                set(app.ProgressBars(barNum).Timer,'Text',['Estimated time: ',timeString]);
            end
        end % UPDATEBAR

        function barNum = checkTimeout(app,cutoff)
            % Input argument validation
            arguments
                app
                cutoff {mustBeA(cutoff,{'duration'})} = hours(1)
            end

            timeout = nan(size(app.ProgressBars));
            for i = 1:numel(app.ProgressBars)
                timeout(i) = app.ProgressBars(i).Clock{2} - ...
                    app.ProgressBars(i).Clock{1};
            end

            barNum = find(timeout >= cutoff);
        end

        function [barNum,status] = getBarNum(app,barID)
            % Handle bar id types
            if isnumeric(barID)
                barNum = barID;
            else
                tags = cell(size(app.ProgressBars));
                for i = 1:numel(app.ProgressBars)
                    tags{i} = app.ProgressBars(i).Label.Tag;
                end
                barNum = find(strcmpi(tags,barID));
            end

            if isempty(barNum)
                status.identifier = 'ProgressBarWindow:getBarNum:InvalidBarID';
                status.message = sprintf('BarID "%s" does not match any of the tags: "%s"',...
                    barID,strjoin(tags,'", "'));
            elseif numel(barNum) > 1
                status.identifier = 'ProgressBarWindow:getBarNum:SeveralBarsMatching';
                status.message = sprintf('BarID "%s" matches %i of the tags: "%s"',barID,numel(barNum),strjoin(tags,'", "'));
            else
                status.identifier = '';
                status.message = '';
            end
        end

        function handleButtonPress(app,source,~)

            % Remove progress bar
            app.removeBar(source.Tag)
        end
    end

    methods (Static)
        function thiscolor = randColor()
            % Generate random RGB
            thiscolor = rand(1, 3);

            % Prevent color from being too dark or too light
            colormin = 1.5;
            colormax = 2.8;
            while (sum(thiscolor) < colormin) || (sum(thiscolor) > colormax)
                thiscolor = rand(1, 3);
            end
        end
    end
end