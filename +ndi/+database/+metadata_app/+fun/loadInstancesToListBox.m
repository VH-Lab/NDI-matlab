function listBox = loadInstancesToListBox(listBox, name, terms)
    %loadInstancesToListBox Load the instances of a controlled term into a list box
    %
    % Inputs
    %   listBox: The list box to load the instances into
    %   name: A string representing the name of the openminds controlledterms to load
    %   terms: The term to be filtered
    %

    command = sprintf('openminds.controlledterms.%s.CONTROLLED_INSTANCES', name);
    instances = eval(command);
    allInstancesCellArray = cellstr(instances);
    instancesCellArray = {};
    if nargin > 2
        for i = 1:numel(terms)
            %filter allInstancesCellArray to only contain instances that contain the term
            instancesCellArray = [instancesCellArray; allInstancesCellArray(contains(allInstancesCellArray, terms{i}))];
        end
    end
    instancesCellArray = [{'not selected'}, instancesCellArray];
    listBox.Items = instancesCellArray;
    listBox.Value = instancesCellArray{1};
end
