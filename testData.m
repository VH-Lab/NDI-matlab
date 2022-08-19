classdef testData < handle
    
    properties
        fullTable = {}; % store whole file list
        tempDocuments = []; % temp doc on the right
        tempTable = {}; % temp list on the left
        search;
        table;
        panel;
    end
    
    methods
        function obj = testData()
            obj.table = uitable('units', 'normalized', 'Position', [2/36 2/24 20/36 18/24], ...
                                'ColumnName', {'Name'; 'ID'; 'Type'; 'Date'}, ...
                                'ColumnWidth', {100, 100, 100, 100}, ...
                                'Data', {}, 'CellSelectionCallback', @obj.details);
                            
            obj.panel = uipanel('Position', [20/36 2/24 14/36 20/24], 'BackgroundColor', 'white');
            
            obj.search = [uicontrol('units', 'normalized', 'Style', 'popupmenu', 'FontSize', 10.25, ...
                                    'Position', [2/36 20/24 4/36 2/24], 'String', {'Select' 'Name' 'ID' 'Type' 'Date'}, ...
                                    'BackgroundColor', [0.9 0.9 0.9]) ...
                          uicontrol('units', 'normalized', 'Style', 'popupmenu', 'FontSize', 10.25, ...
                                    'Position', [6/36 20/24 6/36 2/24], 'String', {'Filter options' 'contains' 'begins with' 'ends with'}, ...
                                    'BackgroundColor', [0.9 0.9 0.9]) ...
                          uicontrol('units', 'normalized', 'Style', 'edit', ...
                                    'Position', [12/36 20/24 5/36 2/24], 'String', '', ...
                                    'BackgroundColor', [1 1 1]) ...
                          uicontrol('units', 'normalized', 'Style', 'pushbutton', ...
                                    'Position', [17/36 21/24 3/36 1/24], 'String', 'Search', ...
                                    'BackgroundColor', [0.9 0.9 0.9], 'Callback', @obj.filter) ...
                          uicontrol('units', 'normalized', 'Style', 'pushbutton', ...
                          'Position', [17/36 20/24 3/36 1/24], 'String', 'Clear', ...
                          'BackgroundColor', [0.9 0.9 0.9], 'Callback', @obj.clear)];
        end
        
        function addDoc(obj)
            % add code to read and initialize list
            obj.tempTable = obj.fullTable;
            obj.table.Data = obj.fullTable;
        end
        
        function details(obj, ~, event)
            % need to add code to display doc
        end
        
        function filter(obj, ~, ~)
            % add code to filter doc
        end
        
        function clear(obj, ~, ~)
            obj.table.Data = {};
        end
        
    end
end
