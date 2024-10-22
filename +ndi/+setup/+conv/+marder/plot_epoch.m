function out=plot_epoch(S, epoch, spacing)
% PLOT_EPOCH - plot an epoch
% 
%

if nargin<3,
    spacing = 3;
end;

dirname = S.getpath()
[parentdir,this_dir] = fileparts(dirname);

fname = fullfile(dirname,[this_dir '_' sprintf('%.4d',epoch) '.abf']);
h = ndr.format.axon.read_abf_header(fname);

D = ndr.format.axon.read_abf(fname,[],'ai', ...
    1:numel(h.recChNames),-Inf,Inf);
t = ndr.format.axon.read_abf(fname,[],'time', ...
    1,-Inf,Inf);

for i=1:size(D,2),
    D(:,i) = D(:,i)-mean(D(:,i));
    if strcmp(h.recChUnits{i},'mV'),
        D(:,i) = D(:,i) / 10;
    end;
end;

h.recChNames,
figure;
vlt.plot.plot_multichan(D(1:numel(t),:),t,spacing);

title([fname],'interp','none');

out.h=h;
out.D=D;
out.t=t;
