function cbt = loadInstancesToTreeCheckbox(tree, name)
    %loadInstancesToTreeCheckbox Load the instances of a controlled term into a tree checkbox 
    %
    % Inputs
    %   tree: The tree to load the instances into
    %   name: A string representing the name of the openminds controlledterms to load
    %

[names, options] = ndi.database.metadata_app.fun.getOpenMindsInstances(name);

for i = 1:numel(names)
    node = uitreenode(tree);
    node.Text = options{i};
    node.NodeData = names{i};
end
cbt = tree;
end
