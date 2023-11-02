function cbt = loadInstancesToTreeCheckbox(tree, name)
    %loadInstancesToTreeCheckbox Load the instances of a controlled term into a tree checkbox 
    %
    % Inputs
    %   tree: The tree to load the instances into
    %   name: A string representing the name of the openminds controlledterms to load
    %

command = sprintf('openminds.controlledterms.%s.CONTROLLED_INSTANCES', name);
instances = eval(command);
for i = 1:numel(instances)
    node = uitreenode(tree);
    node.Text = instances{i};
end
cbt = tree;
end
