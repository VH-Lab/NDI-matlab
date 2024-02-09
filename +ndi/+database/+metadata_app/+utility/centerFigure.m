function centerFigure(figureHandle, referencePosition, offset)
% centerFigure - Center figure window on a reference position
%
%   Syntax:
%       centerFigure(figureHandle, referencePosition)
%
%   Input arguments:
%       figureHandle - Handle object for a figure
%       referencePosition - a reference position. If reference position is
%       not give, the current screen size is used. If reference position
%       can also be anotehr figure handle, in which case the Position
%       property of that figure is used.

    if nargin < 2 || isempty(referencePosition)
        referencePosition = get(0, "ScreenSize");
    else
        if isa(referencePosition, 'matlab.ui.Figure')
            referencePosition = getpixelposition(referencePosition);
        end
    end
    if nargin < 3; offset = [0,0]; end
    
    figurePosition = getpixelposition(figureHandle);
    figureSize = figurePosition(3:4);
    
    % Update figure position
    margins = (referencePosition(3:4) - figureSize) ./ 2;
    figurePosition(1:2) = margins + referencePosition(1:2) + offset;
            
    % Update the figure window position
    setpixelposition(figureHandle, figurePosition)
end