function fig=dsap_partition_view(r,fig)
% Partition review from saved arrays, without PNG export/readback.
    if nargin<2,fig=[];end
    p=r.partition;s=r.partition_stats;reference=r.reference_image;
    colors=[1 .55 .05;.05 .65 1];
    masks={{p.CortexMask,p.SubcortexMask}, ...
        {s.TICMasks{1},s.TICMasks{2},r.large_vessel_mask&~r.aif_mask,r.aif_mask&p.OuterMask}, ...
        {s.ParameterMasks{1},s.ParameterMasks{2},s.TICMasks{3}&~s.ParameterMasks{3}}};
    palettes={colors,[colors;1 .05 .1;0 1 1],[colors;.8 .3 1]};
    alphas={[.3 .3],[.3 .3 .65 .8],[.3 .3 .65]};
    if isempty(fig)||~isgraphics(fig)||~isappdata(fig,'DSAPPartitionView')
        if isempty(fig)||~isgraphics(fig)
        fig=figure('Name','皮层 / 皮层下分区与覆盖率','NumberTitle','off', ...
            'Visible','off','Color','w','Position',[30 30 1550 660]);
        end
        h.Layout=tiledlayout(fig,1,3,'Padding','compact','TileSpacing','compact');
        h.Axes=gobjects(1,3);h.Background=gobjects(1,3);h.Overlays=cell(1,3);h.Curves=gobjects(3,2);
        for k=1:3
            ax=nexttile(h.Layout);h.Axes(k)=ax;
            h.Background(k)=imshow(reference,[],'Parent',ax);hold(ax,'on');
            overlays=gobjects(1,numel(masks{k}));
            for j=1:numel(overlays)
                overlays(j)=imshow(repmat(reshape(palettes{k}(j,:),1,1,3),[size(reference) 1]),'Parent',ax);
            end
            h.Overlays{k}=overlays;
            h.Curves(k,1)=plot(ax,nan,nan,'y-','LineWidth',1.3);
            h.Curves(k,2)=plot(ax,nan,nan,'c-','LineWidth',1.3);
            dsap_style_axes(ax);
        end
        setappdata(fig,'DSAPPartitionView',h);
    end
    h=getappdata(fig,'DSAPPartitionView');
    for k=1:3
        ax=h.Axes(k);h.Background(k).CData=reference;
        h.Background(k).XData=[1 size(reference,2)];h.Background(k).YData=[1 size(reference,1)];
        limits=double([min(reference(:)) max(reference(:))]);if limits(1)==limits(2),limits=getrangefromclass(reference);end
        ax.CLim=limits;
        for j=1:numel(masks{k})
            im=h.Overlays{k}(j);
            if ~isequal(size(im.CData,1),size(reference,1))||~isequal(size(im.CData,2),size(reference,2))
                im.CData=repmat(reshape(palettes{k}(j,:),1,1,3),[size(reference) 1]);
            end
            im.XData=[1 size(reference,2)];im.YData=[1 size(reference,1)];
            im.AlphaData=single(masks{k}{j})*alphas{k}(j);
        end
        set(h.Curves(k,1),'XData',p.OuterCurve(:,1),'YData',p.OuterCurve(:,2));
        set(h.Curves(k,2),'XData',p.InnerCurve(:,1),'YData',p.InnerCurve(:,2));
        xlim(ax,[.5 size(reference,2)+.5]);ylim(ax,[p.CranialLimits.UpperRow-.5 p.CranialLimits.LowerRow+.5]);
    end
    title(h.Axes(1),{'人工确认的几何范围','橙：皮层带；蓝：皮层下（二维分区）'});
    title(h.Axes(2),{'TIC：分区内剔除血管 / AIF','弱信号保留；非有限输入另行排除'});
    title(h.Axes(3),sprintf('灌注有效覆盖：皮层 %.1f%% / 皮层下 %.1f%%\n紫色：计算无效，不按零灌注计入',s.Coverage.PerfusionCoveragePercent(1:2)));
    sgtitle(h.Layout,sprintf('手动上下限 %d–%d 行；分区互不重叠，合并后等于外轮廓范围',p.CranialLimits.UpperRow,p.CranialLimits.LowerRow));
end

