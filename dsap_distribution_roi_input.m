function [map,mask,source]=dsap_distribution_roi_input(r,k,parameter)
% Reuse existing postprocessed maps and existing ParameterMasks. No new cutoff.
map=r.(parameter);mask=logical(r.roi_masks{k});source='tissue final map / finite ROI pixels';
if isfield(r,'vessel_roi_results')
 v=r.vessel_roi_results;idx=find(strcmp(v.Names,r.roi_names{k}));
 if numel(idx)==1&&isequal(v.Masks{idx},r.roi_masks{k})
  source='vessel_roi_results.ParameterMaps / ParameterMasks';
  if isfield(v,'ParameterMaps')&&isfield(v,'ParameterMasks')
   map=v.ParameterMaps.(parameter);mask=mask&v.ParameterMasks{idx};
  else
   map=nan(size(mask));mask(:)=false;source='Unavailable legacy vessel ParameterMaps';
  end
  return;
 end
end
if isfield(r,'partition_stats')&&isfield(r.partition_stats,'ParameterMasks')
 st=r.partition_stats;
 if k<=numel(st.ParameterMasks)&&strcmp(st.Names{k},r.roi_names{k})
  mask=mask&st.ParameterMasks{k};source='tissue final map / partition_stats.ParameterMasks';
 end
elseif isfield(r,'capillary_mask')
 mask=mask&r.capillary_mask;source='tissue final map / capillary_mask';
end
end
