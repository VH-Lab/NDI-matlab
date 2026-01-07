function [fig] = bar3(dataTable, groupingVariables, plottingVariable)
% BAR3 Creates a 3-way grouped bar chart from table data.
%   BAR3(dataTable, groupingVariables, plottingVariable) takes a table and
%   visualizes the mean of plottingVariable across three categorical factors.
%
%   Example:
%       bar3(myData, {'Region', 'Quarter', 'Product'}, 'Sales')

    % 1. Extract indices and unique categories for each grouping variable
    indGroups = nan(height(dataTable), numel(groupingVariables));
    variableGroups = cell(numel(groupingVariables), 1);
    
    for i = 1:numel(groupingVariables)
        [variableGroups{i}, ~, indGroups(:,i)] = unique(dataTable(:, groupingVariables{i}));
    end
    
    groupSizes = cellfun(@numel, variableGroups);
    
    % 2. Initialize Figure and Colors
    % Generates a distinct color for each 'inner' group (Variable 3)
    colors = lines(groupSizes(3)); 
    fig = figure('Color', 'w');
    
    % 3. Plotting Loop
    % Outer Loop: Subplots (Variable 1)
    for i = 1:groupSizes(1)
        subplot(1, groupSizes(1), i)
        hold on;
        
        % Middle Loop: X-axis clusters (Variable 2)
        for j = 1:groupSizes(2)
            % Inner Loop: Individual Bars (Variable 3)
            for k = 1:groupSizes(3)
                % Logical indexing to find matching rows
                ind = indGroups(:,1) == i & indGroups(:,2) == j & indGroups(:,3) == k;
                
                % Calculate X position with spacing between clusters
                x = (j-1)*(groupSizes(3)+1) + k;
                
                % Extract data and plot mean
                y = dataTable{ind, plottingVariable};
                if ~isempty(y)
                    bar(x, mean(y), 'FaceColor', colors(k,:));
                end
            end
        end
        
        % 4. Formatting Subplots
        % Center X-ticks under the bar groups
        tickPositions = ((groupSizes(3)+1)*(0:groupSizes(2)-1)) + (groupSizes(3)+1)/2;
        xticks(tickPositions)
        xticklabels(table2cell(variableGroups{2}))
        
        title(string(table2cell(variableGroups{1}(i,:))))
        ylabel(plottingVariable)
        
        if i == groupSizes(1)
            legend(string(table2cell(variableGroups{3})), 'Box', 'off')
        end
    end
end