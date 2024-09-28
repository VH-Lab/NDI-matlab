function preptemptable(S)
% PREPTEMPTABLE - write a prep temperature table to the session directory
%
% PREPTEMPTABLE(S)
%
% Write a temperature table to the session directory.
%


dirname = S.path();

standard_temps = [ 7:4:31] ;

cols = {'probe_id','epoch_id','type','temp','raw'};
datatypes = {'string','string','string','cell','cell'};

temptable = table('size',[0 numel(cols)],'VariableNames',cols,'VariableTypes',datatypes);

p = S.getprobes('type','thermometer');

for P = 1:numel(p),
	et = p{P}.epochtable();
	for j=1:numel(et),
		[D,t] = p{P}.readtimeseries(et(j).epoch_id,-Inf,Inf);
		out = ndi.setup.conv.marder.preptemp(t,D,standard_temps);
		newtable = cell2table({ p{P}.id() et(j).epoch_id out.type mat2cell(out.temp,1) mat2cell(out.raw,1)},...
			'VariableNames',cols);
		temptable = cat(1,temptable,newtable);
	end;
end;

save([dirname filsep 'temptable.mat'],'temptable','-mat');

