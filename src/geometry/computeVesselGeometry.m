function geometry=computeVesselGeometry(centerline,pixelSpacing,opts)
% Independent 2D projected vessel geometry. Does not read/write DSAP state.
if nargin<2,pixelSpacing=[];end
if nargin<3,opts=struct();end
geometry=empty_geometry();
try
 prepared=prepareCenterlineForGeometry(centerline,pixelSpacing,opts);opts=prepared.Options;
 px=prepared.centerlineSmoothed;active=prepared.ActiveCenterline;
 geometry.Length_px=sum(vecnorm(diff(px),2,2));geometry.ChordLength_px=norm(px(end,:)-px(1,:));
 if strcmp(prepared.Units,'mm')
  geometry.Length_mm=sum(vecnorm(diff(active),2,2));geometry.ChordLength_mm=norm(active(end,:)-active(1,:));
 end
 lengthValue=sum(vecnorm(diff(active),2,2));chord=norm(active(end,:)-active(1,:));
 geometry.DistanceMetric=lengthValue/chord;geometry.ESCAPE_Tortuosity=1-chord/lengthValue;
 geometry.DistanceMetric_px=geometry.Length_px/geometry.ChordLength_px;
 geometry.ESCAPE_Tortuosity_px=1-geometry.ChordLength_px/geometry.Length_px;
 geometry.Units=prepared.Units;geometry.CurvatureUnits=['1/' prepared.Units];geometry.SegmentName=opts.SegmentName;
 geometry.centerlineRaw=prepared.centerlineRaw;geometry.centerlineResampled=prepared.centerlineResampled;
 geometry.centerlineSmoothed=px;geometry.Preparation=rmfield(prepared,{'centerlineRaw','centerlineResampled','centerlineSmoothed','ActiveCenterline'});
 geometry.Options=rmfield(opts,'ReferenceImage');
 if opts.ComputeCurvature
  curvature=computeCurvatureMetrics(active,opts);fields=fieldnames(curvature);
  for k=1:numel(fields),geometry.(fields{k})=curvature.(fields{k});end
  geometry.MaxCurvaturePoint=px(geometry.MaxCurvatureIndex,:);geometry.InflectionPoints=px(geometry.InflectionIndices,:);
 end
 if opts.UseVTI
  vti=callOriginalVTI(active,opts.VTIDirectory);geometry.VTI=vti.Value;
  geometry.VTI_SDTheta=vti.SDTheta;geometry.VTI_MeanDM=vti.MeanDM;geometry.VTI_NumCriticalPoints=vti.NumCriticalPoints;
  geometry.VTI_NumInflectionPoints=vti.NumInflectionPoints;geometry.VTI_ArcLength=vti.ArcLength;geometry.VTI_ChordLength=vti.ChordLength;
  geometry.VTIValid=vti.Valid;geometry.VTIProvenance=vti;
  geometry.Warning=vti.Warning;
 end
 geometry.Valid=true;geometry.Definition='Metrics on equally resampled, smoothed 2D projected centerline; proximal -> distal input order; DICOM row/column spacing.';
 geometry.VTICoordinatePolicy='Original axes preserved; original VTI is axis dependent and has vertical-step singularities.';
catch e
 geometry.Valid=false;geometry.Warning=e.message;geometry.ErrorIdentifier=e.identifier;geometry.Exception=getReport(e,'extended','hyperlinks','off');
 return;
end
if opts.ShowQC,vesselGeometryQC(geometry,opts.ReferenceImage,opts);end
end
function g=empty_geometry
fields={'Length_px','Length_mm','ChordLength_px','ChordLength_mm','DistanceMetric','ESCAPE_Tortuosity', ...
 'MeanCurvature','MedianCurvature','MaxCurvature','RMSCurvature','P90Curvature','P95Curvature','TotalAbsoluteCurvature', ...
 'InflectionCount','VTI','VTI_SDTheta','VTI_MeanDM','VTI_NumCriticalPoints','VTI_NumInflectionPoints','VTI_ArcLength','VTI_ChordLength'};
g=struct();for k=1:numel(fields),g.(fields{k})=NaN;end
g.Valid=false;g.VTIValid=false;g.Warning='';g.CurvatureProfile=[];g.SignedCurvatureProfile=[];g.ArcLengthPosition=[];
g.InflectionPoints=zeros(0,2);g.InflectionIndices=[];g.MaxCurvaturePoint=[];g.centerlineRaw=[];g.centerlineResampled=[];g.centerlineSmoothed=[];
end
