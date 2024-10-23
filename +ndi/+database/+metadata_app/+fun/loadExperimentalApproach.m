function cbt = loadExperimentalApproach(tree)
    % loadExpApproach loads the experimental approach
    % and returns it as a checkList nodes.
    %
    % Output:
    %   cbt - checkList nodes containing the experimental approach
    %


    experimentalApproach = openminds.controlledterms.ExperimentalApproach.CONTROLLED_INSTANCES;
    % Create the tree nodes
    for i = 1:length(experimentalApproach)
        node = uitreenode(tree);
        node.Text = experimentalApproach{i};
    end
    cbt = tree;
end