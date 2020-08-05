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

rightlaser = E.getprobes('name','gctx_opto_right');
if numel(rightlaser)~=1,
	error(['Expected exactly 1 right laser; got ' int2str(numel(rightlaser)) '.']);
end;
rightlaser = rightlaser{1};


t_start = 67;
t_stop = 93;

[d,t] = p{1}.readtimeseries(1,t_start,t_stop); % read first epoch, 100 seconds
[d_emg,t_emg] = p{3}.readtimeseries(1,t_start,t_stop); 
[ioc_data,timevalues,timeref] = ioc.readtimeseriesepoch(1,t_start,t_stop);
[laserdata,lasertimevalues] = leftlaser.readtimeseriesepoch(1,t_start,t_stop);

figure;
plot_multichan(d,t,400); % plot with 400 units of space between channels
xlabel('Time(s)');
ylabel('Microvolts');

hold on
A = axis;
for i=1:numel(timevalues.stimon),
	plot(timevalues.stimon(i)*[1 1],A([3 4]),'k-');
    text(timevalues.stimon(i),A(4)+0.05*diff(A([3 4])),...
        [num2str(1e3*ioc_data.parameters{ioc_data.stimid(i)}.concentration) ' mM '  ioc_data.parameters{ioc_data.stimid(i)}.tastant],...
        'horizontalalignment','center');
end;

for i=1:numel(lasertimevalues.stimon),
	plot(lasertimevalues.stimon(i)*[1 1],A([3 4]),'m-');
end;

hold on
plot(t_emg,d_emg-2000,'g-');

A = axis;
axis([t_start t_stop A(3) A(4)]);
box off;