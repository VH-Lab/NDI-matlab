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
        moved = false;
        back;
        zIn;
        zOut;
        editBox;
        editTxt;
        connects = {};
        transmitting = true;
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
            obj.zIn = image(obj.window, [22.1 22.9], [15.1 15.9], ...
                            flip(imread('zoomIn.png'), 1), ...
                            'ButtonDownFcn', @obj.zoomIn);
            obj.zOut = image(obj.window, [23.1 23.9], [15.1 15.9], ...
                             flip(imread('zoomOut.png'), 1), ...
                             'ButtonDownFcn', @obj.zoomOut);
            colormap(flipud(gray(2)));
        end
                
        function addSubject(obj, icons)
            for i=1:numel(icons)
                obj.subjects = [obj.subjects Icon(obj, numel(obj.subjects), ...
                                icons{i}, 1, 1, 4, 3, [0.2 0.4 1])];
            end
        end
        
        function addProbe(obj, icons)
            for i=1:numel(icons)
                obj.probes = [obj.probes Icon(obj, numel(obj.probes), ...
                              icons{i}, 6, 6, 2, 3, [0 0.6 0])];
            end
        end
        
        function addDAQ(obj, icons)
            for i=1:numel(icons)
                obj.DAQs = [obj.DAQs Icon(obj, numel(obj.DAQs), ...
                            icons{i}, 9, 12, 4, 2, [1 0.6 0])];
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
        
        function move(obj, ~, ~)
            if obj.editable
                cp = get(obj.window, 'CurrentPoint');
                x = cp(1);
                y = cp(3);
                set(gcf, 'Pointer', 'arrow');
                for elem = [obj.subjects obj.probes obj.DAQs]
                    for wire = [elem.transmitted elem.received]
                        if abs(x-wire.XData(1))<0.05 && ...
                           y<max(wire.YData) && y>min(wire.YData) || ...
                           abs(y-wire.YData(1))<0.05 && ...
                           x<max(wire.XData) && x>min(wire.XData)
                            set(gcf, 'Pointer', 'custom');
                        end
                    end
                    if x > elem.x && x < elem.x+elem.w && ...
                       y > elem.y && y < elem.y+elem.h
                        set(gcf, 'Pointer', 'fleur');
                    end
                end
                if obj.drag ~= 0
                    diffX = floor(x-obj.dragPt(1));
                    diffY = floor(y-obj.dragPt(3));
                    obj.drag.x = obj.dragPt(1)+diffX;
                    obj.drag.y = obj.dragPt(3)+diffY;
                    obj.drag.rect.Position = [obj.dragPt(1)+diffX ...
                                              obj.dragPt(3)+diffY ...
                                              obj.drag.w obj.drag.h];
                    set(obj.drag.img, 'XData', obj.dragPt(1:2)+diffX, ...
                        'YData', obj.dragPt(3:4)+diffY);
                    set(obj.drag.term, 'position', ...
                        [obj.dragPt(1)+obj.drag.w-0.25+diffX ...
                         obj.dragPt(3)+obj.drag.h-0.25+diffY 0.5 0.5]);
                    visibility = {get(obj.drag.add, 'visible'), ...
                                  get(obj.drag.check, 'visible'), ...
                                  get(obj.drag.cancel, 'visible')};
                    delete([obj.drag.add obj.drag.check obj.drag.cancel]);
                    obj.drag.add = text(obj.window, ...
                                        obj.dragPt(1)+obj.drag.w+0.01+diffX, ...
                                        obj.dragPt(3)+obj.drag.h+0.01+diffY, ...
                                        '+', 'HorizontalAlignment', ...
                                        'center', 'color', obj.drag.c, ...
                                        'visible', visibility{1}, ...
                                        'ButtonDownFcn', {@obj.connect obj.drag});
                    obj.drag.check = text(obj.window, ...
                                        obj.dragPt(1)+obj.drag.w+0.01+diffX, ...
                                        obj.dragPt(3)+obj.drag.h+0.01+diffY, ...
                                        '?', 'HorizontalAlignment', ...
                                        'center', 'color', obj.drag.c, ...
                                        'visible', visibility{2}, ...
                                        'ButtonDownFcn', {@obj.connect obj.drag});
                    obj.drag.cancel = text(obj.window, ...
                                        obj.dragPt(1)+obj.drag.w+0.01+diffX, ...
                                        obj.dragPt(3)+obj.drag.h+0.01+diffY, ...
                                        'x', 'HorizontalAlignment', ...
                                        'center', 'color', obj.drag.c, ...
                                        'visible', visibility{3}, ...
                                        'ButtonDownFcn', {@obj.connect obj.drag});
                    if diffX ~= 0 || diffY ~= 0
                        obj.moved = true;
                    end
                    obj.updateConnections();
                end
            end    
        end
        
        function updateConnections(obj)
            for elem = [obj.subjects obj.probes obj.DAQs]
                elem.clearWires();
            end
            receivers = [];
            for i = 1:numel(obj.connects)
                receivers = [receivers obj.connects{i}(2:end)];
            end
            rem = receivers;
            for i = 1:numel(obj.connects)
                order = [];
                elem = obj.connects{i};
                out = elem(1);
                for rec = elem(2:end)
                    order = [order rec.x];
                end
                [~, ind] = sort(order, 'descend');
                elem(2:end) = elem(ind+1);
                for j = 2:numel(elem)
                    in = elem(j);
                    count = sum(receivers(:) == in)+1;
                    remain = sum(rem(:) == in);
                    start = [out.x+out.w ...
                             out.y+(j-1)*out.h/numel(elem)];
                    stop = [in.x+(remain)*in.w/count in.y];
                    out.transmit(start(1), stop(1), start(2), start(2), [i j]);
                    in.receive(stop(1), stop(1), start(2), stop(2), [i j]);
                    rem(find(rem == in, 1)) = [];
                end
            end
        end
        
        function cut(obj, src, wire)
            ind = find(src.transmitted == wire, 1);
            if ~isempty(ind)
                if numel(obj.connects{src.transInd(2*ind-1)}) == 2
                    obj.connects(src.transInd(2*ind-1)) = [];
                else
                    elem = obj.connects{src.transInd(2*ind-1)};
                    elem(src.transInd(2*ind)) = [];
                    obj.connects(src.transInd(2*ind-1)) = {elem};
                end
            else
                ind = find(src.received == wire, 1);
                if numel(obj.connects{src.recInd(2*ind-1)}) == 2
                    obj.connects(src.recInd(2*ind-1)) = [];
                else
                    elem = obj.connects{src.recInd(2*ind-1)};
                    elem(src.recInd(2*ind)) = [];
                    obj.connects(src.recInd(2*ind-1)) = {elem};
                end
            end
        end
        
        function connect(obj, ~, ~, src)
            obj.symbol(src);
            fun = cellfun(@(v)v(1), obj.connects);
            index = find(fun == src, 1);
            if ~isempty(index)
                obj.connects([index end]) = obj.connects([end index]);
            else
                if obj.transmitting
                    obj.connects(end+1) = {src};
                else
                    obj.connects(end) = {[obj.connects{end} src]};
                    obj.updateConnections();
                end
            end
            obj.transmitting = ~obj.transmitting;
        end
        
        function symbol(obj, src)
            if strcmp(get(src.add, 'visible'), 'on')
                if isequal(src.c, [0.2 0.4 1])
                    for elem = obj.subjects
                        set(elem.add, 'visible', 'off');
                    end
                    for elem = obj.probes
                        set(elem.add, 'visible', 'off');
                        set(elem.check, 'visible', 'on');
                    end
                    for elem = obj.DAQs
                        set(elem.check, 'visible', 'on');
                    end
                else
                    for elem = obj.subjects
                        set(elem.add, 'visible', 'off');
                    end
                    for elem = obj.probes
                        set(elem.add, 'visible', 'off');
                    end
                    for elem = obj.DAQs
                        set(elem.check, 'visible', 'on');
                    end
                end
                set(src.add, 'visible', 'off');
                set(src.cancel, 'visible', 'on');
            elseif strcmp(get(src.cancel, 'visible'), 'on')
                if isequal(src.c, [0.2 0.4 1])
                    for elem = obj.subjects
                        set(elem.add, 'visible', 'on');
                    end
                    for elem = obj.probes
                        set(elem.add, 'visible', 'on');
                        set(elem.check, 'visible', 'off');
                    end
                    for elem = obj.DAQs
                        set(elem.check, 'visible', 'off');
                    end
                else
                    for elem = obj.probes
                        set(elem.add, 'visible', 'on');
                    end
                    for elem = obj.subjects
                        set(elem.add, 'visible', 'on');
                    end
                    for elem = obj.DAQs
                        set(elem.check, 'visible', 'off');
                    end
                end
                set(src.add, 'visible', 'on');
                set(src.cancel, 'visible', 'off');
            elseif strcmp(get(src.check, 'visible'), 'on')
                if isequal(src.c, [0 0.6 0])
                    for elem = obj.subjects
                        set(elem.add, 'visible', 'on');
                        set(elem.cancel, 'visible', 'off');
                    end
                    for elem = obj.probes
                        set(elem.add, 'visible', 'on');
                        set(elem.check, 'visible', 'off');
                    end
                    for elem = obj.DAQs
                        set(elem.check, 'visible', 'off');
                    end
                else
                    for elem = obj.subjects
                        set(elem.add, 'visible', 'on');
                        set(elem.cancel, 'visible', 'off');
                    end
                    for elem = obj.probes
                        set(elem.add, 'visible', 'on');
                        set(elem.check, 'visible', 'off');
                        set(elem.cancel, 'visible', 'off');
                    end
                    for elem = obj.DAQs
                        set(elem.check, 'visible', 'off');
                    end
                end
                set(src.check, 'visible', 'off');
            end
        end
    end
end