classdef Data < handle
    properties
        fullDocuments = [];
        fullTable = {};
        tempDocuments = [];
        tempTable = {};
        search;
        table;
        panel;
        name;
        info;
    end
    methods
        function obj = Data()
            obj.table = uitable('units', 'normalized', 'Visible', 'off', ...
                                'Position', [1/18 1/12 2/3 5/8], ...
                                'ColumnName', {'Name'; 'ID'; 'Type'; 'Date'}, ...
                                'ColumnWidth', {85, 160, 85, 85}, ...
                                'Data', {}, 'CellSelectionCallback', @obj.details);
            obj.panel = uipanel('Position', [7/9 1/12 1/6 2/3], 'Visible', 'off', ...
                                'BackgroundColor', 'white');
            obj.search = [uicontrol('units', 'normalized', 'Style', 'popupmenu', 'FontSize', 10.25, ...
                                    'Position', [1/18 17/24 7/36 1/24], 'String', {'Select' 'Name' 'ID' 'Type' 'Date'}, ...
                                    'BackgroundColor', [0.9 0.9 0.9], 'Visible', 'off') ...
                          uicontrol('units', 'normalized', 'Style', 'popupmenu', 'FontSize', 10.25, ...
                                    'Position', [9/36 17/24 7/36 1/24], 'String', {'' 'contains' 'begins with' 'ends with'}, ...
                                    'BackgroundColor', [0.9 0.9 0.9], 'Visible', 'off') ...
                          uicontrol('units', 'normalized', 'Style', 'edit', ...
                                    'Position', [4/9 17/24 7/36 1/24], 'String', '', ...
                                    'BackgroundColor', [1 1 1], 'Visible', 'off') ...
                          uicontrol('units', 'normalized', 'Style', 'pushbutton', ...
                                    'Position', [23/36 17/24 1/12 1/24], 'String', 'Search', ...
                                    'BackgroundColor', [0.9 0.9 0.9], 'Visible', 'off', 'Callback', @obj.filter)];
        end
        
        function addDoc(obj, docs)
            for i=1:numel(docs)
                obj.fullDocuments = [obj.fullDocuments; docs{i}];
                d = docs{i}.document_properties.ndi_document;
                obj.fullTable(end+1,:) = {d.name d.id d.type d.datestamp};
            end
            obj.tempTable = obj.fullTable;
            obj.tempDocuments = obj.fullDocuments;
            obj.table.Data = obj.fullTable;
        end
        
        function filter(obj, ~, ~)
            if obj.search(2).Value == 2
                obj.tempTable = {};
                obj.tempDocuments = [];
                for i = 1:numel(obj.fullTable)/4
                    if contains(lower(obj.fullTable{i,obj.search(1).Value-1}), lower(obj.search(3).String))
                        obj.tempTable(end+1,:) = obj.fullTable(i,:);
                        obj.tempDocuments = [obj.tempDocuments obj.fullDocuments(i)];
                    end
                end
            elseif obj.search(2).Value == 3
                obj.tempTable = {};
                obj.tempDocuments = [];
                for i = 1:numel(obj.fullTable)/4
                    if startsWith(lower(obj.fullTable{i,obj.search(1).Value-1}), lower(obj.search(3).String))
                        obj.tempTable(end+1,:) = obj.fullTable(i,:);
                        obj.tempDocuments = [obj.tempDocuments obj.fullDocuments(i)];
                    end
                end
            elseif obj.search(2).Value == 4
                obj.tempTable = {};
                obj.tempDocuments = [];
                for i = 1:numel(obj.fullTable)/4
                    if endsWith(lower(obj.fullTable{i,obj.search(1).Value-1}), lower(obj.search(3).String))
                        obj.tempTable(end+1,:) = obj.fullTable(i,:);
                        obj.tempDocuments = [obj.tempDocuments obj.fullDocuments(i)];
                    end
                end
            end
            obj.table.Data = obj.tempTable;
        end
        
        function details(obj, ~, event)
            if ~isempty(event.Indices)
                id = obj.table.Data(event.Indices(1),:);
                delete(obj.info);
                obj.info = [uicontrol(obj.panel, 'units', 'normalized', 'Style', 'text', ...
                                      'Position', [0 15/16 1 1/16], 'String', 'Name:', ...
                                      'BackgroundColor', [1 1 1], 'FontWeight', 'bold') ...
                            uicontrol(obj.panel, 'units', 'normalized', 'Style', 'text', ...
                                      'Position', [0 3/4 1 3/16], 'String', id{1}, ...
                                      'BackgroundColor', [1 1 1]) ...
                            uicontrol(obj.panel, 'units', 'normalized', 'Style', 'edit', ...
                                      'Position', [0 1/4 1 1/2], 'min', 0, 'max', 2, ...
                                      'String', {'Type:' id{3} '' 'Date:' id{4} '' 'ID:' id{2}}, ...
                                      'enable', 'inactive', 'HorizontalAlignment', 'left', 'BackgroundColor', [1 1 1]) ...
                            uicontrol(obj.panel, 'units', 'normalized', 'Style', 'pushbutton', ...
                                      'Position', [1/6 7/48 2/3 1/16], 'String', 'Graph', ...
                                      'BackgroundColor', [0.9 0.9 0.9], 'Callback', {@obj.graph event.Indices(1)}) ...
                            uicontrol(obj.panel, 'units', 'normalized', 'Style', 'pushbutton', ...
                                      'Position', [1/6 1/24 2/3 1/16], 'String', 'Subgraph', ...
                                      'BackgroundColor', [0.9 0.9 0.9], 'Callback', {@obj.subgraph event.Indices(1)})];
            end
        end
        
        function graph(obj, ~, ~, ind)
            s = [];
            t = [];
            for i = 1:numel(obj.fullDocuments)
                if eq(obj.fullDocuments(i), obj.tempDocuments(ind))
                    ind = i;
                end
            end
            for i = 1:numel(obj.fullDocuments)
                if isfield(obj.fullDocuments(i).document_properties, 'depends_on')
                    depends = obj.fullDocuments(i).document_properties.depends_on;
                    for j = 1:numel(depends)
                        for k = 1:numel(obj.fullDocuments)
                            if isequal(obj.fullDocuments(k).document_properties.ndi_document.id, depends(j).value)
                                s = [s i];
                                t = [t k];
                            end
                        end
                    end
                end
            end
            figure('position', [920, 100, 480, 480], 'resize', 'off');
            ax = axes('position', [0 0 1 1]);
            p = plot(ax, digraph(s, t), 'layout', 'layered');
            highlight(p, ind, 'NodeColor', 'r', 'MarkerSize', 6);
            set(gca, 'ydir', 'reverse');
        end
        
        function subgraph(obj, ~, ~, ind)
            s = [];
            t = [];
            for i = 1:numel(obj.fullDocuments)
                if eq(obj.fullDocuments(i), obj.tempDocuments(ind))
                    ind = i;
                    d = obj.fullDocuments(ind);
                end
            end
            for i = 1:numel(obj.fullDocuments)
                if isfield(obj.fullDocuments(i).document_properties, 'depends_on')
                    depends = obj.fullDocuments(i).document_properties.depends_on;
                    for j = 1:numel(depends)
                        if isequal(d.document_properties.ndi_document.id, depends(j).value)
                            s = [s i];
                            t = [t ind];
                        elseif eq(obj.fullDocuments(i), d)
                            for k = 1:numel(obj.fullDocuments)
                                if isequal(obj.fullDocuments(k).document_properties.ndi_document.id, depends(j).value)
                                    s = [s ind];
                                    t = [t k];
                                end
                            end
                        end
                    end
                end
            end
            g = digraph(s, t);
            d = indegree(g)+outdegree(g);
            g = rmnode(g, find(d==0));
            figure('position', [920, 100, 480, 480], 'resize', 'off');
            ax = axes('position', [0 0 1 1]);
            p = plot(ax, g, 'layout', 'layered');
            highlight(p, ind-numel(find(find(d==0)<ind)), 'NodeColor', 'r', 'MarkerSize', 6);
        end
    end
end
