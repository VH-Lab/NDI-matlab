function E = ndi_angeluccilab_test(ref, dirname)
% NDI_ANGELUCCILAB_TEST - test reading from Angelucci lab data
%
% E = NDI_ANGELUCCILAB_TEST(REF, DIRNAME)
%
% Open a directory from test data provided by Angelucci lab 
%
% Example:
%   E = ndi_angeluccilab_test('/Volumes/van-hooser-lab/Projects/NDI/Datasets_to_Convert/Angelucci/2017-09-11');
%
%

if nargin==0,
	disp(['No reference or dirname given, using defaults:']);
	ref = '2017-09-11',
	dirname = '/Volumes/van-hooser-lab/Projects/NDI/Datasets_to_Convert/Angelucci/2017-09-11'
end;

E = ndi_angeluccilab_expdir(ref, dirname); 

p = E.getprobes('type','n-trode')

p{1}

stimprobe = E.getprobes('type','stimulator')
stimprobe = stimprobe{1};

t_start = 25;
t_stop = 100;

electrodes = 1:100;

[d,t] = p{1}.readtimeseries(1,t_start,t_stop); % read first epoch, 100 seconds
[ds, ts, timeref_]=stimprobe.readtimeseries(timeref,t(1),t(end));

figure;
plot_multichan(d,t,400); % plot with 400 units of space between channels
xlabel('Time(s)');
ylabel('Microvolts');

A = axis;
axis([t_start t_stop A(3) A(4)]);
box off;

keyboard
