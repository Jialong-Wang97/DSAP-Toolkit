function opts=vesselGeometryOptions(opts,hasSpacing)
% Explicit engineering defaults; spans/spacing are in the active mm or px unit.
if nargin<1||isempty(opts),opts=struct();end
if nargin<2,hasSpacing=false;end
assert(isstruct(opts)&&isscalar(opts),'DSAP:GeometryOptions','Options must be a scalar struct.');
spacing=1;span=5;if hasSpacing,spacing=.3;span=1.5;end
defaults=struct('UseVTI',true,'ComputeCurvature',true,'ShowQC',false, ...
 'ResampleSpacing',spacing,'SmoothingMethod','sgolay','SmoothingStrength',span, ...
 'OrderConfirmed',true,'MaxStepRatio',10,'DuplicateTolerance',1e-9, ...
 'MaxResampledPoints',10000,'InflectionRelativeTolerance',.05, ...
 'InflectionAbsoluteTolerance',1e-8,'MinInflectionSpacing',2*spacing, ...
 'SegmentName','Vessel','ReferenceImage',[],'VTIDirectory','', ...
 'MaxSnapDistance',10,'FigureVisible','on','VesselMaskSource','auto', ...
 'PathMethod','center-weighted','PathCenterWeight',4,'MaxPathNodes',600000);
names=fieldnames(opts);assert(all(ismember(names,fieldnames(defaults))),'DSAP:GeometryOptions','Unknown geometry option.');
for k=1:numel(names),defaults.(names{k})=opts.(names{k});end
opts=defaults;
if ~ismember('MinInflectionSpacing',names),opts.MinInflectionSpacing=2*opts.ResampleSpacing;end
for key={'UseVTI','ComputeCurvature','ShowQC','OrderConfirmed'}
 value=opts.(key{1});assert(isscalar(value)&&(islogical(value)||(isnumeric(value)&&ismember(value,[0 1]))),'DSAP:GeometryOptions','Invalid logical option.');
end
for key={'ResampleSpacing','MaxStepRatio','MaxResampledPoints','MaxSnapDistance','MaxPathNodes'}
 value=opts.(key{1});assert(isnumeric(value)&&isscalar(value)&&isfinite(value)&&value>0,'DSAP:GeometryOptions','Spacing and bounds must be positive finite scalars.');
end
for key={'SmoothingStrength','DuplicateTolerance','InflectionRelativeTolerance','InflectionAbsoluteTolerance','MinInflectionSpacing','PathCenterWeight'}
 value=opts.(key{1});assert(isnumeric(value)&&isscalar(value)&&isfinite(value)&&value>=0,'DSAP:GeometryOptions','Invalid smoothing/tolerance option.');
end
opts.SmoothingMethod=validatestring(opts.SmoothingMethod,{'sgolay','movmean','none'});
opts.FigureVisible=validatestring(opts.FigureVisible,{'on','off'});
opts.PathMethod=validatestring(opts.PathMethod,{'center-weighted','skeleton'});
opts.VesselMaskSource=validatestring(opts.VesselMaskSource,{'auto','full_artery','full_vein','full_union','scoped_artery','scoped_vein','raw_union','reviewed_vessels'});
assert(opts.MaxResampledPoints>=5&&opts.InflectionRelativeTolerance<1,'DSAP:GeometryOptions','Invalid point cap or inflection tolerance.');
opts.SegmentName=char(string(opts.SegmentName));opts.VTIDirectory=char(string(opts.VTIDirectory));
end
