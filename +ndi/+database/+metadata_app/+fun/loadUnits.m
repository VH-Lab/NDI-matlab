function cbt = loadUnits(tree)
    % loadUnits loads the techniques from the given path
    % and returns it as a checkList nodes.
    %
    %
    % Output:
    %   cbt - checkList nodes containing the loadUnits
    %
    
treeNodes = [];
    
units = openminds.controlledterms.UnitOfMeasurement.CONTROLLED_INSTANCES;

    % Create the tree nodes
    for i = 1:length(units)
        node = uitreenode(tree);
        node.Text = units{i};
    end
    cbt = tree;
end
