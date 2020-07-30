classdef Icon < handle
    properties
        img;
        rect;
        term;
        src;
        w;
        h;
        x;
        y;
        transmitted = [];
        received = [];
        transInd = [];
        recInd = [];
        c;
        add;
        check;
        cancel;
    end
    methods
        function obj = Icon(src, len, icon, hShift, vShift, w, h, color)
            obj.src = src;
            obj.w = w;
            obj.h = h;
            obj.x = 8*len+hShift;
            obj.y = vShift;
            obj.c = color;
            obj.img = image(src.window, ...
                            [(8*len+hShift) (8*len+hShift+w)], ...
                            [vShift (vShift+h)], flip(imread(icon), 1), ...
                            'ButtonDownFcn', @obj.iconCallback);
            obj.rect = rectangle(src.window, 'position', ...
                                 [(8*len+hShift) vShift w h], ...
                                 'edgecolor', color, 'linewidth', 1.5);
            obj.term = rectangle(src.window, ...
                                 'position', [8*len+hShift+w-0.25 ...
                                 vShift+h-0.25 0.5 0.5], ...
                                 'Curvature', [1 1], 'FaceColor', [1 1 1], ...
                                 'edgecolor', color, 'linewidth', 1.5, ...
                                 'ButtonDownFcn', {@src.connect obj});
            obj.add = text(src.window, 8*len+hShift+w+0.01, vShift+h+0.01, ...
                           '+', 'HorizontalAlignment', 'center', 'color', ...
                           color, 'ButtonDownFcn', {@src.connect obj});
            obj.check = text(src.window, 8*len+hShift+w+0.01, vShift+h+0.01, ...
                           '?', 'HorizontalAlignment', 'center', 'color', ...
                           color, 'visible', 'off', ...
                           'ButtonDownFcn', {@src.connect obj});
            obj.cancel = text(src.window, 8*len+hShift+w+0.01, vShift+h+0.01, ...
                           'x', 'HorizontalAlignment', 'center', 'color', ...
                           color, 'visible', 'off', ...
                           'ButtonDownFcn', {@src.connect obj});
            if isequal(color, [1 0.6 0])
                set(obj.add, 'visible', 'off');
                set(obj.term, 'ButtonDownFcn', []);
            end
        end
        
        function iconCallback(obj, ~, ~)
            obj.src.drag = obj;
            obj.src.dragPt = [obj.img.XData obj.img.YData];
            
        end
        
        function transmit(obj, startX, endX, startY, endY, ind)
            obj.transmitted = [obj.transmitted ...
                               line(obj.src.window, [startX endX], ...
                                    [startY endY], 'Color', [1 0 0], ...
                                    'linewidth', 1.5, 'ButtonDownFcn', ...
                                    @obj.cut)];
            obj.transInd = [obj.transInd ind];
        end
        
        function receive(obj, startX, endX, startY, endY, ind)
            obj.received = [obj.received ...
                            line(obj.src.window, [startX endX], ...
                                 [startY endY], 'Color', [1 0 0], ...
                                 'linewidth', 1.5, 'ButtonDownFcn', ...
                                 @obj.cut)];
            obj.recInd = [obj.recInd ind];
        end
        
        function cut(obj, src, ~)
            obj.src.cut(obj, src);
            obj.src.updateConnections();
        end
        
        function clearWires(obj)
            delete([obj.transmitted obj.received]);
            obj.transmitted = [];
            obj.received = [];
            obj.transInd = [];
            obj.recInd = [];
        end
    end
end