function dsap_workspace_frozen_roi(parent,reference,aif,limits,partition,imported)
t=dsap_theme;g=uigridlayout(parent,[2 1],'RowHeight',{45,'1x'},'Padding',t.Space.M);
uilabel(g,'Text','ROI 已锁定 · 只读','FontSize',t.Section,'FontWeight','bold','FontColor',t.Success);
ax=uiaxes(g);imshow(reference,[],'Parent',ax);hold(ax,'on');visboundaries(ax,aif,'Color',t.AIFColor);
if isempty(fieldnames(imported))
 if isfield(partition,'Mode')&&strcmp(partition.Mode,'Freehand'),masks=partition.Masks;
 else,masks={partition.OuterMask,partition.SubcortexMask};end
else,masks=imported.Masks;end
for k=1:numel(masks),visboundaries(ax,masks{k},'Color',t.TissueColor);end
yline(ax,limits.UpperRow,'--','Color',t.UpperLimitColor);yline(ax,limits.LowerRow,'--','Color',t.LowerLimitColor);
dsap_style_axes(ax);dsap_workspace_style(parent);
end
