function [data, t] = splitSeriesRead(session, bodyDoc, owner, t0, t1)
%SPLITSERIESREAD Read a second-pass split series body over [T0, T1].
%
%   [DATA, T] = ndi.vintage.splitSeriesRead(SESSION, BODYDOC, OWNER, T0, T1)
%   reads the gzip'd raw array of BODYDOC (a sampled_body written by
%   ndi.migrate.internal.epochSeriesBodies: column-major, little-endian, its
%   owner's value.data_type, shaped by its dimensions) and returns the rows
%   whose time lies in [T0, T1]: DATA is [frames x (the other dimensions,
%   flattened)], T the frame times from the owner's `time` covariate
%   (origin + k * spacing). OWNER is the statement (ndi.document or props).
%
%   See also ndi.migrate.internal.epochSeriesBodies,
%            ndi.element.timeseries/readtimeseries.

if isa(owner, 'ndi.document') || isa(owner, 'did.document')
    op = owner.document_properties;
else
    op = owner;
end
bp = bodyDoc.document_properties;
dims = bp.data.dimensions;
sz = arrayfun(@(d) double(d.n), dims(:)');
dt = char(op.value.data_type);
prec = dt;
if strcmp(dt, 'float64'); prec = 'double'; elseif strcmp(dt, 'float32'); prec = 'single'; end
f = session.database_openbinarydoc(bodyDoc, 'body_data_0');
raw = fread(f, Inf, 'uint8');
session.database_closebinarydoc(f);
tmp = [tempname '.gz'];
fid = fopen(tmp, 'w'); fwrite(fid, raw, 'uint8'); fclose(fid);
g = gunzip(tmp, tempname());
delete(tmp);
fid = fopen(g{1}, 'r', 'ieee-le'); a = fread(fid, Inf, ['*' prec]); fclose(fid);
delete(g{1});
a = reshape(double(a), [sz 1]);
data = reshape(a, sz(1), []);
t = (0:sz(1)-1)';
covs = op.data.covariates;
for i = 1:numel(covs)
    c = covs(i);
    if isfield(c, 'variable') && strcmp(char(c.variable.node), 'om:Time') ...
            && isfield(c, 'origin') && ~isempty(c.origin)
        t = c.origin.value + (0:sz(1)-1)' * c.spacing.value;
    end
end
keep = t >= t0 & t <= t1;
data = data(keep, :);
t = t(keep);
end
