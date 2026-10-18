function suggestion=dsap_suggest_reference_frame(prepared)
% Mean enhancement of strong, early-peaking signal; avoids late washout/background drift.
data=dsap_roi_suggestion_data(prepared);
suggestion=dsap_roi_suggestion([], 'native-early-supported-enhancement-mean-v1');
curve=data.EffectiveCurve;[peak,index]=max(curve);
if peak<=eps||data.FiniteFraction<.95
 suggestion.Reason='增强信号不足或图像异常，请手动选择参考帧。';return;
end
baseline=median(curve(1:min(3,numel(curve))));contrast=(peak-baseline)/max(peak,eps);
suggestion.Value=index;suggestion.Score=contrast;suggestion.Available=true;
if contrast>.5&&index>2&&index<numel(curve)
 suggestion.Quality='Good';
elseif contrast>.15&&index>1
 suggestion.Quality='Acceptable';
else
 suggestion.Quality='Poor';
end
suggestion.Reason=sprintf('强增强且在前 2/3 序列达峰的有效区，平均信号在第 %d 帧最大；不重新计算基线。',index);
if strcmp(suggestion.Quality,'Poor'),suggestion.Reason='峰值位于序列端点或显影变化较弱，请手动选择参考帧。';end
suggestion.Metrics=struct('GlobalEnhancementCurve',data.Curve,'ScoredEnhancementCurve',curve,'Peak',peak,'Contrast',contrast,'SamplingStride',data.Stride);
end
