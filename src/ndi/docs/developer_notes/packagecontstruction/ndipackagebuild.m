function ndipackagebuild

    % developers: follow this pipeline manually to edit directories en mass

    dirname = ['/Users/vanhoosr/Documents/matlab/tools/NDI-matlab'];

    m=vlt.matlab.mfiledirinfo(dirname);

    rt_data = text2cellstr('ndireplacement.txt');

    rt = vlt.data.emptystruct('original','replacement');

    for i=2:numel(rt_data),
        tab = find( rt_data{i}==sprintf('\t') );
        rt_here.original = rt_data{i}(1:tab-1);
        rt_here.replacement = rt_data{i}(tab+1:end);
        rt(end+1) = rt_here;
    end;

    fuse = vlt.matlab.findfunctionusedir('/Users/vanhoosr/Documents/MATLAB/tools/NDI-matlab/demo',m);

    status = vlt.matlab.replacefunction(fuse,rt,'Disable',0)
