function cbt = loadInstancesToListBox(listBox, name)
    %loadInstancesToListBox Load the instances of a controlled term into a list box
    %
    % Inputs
    %   listBox: The list box to load the instances into
    %   name: A string representing the name of the openminds controlledterms to load
    %
    
treeNodes = [];
command = sprintf('openminds.controlledterms.%s.CONTROLLED_INSTANCES', name);
instances = eval(command);
instancesCellArray = cellstr(instances);
instancesCellArray = [{'not selected'}, instancesCellArray];
listBox.Items = instancesCellArray;
listBox.Value = instancesCellArray{1};
end
