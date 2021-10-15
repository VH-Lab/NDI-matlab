classdef Icon < handle
    properties
        elem;
        img;
        rect;
        term;
        src;
        w;
        h;
        x;
        y;
        c;
        active = 1;
        tag;
    end
    methods
        function obj = Icon(src, len, elem, hShift, vShift, w, h, color)
            ndi.globals;
            guipath = [ndi_globals.path.path filesep '+ndi' filesep '+gui'];
            obj.elem = elem;
            obj.src = src;
            obj.w = w;
            obj.h = h;
            obj.x = 8*len+hShift;
            obj.y = vShift;
            obj.c = color;
            obj.tag = num2str(numel([src.subjects src.probes src.DAQs])+1);
            obj.img = image(src.window, ...
                            [(8*len+hShift) (8*len+hShift+w)], ...
                            [vShift (vShift+h)], flip(imread([guipath filesep 'default.png']), 1), ...
                            'ButtonDownFcn', {@src.iconCallback obj});
            obj.rect = rectangle(src.window, 'position', ...
                                 [(8*len+hShift) vShift w h], ...
                                 'edgecolor', color, 'linewidth', 1.5);
            obj.term = rectangle(src.window, ...
                                 'position', [8*len+hShift+w-0.25 ...
                                 vShift+h-0.25 0.5 0.5], ...
                                 'Curvature', [1 1], 'FaceColor', [1 1 1], ...
                                 'edgecolor', color, 'linewidth', 1.5, ...
                                 'ButtonDownFcn', {@src.connect obj});
            if isequal(color, [1 0.6 0])
                obj.active = 0;
                set(obj.term, 'Visible', 'off');
            end
        end
        
        function upload(obj, ~, ~)
            [file, path] = uigetfile({'*.png'; '*.jpg'; '*.jpeg'});
            obj.img.CData = flip(imread(strcat(path, file)), 1);
        end
    end
end
