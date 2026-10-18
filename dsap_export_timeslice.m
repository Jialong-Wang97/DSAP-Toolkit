function dsap_export_timeslice(folder,reference,imported,stats,vessels,aif)
% Save immutable input masks and IDs alongside the masks used in computation.
    save(fullfile(folder,'TIMESlice_import_snapshot.mat'),'imported','stats');
    writetable(stats.Coverage,fullfile(folder,'TIMESlice_ROI_coverage.csv'));
    imwrite(aif,fullfile(folder,'TIMESlice_AIF_imported_mask.png'));
    for k=1:numel(imported.Masks)
        imwrite(imported.Masks{k},fullfile(folder,sprintf('TIMESlice_%02d_original_geometry.png',k)));
    end
    for k=1:numel(stats.Names)
        imwrite(stats.GeometryMasks{k},fullfile(folder,sprintf('TIMESlice_%02d_clipped_geometry.png',k)));
        imwrite(stats.TICMasks{k},fullfile(folder,sprintf('TIMESlice_%02d_TIC_mask.png',k)));
        imwrite(stats.ParameterMasks{k},fullfile(folder,sprintf('TIMESlice_%02d_perfusion_mask.png',k)));
    end
    fig=figure('Visible','off','Color','w','Position',[50 50 1400 700]);
    cleanup=onCleanup(@()dsap_safe_delete(fig)); %#ok<NASGU>
    layout=tiledlayout(fig,1,2);colors=lines(numel(imported.Masks));
    for panel=1:2
        ax=nexttile(layout);imshow(reference,[],'Parent',ax);hold(ax,'on');
        visboundaries(ax,aif,'Color',[1 .35 0],'LineWidth',1.5);
        for k=1:numel(imported.Masks)
            if panel==1,mask=imported.Masks{k};else,mask=stats.TICMasks{k};end
            visboundaries(ax,mask,'Color',colors(k,:),'LineWidth',1);
            [y,x]=find(mask);if ~isempty(x),text(ax,mean(x),mean(y),sprintf('ROI %d',k),'Color',colors(k,:),'BackgroundColor','k');end
        end
        if panel==1,title(ax,'导入的当前保存 ROI / AIF（未经血管排除）');
        else
            overlay=imshow(cat(3,zeros(size(vessels)),ones(size(vessels)),ones(size(vessels))),'Parent',ax);
            overlay.AlphaData=.35*single(vessels);title(ax,'上下限内 ROI；剔除 CAVE 血管及 AIF 后的 TIC 区域');
        end
    end
    exportgraphics(fig,fullfile(folder,'TIMESlice_import_review.png'),'Resolution',150);
end
