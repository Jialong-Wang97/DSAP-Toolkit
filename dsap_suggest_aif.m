function suggestion=dsap_suggest_aif(prepared,calibration,sequence)
% Explainable early, strong, steep, supported enhancement; no CAVE or onset call.
data=dsap_roi_suggestion_data(prepared);
if nargin<2||isempty(calibration),calibration=area_calibration(data.Shape);end
if nargin<3,sequence=[];if isnumeric(prepared),sequence=prepared;end,end
suggestion=dsap_roi_suggestion(false(data.Shape),'early-peak-rise-snr-connected-region-v1');
if max(data.Peak,[],'all')<=eps||data.FiniteFraction<.95
 suggestion.Reason='AIF 自动建议质量较低，建议手工绘制。';return;
end
[~,globalPeak]=max(data.Curve);p=data.Peak;positive=p(p>0);strong=prctile(positive,80);
strongTTP=data.TTP(p>=strong&data.SNR>=3);earlyCutoff=globalPeak;
if ~isempty(strongTTP),earlyCutoff=min(globalPeak,prctile(strongTTP,50));end
early=data.TTP<=earlyCutoff&data.TTP>1;candidate=p>=strong&early&data.SNR>=3&data.Arrival>1;
edge=max(1,ceil(.03*min(size(p))));candidate([1:edge end-edge+1:end],:)=false;candidate(:,[1:edge end-edge+1:end])=false;
support=conv2(double(candidate),ones(3),'same');candidate=candidate&support>=3;
score=p/max(p,[],'all').*data.Rise/max(max(data.Rise,[],'all'),eps).*min(data.SNR/10,1) ...
 .*(data.FrameCount-data.TTP+1)/data.FrameCount.*min(support/9,1) ...
 .*(data.FrameCount-data.Arrival+1)/data.FrameCount;
components=bwconncomp(candidate,8);
if components.NumObjects==0,suggestion.Reason='未找到有空间支持的早期血管信号，建议手工绘制 AIF。';return;end
componentScore=cellfun(@(v) max(score(v))*min(1,numel(v)/3),components.PixelIdxList);
[~,order]=sort(componentScore,'descend');bestRank=-1;
% Evaluate the actual small ROI's mean curve, not just its highest-scoring pixel.
% Bound the search to 20 components so recommendation latency stays small.
for component=order(1:min(20,numel(order)))
 pixels=components.PixelIdxList{component};[~,seed]=max(score(pixels));
 [r,c]=ind2sub(size(p),pixels(seed));y=data.Rows(r);x=data.Columns(c);
 radius=max(1,round(sqrt(calibration.TargetPixels/pi)));
 yr=max(1,y-radius):min(data.Shape(1),y+radius);xr=max(1,x-radius):min(data.Shape(2),x+radius);
 [xx,yy]=meshgrid(xr,yr);disk=(xx-x).^2+(yy-y).^2<=radius^2;
 mask=false(data.Shape);mask(yr,xr)=disk;area=nnz(mask);
 if isempty(sequence),trace=data.Traces(:,sub2ind(size(p),r,c));
 else,trace=double(mean(sequence(:,mask),2));end
 [peak,ttp]=max(trace);noise=std(trace(1:min(3,numel(trace))));snr=peak/max(noise,max(eps,.01*peak));
 qualityTrace=movmean(trace,3);dominant=qualityTrace>=.5*max(qualityTrace);
 peaks=bwconncomp(dominant');singlePeak=peaks.NumObjects==1;
 quality='Acceptable';rank=1;
 if snr>=8&&ttp<=earlyCutoff&&singlePeak&&area>=calibration.MinPixels&&area<=calibration.MaxPixels,quality='Good';rank=2;end
 if snr<4||ttp>earlyCutoff||area<3||peaks.NumObjects>2||peak<=eps,quality='Poor';rank=0;end
 if rank>bestRank
  bestRank=rank;suggestion.Value=mask;suggestion.Score=score(r,c);suggestion.Quality=quality;suggestion.Available=area>=3;
  suggestion.Reason=sprintf('早期增强连通区域：ROI 平均曲线 TTP 帧 %d，峰值 %.3g，SNR %.1f，候选 %d 像素。',ttp,peak,snr,area);
  if strcmp(quality,'Poor'),suggestion.Reason=['AIF 自动建议质量较低，建议手工绘制。' suggestion.Reason];end
  suggestion.Metrics=struct('TTPFrame',ttp,'Peak',peak,'SNR',snr,'SinglePeak',singlePeak, ...
   'SeedXY',[x y],'Area',area,'AreaCalibration',calibration,'GlobalPeakFrame',globalPeak, ...
   'ArrivalFrame',data.Arrival(r,c),'QualityCurveSmoothingFrames',3,'EarlyTTPMaximum',earlyCutoff,'QualityUsesROIMean',~isempty(sequence));
 end
 if rank==2,break;end
end
end
function area=area_calibration(shape)
path=fullfile(fileparts(mfilename('fullpath')),'templates','roi_aif_area_calibration.json');
if isfile(path)
 q=jsondecode(fileread(path));area=struct('MinPixels',max(3,round(q.MinFraction*prod(shape))), ...
 'MaxPixels',max(3,round(q.MaxFraction*prod(shape))),'TargetPixels',max(3,round(q.TargetFraction*prod(shape))), ...
 'HistoricalN',q.HistoricalN,'Method',q.Method);
else
 % Conservative 3x3 seed only when no historical evidence is installed.
 area=struct('MinPixels',3,'MaxPixels',9,'TargetPixels',9,'HistoricalN',0,'Method','uncalibrated-small-seed');
end
end
