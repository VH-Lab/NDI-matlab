function E = ndi_katzlab_narendra_test(ref, dirname)
% NDI_KATZLAB_NARENDRA_TEST - test reading from Murkherjee et al. 2019
%
% E = NDI_KATZLAB_NARENDRA_TEST(REF, DIRNAME)
%
% Open a directory from Murkherjee et al. (2019, Don Katz lab)
%
% Example:
%   E = ndi_katzlab_narendra_test('/Volumes/van-hooser-lab/Projects/NDI/Datasets_to_Convert/Katz/NM43_Raw');
%
%

if nargin==0,
	disp(['No reference or dirname given, using defaults:']);
	ref = 'MN43',
	dirname = '/Volumes/van-hooser-lab/Projects/NDI/Datasets_to_Convert/Katz/NM43_Raw',
end;

E = ndi_katzlab_expdir(ref, dirname); 

p = E.getprobes()

p{1}

[d,t] = p{1}.readtimeseries(1,0,100); % read first epoch, 100 seconds

figure;
plot_multichan(d,t,400); % plot with 400 units of space between channels
xlabel('Time(s)');
ylabel('Microvolts');


