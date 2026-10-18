function o=dsap_distribution_options(o)
% Single reproducible settings contract; no physiological pixel thresholds.
if nargin==0,o=struct();end
d=struct('TrimLowerPercentile',5,'TrimUpperPercentile',95, ...
 'RobustScaleLowerPercentile',1,'RobustScaleUpperPercentile',99, ...
 'HistogramBins',32,'GLCMGrayLevels',32,'GLCMDistancePixels',1, ...
 'GLCMDirections',[0 45 90 135],'GLCMOffsets',[0 1;-1 1;-1 0;-1 -1], ...
 'LocalEntropyWindow',[3 3],'MinLocalNeighbors',5,'MinGLCMPairs',1, ...
 'LowValidPixelCount',50,'LowPerfusionThreshold',.70, ...
 'ContralateralPairs',zeros(0,2));
assert(isstruct(o)&&isscalar(o),'DSAP:DistributionOptions','Options must be a scalar struct.');
f=fieldnames(o);assert(all(ismember(f,fieldnames(d))),'DSAP:DistributionOptions','Unknown option.');
for k=1:numel(f),d.(f{k})=o.(f{k});end;o=d;
for pair={'Trim','RobustScale'}
 lo=o.([pair{1} 'LowerPercentile']);hi=o.([pair{1} 'UpperPercentile']);
 assert(isscalar(lo)&&isscalar(hi)&&isfinite(lo)&&isfinite(hi)&&0<=lo&&lo<hi&&hi<=100,'DSAP:DistributionOptions','Invalid percentile range.');
end
for key={'HistogramBins','GLCMGrayLevels','GLCMDistancePixels','MinLocalNeighbors','MinGLCMPairs','LowValidPixelCount'}
 v=o.(key{1});assert(isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>=1&&v==fix(v),'DSAP:DistributionOptions','Counts must be positive integers.');
end
assert(o.HistogramBins>=2&&o.GLCMGrayLevels>=2&&o.HistogramBins<=256&&o.GLCMGrayLevels<=256,'DSAP:DistributionOptions','Gray levels must be 2..256.');
assert(isequal(o.GLCMDirections,[0 45 90 135])&&isequal(o.GLCMOffsets,[0 1;-1 1;-1 0;-1 -1]),'DSAP:DistributionOptions','This version uses four documented directions; configure distance instead.');
w=o.LocalEntropyWindow;assert(isnumeric(w)&&numel(w)==2&&all(isfinite(w))&&all(w>=1)&all(mod(w,2)==1)&&o.MinLocalNeighbors<=prod(w),'DSAP:DistributionOptions','Use an odd window and feasible minimum count.');
assert(isscalar(o.LowPerfusionThreshold)&&isfinite(o.LowPerfusionThreshold)&&o.LowPerfusionThreshold>0,'DSAP:DistributionOptions','Invalid low-perfusion ratio.');
p=o.ContralateralPairs;assert(isnumeric(p)&&size(p,2)==2&&all(isfinite(p),'all')&&all(p>=1&p==fix(p),'all'),'DSAP:DistributionOptions','Pairs are explicit [affected ROI row, contralateral ROI row].');
end
