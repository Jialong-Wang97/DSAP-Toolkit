function [x,valid,q,z,range]=dsap_distribution_pixels(map,mask,o)
% Background has a sentinel zero label and is NEVER counted as a gray level.
assert(isnumeric(map)&&isreal(map)&&ismatrix(map)&&islogical(mask)&&isequal(size(map),size(mask)), ...
 'DSAP:DistributionInput','Map and logical valid ROI mask must have equal 2D size.');
valid=mask&isfinite(map);x=double(map(valid));range=dsap_distribution_percentile(x,[o.RobustScaleLowerPercentile o.RobustScaleUpperPercentile]);
z=zeros(size(x));if ~isempty(x)&&range(2)>range(1),z=min(1,max(0,(x-range(1))/(range(2)-range(1))));end
q=zeros(size(map),'uint16');q(valid)=uint16(min(o.GLCMGrayLevels-1,floor(z*o.GLCMGrayLevels))+1);
end
