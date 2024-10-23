function cbt = loadTechniquesEmployed(tree)
    % loadTechniquesEmployed loads the techniques employed
    % and returns it as a checkList nodes.
    %
    %
    % Output:
    %   cbt - checkList nodes containing the TechniquesEmployed
    %

    treeNodes = [];
    technique = openminds.controlledterms.Technique.CONTROLLED_INSTANCES;
    % Create the tree nodes
    for i = 1:length(technique)
        % node = uitreenode('Text', nodeTexts{1}{i}, 'CheckBox', true);
        % tree.addNode(node);
        node = uitreenode(tree);
        node.Text = technique{i};
    end
    cbt = tree;

end