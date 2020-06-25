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
	ref = 'NM43',
	dirname = '/Volumes/van-hooser-lab/Projects/NDI/Datasets_to_Convert/Katz/NM43_Raw',
end;

E = ndi_katzlab_expdir(ref, dirname); 

p = E.getprobes('type','n-trode')

p{1}

ioc = E.getprobes('type','intraoral-cannula');
if numel(ioc)~=1,
	error(['Expected exactly 1 ioc; got ' int2str(numel(ioc)) '.']);
end;
ioc = ioc{1};

leftlaser = E.getprobes('name','gctx_opto_left');
if numel(leftlaser)~=1,
	error(['Expected exactly 1 left laser; got ' int2str(numel(leftlaser)) '.']);
end;
leftlaser = leftlaser{1};

[d,t] = p{1}.readtimeseries(1,0,100); % read first epoch, 100 seconds
[data,timevalues,timeref] = ioc.readtimeseriesepoch(1,0,100);
[laserdata,lasertimevalues] = leftlaser.readtimeseriesepoch(1,0,100);

figure;
plot_multichan(d,t,400); % plot with 400 units of space between channels
xlabel('Time(s)');
ylabel('Microvolts');

hold on
A = axis;
for i=1:numel(timevalues.stimon),
	plot(timevalues.stimon(i)*[1 1],A([3 4]),'k-');
end;

for i=1:numel(lasertimevalues.stimon),
	plot(lasertimevalues.stimon(i)*[1 1],A([3 4]),'m-');
end;

