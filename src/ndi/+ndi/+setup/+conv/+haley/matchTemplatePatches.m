function [slot, why] = matchTemplatePatches(c, centerYX, angleDeg, scale, layout)
%MATCHTEMPLATEPATCHES Place detected E. coli patches by the acetate template's frame.
%
%   [SLOT, WHY] = ndi.setup.conv.haley.matchTemplatePatches(C, CENTERYX,
%   ANGLEDEG, SCALE, LAYOUT) takes the centroids C (N x 2, [x y] pixels) of
%   the patches detected in one image and the acetate template registered on
%   that image's brightfield image (analyzeGFP's `template`: CENTERYX the
%   centre as stored, [y x] pixels; ANGLEDEG; SCALE pixels per mm), puts each
%   centroid in the acetate's frame (mm) and gives it the nearest of the 12
%   patch positions in LAYOUT. SLOT(j) is that patch's number (decision #62's
%   numbering). SLOT is [] and WHY says why when a patch is farther than
%   LAYOUT.max_distance_mm from every position, or two patches claim one.
%   Decision #80.
%
%   LAYOUT (the spec's `ecoli_patch_layout`): positions_mm (12 x 2),
%   angle_sign (+1/-1: how the template angle turns the frame),
%   max_distance_mm.

slot = [];
why = '';
pos = reshape(double(layout.positions_mm), [], 2);
n = size(c, 1);
if n == 0
    why = 'no patch detected';
    return;
end
if any(~isfinite([centerYX(:); angleDeg; scale])) || scale <= 0
    why = 'the template registration is incomplete';
    return;
end
th = double(layout.angle_sign) * angleDeg * pi / 180;
dx = c(:, 1) - centerYX(2);
dy = c(:, 2) - centerYX(1);
u = ( cos(th) * dx + sin(th) * dy) / scale;
v = (-sin(th) * dx + cos(th) * dy) / scale;
slot = zeros(n, 1);
far = 0;
for j = 1:n
    [d, k] = min(vecnorm(pos - [u(j) v(j)], 2, 2));
    slot(j) = k;
    far = max(far, d);
end
if far > layout.max_distance_mm
    why = sprintf('a patch is %.2f mm from the nearest template position (limit %.2f mm)', ...
        far, layout.max_distance_mm);
    slot = [];
elseif numel(unique(slot)) ~= n
    why = 'two detected patches are nearest the same template position';
    slot = [];
end
end
