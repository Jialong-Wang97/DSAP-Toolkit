function shown=dsap_cave_result_view(r,view)
% Display the saved formal AV ROIs. No segmentation, relabelling, or mask derivation.
shown=false;h=getappdata(view.Perfusion,'DSAPCriticalView');
if ~isfield(h,'CAVE'),return;end % A pre-upgrade live view must be reopened.
c=h.CAVE;t=dsap_theme;names={'CAVE_Artery','CAVE_Vein'};titles={'CAVE 动脉','CAVE 静脉'};
ref=r.reference_image;shape=size(ref);range=double([min(ref(:)) max(ref(:))]);
if range(1)==range(2),range(2)=range(1)+1;end
available=isfield(r,'vessel_roi_results')&&isfield(r.vessel_roi_results,'Masks')&&isfield(r.vessel_roi_results,'Names');
for k=1:2
 c.Backgrounds(k).CData=ref;c.Backgrounds(k).XData=[1 shape(2)];c.Backgrounds(k).YData=[1 shape(1)];
 c.Axes(k).XLim=[.5 shape(2)+.5];c.Axes(k).YLim=[.5 shape(1)+.5];c.Axes(k).CLim=range;
 index=[];if available,index=find(strcmp(r.vessel_roi_results.Names,names{k}));end
 if numel(index)~=1
  c.Overlays(k).AlphaData=0;title(c.Axes(k),[titles{k} '（历史结果未保存）']);continue;
 end
 mask=r.vessel_roi_results.Masks{index};
 assert(islogical(mask)&&isequal(size(mask),shape),'DSAP:SavedCAVEMaskDimensions', ...
  '已保存的 %s mask 类型或尺寸无效；显示未执行 resize 或重新分割。',names{k});
 color=t.CAVEArteryColor;if k==2,color=t.CAVEVeinColor;end
 if ~isequal(size(c.Overlays(k).CData),[shape 3])
  c.Overlays(k).CData=repmat(reshape(single(color),1,1,3),[shape 1]);
 end
 c.Overlays(k).XData=[1 shape(2)];c.Overlays(k).YData=[1 shape(1)];
 c.Overlays(k).AlphaData=t.CAVEOverlayAlpha*single(mask);
 c.Axes(k).Title.String=titles{k};shown=true;
end
setappdata(view.Perfusion,'DSAPCAVEResultsShown',shown);
end
