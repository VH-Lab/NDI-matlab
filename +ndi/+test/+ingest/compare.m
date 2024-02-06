function b = compare(dirname1, dirname2)
% COMPARE - compare sessions that are obtaining data from ingested or non-ingested sources
%
% B = COMPARE(DIRNAME1, DIRNAME2)
%  
% Compare data from ndi sessions (from VH Lab) where one dataset
%  (DIRNAME1) is ingested and the other (DIRNAME2) is not.
%
% If DIRNAME1 and DIRNAME2 are not provided, then
%   DIRNAME1 = '/Users/vanhoosr/test/2019-11-19' and
%   DIRNAME2 = '/Users/vanhoosr/test/3019-11-19'
%  
%

if nargin<1,
	dirname1 = '/Users/vanhoosr/test/3019-11-19';
end;

if nargin<2,
	dirname2 = '/Users/vanhoosr/test/2019-11-19';
end;


dirname = {dirname1 dirname2};

ts = vlt.data.emptystruct('S','ds_list');

for i=1:numel(dirname),
	ts_here = [];
	ts_here.S = ndi.session.dir(dirname{i});
	ts_here.ds_list = ts_here.S.daqsystem_load('name','(.*)');
	ts(i) = ts_here;
end;

 % assume same daq systems

for i=1:numel(ts(1).ds_list),
	daq1 = ts(1).ds_list{i};
	daq2 = ts(2).ds_list{i};
	[b,errmsg] = ndi.test.ingest.mfdaq_compare(daq1,daq2);
	if any(~b),
		errmsg(:),
		error(['Daqs ' daq1.name ' and ' daq2.name ' do not match.']);
	end;
end;

