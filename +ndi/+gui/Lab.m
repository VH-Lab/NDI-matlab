classdef Lab < handle
    properties
        editable;
        window;
        panel;
        info;
        panelImage;
        subjects = [];
        probes = [];
        DAQs = [];
        drag;
        dragPt;
        moved = false;
        back;
        zIn;
        zOut;
        editBox;
        editTxt;
        connects = [];
        wires = [];
        row;
        transmitting = true;
    end
    methods
        function obj = Lab()

            guipath = [ndi.common.PathConstants.RootFolder filesep '+ndi' filesep '+gui'];

            % Create lab
            obj.window = axes('position', [1/18 1/12 2/3 2/3], ...
                'XLim', [0 24], 'YLim', [0 16]);
            axis off;
            hold on;
            obj.back = rectangle(obj.window, 'position', [0 0 24 16], ...
                'facecolor', [1 1 1]);

            % Create panel
            obj.panel = uipanel('Position', [7/9 1/12 1/6 2/3], 'BackgroundColor', 'white');

            % Create edit
            obj.editable = false;
            [X, Y] = meshgrid(0:576);
            plot(obj.window, X, Y, 'k', 'Tag', 'XGrid', 'Visible', 'off');
            plot(obj.window, Y, X, 'k', 'Tag', 'YGrid', 'Visible', 'off');
            obj.editBox = rectangle(obj.window, 'position', [0 15 2 1], ...
                'facecolor', [0.9 0.9 0.9]);
            obj.editTxt = text(obj.window, 1, 15.5, 'EDIT', ...
                'HorizontalAlignment', 'center', ...
                'ButtonDownFcn', @obj.editCallback);

            % Create zoom
            obj.zIn = image(obj.window, [22.1 22.9], [15.1 15.9], ...
                flip(imread([guipath filesep 'zoomIn.png']), 1), ...
                'ButtonDownFcn', {@obj.setZoom 2/3});
            obj.zOut = image(obj.window, [23.1 23.9], [15.1 15.9], ...
                flip(imread([guipath filesep 'zoomOut.png']), 1), ...
                'ButtonDownFcn', {@obj.setZoom 3/2});
            colormap(flipud(gray(2)));
        end

        function addSubject(obj, subj)
            for i=1:numel(subj)
                obj.subjects = [obj.subjects ndi.gui.Icon(obj, numel(obj.subjects), ...
                    subj{i}, 1, 1, 4, 3, [0.2 0.4 1])];
            end
        end

        function addProbe(obj, prob)
            for i=1:numel(prob)
                obj.probes = [obj.probes ndi.gui.Icon(obj, numel(obj.probes), ...
                    prob{i}, 6, 6, 2, 3, [0 0.6 0])];
            end
        end

        function addDAQ(obj, daq)
            for i=1:numel(daq)
                obj.DAQs = [obj.DAQs ndi.gui.Icon(obj, numel(obj.DAQs), ...
                    daq{i}, 9, 12, 4, 2, [1 0.6 0])];
            end
            obj.connects = zeros(numel([obj.subjects obj.probes obj.DAQs]));
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

        function details(obj, src)
            if isequal(src.c, [0.2 0.4 1])
                id = {'Not Found' 'Subject' src.elem{1}.document_properties.subject.local_identifier ...
                    src.elem{1}.document_properties.subject.description};
            elseif isequal(src.c, [0 0.6 0])
                id = {src.elem.name src.elem.type src.elem.identifier ''};
            else
                id = {src.elem.name 'DAQ' src.elem.identifier ''};
            end
            delete([obj.info obj.panelImage]);
            obj.info = [uicontrol(obj.panel, 'units', 'normalized', 'Style', 'text', ...
                'Position', [0 15/16 1 1/16], 'String', 'Name:', ...
                'BackgroundColor', [1 1 1], 'FontWeight', 'bold') ...
                uicontrol(obj.panel, 'units', 'normalized', 'Style', 'text', ...
                'Position', [0 3/4 1 3/16], 'String', id{1}, ...
                'BackgroundColor', [1 1 1]) ...
                uicontrol(obj.panel, 'units', 'normalized', 'Style', 'edit', ...
                'Position', [0 1/4 1 1/2], 'min', 0, 'max', 2, ...
                'String', {'Type:' id{2} '' 'ID:' id{3} '' 'Description:' id{4}}, ...
                'enable', 'inactive', 'HorizontalAlignment', 'left') ...
                uicontrol(obj.panel, 'units', 'normalized', 'Style', 'pushbutton', ...
                'Position', [1/6 1/16 2/3 1/8], 'String', 'Upload Image', ...
                'BackgroundColor', [0.9 0.9 0.9], 'Callback', @src.upload)];
            img = get(src.img, 'CData');
            obj.panelImage = image([8/9 18/19], [2/3 3/4], img);
        end

        function setZoom(obj, ~, ~, z)
            if obj.window.XLim(2)*z <= 54 && obj.window.XLim(2)*z >= 16
                set(obj.window, 'XLim', obj.window.XLim*z, ...
                    'YLim', obj.window.YLim*z);
                obj.back.Position = [0 0 obj.window.XLim(2) obj.window.YLim(2)];
                set(obj.zOut, 'XData', get(obj.zOut, 'XData')*z, ...
                    'YData', get(obj.zOut, 'YData')*z);
                set(obj.zIn, 'XData', get(obj.zIn, 'XData')*z, ...
                    'YData', get(obj.zIn, 'YData')*z);
                obj.editBox.Position = [0 obj.editBox.Position(2:4)*z];
                obj.editTxt.Position = [obj.window.XLim(2)/24 ...
                    31*obj.window.YLim(2)/32];
            end
        end

        function iconCallback(obj, ~, ~, src)
            obj.drag = src;
            obj.dragPt = [src.img.XData src.img.YData];
        end

        function move(obj, ~, ~)
            if obj.editable
                cp = get(obj.window, 'CurrentPoint');
                x = cp(1);
                y = cp(3);
                set(gcf, 'Pointer', 'arrow');
                for i = 1:3:numel(obj.wires)
                    if abs(x-obj.wires(i).XData(1))<0.1 && ...
                            y > obj.wires(i).YData(1) && ...
                            y < obj.wires(i).YData(2) || ...
                            abs(y-obj.wires(i+1).YData(1))<0.1 && ...
                            x > obj.wires(i+1).XData(1) && ...
                            x < obj.wires(i+1).XData(2) || ...
                            abs(x-obj.wires(i+2).XData(1))<0.1 && ...
                            y > obj.wires(i+2).YData(1) && ...
                            y < obj.wires(i+2).YData(2)
                        set(gcf, 'Pointer', 'custom');
                    end
                end
                for elem = [obj.subjects obj.probes obj.DAQs]
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
                    if diffX ~= 0 || diffY ~= 0
                        obj.moved = true;
                    end
                    obj.updateConnections();
                end
            end
        end

        function updateConnections(obj)
            delete(obj.wires);
            obj.wires = [];
            elems = [obj.subjects obj.probes obj.DAQs];
            N = numel(elems);
            for r = 1:N
                for c = 1:N
                    out = elems(r);
                    in = elems(c);
                    num = obj.connects(r, c);
                    for k = 1:num
                        xRange = [out.x+(sum(obj.connects(r,1:c-1))+k)*out.w/(sum(obj.connects(r,:))+1) ...
                            in.x+(sum(obj.connects(1:r-1,c))+k)*in.w/(sum(obj.connects(:,c))+1)];
                        if sum(obj.connects(:,c)) > sum(obj.connects(r,:))
                            yRange = [out.y+out.h ...
                                in.y-(sum(obj.connects(1:r-1,c))+k)*(in.y-out.y-out.h)/(sum(obj.connects(:,c))+1) ...
                                in.y];
                        else
                            yRange = [out.y+out.h ...
                                in.y-(sum(obj.connects(r,1:c-1))+k)*(in.y-out.y-out.h)/(sum(obj.connects(r,:))+1) ...
                                in.y];
                        end
                        obj.wires = [obj.wires ...
                            line(obj.window, [xRange(1) xRange(1)], ...
                            [yRange(1) yRange(2)], ...
                            'Color', [1 0 0], 'linewidth', 1.5, ...
                            'ButtonDownFcn', @obj.cut, ...
                            'Tag', strcat(out.tag, '_', in.tag)) ...
                            line(obj.window, [xRange(1) xRange(2)], ...
                            [yRange(2) yRange(2)], ...
                            'Color', [1 0 0], 'linewidth', 1.5, ...
                            'ButtonDownFcn', @obj.cut, ...
                            'Tag', strcat(out.tag, '_', in.tag)) ...
                            line(obj.window, [xRange(2) xRange(2)], ...
                            [yRange(2) yRange(3)], ...
                            'Color', [1 0 0], 'linewidth', 1.5, ...
                            'ButtonDownFcn', @obj.cut, ...
                            'Tag', strcat(out.tag, '_', in.tag))];
                    end
                end
            end
        end

        function cut(obj, src, ~)
            if obj.editable
                out = str2double(src.Tag(1:strfind(src.Tag,'_')-1));
                in = str2double(src.Tag(strfind(src.Tag,'_')+1:end));
                obj.connects(out, in) = obj.connects(out, in) - 1;
                obj.updateConnections();
            end
        end

        function connect(obj, varargin)
            if nargin == 2
                src = varargin{1};
            else
                src = varargin{3};
                obj.symbol(src);
            end
            if isempty(src)
                return;
            end;
            ind = find([obj.subjects obj.probes obj.DAQs] == src, 1);
            if obj.transmitting
                obj.row = ind;
            elseif obj.row ~= ind
                obj.connects(obj.row, ind) = obj.connects(obj.row, ind) + 1;
                obj.updateConnections();
            end
            obj.transmitting = ~obj.transmitting;
        end

        function symbol(obj, src)
            if isequal(src.c, [0.2 0.4 1])
                if src.active == 1
                    for elem = [obj.subjects]
                        elem.active = 0;
                    end
                    for elem = obj.probes
                        elem.active = 2;
                    end
                    src.active = 3;
                else
                    for elem = [obj.subjects obj.probes]
                        elem.active = 1;
                    end
                end
            elseif isequal(src.c, [0 0.6 0])
                if src.active == 1
                    for elem = [obj.subjects obj.probes]
                        elem.active = 0;
                    end
                    for elem = obj.DAQs
                        elem.active = 2;
                    end
                    src.active = 3;
                else
                    for elem = [obj.subjects obj.probes]
                        elem.active = 1;
                    end
                    for elem = [obj.DAQs]
                        elem.active = 0;
                    end
                end
            else
                for elem = [obj.subjects obj.probes]
                    elem.active = 1;
                end
                for elem = obj.DAQs
                    elem.active = 0;
                end
            end
            obj.buttons();
        end

        function buttons(obj)
            color = {[1 1 1] [0 1 0] [1 0 0]};
            for elem = [obj.subjects obj.probes obj.DAQs]
                if elem.active == 0
                    set(elem.term, 'Visible', 'off');
                else
                    set(elem.term, 'Visible', 'on');
                    set(elem.term, 'FaceColor', color{elem.active});
                end
            end
        end
    end
end
