function E = marderlab_hamood(ref, dirname)
% ndi.test.setup.marderlab_hamood - test reading from Murkherjee et al. 2019
%
% E = ndi.test.setup.marderlab_hamood(REF, DIRNAME)
%
% Open a directory from Hamood et al. (2015, Eve Marder lab)
%
% Example:
%   E = ndi.test.setups.marderlab_hamood('811_05','/Volumes/van-hooser-lab/Projects/NDI/Datasets_to_Convert/Marder/Data/811/811_05');
%


if nargin==0,
    disp(['No reference or dirname given, using defaults:']);
    ref = '811_105',
    dirname = '/Volumes/van-hooser-lab/Projects/NDI/Datasets_to_Convert/Marder/Data/811/811_105',
end;

E = ndi.setup.marderlab(ref, dirname); 

d = E.daqsystem_load('name','marder_ced');

et = d.epochtable();

disp(['Found ' int2str(numel(et)) ' epochs.']);

p_lvn = E.getprobes('name','lvn')
p_pdn = E.getprobes('name','pdn')

[d_lvn,t_lvn] = p_lvn{1}.readtimeseries(1,0,100); % read first epoch, 100 seconds

[d_pdn, t_pdn] = p_pdn{1}.readtimeseries(1,0,100); % read first epoch, 100 seconds

figure;
vlt.plot.plot_multichan([d_lvn(:) d_pdn(:)],t_lvn,1); % plot with 1 unit of space between channels
xlabel('Time(s)');
ylabel('Microvolts');
box off;
