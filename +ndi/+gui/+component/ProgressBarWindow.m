classdef ProgressBarWindow
    %UNTITLED5 Summary of this class goes here
    %   Detailed explanation goes here

    properties (Access = private, Constant)
        ScreenFrac = 0.02 % Each progress bar will be ~2% of the screen height
    end

    properties
        ProgressFigure
        ProgressGrid
        ProgressBars
    end

    methods
        function obj = ProgressBarWindow(title)

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
            obj.ProgressFigure = uifigure(...
                'Units', 'normalized',...
                'NumberTitle', 'off',...%'Resize', 'off',...
                'MenuBar', 'none',...
                'Tag', 'progressbar');

            % Initiliaze progress bar grid
            obj.ProgressGrid = uigridlayout(obj.ProgressFigure,...
                'ColumnWidth',{'17.5x','1.5x','1x'},'RowHeight',{},...
                'RowSpacing',0);

            %
            obj = obj.setFigureSize(1);
            obj = obj.setFigureTitle(title);

            % Initialize progress bar struct
            obj.ProgressBars = struct('Panel',{},'Patch',{},'Percent',{},'Button',{},...
                'Label',{},'Clock',{},'Timer',{});
        end

        function obj = setFigureSize(obj,numBar)
            
            % Define figure size
            vpad = sum(obj.ProgressGrid.Padding([2,4]));
            height = obj.ScreenFrac * (numBar * 25 + vpad)/25;
            width = obj.ScreenFrac * 12;
            left = obj.ProgressFigure.Position(1);
            hdiff = height - obj.ProgressFigure.Position(4);
            bottom = obj.ProgressFigure.Position(2) - hdiff;

            % Update figure size
            obj.ProgressFigure.Position = [left bottom width height];

        end % SETFIGURESIZE

        function obj = setFigureTitle(obj,titleName)
            % Assign figure title
            obj.ProgressFigure.Name = titleName;
        end % SETFIGURETITLE

        function obj = addBar(obj,options)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here

            % Input argument validation
            arguments
                obj
                options.Label {mustBeTextScalar(options.Label)} = ''
                options.Color (1,3) double {mustBeInRange(options.Color,0,1)} = ndi.gui.component.ProgressBarWindow.randColor
                options.Tag {mustBeTextScalar(options.Tag)} = ''
            end

            % Check if tag already exists
            if isempty(options.Tag)
                options.Tag = options.Label;
            end
            currentBar = obj.getBarNum(options.Tag);
            if ~isempty(currentBar)
                error('ProgressBarWindow:addBar:InvalidTag',...
                    'Tag "%s" already used. Please specify a new label or tag.',options.Tag)
            end

            % Get current barNum
            barNum = numel(obj.ProgressBars) + 1;

            if isempty(options.Label)
                % Add rows
                obj.ProgressGrid.RowHeight{end+1} = '0.25x';
                obj.ProgressGrid.RowHeight{end+1} = '1x';
                rowNum = numel(obj.ProgressGrid.RowHeight);

            else
                % Add rows
                obj.ProgressGrid.RowHeight{end+1} = '0.75x';
                obj.ProgressGrid.RowHeight{end+1} = '1x';
                rowNum = numel(obj.ProgressGrid.RowHeight);
            end

            % Add label (and tag)
            obj.ProgressBars(barNum).Label = uilabel(obj.ProgressGrid,...
                'Text',options.Label,'FontSize',12,...
                'VerticalAlignment','bottom','HorizontalAlignment','left');
            obj.ProgressBars(barNum).Label.Layout.Row = rowNum - 1;
            obj.ProgressBars(barNum).Label.Layout.Column = 1:2;
            obj.ProgressBars(barNum).Label.Tag = options.Tag;

            % Add countdown timer
            obj.ProgressBars(barNum).Timer = uilabel(obj.ProgressGrid,...
                'Text','Estimated time: calculating',...
                'FontSize',12,'FontColor',0.7*ones(1,3),...
                'VerticalAlignment','bottom','HorizontalAlignment','right');
            obj.ProgressBars(barNum).Timer.Layout.Row = rowNum - 1;
            obj.ProgressBars(barNum).Timer.Layout.Column = 1:2;

            % Adjust figure size
            rowHeight = cellfun(@(rh) str2double(replace(rh,'x','')),...
                obj.ProgressGrid.RowHeight);
            obj = obj.setFigureSize(sum(rowHeight));
            
            % Add panel for bar
            obj.ProgressBars(barNum).Panel = uipanel(obj.ProgressGrid,...
                'BackgroundColor','w','BorderType','none');
            obj.ProgressBars(barNum).Panel.Layout.Row = rowNum;
            obj.ProgressBars(barNum).Panel.Layout.Column = 1;

            % Add progress bar
            obj.ProgressBars(barNum).Patch = uipanel(obj.ProgressBars(barNum).Panel,...
                'Units','normalized','Position',[0 0 0 1],...
                'BackgroundColor',options.Color,'BorderType','none');

            % Add progress text
            obj.ProgressBars(barNum).Percent = uilabel(obj.ProgressGrid,...
                'Text','0%','FontSize',10);
            obj.ProgressBars(barNum).Percent.Layout.Row = rowNum;
            obj.ProgressBars(barNum).Percent.Layout.Column = 2;

            % Add close button
            icon = fullfile(ndi.common.PathConstants.RootFolder,'+ndi','+gui','gray_x.svg');
            obj.ProgressBars(barNum).Button = uibutton(obj.ProgressGrid,...
                'Icon',icon,'IconAlignment','center','text','');
                %'Text',char(10005),'FontSize',8,'HorizontalAlignment','center','VerticalAlignment','center');
            obj.ProgressBars(barNum).Button.Layout.Row = rowNum;
            obj.ProgressBars(barNum).Button.Layout.Column = 3;

            % Add clock
            obj.ProgressBars(barNum).Clock(1:2) = {datetime('now')};

        end % ADDBAR

        function obj = removeBar(obj,barID)

            % Input argument validation
            arguments
                obj
                barID {mustBeA(barID,{'numeric','char','str'})}
            end

            % Get bar number
            [barNum,status] = obj.getBarNum(barID);
            if ~isempty(status.identifier)
                error(status.identifier,status.message)
            end
            
            % Remove progress bar objects
            delete([obj.ProgressBars(barNum).Panel,...
                obj.ProgressBars(barNum).Percent,...
                obj.ProgressBars(barNum).Button,...
                obj.ProgressBars(barNum).Label])

            % Adjust position of other bars
            totalBars = numel(obj.ProgressBars);
            if barNum < totalBars
                for i = (barNum + 1):totalBars
                    obj.ProgressBars(i).Panel.Layout.Row = ...
                        obj.ProgressBars(i).Panel.Layout.Row - 2;
                    obj.ProgressBars(i).Percent.Layout.Row = ...
                        obj.ProgressBars(i).Percent.Layout.Row - 2;
                    obj.ProgressBars(i).Button.Layout.Row = ...
                        obj.ProgressBars(i).Button.Layout.Row - 2;
                    obj.ProgressBars(i).Label.Layout.Row = ...
                        obj.ProgressBars(i).Label.Layout.Row - 2;
                end
            end
            obj.ProgressBars(barNum) = [];

            % Adjust figure size
            obj.ProgressGrid.RowHeight(2 * barNum + [-1 0]) = [];
            rowHeight = cellfun(@(rh) str2double(replace(rh,'x','')),...
                obj.ProgressGrid.RowHeight);
            obj = obj.setFigureSize(sum(rowHeight));
        end % REMOVEBAR

        function obj = updateBarProgress(obj,barID,progress)
            % Input argument validation
            arguments
                obj
                barID {mustBeA(barID,{'numeric','char','str'})}
                progress (1,1) {mustBeInRange(progress,0,1)}
            end

            % Get bar number
            [barNum,status] = obj.getBarNum(barID);
            if ~isempty(status.identifier)
                error(status.identifier,status.message)
            end

            % Set progress bar
            set(obj.ProgressBars(barNum).Patch,...
                'Position',[0 0 progress 1],'Units','normalized')

            % Set percent label
            set(obj.ProgressBars(barNum).Percent,...
                'Text',sprintf('%.0f%%', progress * 100))

            % Add current time
            obj.ProgressBars(barNum).Clock{2} = datetime('now');

            % If complete
            if progress == 1
                set(obj.ProgressBars(barNum).Timer,'Text','Complete');
                set(obj.ProgressBars(barNum).Button,'Icon','success');
            else
                % Update timer
                timeElapsed = obj.ProgressBars(barNum).Clock{2} - ...
                    obj.ProgressBars(barNum).Clock{1};
                timeRemaining = timeElapsed / progress;
                if timeRemaining <= minutes(1)
                    timeString = sprintf('%.0f seconds',seconds(timeRemaining));
                elseif timeRemaining <= hours(2)
                    timeString = sprintf('%.0f minutes',minutes(timeRemaining));
                elseif timeRemaining > hours(2)
                    timeString = sprintf('%.0f hours',hours(timeRemaining));
                end
                set(obj.ProgressBars(barNum).Timer,'Text',['Estimated time: ',timeString]);
            end
        end

        function barNum = checkTimeout(obj,cutoff)
            % Input argument validation
            arguments
                obj
                cutoff {mustBeA(cutoff,{'duration'})} = hours(1)
            end

            timeout = nan(size(obj.ProgressBars));
            for i = 1:numel(obj.ProgressBars)
                timeout(i) = obj.ProgressBars(i).Clock{2} - ...
                    obj.ProgressBars(i).Clock{1};
            end

            barNum = find(timeout >= cutoff);
        end

        function [barNum,status] = getBarNum(obj,barID)
            % Handle bar id types
            if isnumeric(barID)
                barNum = barID;
            else
                tags = cell(size(obj.ProgressBars));
                for i = 1:numel(obj.ProgressBars)
                    tags{i} = obj.ProgressBars(i).Label.Tag;
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