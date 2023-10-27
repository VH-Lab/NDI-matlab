function cbt = loadExperimentalApproach(tree, filePath)
    % loadExpApproach loads the experimental approach from the given path
    % and returns it as a checkList nodes.
    %
    % Input:
    %   filePath - path to the experimental approach
    %
    % Output:
    %   cbt - checkList nodes containing the experimental approach
    %

    % Define the file path
    if nargin < 2
        filePath = fullfile(fileparts(mfilename('fullpath')), 'ExperimentalApproach.txt');
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
        disp('File experimental_approach.txt not found.');
    end
end