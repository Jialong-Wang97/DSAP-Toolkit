function [curve,metrics]=extract_TDC(sequence,mask,time,fitFunction)
% Input is existing baseline-subtracted positive enhancement, [time row col].
% Threshold crossings are interpolated in seconds; censored widths remain NaN.
if nargin<4,fitFunction=[];end
time=double(time(:));assert(numel(time)==size(sequence,1)&&all(isfinite(time))&&all(diff(time)>0),'AutoAIF:Time','Strictly increasing acquisition times required.');
assert(isequal(size(mask),[size(sequence,2) size(sequence,3)])&&nnz(mask)>=3,'AutoAIF:ROI','Invalid ROI.');
curve=double(mean(sequence(:,mask),2));
metrics=struct('ArrivalTime',NaN,'PeakIntensity',NaN,'MaxSlope',NaN,'TimeToPeak',NaN,'FWHM',NaN,'AUC',NaN,'R2',NaN,'Valid',false);
if any(~isfinite(curve))||max(curve)<=eps||numel(curve)<3,return;end
[peak,k]=max(curve);metrics.PeakIntensity=peak;metrics.TimeToPeak=time(k);
metrics.MaxSlope=max(diff(curve)./diff(time));metrics.AUC=trapz(time,curve);
arrival=find(curve>=.2*peak,1);metrics.ArrivalTime=crossing(arrival,.2*peak);
left=find(curve(1:k)>=.5*peak,1);right=k-1+find(curve(k:end)<.5*peak,1);
if left>1&&~isempty(right),metrics.FWHM=crossing(right,.5*peak)-crossing(left,.5*peak);end
metrics.Valid=arrival>1&&k>1&&k<numel(curve)&&metrics.MaxSlope>0;
if ~isempty(fitFunction)
 try,predicted=fitFunction(time,curve);if isequal(size(predicted),size(curve))&&all(isfinite(predicted)),metrics.R2=1-sum((curve-predicted).^2)/max(sum((curve-mean(curve)).^2),eps);end
 catch,metrics.R2=NaN;end
end
 function value=crossing(index,threshold)
  value=NaN;if isempty(index)||index<=1,return;end
  value=time(index-1)+(time(index)-time(index-1))*(threshold-curve(index-1))/(curve(index)-curve(index-1));
 end
end
