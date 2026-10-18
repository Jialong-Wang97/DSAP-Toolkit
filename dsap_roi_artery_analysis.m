function r=dsap_roi_artery_analysis(r)
% Downstream descriptors of existing CAVE arteries inside frozen ROI geometry.
% Never use vessel-excluded tissue masks or infer arterial labels from geometry.
if isfield(r,'roi_artery'),r=rmfield(r,'roi_artery');end
if ~isfield(r,'roi_snapshot')||~isfield(r,'vessel_roi_results'),return;end
s=r.roi_snapshot;dsap_validate_roi_snapshot(s);v=r.vessel_roi_results;
required={'Types','GeometryMasks','Masks','ParameterMasks','ParameterMaps'};
if ~all(isfield(v,required)),return;end
a=find(strcmp(v.Types,'CAVEArtery'));if numel(a)~=1,return;end
parameters={'CBF','CBV','MTT','Tmax'};
if ~all(isfield(v.ParameterMaps,parameters)),return;end
[found,ix]=ismember(s.StatisticsPlan.ROIIds,{s.ROIs.ID});
assert(all(found),'DSAP:ArteryROI','Missing frozen ROI identities.');
rois=s.ROIs(ix);n=numel(rois);names=reshape({rois.Name},[],1);
assert(n<=height(r.summary_table)&&isequal(string(names),string(r.summary_table.ROI(1:n))), ...
 'DSAP:ResultTableAlignment','Artery ROI order differs from result table.');
o=struct();if isfield(r,'DistributionAnalysisOptions'),o=r.DistributionAnalysisOptions;end
o=dsap_distribution_options(o);
geometry=cell(n,1);masks=cell(n,1);validMasks=cell(n,1);metrics=cell(n,4);
t=table(names,'VariableNames',{'ROI'});t.Status=repmat({'available'},n,1);
counts={'GeometryPixels','ArteryPixels','TICPixels','ValidPixels','ArteryAreaPercent','AIFOverlapPixels','AVOverlapPixels'};
for j=1:numel(counts),t.(counts{j})=zeros(n,1);end
for k=1:n
 roi=logical(rois(k).Mask);
 assert(isequal(size(roi),size(v.GeometryMasks{a})),'DSAP:ArterySpace','Artery/ROI native image size mismatch.');
 geometry{k}=roi&v.GeometryMasks{a};masks{k}=geometry{k}&v.Masks{a};
 validMasks{k}=masks{k}&v.ParameterMasks{a};
 for j=1:4
  map=v.ParameterMaps.(parameters{j});
  assert(isequal(size(map),size(roi)),'DSAP:ArterySpace','Parameter map size mismatch.');
  validMasks{k}=validMasks{k}&isfinite(map);
 end
 t.GeometryPixels(k)=nnz(roi);t.ArteryPixels(k)=nnz(geometry{k});
 t.TICPixels(k)=nnz(masks{k});t.ValidPixels(k)=nnz(validMasks{k});
 t.ArteryAreaPercent(k)=100*nnz(geometry{k})/max(nnz(roi),1);
 if ~any(roi,'all'),t.ArteryAreaPercent(k)=NaN;end
 t.AIFOverlapPixels(k)=nnz(geometry{k}&r.aif_mask);
 if isfield(v,'OverlapMask'),t.AVOverlapPixels(k)=nnz(geometry{k}&v.OverlapMask);end
 if t.ArteryPixels(k)==0,t.Status{k}='no_artery_in_roi';
 elseif t.ValidPixels(k)==0,t.Status{k}='no_valid_parameters';end
 for j=1:4
  p=parameters{j};m=computeRoiDistributionMetrics(v.ParameterMaps.(p),validMasks{k},o);metrics{k,j}=m;
  fields=fieldnames(m);
  for b=1:numel(fields)
   value=m.(fields{b});field=[p '_' fields{b}];
   if (isnumeric(value)||islogical(value))&&isscalar(value)
    if ~ismember(field,t.Properties.VariableNames),t.(field)=nan(n,1);end
    t.(field)(k)=double(value);
   end
  end
  flags=fieldnames(m.QCFlags);
  for b=1:numel(flags)
   field=[p '_QC_' flags{b}];
   if ~ismember(field,t.Properties.VariableNames),t.(field)=false(n,1);end
   t.(field)(k)=m.QCFlags.(flags{b});
  end
 end
 % Existing signal descriptors use finite-input artery pixels, as global vessels do.
 for field={'volume_map','peak_map','ttp_map','intensity_map'}
  f=field{1};if ~ismember(f,t.Properties.VariableNames),t.(f)=nan(n,1);end
  if isfield(r,f),map=r.(f);t.(f)(k)=mean(map(masks{k}),'omitnan');end
 end
end
r.roi_artery=struct('Version',1,'Summary',t,'GeometryMasks',{geometry},'Masks',{masks}, ...
 'ParameterMasks',{validMasks},'Distribution',{metrics},'Parameters',{parameters},'Options',o, ...
 'ROIIds',{s.StatisticsPlan.ROIIds},'SnapshotSignature',s.FullSignature, ...
 'Definition','Frozen ROI geometry intersect existing reviewed CAVE artery mask; original artery parameter validity retained.', ...
 'OverlapPolicy','AIF and artery/vein projection overlap retained and counted, matching global CAVE artery descriptors.', ...
 'Interpretation','Relative vascular projection descriptors, not parenchymal perfusion; no new segmentation or deconvolution.');
end
