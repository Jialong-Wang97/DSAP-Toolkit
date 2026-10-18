function report=select_lumen_AIF(sequence,mask,network,time)
% Pixel-space lumen selection on EXISTING vascular output; no segmentation.
% network may contain Graph/XY and optionally an ordered ICA centerline in
% ICACenterline. Without a labelled path, the thick main trunk is a heuristic
% ICA candidate, NOT an anatomical C4/C5 classification.
report=struct('Version',2,'Available',false,'Reason','','Units','px', ...
 'SelectedIndex',[],'Candidates',[],'Ranking',table(),'Time',time(:));
try
 assert(islogical(mask)&&ismatrix(mask)&&any(mask,'all'),'AutoAIF:Mask','需要已有血管 mask。');
 assert(isequal(size(mask),[size(sequence,2) size(sequence,3)]),'AutoAIF:Shape','血管与当前序列尺寸不一致。');
 if isempty(network)||~isfield(network,'PreparedGeometry')
  network=prepare_lumen_geometry(mask,network);
 end
 prepared=network.PreparedGeometry;
 assert(isequal(prepared.Mask,mask),'AutoAIF:GeometrySource','中心线缓存与血管 mask 不一致。');
 path=prepared.Centerline;p=round(path);arc=prepared.Arc;g=prepared.Geometry;
 radius=g.Radius_px;curvature=g.Curvature_per_px;clearance=g.BranchDistance_px;eligible=g.Eligible;
 report.Anatomy=prepared.Anatomy;report.ICA_candidate_centerline=path;report.Geometry=g;
 candidates=struct([]);last=-inf;
 for k=reshape(find(eligible),1,[])
  if arc(k)-last<max(1,.5*radius(k)),continue;end
  r=.95*radius(k);x=max(1,floor(p(k,1)-r)):min(size(mask,2),ceil(p(k,1)+r));
  y=max(1,floor(p(k,2)-r)):min(size(mask,1),ceil(p(k,2)+r));[xx,yy]=meshgrid(x,y);
  roi=false(size(mask));roi(y,x)=(xx-p(k,1)).^2+(yy-p(k,2)).^2<=r^2;
  % Reject instead of clipping: the accepted footprint stays circular.
  if nnz(roi)<3||any(roi&~mask,'all'),continue;end
  [tdc,metrics]=extract_TDC(sequence,roi,time);
  quality=metrics.Valid&&isfinite(metrics.FWHM)&&metrics.FWHM>0&&metrics.AUC>0;
  metrics.Valid=quality;reason='';if ~quality,reason='No complete positive first-pass peak / half-maximum crossings';end
  c=struct('ID',numel(candidates)+1,'Mask',roi,'CenterlineXY',p(k,:),'Vessel','ICA candidate', ...
   'VesselRadius_px',radius(k),'Radius_px',r,'Curvature_per_px',curvature(k), ...
   'BranchDistance_px',clearance(k),'TDC',tdc,'Metrics',metrics,'QCReason',reason,'Score',-inf);
  candidates=[candidates;c];last=arc(k); %#ok<AGROW>
 end
 assert(~isempty(candidates),'AutoAIF:Candidates','没有远离分叉且管径足够的腔内圆形 ROI。');
 [tdcScore,detail]=calculate_AIF_score([candidates.Metrics]);valid=isfinite(tdcScore);
 % Geometry contributes explicitly, including when all TDCs are identical.
 geometryScore=.6*standardize([candidates.VesselRadius_px]',valid)+.4*standardize([candidates.Curvature_per_px]',valid);
 scores=.5*tdcScore+.5*geometryScore;
 for k=1:numel(candidates),candidates(k).Score=scores(k);end
 [~,order]=sort(scores,'descend');report.Candidates=candidates;report.ScoreDetail=detail;
 report.Scoring='0.5*TDC z-score + 0.5*(0.6*radius z-score + 0.4*curvature z-score); QC failures excluded';
 centers=vertcat(candidates.CenterlineXY);
 report.Ranking=table((1:numel(order))',order,scores(order),centers(order,1),centers(order,2), ...
  [candidates(order).Radius_px]',[candidates(order).VesselRadius_px]',[candidates(order).Curvature_per_px]', ...
  [candidates(order).BranchDistance_px]',valid(order),string({candidates(order).QCReason})', ...
  'VariableNames',{'Rank','CandidateIndex','Score','X_px','Y_px','ROIRadius_px','VesselRadius_px','Curvature_per_px','BranchDistance_px','QCPassed','QCReason'});
 assert(any(valid),'AutoAIF:QC','候选 AIF 曲线未通过峰值完整性检查。');
 report.SelectedIndex=order(1);report.Selected=candidates(order(1));report.Selection='Automatic';report.Available=true;
catch e
 report.Reason=e.message;report.ErrorIdentifier=e.identifier;report.Exception=getReport(e,'extended','hyperlinks','off');
end
end
function z=standardize(values,valid)
% Invalid candidates never affect the relative geometry scale.
z=zeros(size(values));v=values(valid);if numel(v)>1&&std(v)>eps,z(valid)=(v-mean(v))/std(v);end
end
