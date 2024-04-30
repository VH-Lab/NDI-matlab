classdef NDIProgressBar < ndi.gui.component.abstract.ProgressMonitor
% NDIProgressBar - Progress monitor with NDI-styled progress bar

    properties
        % Value of progress. Fractional value between 0 and 1.
        Value (1,1) double {mustBeInRange(Value,0,1)} = 0
        Message (1,1) string
        Size = [500, 10]
        Location = [1,1]
        ShowPercent = false
        Text = ""
        BorderWidth = 0.5
    end

    properties (Access = private, Constant)
        BackgroundColor = [0.3059    0.6471    0.9725]
        ForegroundColor = [0.0314    0.1216    0.3176]
    end
    
    properties (Access = private)
        Axes
        Panel
        Parent
        Textbox
        BarBackground
        BarForeground
    end

    methods
        function obj = NDIProgressBar(propertyArgs)
        % NDIProgressBar - Create an NDI progress bar object
            
            arguments
                propertyArgs.?ndi.gui.component.NDIProgressBar
                propertyArgs.Parent = []
            end
            
            for propertyName = string( fieldnames(propertyArgs)' )
                obj.(propertyName) = propertyArgs.(propertyName);
            end

            obj.createAxes()
            obj.drawProgressBar()
            obj.createTextBox()
        end
    end

    methods (Access = protected)
        function updateProgressDisplay(obj)
            progressMessage = obj.getProgressMessage();
            progressValue = obj.getProgressValue();
            
            obj.Value = progressValue;
            obj.updateMessage(progressMessage)
            %obj.Textbox.Text = progressMessage;
            drawnow
        end

        function updateMessage(obj, message)
            if isa(obj.Textbox, 'matlab.ui.control.UIControl')
                obj.Textbox.String = message;
            else
                obj.Textbox.Text = message;
            end
            drawnow
        end

        function finish(obj)
            % Todo: Display completed...
            if ~ismissing(obj.ProgressTracker.CompletedMessage)
                obj.Textbox.Text = obj.ProgressTracker.CompletedMessage;
            %else
            %    obj.Textbox.Text = 'Completed.';
            end
            obj.Value = 1;
        end
    end

    methods
        function set.Value(obj, newValue)
            obj.Value = newValue;
            obj.updateProgressBar()
        end

        function set.Message(obj, newValue)
            obj.Message = newValue;
            obj.updateMessage(obj.Message)
        end
    end

    methods (Access = private)
        function createAxes(obj)
            hFigure = ancestor(obj.Parent, 'figure');
            if matlab.ui.internal.isUIFigure(hFigure)
                obj.Axes = uiaxes(obj.Parent);
            else
                obj.Axes = axes(obj.Parent);
            end
            obj.Axes.Units = 'pixels';
            obj.Axes.InnerPosition = [obj.Location, obj.Size];
            %axis(obj.Axes, 'equal');
            
            hold(obj.Axes, 'on')
            obj.Axes.XLim = [-1,obj.Size(1)+1];
            obj.Axes.YLim = [-1,obj.Size(2)+1];

            obj.Axes.XAxis.Visible = 'off';
            obj.Axes.YAxis.Visible = 'off';

            if isa(obj.Parent, 'figure')
                % Need to place the axes in a panel and turn
                % AutoResizeChildren off
                if matlab.ui.internal.isUIFigure(hFigure)
                    obj.Panel = uipanel(obj.Parent);
                    obj.Panel.BorderType = 'none';
                    if isa(obj.Parent, 'matlab.ui.Figure')
                        obj.Panel.BackgroundColor = obj.Parent.Color;
                    else
                        obj.Panel.BackgroundColor = obj.Parent.BackgroundColor;
                    end
                    obj.Panel.Position=[10,100,obj.Size+[2,4]]; % Add some margins for uiaxes to get correct size. Todo: generalize this.
                    obj.Axes.Parent = obj.Panel;
                    obj.Panel.AutoResizeChildren = 'off';
                    obj.Axes.InnerPosition = [1,1,obj.Size];
                end
            end

            if ~verLessThan('matlab', '9.5.0')
                obj.Axes.Toolbar.Visible = 'off';
                disableDefaultInteractivity(obj.Axes)
            end
        end

        function createTextBox(obj)
            hFigure = ancestor(obj.Parent, 'figure');
            if matlab.ui.internal.isUIFigure(hFigure)
                obj.Textbox = uilabel(obj.Parent);
                %obj.Textbox.VerticalAlignment = 'top';
                obj.Textbox.WordWrap = 'on';

                obj.Textbox.Text = obj.Text;
            else
                obj.Textbox = uicontrol(obj.Parent, 'style', 'text');
                obj.Textbox.String = obj.Text;
                obj.Textbox.HorizontalAlignment = 'left';
            end

            obj.Textbox.Position(1) = obj.Location(1)+1;
            obj.Textbox.Position(2) = sum(obj.Axes.InnerPosition([2,4])) + 3;
            obj.Textbox.Position(3) = obj.Size(1);
            obj.Textbox.Position(4) = 32;
        end

        function drawProgressBar(obj)
            
            barLength = obj.Size(1);
            barHeight = obj.Size(2);

            [X1, Y1] = get_rectangle_coords([barLength, barHeight], barHeight/2, 50);
            obj.BarBackground = patch(obj.Axes, X1, Y1, obj.BackgroundColor);
            obj.BarBackground.EdgeColor = obj.ForegroundColor;
            obj.BarBackground.LineWidth = obj.BorderWidth;

            barLength = barLength*obj.Value;
            [X2, Y2] = get_rectangle_coords([barLength*obj.Value, barHeight], barHeight/2, 50);
            if barLength < barHeight
                X2(:) = nan;
            end

            obj.BarForeground = patch(obj.Axes, X2, Y2, obj.ForegroundColor);                        
        end

        function updateProgressBar(obj)
            if isempty(obj.BarForeground); return; end
            barLength = obj.Size(1);
            barHeight = obj.Size(2);

            barLength = barLength*obj.Value;
            [X2, Y2] = get_rectangle_coords([barLength, barHeight], barHeight/2);
            if barLength <= 0 % barHeight
                X2(:) = nan;
            end
            set(obj.BarForeground, 'XData', X2, 'YData', Y2);
        end
    end
end

function varargout = get_rectangle_coords(boxSize, cornerRadius, numCornerSegmentPoints)
%uim.shape.rectangle Create edgecoordinates for outline of a rectangle
% 
%   [edgeCoordinates] = uim.shape.rectangle(boxSize) creates 
%   edgeCoordinates for a box of size boxSize ([width, height]). This function 
%   creates edgeCoordinates for each unit length of width and height.
%   edgeCoordinates is a nx2 vector of x and y coordinates where 
%   n = 2 x (height+1) + 2 x (width+1)
%
%   [xCoords, yCoords] = uim.shape.rectangle(boxSize) returns xCoords and 
%   yCoords are separate vectors.
%
%   [xCoords, yCoords] = createBox(boxSize, cornerRadius) creates the
%   rectangle boundary coordinates with rounded corners.
%
%   [xCoords, yCoords] = createBox(boxSize, cornerRadius, numCornerPoints)
%   additionally specifies how many points to dra for round corners. Higher
%   value gives a finer resolution (Default = 25)
%
% Coordinates starts in the upper left corner and traverses the box ccw
%
%        <--
%  ul _ _ _ _ _          y ^
%    |         | ^         |
%  | |         | |         |
%  v |_ _ _ _ _|            -------> x
%        -->               0

%   Written by Eivind Hennestad

    if nargin < 3; numCornerSegmentPoints = 25; end
    if nargin < 2; cornerRadius = 0; end
    
    boxSize = round(boxSize);

    if any(boxSize==0)
        [xx, yy] = deal(nan);
    
    elseif cornerRadius == 0
        xx = [0, 0, boxSize(1), boxSize(1)];
        yy = [boxSize(2), 0, 0, boxSize(2)];

    else
        numPoints = numCornerSegmentPoints * 4;
        segmentInd = repmat(1:4, numCornerSegmentPoints, 1);

        thetaOffset = (360 / numPoints) / 2;

        theta = linspace(thetaOffset, 360-thetaOffset, numPoints);
        theta = theta + 90; % 1st segment should be upper left
        theta = deg2rad(theta);

        rho = ones(size(theta)) .* cornerRadius;

        [xx, yy] = pol2cart(theta, rho);

        % Shift so that circle is in the 1st quadrant of the coordinate system
        xx = xx-min(xx); yy = yy-min(yy);
   
        isRightSide = segmentInd==3 | segmentInd==4;
        xx(isRightSide) = xx(isRightSide) + boxSize(1) - cornerRadius*2;

        isTopSide = segmentInd==1 | segmentInd==4;
        yy(isTopSide) = yy(isTopSide) + boxSize(2) - cornerRadius*2;

        if boxSize(1) < cornerRadius
            % If the rounded corners are larger than the rectangle itself,
            % we need to correct to prevent creating an "inverted" rounded 
            % rectangle
            thetaIntersect = acos((cornerRadius-boxSize(1)/2)/cornerRadius);
            yOffset = cornerRadius * sin(thetaIntersect);
            yUpper = boxSize(2) / 2 + yOffset;
            yLower = boxSize(2) / 2 - yOffset;

            keep = yy>yLower & yy<yUpper;
            yy = yy(keep);
            xx = xx(keep);
        end

        xx(end+1) = xx(1);
        yy(end+1) = yy(1);
    end
    
    if nargout == 1
        varargout = {[xx', yy']};
    elseif nargout == 2
        varargout = {xx, yy};
    end
end
