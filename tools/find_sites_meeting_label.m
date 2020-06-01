function sites_to_use = find_sites_meeting_label(ds, fieldLabelArray)
% function which specifics which sites to use based on raster label
% criteria. Meant to function as an additional tool in the Neural decoding
% toolbox.

% Inputs:
% ds: a datasource object.
% fields: a cell array of names of fields in the raster_label object.
% labels: a cell array of specific labels represented in the fields
% catagory. sites/units with this label will be kept, other excluded.

% Output:
% a 1 by site array of the index of sites to use in the original ds. can be
% assigned directly to ds.sites_to_use.

if ds.sites_to_use == -1
  possible_site_ind = 1:length(ds.the_data);
else
  possible_site_ind = ds.sites_to_use;
end

% retrieve the relevant labels for the fields currently in use.
for field_i = 1:size(fieldLabelArray,1)
  field_data = ds.binned_site_info.(fieldLabelArray{field_i,1});
  field_data = field_data(possible_site_ind);
  
  % See which labels match
  validLabels = fieldLabelArray{field_i,2};
  validInd = false(size(field_data));
  for label_i = 1:length(validLabels)
    vali = strcmp(field_data, fieldLabelArray{field_i,2}{label_i});
    validInd(vali) = true;
  end
end

sites_to_use = possible_site_ind(validInd);

end