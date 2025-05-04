classdef FolderOrganizationTableController < handle
% FolderOrganizationTableController - Controller class for folder organization table
%
%   This class should respond to a user's actions in the FolderOrganization
%   page and update the FolderOrganization model accordingly.

% Todo: 
%   [ ] Create the table toolbar and also assign its callbacks. 
%   [ ] Store the view handle as a controller property


    properties (Access = private)
        % UITable - Handle object of the UITable representing the folder levels
        UITable
    end

    properties (Access = private)
        % DataModel - Handle of a FolderOrganizationModel object.
        DataModel
    end

    methods % Constructor
        function obj = FolderOrganizationTableController(dataModel, uiTable)
            if ~nargin; return; end
            
            % Assign controller dependencies
            obj.DataModel = dataModel;
            obj.UITable = uiTable;

            % Assign controller callbacks
            obj.UITable.CellEditedFcn = @obj.onTableCellValueChanged;
            obj.UITable.AddRowFcn = @obj.onAddSubfolderLevelButtonPushed;
            obj.UITable.RowRemovedFcn = @obj.onSubfolderLevelRemoved;
        end
    end

    methods (Access = private)
        % Callback handler for value change in FolderLevel table.
        function onTableCellValueChanged(obj, ~, evt)
            rowInd = evt.Indices(1);
            varName = evt.ColumnName;
            newValue = evt.NewData;

            % Process input
            switch varName
                case 'Expression'
                    newValue = numbersign2expression(evt.NewData);

                case 'IgnoreList'
                    newValue = strtrim( strsplit(newValue, ',') );
                    newValue = newValue(~cellfun('isempty', newValue));
                    newValue = string(newValue);
                
                case 'Name' % Make sure "placeholder" value does not end up in model
                    if strcmp(newValue, '<Select a Folder>')
                        newValue = '';
                    end
            end

            obj.DataModel.updateFolderLevel(rowInd, varName, newValue)
        end

        % Callback handler for button to add more subfolder levels.
        function onAddSubfolderLevelButtonPushed(obj, ~, ~)
            try
                obj.DataModel.assertExistSubfolders()
                obj.DataModel.addSubFolderLevel()
            catch ME
                switch ME.identifier
                    case 'NDI:FolderModel:FolderNameIsEmpty'
                        error('Please select a subfolder for each folder level before adding a new folder level')
                    otherwise
                        rethrow(ME)
                end
            end
        end

        % Callback handler for when subfolder is removed.
        function onSubfolderLevelRemoved(obj, ~, evt)
            obj.DataModel.removeSubfolderLevel(evt.RowIndex)
        end
    end
end

function str = numbersign2expression(str)
% numbersign2expression - Convert number signs (#) to regexp expression
%
%   Example:
%       str = test###;
%       expr = numbersign2expression(str)
%
%       expr =
%
%           test\d{3}

    assert(ischar(str), 'Input must be a character vector')

    numChars = numel(str);
    for i = numChars:-1:1
    
        searchStr = repmat('#', 1, i);
        replaceStr = ['\', sprintf('d{%d}', i)];
        
        str = strrep(str, searchStr, replaceStr);
    end
end
