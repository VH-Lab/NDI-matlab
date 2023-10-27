function cbt = loadUnits(tree, filePath)
    % loadUnits loads the techniques from the given path
    % and returns it as a checkList nodes.
    %
    % Input:
    %   filePath - path to the loadUnits
    %
    % Output:
    %   cbt - checkList nodes containing the loadUnits
    %

    % Define the file path
    if nargin < 2
        filePath = fullfile(fileparts(mfilename('fullpath')), 'Unit.txt');
    end
    
    treeNodes = [];
    
    % Check if the file exists
    if exist(filePath, 'file') == 2
        % Read the text file
        fileID = fopen(filePath, 'r');
        nodeTexts = textscan(fileID, '%s', 'Delimiter', '\n');
        fclose(fileID);
    

        % Create the tree nodes
        for i = 1:length(nodeTexts{1})
            % node = uitreenode('Text', nodeTexts{1}{i}, 'CheckBox', true);
            % tree.addNode(node);
            node = uitreenode(tree);
            node.Text = nodeTexts{1}{i};
        end
        cbt = tree;
    else
        disp('File Unit.txt not found.');
    end
end