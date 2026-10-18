function suggestion=dsap_suggest_cranial_limits(prepared)
% Row support of enhancement above background, longest continuous run; no margin.
data=dsap_roi_suggestion_data(prepared);
suggestion=dsap_roi_suggestion([], 'row-enhancement-support-longest-run-no-margin-v1');
p=data.Peak;positive=p(p>0);
if isempty(positive)||data.FiniteFraction<.95,suggestion.Reason='无法可靠自动确定颅内上下界，请手动点击设置。';return;end
threshold=prctile(positive,60);support=mean(p>=threshold,2);
profile=movmean(support,max(1,round(.025*numel(support))));
active=profile>=max(.08,.5*max(profile))&support>=.08;runs=bwconncomp(active');
if runs.NumObjects==0,suggestion.Reason='无法可靠自动确定颅内上下界，请手动点击设置。';return;end
lengths=cellfun(@numel,runs.PixelIdxList);[span,index]=max(lengths);region=runs.PixelIdxList{index};
first=data.Rows(min(region));last=min(data.Shape(1),data.Rows(max(region))+data.Stride-1);
upper=dsap_roi_image_row(first,data.Shape(1));lower=dsap_roi_image_row(last,data.Shape(1));
coverage=span/numel(profile);competing=sum(lengths>=.35*span)>1;
if lower-upper+1<max(5,round(.05*data.Shape(1)))||coverage<.3||competing
 suggestion.Reason='无法可靠自动确定颅内上下界，请手动点击设置。有效范围较小或存在多个分离高分区。';
 suggestion.Metrics=struct('RowProfile',profile,'Coverage',coverage,'CompetingRuns',competing);return;
end
suggestion.Value=struct('UpperRow',upper,'LowerRow',lower);suggestion.Available=true;suggestion.Score=coverage;
suggestion.Quality='Acceptable';if coverage>=.4&&coverage<.95&&~competing,suggestion.Quality='Good';end
if coverage>=.95
 suggestion.Quality='Poor';suggestion.Available=false;suggestion.Value=[];
 suggestion.Reason='无法可靠自动确定颅内上下界，请手动点击设置。增强覆盖几乎全图，缺少可靠边缘。';
else
 suggestion.Reason=sprintf('按行增强覆盖的连续高分区为 %d–%d 行；未添加范围 margin。',upper,lower);
end
suggestion.Metrics=struct('RowProfile',profile,'Coverage',coverage,'Threshold',threshold, ...
 'CompetingRuns',competing,'SamplingStride',data.Stride,'MarginRows',0,'RelativeSupportThreshold',.5);
end
