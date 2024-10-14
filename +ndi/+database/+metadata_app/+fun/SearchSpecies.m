function [species, uuid] = SearchSpecies(term)
base_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils";

database = "taxonomy";
search_url = sprintf("esearch.fcgi?db=%s&term=%s", database, term);
search_result = webread(base_url+"/"+search_url);

temp_dir = ndi.common.PathConstants.TempFolder;
ido_ = ndi.ido;
rand_num = ido_.identifier;
temp_filename = sprintf("search_result_%s.xml", rand_num);
file_path = fullfile(temp_dir,temp_filename);

fid = fopen(file_path,'w');
fprintf(fid,'%s',search_result);
fclose(fid);

species = readstruct(file_path);
uuid = -1;
if (species.Count == 1)
    uuid = species.IdList.Id;
end

if exist(file_path, 'file')==2
  delete(file_path);
end
end

