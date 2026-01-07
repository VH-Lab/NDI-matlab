function [fig] = bar3(dataTable,groupingVariables,plottingVariable)

% Get indices of grouping variables
indGroups = nan(height(dataTable),numel(groupingVariables));
variableGroups = cell(numel(groupingVariables),1);
for i = 1:numel(groupingVariables)
    [variableGroups{i},~,indGroups(:,i)] = unique(dataTable(:,groupingVariables{i}));
end
groupSizes = cellfun(@numel,variableGroups);

% Plot data
colors = rand(groupSizes(3), 3);
fig = figure;
for i = 1:groupSizes(1)
    subplot(1,groupSizes(1),i)
    hold on;
    for j = 1:groupSizes(2)
        for k = 1:groupSizes(3)
            ind = indGroups(:,1) == i & indGroups(:,2) == j & indGroups(:,3) == k;
            x = (j-0.5)*(groupSizes(3)+1) + k;
            y = dataTable{ind,plottingVariable};
            bar(x,mean(y),'FaceColor',colors(k,:));
        end
    end
    xticks((groupSizes(3)+1)*(1:groupSizes(2)))
    xticklabels(table2cell(variableGroups{2}))
    title(variableGroups{1}{i,:})
    legend(table2cell(variableGroups{3}),'Box','off')
    ylabel(plottingVariable)
end

end