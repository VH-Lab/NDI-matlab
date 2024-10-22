function syncgraph_example_figure
% SYNCGRAPH_EXAMPLE_FIGURE - Create an example figure to demonstrate syncgraph
% 
% ndi.demo.syncgraph_example_figure 
%
% Plots a figure that shows relationships between local and global clocks.
% Used in the paper "A platform-independent data interface and database for
% neuroscience physiology and imaging sessions".
%
%



t_utc = 0:0.1:300;

t_elec{1} = 5:0.1:80;
t_elec{2} = 103:0.1:103+65;
t_elec{3} = 103+65+22:0.1:103+65+22+55;

t_visstim{1} = 5+13:0.1:5+13+63;
t_visstim{2} = 100:0.1:170;
t_visstim{3} = 103+65+22-7:0.1:103+65+22+65;


figure

plot([t_utc(1) t_utc(end)], [0 0], 'linewidth', 1.01,'color',[0 0 0]);

hold on;

for i=1:3,
    plot([t_elec{i}(1) t_elec{i}(end)], [1 1], 'linewidth', 1.01,'color',[0 0 0]);
    plot([t_visstim{i}(1) t_visstim{i}(end)], [0.5 0.5], 'linewidth', 1.01,'color',[0 0 0]);
end;

box off;

axis([-10 320 -1 2]);

