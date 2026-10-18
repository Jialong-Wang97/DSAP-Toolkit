function h=dsap_prepare_cave_result_view(layout,tiles)
% Two display-only placeholders, prepared with Results before science.
t=dsap_theme;colors=[t.CAVEArteryColor;t.CAVEVeinColor];
h=struct('Axes',gobjects(2,1),'Backgrounds',gobjects(2,1),'Overlays',gobjects(2,1));
names={'CAVE 动脉','CAVE 静脉'};
for k=1:2
 ax=nexttile(layout,tiles(k));h.Axes(k)=ax;
 h.Backgrounds(k)=imshow(zeros(2,'single'),[],'Parent',ax);hold(ax,'on');
 h.Overlays(k)=image(ax,repmat(reshape(single(colors(k,:)),1,1,3),2,2));
 h.Overlays(k).AlphaData=zeros(2,'single');title(ax,names{k});
 colormap(ax,gray(256));axis(ax,'image','off');dsap_style_axes(ax);
end
end
