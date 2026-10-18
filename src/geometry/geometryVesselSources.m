function sources=geometryVesselSources(result,shape)
% Read existing vessel extraction outputs; never infer or change a DSAP mask.
if nargin<2,shape=[];end
sources=struct('ID',{},'Label',{},'Mask',{},'Field',{},'Reviewed',{});
if ~isstruct(result)||~isscalar(result),return;end
if isfield(result,'cave_full_field')&&isstruct(result.cave_full_field)
 add(result.cave_full_field,'ArteryMask','full_artery','全幅动脉 · CAVE 原始结果','cave_full_field.ArteryMask',false);
 add(result.cave_full_field,'VeinMask','full_vein','全幅静脉 · CAVE 原始结果','cave_full_field.VeinMask',false);
 add(result.cave_full_field,'UnionMask','full_union','全幅动静脉 · CAVE 原始结果','cave_full_field.UnionMask',false);
end
if isfield(result,'vessel_features')&&isstruct(result.vessel_features)
 add(result.vessel_features,'ArteryMask','scoped_artery','范围内动脉 · CAVE','vessel_features.ArteryMask',false);
 add(result.vessel_features,'VeinMask','scoped_vein','范围内静脉 · CAVE','vessel_features.VeinMask',false);
 add(result.vessel_features,'RawVesselMask','raw_union','全幅大血管 · 旧版原始结果','vessel_features.RawVesselMask',false);
end
add(result,'large_vessel_mask','reviewed_vessels','已确认大血管 · 灌注分析范围','large_vessel_mask',true);
 function add(container,key,id,label,field,reviewed)
  if ~isfield(container,key),return;end
  value=container.(key);
  if ~(islogical(value)||isnumeric(value))||~ismatrix(value)||isempty(value)||~all(isfinite(value),'all')||~any(value,'all'),return;end
  if ~isempty(shape)&&~isequal(size(value),shape),return;end
  sources(end+1)=struct('ID',id,'Label',label,'Mask',logical(value),'Field',field,'Reviewed',reviewed);
 end
end
