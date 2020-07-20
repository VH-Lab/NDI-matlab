classdef Lab < handle
    properties
        editable;
        window;
        subjects = [];
        probes = [];
        DAQs = [];
        drag;
        dragPt;
        info;
        moved;
        back;
        zIn;
        zOut;
        editBox;
        editTxt;
    end
    methods
        function obj = Lab()
            %Create lab
            obj.window = axes('position', [1/18 1/12 2/3 2/3], ...
                              'XLim', [0 24], 'YLim', [0 16]);
            axis off;
            hold on;
            obj.back = rectangle(obj.window, 'position', [0 0 24 16], ...
                                 'facecolor', [1 1 1]);
            
            %Create info
            obj.info = axes('position', [7/9 1/12 1/6 2/3], ...
                            'Xlim', [0 6], 'YLim', [0 16]);
            axis off;
            hold on;
            rectangle(obj.info, 'position', [0 0 6 16], 'facecolor', [1 1 1]);
            
            %Create edit
            obj.editable = false;
            [X, Y] = meshgrid(0:576);
            plot(obj.window, X, Y, 'k', 'Tag', 'XGrid', 'Visible', 'off');
            plot(obj.window, Y, X, 'k', 'Tag', 'YGrid', 'Visible', 'off');
            obj.editBox = rectangle(obj.window, 'position', [0 15 2 1], ...
                                    'facecolor', [0.9 0.9 0.9]);
            obj.editTxt = text(obj.window, 1, 15.5, 'EDIT', ...
                               'HorizontalAlignment', 'center', ...
                               'ButtonDownFcn', @obj.editCallback);
        
            %Create zoom
            obj.zIn = image(obj.window, [22 23], [15 16], ...
                            flip(imread('zoomIn.png'), 1), ...
                            'ButtonDownFcn', @obj.zoomIn);
            obj.zOut = image(obj.window, [23 24], [15 16], ...
                             flip(imread('zoomOut.png'), 1), ...
                             'ButtonDownFcn', @obj.zoomOut);
        end
                
        function addSubject(obj, icons)
            for i=1:numel(icons)
                obj.subjects = [obj.subjects Icon(obj, numel(obj.subjects), ...
                                icons{i}, 1, 1, 4, 3)];
            end
        end
        
        function addProbe(obj, icons)
            for i=1:numel(icons)
                obj.probes = [obj.probes Icon(obj, numel(obj.probes), ...
                              icons{i}, 6, 6, 2, 3)];
            end
        end
        
        function addDAQ(obj, icons)
            for i=1:numel(icons)
                obj.DAQs = [obj.DAQs Icon(obj, numel(obj.DAQs), ...
                            icons{i}, 9, 12, 4, 2)];
            end
        end
        
        function editCallback(obj, ~, ~)
            set(obj.editBox, 'facecolor', 1-get(obj.editBox, 'facecolor'));
            set(obj.editTxt, 'Color', 1-get(obj.editTxt, 'Color'));
            obj.editable = ~obj.editable;
            obj.grid();
        end
        
        function grid(obj)
            if obj.editable
                set(findobj(obj.window, 'Tag', 'XGrid'), 'Visible', 'on');
                set(findobj(obj.window, 'Tag', 'YGrid'), 'Visible', 'on');
            else
                set(findobj(obj.window, 'Tag', 'XGrid'), 'Visible', 'off');
                set(findobj(obj.window, 'Tag', 'YGrid'), 'Visible', 'off');
            end
        end
        
        function details(obj, img)
            image(obj.info, [4 6], [14 16], img);
            rectangle(obj.info, 'position', [4 14 2 2]);
            rectangle(obj.info, 'position', [0 14 4 2]);
            rectangle(obj.info, 'position', [0 5 6 9]);
        end
        
        function terminalCallback(obj, ~, ~)
            %WIP
        end
        
        function zoomOut(obj, ~, ~)
            set(obj.window, 'XLim', [0 obj.window.XLim(2)*2], ...
                'YLim', [0 obj.window.YLim(2)*2]);
            obj.back.Position = [0 0 obj.back.Position(3)*2 ...
                                 obj.back.Position(4)*2];
            set(obj.zOut, 'XData', get(obj.zOut, 'XData')*2, ...
                'YData', get(obj.zOut, 'YData')*2);
            set(obj.zIn, 'XData', get(obj.zIn, 'XData')*2, ...
                'YData', get(obj.zIn, 'YData')*2);
            obj.editBox.Position = [0 obj.editBox.Position(2:4)*2];
            delete(obj.editTxt);
            obj.editTxt = text(obj.window, obj.window.XLim(2)/24, ...
                               31*obj.window.YLim(2)/32, ...
                               'EDIT', 'HorizontalAlignment', 'center', ...
                               'ButtonDownFcn', @obj.editCallback);
            if obj.editable
            	set(obj.editTxt, 'Color', [1 1 1])
            end
        end
        
        function zoomIn(obj, ~, ~)
            set(obj.window, 'XLim', [0 obj.window.XLim(2)/2], ...
                'YLim', [0 obj.window.YLim(2)/2]);
            obj.back.Position = [0 0 obj.back.Position(3)/2 ...
                                 obj.back.Position(4)/2];
            set(obj.zOut, 'XData', get(obj.zOut, 'XData')/2, ...
                'YData', get(obj.zOut, 'YData')/2);
            set(obj.zIn, 'XData', get(obj.zIn, 'XData')/2, ...
                'YData', get(obj.zIn, 'YData')/2);
            obj.editBox.Position = [0 obj.editBox.Position(2:4)/2];
            delete(obj.editTxt);
            obj.editTxt = text(obj.window, obj.window.XLim(2)/24, ...
                               31/32*obj.window.YLim(2), ...
                               'EDIT', 'HorizontalAlignment', 'center', ...
                               'ButtonDownFcn', @obj.editCallback);
            if obj.editable
            	set(obj.editTxt, 'Color', [1 1 1])
            end
        end
    end
end